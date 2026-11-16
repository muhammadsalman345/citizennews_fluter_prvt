import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../theme/app_colors.dart';
import 'ad_units.dart';
import 'ads_controller.dart';
import 'ads_scope.dart';

class CitizenNativeAd extends StatefulWidget {
  const CitizenNativeAd({super.key});

  @override
  State<CitizenNativeAd> createState() => _CitizenNativeAdState();
}

class _CitizenNativeAdState extends State<CitizenNativeAd> {
  NativeAd? _ad;
  bool _loaded = false;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ads = AdsScope.watch(context);
    if (ads.canServe && !_requested) _load(ads);
    if (!ads.canServe && _loaded) {
      _ad?.dispose();
      _ad = null;
      _loaded = false;
      _requested = false;
    }
  }

  void _load(AdsController ads) {
    _requested = true;
    _ad = NativeAd(
      adUnitId: activeAdUnits.native,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _ad = null;
          _requested = false;
          debugPrint('[CitizenNews AdMob] native load failed: $error');
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

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
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
                  onPressed: !ads.available ||
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
