import 'package:flutter/material.dart';

import '../../services/email_service.dart';

class EmailHandoffPanel extends StatelessWidget {
  const EmailHandoffPanel({
    super.key,
    required this.recentRecipients,
    this.selectedRecipients = const <String>[],
    this.onRecipientSelected,
    this.onRecipientRemoved,
    this.onSharePressed,
    this.onSaveMappingPressed,
    this.customerName,
    this.title = 'Email Handoff',
  });

  final List<RecentEmailRecipient> recentRecipients;
  final List<String> selectedRecipients;
  final ValueChanged<String>? onRecipientSelected;
  final ValueChanged<String>? onRecipientRemoved;
  final VoidCallback? onSharePressed;
  final VoidCallback? onSaveMappingPressed;
  final String? customerName;
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
                FilledButton.icon(
                  onPressed: onSharePressed,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Share PDF'),
                ),
              ],
            ),
            if (customerName != null) ...[
              const SizedBox(height: 8),
              Text('Customer: $customerName'),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedRecipients
                  .map(
                    (email) => InputChip(
                      label: Text(email),
                      onDeleted: onRecipientRemoved == null
                          ? null
                          : () => onRecipientRemoved!(email),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            Text(
              'Recent recipients',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (recentRecipients.isEmpty)
              const Text('No recent recipients saved yet.')
            else
              ...recentRecipients.map(
                (recipient) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(recipient.email),
                  subtitle: Text(
                    recipient.customer == null
                        ? 'Used ${recipient.usageCount} time(s)'
                        : '${recipient.customer} • used ${recipient.usageCount} time(s)',
                  ),
                  trailing: IconButton(
                    onPressed: onRecipientSelected == null
                        ? null
                        : () => onRecipientSelected!(recipient.email),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onSaveMappingPressed,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Save customer mapping'),
            ),
          ],
        ),
      ),
    );
  }
}
