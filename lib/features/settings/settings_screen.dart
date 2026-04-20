import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/section_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
      title: 'Workflow Preferences',
      subtitle: 'These settings align the UI to the current V1 tablet scope.',
      child: Column(
        children: [
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Lock landscape mode'),
            subtitle: const Text('Keep the UI optimized for 10-inch tablets.'),
            activeThumbColor: CtsPalette.orange,
          ),
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Compress images for report output'),
            subtitle: const Text(
              'Keeps PDFs readable without unnecessary file size.',
            ),
            activeThumbColor: CtsPalette.orange,
          ),
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Save recent email recipients'),
            subtitle: const Text(
              'Recent addresses stay available for handoff workflows.',
            ),
            activeThumbColor: CtsPalette.orange,
          ),
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Use branded industrial theme'),
            subtitle: const Text(
              'Deep navy, slate, and safety orange palette.',
            ),
            activeThumbColor: CtsPalette.orange,
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
      subtitle: 'Implementation choices for the current build.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The current UI is prepared for offline persistence, PDF generation, and email handoff in the next layer.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          const _Note(text: 'Public Sans headings with Inter body text.'),
          const _Note(text: 'Deep navy shell with orange safety accents.'),
          const _Note(
            text: 'Left navigation rail and three-panel editor layout.',
          ),
        ],
      ),
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
