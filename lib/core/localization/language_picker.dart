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
    backgroundColor: AppColors.paper,
    builder: (sheetContext) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('language.choose'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            for (final language in AppLanguage.values)
              RadioListTile<AppLanguage>(
                value: language,
                groupValue: controller.language,
                contentPadding: EdgeInsets.zero,
                title: Text(language.nativeName),
                secondary: language.rtl
                    ? const Icon(Icons.format_textdirection_r_to_l_rounded)
                    : const Icon(Icons.translate_rounded),
                onChanged: (value) => Navigator.pop(sheetContext, value),
              ),
          ],
        ),
      ),
    ),
  );
  if (selected != null) await controller.setLanguage(selected);
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const Icon(Icons.language_rounded),
        title: Text(context.tr('language.title')),
        subtitle: Text(context.tr('language.subtitle')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              language.nativeName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: () => showLanguagePicker(context),
      ),
    );
  }
}
