import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../theme/app_colors.dart';
import 'ad_units.dart';
import 'ads_controller.dart';
import 'ads_scope.dart';

Duration _adRetryDelay(int failures) => switch (failures) {
  <= 1 => const Duration(minutes: 2),
  2 => const Duration(minutes: 5),
  3 => const Duration(minutes: 10),
  _ => const Duration(minutes: 15),
};

class CitizenBannerAd extends StatefulWidget {
  const CitizenBannerAd({super.key});

  @override
  State<CitizenBannerAd> createState() => _CitizenBannerAdState();
}

class _CitizenBannerAdState extends State<CitizenBannerAd> {
  BannerAd? _ad;
  AdSize? _size;
  Timer? _retryTimer;
  bool _loaded = false;
  bool _requested = false;
  int _failures = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ads = AdsScope.watch(context);
    if (!ads.canServe) _reset();
  }

  void _scheduleLoad(AdsController ads, int width) {
    if (_requested || _retryTimer != null || width <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ads.canServe && !_requested && _retryTimer == null) {
        unawaited(_load(ads, width));
      }
    });
  }

  Future<void> _load(AdsController ads, int width) async {
    _requested = true;
    final size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width) ??
        AdSize.banner;
    if (!mounted || !ads.canServe) {
      _requested = false;
      return;
    }
    _size = size;
    final ad = BannerAd(
      adUnitId: activeAdUnits.banner,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          _failures = 0;
          _retryTimer?.cancel();
          _retryTimer = null;
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (failedAd, error) {
          failedAd.dispose();
          if (identical(_ad, failedAd)) _ad = null;
          _requested = false;
          _loaded = false;
          debugPrint('[CitizenNews AdMob] banner load failed: $error');
          _scheduleRetry(ads, width);
          if (mounted) setState(() {});
        },
        onAdClicked: (_) => ads.recordAdClick(),
      ),
    );
    _ad = ad;
    await ad.load();
  }

  void _scheduleRetry(AdsController ads, int width) {
    if (!mounted || !ads.canServe || _retryTimer != null) return;
    _failures++;
    _retryTimer = Timer(_adRetryDelay(_failures), () {
      _retryTimer = null;
      if (mounted && ads.canServe && !_requested) {
        unawaited(_load(ads, width));
      }
    });
  }

  void _reset() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _ad?.dispose();
    _ad = null;
    _size = null;
    _loaded = false;
    _requested = false;
    _failures = 0;
  }

  @override
  void dispose() {
    _reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ads = AdsScope.watch(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.floor()
            : MediaQuery.sizeOf(context).width.floor();
        if (ads.canServe) _scheduleLoad(ads, width);
        final ad = _ad;
        final size = _size;
        if (!_loaded || ad == null || size == null) {
          return const SizedBox.shrink();
        }
        return Semantics(
          label: 'Advertisement',
          child: Center(
            child: SizedBox(
              width: size.width.toDouble(),
              height: size.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
          ),
        );
      },
    );
  }
}

class CitizenNativeAd extends StatefulWidget {
  const CitizenNativeAd({super.key});

  @override
  State<CitizenNativeAd> createState() => _CitizenNativeAdState();
}

class _CitizenNativeAdState extends State<CitizenNativeAd> {
  NativeAd? _ad;
  Timer? _retryTimer;
  bool _loaded = false;
  bool _requested = false;
  int _failures = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ads = AdsScope.watch(context);
    if (ads.canServe && !_requested && _retryTimer == null) _load(ads);
    if (!ads.canServe) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _ad?.dispose();
      _ad = null;
      _loaded = false;
      _requested = false;
      _failures = 0;
    }
  }

  void _load(AdsController ads) {
    _requested = true;
    _ad = NativeAd(
      adUnitId: activeAdUnits.native,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          _failures = 0;
          _retryTimer?.cancel();
          _retryTimer = null;
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _ad = null;
          _requested = false;
          debugPrint('[CitizenNews AdMob] native load failed: $error');
          _scheduleRetry(ads);
          if (mounted) setState(() => _loaded = false);
        },
        onAdClicked: (_) => ads.recordAdClick(),
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: AppColors.paper,
        cornerRadius: 12,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: AppColors.red,
          style: NativeTemplateFontStyle.bold,
          size: 13,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.ink,
          style: NativeTemplateFontStyle.bold,
          size: 15,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.muted,
          style: NativeTemplateFontStyle.normal,
          size: 12,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.muted,
          style: NativeTemplateFontStyle.normal,
          size: 11,
        ),
      ),
    )..load();
  }

  void _scheduleRetry(AdsController ads) {
    if (!mounted || !ads.canServe || _retryTimer != null) return;
    _failures++;
    _retryTimer = Timer(_adRetryDelay(_failures), () {
      _retryTimer = null;
      if (mounted && ads.canServe && !_requested) _load(ads);
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ads = AdsScope.watch(context);
    if (!ads.canServe) return const SizedBox.shrink();
    if (!_loaded || _ad == null) {
      return const SizedBox(
        height: 115,
        child: Center(
          child: Text(
            'Advertisement',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ),
      );
    }
    return Semantics(
      label: 'Advertisement',
      child: Container(
        height: 115,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.paper,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}

class AdPreferencesCard extends StatelessWidget {
  const AdPreferencesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final ads = AdsScope.watch(context);
    if (!ads.supported) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.ads_click_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Advertising controls',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (ads.testMode)
                  const Chip(
                    label: Text('DEMO ADS'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ads.adFree
                  ? 'Ads are paused for this session period.'
                  : 'Watch an optional rewarded ad to pause ads for 30 minutes. This does not add points, money or wallet credit.',
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
            if (ads.message != null) ...[
              const SizedBox(height: 8),
              Text(ads.message!, style: const TextStyle(color: AppColors.red)),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed:
                      !ads.available ||
                          ads.adFree ||
                          ads.trafficProtected ||
                          ads.rewardedBusy ||
                          ads.fullScreen
                      ? null
                      : ads.showRewardedAd,
                  icon: ads.rewardedBusy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_circle_outline_rounded),
                  label: Text(
                    ads.adFree
                        ? 'Ads paused'
                        : ads.rewardedBusy
                        ? 'Loading ad...'
                        : 'Watch optional ad',
                  ),
                ),
                if (ads.privacyRequired)
                  OutlinedButton.icon(
                    onPressed: ads.showPrivacyOptions,
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: const Text('Ad privacy choices'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
