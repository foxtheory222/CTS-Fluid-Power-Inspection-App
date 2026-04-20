import 'package:flutter/material.dart';

class BackupImportExportPanel extends StatelessWidget {
  const BackupImportExportPanel({
    super.key,
    this.onExportPressed,
    this.onImportPressed,
    this.lastExportPath,
    this.lastImportPath,
    this.title = 'Backup and Restore',
  });

  final VoidCallback? onExportPressed;
  final VoidCallback? onImportPressed;
  final String? lastExportPath;
  final String? lastImportPath;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onExportPressed,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Export'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: onImportPressed,
                  icon: const Icon(Icons.unarchive_outlined),
                  label: const Text('Import'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (lastExportPath != null) Text('Last export: $lastExportPath'),
            if (lastImportPath != null) Text('Last import: $lastImportPath'),
            const SizedBox(height: 8),
            const Text(
              'Archives inspection JSON, photos, and PDF locally in a portable ZIP file.',
            ),
          ],
        ),
      ),
    );
  }
}
