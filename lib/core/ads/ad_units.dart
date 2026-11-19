import 'package:flutter/foundation.dart';

class AdUnits {
  const AdUnits({
    required this.banner,
    required this.native,
    required this.interstitial,
    required this.rewarded,
    required this.rewardedInterstitial,
    required this.appOpen,
  });

  final String banner;
  final String native;
  final String interstitial;
  final String rewarded;
  final String rewardedInterstitial;
  final String appOpen;
}

/// Debug/profile builds are safe by default while release builds use the
/// publisher units. The environment flag can still override either mode.
const useTestAds = bool.fromEnvironment(
  'ADMOB_USE_TEST_ADS',
  defaultValue: !kReleaseMode,
);

const googleAndroidTestAdUnits = AdUnits(
  banner: 'ca-app-pub-3940256099942544/9214589741',
  native: 'ca-app-pub-3940256099942544/2247696110',
  interstitial: 'ca-app-pub-3940256099942544/1033173712',
  rewardedInterstitial: 'ca-app-pub-3940256099942544/5354046379',
  rewarded: 'ca-app-pub-3940256099942544/5224354917',
  appOpen: 'ca-app-pub-3940256099942544/9257395921',
);

const citizenNewsProductionAdUnits = AdUnits(
  banner: 'ca-app-pub-1379075222012113/5547199430',
  native: 'ca-app-pub-1379075222012113/8361065030',
  interstitial: 'ca-app-pub-1379075222012113/8392854620',
  rewardedInterstitial: 'ca-app-pub-1379075222012113/9538415330',
  rewarded: 'ca-app-pub-1379075222012113/5926473381',
  appOpen: 'ca-app-pub-1379075222012113/6720680308',
);

const activeAdUnits = useTestAds
    ? googleAndroidTestAdUnits
    : citizenNewsProductionAdUnits;
