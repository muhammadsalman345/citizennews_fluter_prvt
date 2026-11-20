import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_language.dart';
import 'app_localizations.dart';
import 'localization_scope.dart';

Future<void> showLanguagePicker(BuildContext context) async {
  final controller = LocalizationScope.read(context);
  final selected = await showModalBottomSheet<AppLanguage>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: AppColors.ink.withValues(alpha: .58),
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) => _LanguagePickerSheet(
      selected: controller.language,
      onSelected: (language) => Navigator.pop(sheetContext, language),
    ),
  );
  if (selected != null) await controller.setLanguage(selected);
}

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet({
    required this.selected,
    required this.onSelected,
  });

  final AppLanguage selected;
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
        heightFactor: .82,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0, end: 1),
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - value)),
              child: child,
            ),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECEE),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.language_rounded,
                        color: AppColors.red,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('language.choose'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Read CitizenNews in the language that feels natural to you.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip:
                          MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _LanguagePreview(language: selected),
                const SizedBox(height: 20),
                const Text(
                  'AVAILABLE LANGUAGES',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.25,
                  ),
                ),
                const SizedBox(height: 9),
                for (final language in AppLanguage.values) ...[
                  _LanguageOption(
                    language: language,
                    selected: language == selected,
                    onTap: () => onSelected(language),
                  ),
                  const SizedBox(height: 9),
                ],
                const SizedBox(height: 6),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.muted,
                      size: 17,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your selection changes app labels and reading direction. News stories remain in the language submitted by their reporter.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _LanguagePreview extends StatelessWidget {
  const _LanguagePreview({required this.language});

  final AppLanguage language;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF152431), Color(0xFF26394A)],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                language.code.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CURRENT LANGUAGE',
                    style: TextStyle(
                      color: Color(0xFFFF8A8A),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    language.nativeName,
                    textDirection:
                        language.rtl ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              language.rtl
                  ? Icons.format_textdirection_r_to_l_rounded
                  : Icons.format_textdirection_l_to_r_rounded,
              color: const Color(0xFFCBD5E1),
            ),
          ],
        ),
      );
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        label: language.nativeName,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFF3F4) : AppColors.paper,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? AppColors.red : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.red : AppColors.surface,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      language.code.toUpperCase(),
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      language.nativeName,
                      textDirection:
                          language.rtl ? TextDirection.rtl : TextDirection.ltr,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: selected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            key: ValueKey('selected'),
                            color: AppColors.red,
                          )
                        : Icon(
                            language.rtl
                                ? Icons.format_textdirection_r_to_l_rounded
                                : Icons.chevron_right_rounded,
                            key: ValueKey(language.code),
                            color: AppColors.muted,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class LanguageIconButton extends StatelessWidget {
  const LanguageIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    final language = LocalizationScope.watch(context).language;
    return Tooltip(
      message: context.tr('language.choose'),
      child: IconButton(
        onPressed: () => showLanguagePicker(context),
        icon: const Icon(Icons.language_rounded),
        visualDensity: VisualDensity.compact,
        selectedIcon: const Icon(Icons.language_rounded),
        isSelected: language != AppLanguage.english,
      ),
    );
  }
}

class LanguageSettingsCard extends StatelessWidget {
  const LanguageSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final language = LocalizationScope.watch(context).language;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showLanguagePicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.language_rounded, color: AppColors.red),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('language.title'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr('language.subtitle'),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                language.nativeName,
                style: const TextStyle(
                  color: AppColors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
