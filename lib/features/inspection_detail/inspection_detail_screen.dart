import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/workspace_models.dart';
import '../../core/workspace_providers.dart';
import '../../features/email/email_handoff_panel.dart';
import '../../services/email_service.dart';
import '../../widgets/photo_grid.dart';
import '../../widgets/section_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/signature_pad.dart';
import '../../data/models/inspection_enums.dart';

class InspectionDetailScreen extends ConsumerWidget {
  const InspectionDetailScreen({super.key, required this.inspectionId});

  final String inspectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(workspaceProvider);
    final inspection = controller.inspectionById(inspectionId);
    if (inspection == null) {
      return _NotFoundState(inspectionId: inspectionId);
    }

    Future<void> runAction(Future<void> Function() action) async {
      try {
        await action();
      } catch (error) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }

    Future<void> shareReport() async {
      await runAction(() async {
        var suggestions = const <RecentEmailRecipient>[];
        try {
          suggestions = await controller.emailRecipientSuggestions(
            inspection.customer,
          );
        } catch (_) {
          // Recipient history is optional; a storage issue must not block share.
        }
        if (!context.mounted) {
          return;
        }
        final recipients = await showModalBottomSheet<List<String>>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          constraints: const BoxConstraints(maxWidth: 720),
          builder: (context) => _EmailHandoffSheet(
            customer: inspection.customer,
            suggestions: suggestions,
          ),
        );
        if (recipients == null || !context.mounted) {
          return;
        }

        await controller.emailInspectionPdf(
          inspection.id,
          recipients: recipients,
        );
        if (!context.mounted) {
          return;
        }
        final sent = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Was the report sent?'),
            content: const Text(
              'Only confirm after the email or share app has finished sending the report.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not yet'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, mark emailed'),
              ),
            ],
          ),
        );
        if (sent == true) {
          await controller.confirmInspectionEmailed(inspection.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Report marked as emailed.')),
            );
          }
        }
      });
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailHeader(
            inspection: inspection,
            onEdit: () => context.go(
              '/inspection/${inspection.id}/edit',
              extra: inspection,
            ),
            onDuplicate: () {
              runAction(() async {
                final duplicate = await controller.duplicatePersistedInspection(
                  inspection,
                );
                if (context.mounted) {
                  context.go(
                    '/inspection/${duplicate.id}/edit',
                    extra: duplicate,
                  );
                }
              });
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1180;
              final details = _DetailSections(inspection: inspection);
              final side = _SideSummary(
                inspection: inspection,
                actionsEnabled:
                    inspection.status == InspectionStatus.complete ||
                    inspection.status == InspectionStatus.emailed,
                onGeneratePdf: () => runAction(() async {
                  final pdfFile = await controller.generatePdf(inspection.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('PDF generated at ${pdfFile.path}'),
                      ),
                    );
                  }
                }),
                onEmail: shareReport,
                onExport: () => runAction(() async {
                  final result = await controller.exportInspection(
                    inspection.id,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Inspection exported to ${result.archiveFile.path}',
                        ),
                      ),
                    );
                  }
                }),
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: details),
                    const SizedBox(width: 18),
                    SizedBox(width: 360, child: side),
                  ],
                );
              }
              return Column(
                children: [details, const SizedBox(height: 18), side],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmailHandoffSheet extends StatefulWidget {
  const _EmailHandoffSheet({required this.customer, required this.suggestions});

  final String customer;
  final List<RecentEmailRecipient> suggestions;

  @override
  State<_EmailHandoffSheet> createState() => _EmailHandoffSheetState();
}

class _EmailHandoffSheetState extends State<_EmailHandoffSheet> {
  final TextEditingController _recipientController = TextEditingController();
  final List<String> _selectedRecipients = <String>[];
  String? _recipientError;

  @override
  void dispose() {
    _recipientController.dispose();
    super.dispose();
  }

  bool _addRecipient([String? candidate]) {
    final email = (candidate ?? _recipientController.text).trim();
    if (email.isEmpty) {
      setState(() => _recipientError = null);
      return true;
    }
    if (!_looksLikeEmail(email)) {
      setState(() => _recipientError = 'Enter a valid email address.');
      return false;
    }
    setState(() {
      _recipientError = null;
      if (!_selectedRecipients.any(
        (existing) => existing.toLowerCase() == email.toLowerCase(),
      )) {
        _selectedRecipients.add(email);
      }
      _recipientController.clear();
    });
    return true;
  }

  void _continueToShare() {
    if (!_addRecipient()) {
      return;
    }
    Navigator.pop(context, List<String>.unmodifiable(_selectedRecipients));
  }

  bool _looksLikeEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmailHandoffPanel(
              title: 'Share inspection report',
              customerName: widget.customer,
              recentRecipients: widget.suggestions,
              selectedRecipients: _selectedRecipients,
              recipientController: _recipientController,
              recipientErrorText: _recipientError,
              onAddRecipient: _addRecipient,
              onRecipientSelected: _addRecipient,
              onRecipientRemoved: (email) {
                setState(() => _selectedRecipients.remove(email));
              },
              onSharePressed: _continueToShare,
            ),
            const SizedBox(height: 10),
            Text(
              'The selected share app controls final addressing and delivery. Recipient history remains on this device.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.inspection,
    required this.onEdit,
    required this.onDuplicate,
  });

  final InspectionSummary inspection;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [CtsPalette.navyAlt, CtsPalette.navy, Color(0xFF152947)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  StatusBadge.forInspection(inspection.status),
                  StatusBadge(
                    label: inspection.documentNumber,
                    color: CtsPalette.orangeSoft,
                    icon: Icons.confirmation_number_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                inspection.customer,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${inspection.assetName} · ${inspection.workOrderNumber}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _HeaderInfo(
                    label: 'Technician',
                    value: inspection.technicianName,
                  ),
                  _HeaderInfo(label: 'Site', value: inspection.siteLocation),
                  _HeaderInfo(
                    label: 'Servicing Shop',
                    value: inspection.servicingShop,
                  ),
                  _HeaderInfo(
                    label: 'Updated',
                    value: DateFormat(
                      'MMM d, h:mm a',
                    ).format(inspection.lastUpdatedAt),
                  ),
                ],
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                onPressed: onDuplicate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Duplicate'),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [details, const SizedBox(height: 18), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 18),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _HeaderInfo extends StatelessWidget {
  const _HeaderInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSections extends StatelessWidget {
  const _DetailSections({required this.inspection});

  final InspectionSummary inspection;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionCard(
          title: 'Inspection Summary',
          subtitle: 'High-level report details and current state.',
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _SummaryCard(
                label: 'Flagged',
                value: inspection.flaggedCount.toString(),
                color: CtsPalette.orange,
              ),
              _SummaryCard(
                label: 'At Risk',
                value: inspection.atRiskCount.toString(),
                color: CtsPalette.warning,
              ),
              _SummaryCard(
                label: 'Unsatisfactory',
                value: inspection.unsatisfactoryCount.toString(),
                color: CtsPalette.orangeSoft,
              ),
              _SummaryCard(
                label: 'Critical',
                value: inspection.criticalCount.toString(),
                color: CtsPalette.danger,
              ),
              _SummaryCard(
                label: 'Actions',
                value: inspection.actionItems.length.toString(),
                color: CtsPalette.info,
              ),
              _SummaryCard(
                label: 'Photos',
                value: inspection.photoCount.toString(),
                color: CtsPalette.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'Section Overview',
          subtitle:
              'Completion state and photo coverage across the fixed inspection flow.',
          child: Column(
            children: [
              for (final section in inspection.sections) ...[
                _SectionRow(section: section),
                if (section != inspection.sections.last)
                  const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'Action Items',
          subtitle: 'Auto-generated and manually tracked follow-up work.',
          child: Column(
            children: [
              if (inspection.actionItems.isEmpty)
                _EmptyMessage(
                  icon: Icons.task_alt_outlined,
                  title: 'No action items',
                  body: 'This report currently has no open follow-up work.',
                )
              else
                for (final action in inspection.actionItems) ...[
                  _ActionCard(action: action),
                  if (action != inspection.actionItems.last)
                    const SizedBox(height: 12),
                ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'Media Summary',
          subtitle:
              'Photos embedded in the report and stored locally on the device.',
          child: PhotoGrid(photos: inspection.photos),
        ),
      ],
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.section});

  final InspectionSectionView section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _stateColor(
                section.completionState,
              ).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _stateIcon(section.completionState),
              color: _stateColor(section.completionState),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  section.summary,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusChip(
                text: section.completionState.label,
                color: _stateColor(section.completionState),
              ),
              const SizedBox(height: 6),
              Text(
                '${section.photoCount} photo${section.photoCount == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _stateColor(SectionCompletionState state) {
    switch (state) {
      case SectionCompletionState.complete:
        return CtsPalette.success;
      case SectionCompletionState.inProgress:
        return CtsPalette.orange;
      case SectionCompletionState.blocked:
        return CtsPalette.danger;
      case SectionCompletionState.notStarted:
        return CtsPalette.slate;
    }
  }

  IconData _stateIcon(SectionCompletionState state) {
    switch (state) {
      case SectionCompletionState.complete:
        return Icons.check_circle_outline;
      case SectionCompletionState.inProgress:
        return Icons.timelapse_outlined;
      case SectionCompletionState.blocked:
        return Icons.warning_amber_rounded;
      case SectionCompletionState.notStarted:
        return Icons.radio_button_unchecked;
    }
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});

  final InspectionActionItemView action;

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
                    action.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StatusBadge.forCondition(action.conditionRating),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              action.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tag(
                  text: action.sourceSection,
                  icon: Icons.view_agenda_outlined,
                ),
                _Tag(text: action.sourceItem, icon: Icons.label_outline),
                if (action.partsRequired != null)
                  _Tag(
                    text: action.partsRequired!,
                    icon: Icons.construction_outlined,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: CtsPalette.orange),
      label: Text(text),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SideSummary extends StatelessWidget {
  const _SideSummary({
    required this.inspection,
    required this.actionsEnabled,
    required this.onGeneratePdf,
    required this.onEmail,
    required this.onExport,
  });

  final InspectionSummary inspection;
  final bool actionsEnabled;
  final VoidCallback onGeneratePdf;
  final VoidCallback onEmail;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Report Actions',
      subtitle: 'Generate, share, and complete this inspection.',
      child: Column(
        children: [
          _ActionButton(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Generate PDF',
            subtitle: actionsEnabled
                ? 'Create the branded local report.'
                : 'Complete the inspection before generating a final report.',
            onTap: actionsEnabled ? onGeneratePdf : null,
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.email_outlined,
            title: 'Share report',
            subtitle: actionsEnabled
                ? 'Open email or another device share app.'
                : 'Complete the inspection before sharing.',
            onTap: actionsEnabled ? onEmail : null,
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.file_download_outlined,
            title: 'Export inspection',
            subtitle: 'Bundle PDF and restore data locally.',
            onTap: onExport,
          ),
          const SizedBox(height: 16),
          _SummaryMini(
            label: 'Completed',
            value: inspection.completedAt == null
                ? 'Not yet'
                : DateFormat('MMM d, h:mm a').format(inspection.completedAt!),
          ),
          _SummaryMini(
            label: 'Emailed',
            value: inspection.emailedAt == null
                ? 'Pending'
                : DateFormat('MMM d, h:mm a').format(inspection.emailedAt!),
          ),
          _SummaryMini(
            label: 'PDF',
            value: inspection.generatedPdfPath ?? 'Generate locally',
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: onTap == null
              ? Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.52)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: CtsPalette.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: onTap == null
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : CtsPalette.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMini extends StatelessWidget {
  const _SummaryMini({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CtsPalette.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: CtsPalette.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotFoundState extends StatelessWidget {
  const _NotFoundState({required this.inspectionId});

  final String inspectionId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SectionCard(
        title: 'Inspection not found',
        subtitle: 'No inspection exists for ID $inspectionId.',
        child: FilledButton(
          onPressed: () => context.go('/inspections'),
          child: const Text('Back to list'),
        ),
      ),
    );
  }
}
