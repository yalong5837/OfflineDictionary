import 'package:flutter/material.dart';

import '../models/dictionary_entry.dart';

/// One dictionary entry: headword, reading and definition.
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    this.onSpeak,
    this.dense = false,
  });

  final DictionaryEntry entry;
  final VoidCallback? onSpeak;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = entry.alt == null
        ? entry.headword
        : '${entry.headword}（${entry.alt}）';
    return ListTile(
      dense: dense,
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: title, style: theme.textTheme.titleMedium),
            if (entry.reading != null)
              TextSpan(
                text: '  ${entry.reading}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
      subtitle: Text(
        entry.definition,
        maxLines: dense ? 2 : null,
        overflow: dense ? TextOverflow.ellipsis : null,
      ),
      trailing: onSpeak == null
          ? null
          : IconButton(
              tooltip: '朗读',
              icon: const Icon(Icons.volume_up_outlined),
              onPressed: onSpeak,
            ),
    );
  }
}
