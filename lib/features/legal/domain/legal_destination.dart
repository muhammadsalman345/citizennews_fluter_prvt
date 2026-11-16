class LegalDestination {
  const LegalDestination({
    required this.label,
    required this.path,
    required this.translationKey,
  });

  final String label;
  final String path;
  final String translationKey;
}

/// Public newsroom and policy links exposed by the Ionic site footer.
const legalDestinations = <LegalDestination>[
  LegalDestination(
    label: 'About',
    path: '/about',
    translationKey: 'legal.about',
  ),
  LegalDestination(
    label: 'Contact',
    path: '/contact',
    translationKey: 'legal.contact',
  ),
  LegalDestination(
    label: 'Editorial policy',
    path: '/editorial-policy',
    translationKey: 'legal.editorial',
  ),
  LegalDestination(
    label: 'Community guidelines',
    path: '/community-guidelines',
    translationKey: 'legal.community',
  ),
  LegalDestination(
    label: 'Privacy',
    path: '/privacy',
    translationKey: 'legal.privacy',
  ),
  LegalDestination(
    label: 'Terms',
    path: '/terms',
    translationKey: 'legal.terms',
  ),
  LegalDestination(
    label: 'Corrections',
    path: '/corrections-policy',
    translationKey: 'legal.corrections',
  ),
  LegalDestination(
    label: 'Content removal',
    path: '/content-removal',
    translationKey: 'legal.removal',
  ),
  LegalDestination(
    label: 'Copyright',
    path: '/copyright',
    translationKey: 'legal.copyright',
  ),
];
