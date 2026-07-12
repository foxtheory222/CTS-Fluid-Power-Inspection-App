import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/workspace_providers.dart';
import '../../widgets/section_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isImporting = false;

  Future<void> _importInspection() async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Choose a CTS inspection backup',
      type: FileType.custom,
      allowedExtensions: const <String>['zip'],
      allowMultiple: false,
    );
    final path = picked?.files.single.path;
    if (path == null || !mounted) {
      return;
    }
    setState(() => _isImporting = true);
    try {
      final imported = await ref
          .read(workspaceProvider)
          .importInspectionArchive(File(path));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported inspection ${imported.documentNumber} successfully.',
          ),
        ),
      );
      context.go('/inspection/${imported.id}', extra: imported);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to import this backup: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionCard(
            title: 'Settings',
            subtitle:
                'Tablet-safe local workflow settings and display preferences.',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                _SettingsChip(text: 'Offline-first'),
                _SettingsChip(text: 'Local storage only'),
                _SettingsChip(text: 'Landscape preferred'),
                _SettingsChip(text: 'Large touch targets'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: 'Restore Inspection',
            subtitle: 'Import a CTS inspection backup from this device.',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final description = Text(
                  'The imported record is restored locally. Document number conflicts are resolved without replacing the original.',
                  style: Theme.of(context).textTheme.bodyMedium,
                );
                final action = FilledButton.icon(
                  key: const Key('import-inspection-backup'),
                  onPressed: _isImporting ? null : _importInspection,
                  icon: _isImporting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.unarchive_outlined),
                  label: Text(_isImporting ? 'Importing…' : 'Choose backup'),
                );
                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [description, const SizedBox(height: 16), action],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: description),
                    const SizedBox(width: 16),
                    action,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1180;
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Expanded(child: _SettingsPanel()),
                        SizedBox(width: 18),
                        SizedBox(width: 360, child: _AboutPanel()),
                      ],
                    )
                  : const Column(
                      children: [
                        _SettingsPanel(),
                        SizedBox(height: 18),
                        _AboutPanel(),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'App Configuration',
      subtitle: 'Release safeguards that are active on this device.',
      child: Column(
        children: const [
          _ConfigurationRow(
            icon: Icons.screen_lock_rotation_outlined,
            title: 'Landscape tablet layout',
            subtitle:
                'The inspection workspace stays optimized for wide screens.',
          ),
          Divider(),
          _ConfigurationRow(
            icon: Icons.photo_size_select_large_outlined,
            title: 'Photo compression',
            subtitle:
                'Field photos are compressed before local storage and PDF use.',
          ),
          Divider(),
          _ConfigurationRow(
            icon: Icons.contact_mail_outlined,
            title: 'Recipient history',
            subtitle:
                'Recent addresses and customer mappings remain on this device.',
          ),
          Divider(),
          _ConfigurationRow(
            icon: Icons.cloud_off_outlined,
            title: 'Offline-only storage',
            subtitle: 'Inspections, media, reports, and exports stay local.',
          ),
        ],
      ),
    );
  }
}

class _AboutPanel extends StatelessWidget {
  const _AboutPanel();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'App Notes',
      subtitle: 'What this release is ready to do.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create, complete, duplicate, search, export, and share inspection reports without a network connection.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          const _Note(
            text: 'Completion blockers are enforced before final PDF sharing.',
          ),
          const _Note(text: 'Edits invalidate stale PDF and emailed status.'),
          const _Note(text: 'Photo and signature files are inspection-scoped.'),
        ],
      ),
    );
  }
}

class _ConfigurationRow extends StatelessWidget {
  const _ConfigurationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: CtsPalette.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: CtsPalette.success),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.check_circle, color: CtsPalette.success),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.fiber_manual_record,
            size: 10,
            color: CtsPalette.orange,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SettingsChip extends StatelessWidget {
  const _SettingsChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text),
      backgroundColor: CtsPalette.orange.withValues(alpha: 0.12),
      side: BorderSide(color: CtsPalette.orange.withValues(alpha: 0.24)),
    );
  }
}
