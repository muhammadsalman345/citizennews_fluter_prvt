import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_units.dart';
import 'ads_policy.dart';

class AdsController extends ChangeNotifier with WidgetsBindingObserver {
  static const _prefix = 'cn-ad-limits-';

  bool _available = false;
  bool _starting = false;
  bool _started = false;
  bool _stateRestored = false;
  bool _sessionCounted = false;
  bool _observingLifecycle = false;
  bool _privacyRequired = false;
  bool _blocked = false;
  bool _fullScreen = false;
  bool _rewardedBusy = false;
  String _route = '';
  String? _message;

  Timer? _articleTimer;
  Timer? _adFreeTimer;
  Timer? _trafficProtectionTimer;
  bool _articleQualified = false;
  int _qualifiedArticles = 0;
  int _dailyInterstitials = 0;
  String _interstitialDay = '';
  DateTime? _lastInterstitial;
  DateTime? _adFreeUntil;
  DateTime? _trafficProtectedUntil;
  int _clicks = 0;
  DateTime? _clickWindowStarted;

  int _sessions = 0;
  int _dailyAppOpen = 0;
  String _appOpenDay = '';
  DateTime? _lastAppOpen;
  DateTime? _backgroundAt;
  DateTime? _appOpenLoadedAt;

  InterstitialAd? _interstitial;
  AppOpenAd? _appOpen;
  Timer? _interstitialRetryTimer;
  Timer? _appOpenRetryTimer;
  int _interstitialFailures = 0;
  int _appOpenFailures = 0;

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get available => _available;
  bool get testMode => useTestAds;
  bool get privacyRequired => _privacyRequired;
  bool get blocked => _blocked;
  bool get fullScreen => _fullScreen;
  bool get rewardedBusy => _rewardedBusy;
  String? get message => _message;
  bool get adFree =>
      _adFreeUntil != null && _adFreeUntil!.isAfter(DateTime.now());
  bool get trafficProtected =>
      _trafficProtectedUntil != null &&
      _trafficProtectedUntil!.isAfter(DateTime.now());
  bool get canServe =>
      supported &&
      _available &&
      !_blocked &&
      !_fullScreen &&
      !adFree &&
      !trafficProtected &&
      AdsPolicy.canShowInlineAdsOnRoute(_route);

  /// Push/deep-link or other sensitive flows can temporarily suppress ads.
  void setBlocked(bool blocked) {
    if (_blocked == blocked) return;
    _blocked = blocked;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_started || _starting || !supported) return;
    _starting = true;
    try {
      if (!_observingLifecycle) {
        WidgetsBinding.instance.addObserver(this);
        _observingLifecycle = true;
      }
      if (!_stateRestored) {
        await _restore();
        _stateRestored = true;
      }
      if (!_sessionCounted) {
        _sessions++;
        _sessionCounted = true;
        await _persist();
      }
      if (!useTestAds) {
        await _gatherConsent();
        if (!await ConsentInformation.instance.canRequestAds()) {
          _message = 'Ads are waiting for a privacy consent decision.';
          return;
        }
      }
      await MobileAds.instance.initialize();
      _available = true;
      _started = true;
    } catch (error) {
      _available = false;
      _message = 'AdMob could not start. Check the network and consent setup.';
      debugPrint('[CitizenNews AdMob] startup failed: $error');
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  Future<void> _gatherConsent() async {
    final update = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => update.complete(),
      (error) => update.completeError(error),
    );
    try {
      await update.future;
      final form = Completer<void>();
      ConsentForm.loadAndShowConsentFormIfRequired((error) {
        if (error == null) {
          form.complete();
        } else {
          form.completeError(error);
        }
      });
      await form.future;
    } catch (error) {
      // Google recommends checking canRequestAds even when refreshing consent
      // fails because an earlier valid decision may still permit requests.
      debugPrint('[CitizenNews AdMob] consent refresh failed: $error');
    }
    await _refreshPrivacyRequirement();
  }

  Future<void> _refreshPrivacyRequirement() async {
    if (useTestAds) {
      _privacyRequired = false;
      return;
    }
    _privacyRequired =
        await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  }

  Future<void> showPrivacyOptions() async {
    if (!supported || useTestAds) return;
    final result = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((error) {
      if (error == null) {
        result.complete();
      } else {
        result.completeError(error);
      }
    });
    try {
      await result.future;
      await _refreshPrivacyRequirement();
      _available = await ConsentInformation.instance.canRequestAds();
      if (_available && !_started) await initialize();
      _message = null;
    } catch (error) {
      _message = 'Ad privacy choices are unavailable. Please try again.';
      debugPrint('[CitizenNews AdMob] privacy options failed: $error');
    }
    notifyListeners();
  }

  void setRoute(String route) {
    if (_route == route) return;
    final leftQualifiedArticle =
        _route.startsWith('/news/') && _articleQualified;
    _articleTimer?.cancel();
    _route = route;
    _articleQualified = false;
    if (leftQualifiedArticle) {
      _qualifiedArticles++;
      unawaited(_persist());
      unawaited(_maybeShowInterstitial());
    }
    if (route.startsWith('/news/')) {
      _articleTimer = Timer(AdsPolicy.qualifyingReadTime, () {
        if (_route.startsWith('/news/')) _articleQualified = true;
      });
      if (_qualifiedArticles >= AdsPolicy.articlesBetweenInterstitials - 1) {
        _loadInterstitial();
      }
    }
  }

  void _loadInterstitial() {
    _resetDailyCounters();
    if (!_shouldPrepareInterstitial || _interstitial != null) return;
    InterstitialAd.load(
      adUnitId: activeAdUnits.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialFailures = 0;
          _interstitialRetryTimer?.cancel();
          _interstitialRetryTimer = null;
          _interstitial = ad;
          if (_qualifiedArticles >= AdsPolicy.articlesBetweenInterstitials &&
              AdsPolicy.isPublicDiscoveryRoute(_route)) {
            unawaited(_maybeShowInterstitial());
          }
        },
        onAdFailedToLoad: (error) {
          _interstitial = null;
          debugPrint('[CitizenNews AdMob] interstitial load failed: $error');
          _scheduleInterstitialRetry();
        },
      ),
    );
  }

  void _scheduleInterstitialRetry() {
    if (!_shouldPrepareInterstitial || _interstitialRetryTimer != null) return;
    _interstitialFailures++;
    _interstitialRetryTimer = Timer(_retryDelay(_interstitialFailures), () {
      _interstitialRetryTimer = null;
      _loadInterstitial();
    });
  }

  Future<void> _maybeShowInterstitial() async {
    _resetDailyCounters();
    final now = DateTime.now();
    final cooldownPassed =
        _lastInterstitial == null ||
        now.difference(_lastInterstitial!) >= AdsPolicy.interstitialCooldown;
    if (!_available ||
        adFree ||
        trafficProtected ||
        _fullScreen ||
        _blocked ||
        !AdsPolicy.isPublicDiscoveryRoute(_route) ||
        _qualifiedArticles < AdsPolicy.articlesBetweenInterstitials ||
        _dailyInterstitials >= AdsPolicy.interstitialDailyLimit ||
        !cooldownPassed) {
      return;
    }
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    _fullScreen = true;
    _lastInterstitial = now;
    _dailyInterstitials++;
    _qualifiedArticles = 0;
    await _persist();
    notifyListeners();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdClicked: (_) => recordAdClick(),
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _finishFullScreen();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        debugPrint('[CitizenNews AdMob] interstitial show failed: $error');
        _finishFullScreen();
      },
    );
    ad.show();
  }

  Future<bool> showRewardedAd() async {
    if (!_available ||
        _rewardedBusy ||
        _fullScreen ||
        adFree ||
        trafficProtected) {
      return false;
    }
    _rewardedBusy = true;
    _message = null;
    notifyListeners();
    final result = Completer<bool>();
    var rewardEarned = false;
    RewardedAd.load(
      adUnitId: activeAdUnits.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _fullScreen = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdClicked: (_) => recordAdClick(),
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedBusy = false;
              _finishFullScreen();
              if (!result.isCompleted) result.complete(rewardEarned);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedBusy = false;
              _message = 'Rewarded ad is unavailable. Please try again later.';
              _finishFullScreen();
              if (!result.isCompleted) result.complete(false);
            },
          );
          ad.show(
            onUserEarnedReward: (_, reward) {
              if (reward.amount <= 0) return;
              rewardEarned = true;
              _adFreeUntil = DateTime.now().add(AdsPolicy.rewardedAdFreeTime);
              _scheduleAdFreeExpiry();
              unawaited(_persist());
              notifyListeners();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _rewardedBusy = false;
          _message = 'Rewarded ad is unavailable. Please try again later.';
          debugPrint('[CitizenNews AdMob] rewarded load failed: $error');
          notifyListeners();
          result.complete(false);
        },
      ),
    );
    return result.future;
  }

  void _loadAppOpen() {
    _resetDailyCounters();
    final now = DateTime.now();
    final cooldownPassed =
        _lastAppOpen == null ||
        now.difference(_lastAppOpen!) >= AdsPolicy.appOpenCooldown;
    if (!_available ||
        _backgroundAt == null ||
        _sessions < AdsPolicy.appOpenMinimumSessions ||
        adFree ||
        trafficProtected ||
        _blocked ||
        _fullScreen ||
        _dailyAppOpen >= AdsPolicy.appOpenDailyLimit ||
        !cooldownPassed ||
        _appOpen != null) {
      return;
    }
    AppOpenAd.load(
      adUnitId: activeAdUnits.appOpen,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenFailures = 0;
          _appOpenRetryTimer?.cancel();
          _appOpenRetryTimer = null;
          _appOpen = ad;
          _appOpenLoadedAt = DateTime.now();
        },
        onAdFailedToLoad: (error) {
          _appOpen = null;
          debugPrint('[CitizenNews AdMob] app-open load failed: $error');
          _scheduleAppOpenRetry();
        },
      ),
    );
  }

  void _scheduleAppOpenRetry() {
    if (!_available || _backgroundAt == null || _appOpenRetryTimer != null) {
      return;
    }
    _appOpenFailures++;
    _appOpenRetryTimer = Timer(_retryDelay(_appOpenFailures), () {
      _appOpenRetryTimer = null;
      _loadAppOpen();
    });
  }

  Duration _retryDelay(int failures) => switch (failures) {
    <= 1 => const Duration(seconds: 30),
    2 => const Duration(minutes: 1),
    3 => const Duration(minutes: 2),
    4 => const Duration(minutes: 4),
    _ => const Duration(minutes: 5),
  };

  Future<void> _maybeShowAppOpen() async {
    _resetDailyCounters();
    final now = DateTime.now();
    final backgroundAt = _backgroundAt;
    _backgroundAt = null;
    _appOpenRetryTimer?.cancel();
    _appOpenRetryTimer = null;
    final loadedAt = _appOpenLoadedAt;
    if (loadedAt != null &&
        now.difference(loadedAt) >= AdsPolicy.appOpenMaxCache) {
      _appOpen?.dispose();
      _appOpen = null;
      _appOpenLoadedAt = null;
    }
    final cooldownPassed =
        _lastAppOpen == null ||
        now.difference(_lastAppOpen!) >= AdsPolicy.appOpenCooldown;
    final backgroundQualified =
        backgroundAt != null &&
        now.difference(backgroundAt) >= AdsPolicy.appOpenMinimumBackground;
    final ad = _appOpen;
    if (!_available ||
        ad == null ||
        adFree ||
        trafficProtected ||
        _blocked ||
        _fullScreen ||
        !AdsPolicy.isPublicDiscoveryRoute(_route) ||
        !backgroundQualified ||
        !cooldownPassed ||
        _dailyAppOpen >= AdsPolicy.appOpenDailyLimit) {
      return;
    }
    _appOpen = null;
    _appOpenLoadedAt = null;
    _fullScreen = true;
    _lastAppOpen = now;
    _dailyAppOpen++;
    await _persist();
    notifyListeners();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdClicked: (_) => recordAdClick(),
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _finishFullScreen();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        debugPrint('[CitizenNews AdMob] app-open show failed: $error');
        _finishFullScreen();
      },
    );
    ad.show();
  }

  void _finishFullScreen() {
    _fullScreen = false;
    notifyListeners();
  }

  void recordAdClick() {
    final now = DateTime.now();
    if (_clickWindowStarted == null ||
        now.difference(_clickWindowStarted!) > const Duration(minutes: 10)) {
      _clickWindowStarted = now;
      _clicks = 0;
    }
    _clicks++;
    if (_clicks >= 3) {
      _trafficProtectedUntil = now.add(const Duration(minutes: 10));
      _scheduleProtectionExpiry();
      _clicks = 0;
      _clickWindowStarted = null;
      notifyListeners();
    }
    unawaited(_persist());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundAt ??= DateTime.now();
      _loadAppOpen();
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_maybeShowAppOpen());
    }
  }

  void _resetDailyCounters() {
    final day = _dayKey(DateTime.now());
    if (_interstitialDay != day) {
      _interstitialDay = day;
      _dailyInterstitials = 0;
    }
    if (_appOpenDay != day) {
      _appOpenDay = day;
      _dailyAppOpen = 0;
    }
  }

  bool get _shouldPrepareInterstitial =>
      _available &&
      !adFree &&
      !trafficProtected &&
      !_blocked &&
      !_fullScreen &&
      _qualifiedArticles >= AdsPolicy.articlesBetweenInterstitials - 1 &&
      _dailyInterstitials < AdsPolicy.interstitialDailyLimit;

  String _dayKey(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    _qualifiedArticles = preferences.getInt('${_prefix}articles') ?? 0;
    _dailyInterstitials =
        preferences.getInt('${_prefix}interstitial-count') ?? 0;
    _interstitialDay =
        preferences.getString('${_prefix}interstitial-day') ?? '';
    _sessions = preferences.getInt('${_prefix}sessions') ?? 0;
    _dailyAppOpen = preferences.getInt('${_prefix}app-open-count') ?? 0;
    _appOpenDay = preferences.getString('${_prefix}app-open-day') ?? '';
    _clicks = preferences.getInt('${_prefix}clicks') ?? 0;
    _lastInterstitial = _savedDate(preferences, 'last-interstitial');
    _lastAppOpen = _savedDate(preferences, 'last-app-open');
    _adFreeUntil = _savedDate(preferences, 'ad-free-until');
    _trafficProtectedUntil = _savedDate(preferences, 'protected-until');
    _clickWindowStarted = _savedDate(preferences, 'click-window');
    _resetDailyCounters();
    _scheduleAdFreeExpiry();
    _scheduleProtectionExpiry();
  }

  void _scheduleAdFreeExpiry() {
    _adFreeTimer?.cancel();
    final until = _adFreeUntil;
    if (until == null || !until.isAfter(DateTime.now())) return;
    _adFreeTimer = Timer(until.difference(DateTime.now()), () {
      _adFreeUntil = null;
      unawaited(_persist());
      notifyListeners();
    });
  }

  void _scheduleProtectionExpiry() {
    _trafficProtectionTimer?.cancel();
    final until = _trafficProtectedUntil;
    if (until == null || !until.isAfter(DateTime.now())) return;
    _trafficProtectionTimer = Timer(until.difference(DateTime.now()), () {
      _trafficProtectedUntil = null;
      unawaited(_persist());
      notifyListeners();
    });
  }

  DateTime? _savedDate(SharedPreferences preferences, String key) {
    final milliseconds = preferences.getInt('$_prefix$key');
    return milliseconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setInt('${_prefix}articles', _qualifiedArticles),
      preferences.setInt('${_prefix}interstitial-count', _dailyInterstitials),
      preferences.setString('${_prefix}interstitial-day', _interstitialDay),
      preferences.setInt('${_prefix}sessions', _sessions),
      preferences.setInt('${_prefix}app-open-count', _dailyAppOpen),
      preferences.setString('${_prefix}app-open-day', _appOpenDay),
      preferences.setInt('${_prefix}clicks', _clicks),
      _saveDate(preferences, 'last-interstitial', _lastInterstitial),
      _saveDate(preferences, 'last-app-open', _lastAppOpen),
      _saveDate(preferences, 'ad-free-until', _adFreeUntil),
      _saveDate(preferences, 'protected-until', _trafficProtectedUntil),
      _saveDate(preferences, 'click-window', _clickWindowStarted),
    ]);
  }

  Future<bool> _saveDate(
    SharedPreferences preferences,
    String key,
    DateTime? value,
  ) => value == null
      ? preferences.remove('$_prefix$key')
      : preferences.setInt('$_prefix$key', value.millisecondsSinceEpoch);

  @override
  void dispose() {
    if (_observingLifecycle) WidgetsBinding.instance.removeObserver(this);
    _articleTimer?.cancel();
    _adFreeTimer?.cancel();
    _trafficProtectionTimer?.cancel();
    _interstitialRetryTimer?.cancel();
    _appOpenRetryTimer?.cancel();
    _interstitial?.dispose();
    _appOpen?.dispose();
    super.dispose();
  }
}
