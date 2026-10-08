import 'package:flutter/material.dart';

import '../models/app_language.dart';

/// Dropdown of languages. With [allowAuto], null means "detect automatically".
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.allowAuto = false,
    this.autoLabel = '自动检测',
  });

  final AppLanguage? value;
  final ValueChanged<AppLanguage?> onChanged;
  final bool allowAuto;
  final String autoLabel;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<AppLanguage?>(
      value: value,
      underline: const SizedBox.shrink(),
      onChanged: onChanged,
      items: [
        if (allowAuto) DropdownMenuItem(value: null, child: Text(autoLabel)),
        for (final language in AppLanguage.values)
          DropdownMenuItem(value: language, child: Text(language.label)),
      ],
    );
  }
}
