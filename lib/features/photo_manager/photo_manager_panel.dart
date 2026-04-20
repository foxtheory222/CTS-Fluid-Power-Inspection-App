import 'package:flutter/material.dart';

import '../../services/photo_service.dart';

class PhotoManagerPanel extends StatelessWidget {
  const PhotoManagerPanel({
    super.key,
    required this.photos,
    this.onCapturePressed,
    this.onGalleryPressed,
    this.onSamplePressed,
    this.onDeletePressed,
    this.emptyMessage = 'No photos added yet.',
    this.title = 'Photos',
  });

  final List<ManagedInspectionPhoto> photos;
  final VoidCallback? onCapturePressed;
  final VoidCallback? onGalleryPressed;
  final VoidCallback? onSamplePressed;
  final ValueChanged<ManagedInspectionPhoto>? onDeletePressed;
  final String emptyMessage;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                FilledButton.tonalIcon(
                  onPressed: onCapturePressed,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Camera'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onGalleryPressed,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
                OutlinedButton.icon(
                  onPressed: onSamplePressed,
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Sample'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (photos.isEmpty)
              _EmptyState(message: emptyMessage)
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: photos
                    .map(
                      (photo) => _PhotoTile(
                        photo: photo,
                        onDeletePressed: onDeletePressed,
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.onDeletePressed});

  final ManagedInspectionPhoto photo;
  final ValueChanged<ManagedInspectionPhoto>? onDeletePressed;

  @override
  Widget build(BuildContext context) {
    final fileName = photo.filePath.split(RegExp(r'[\\/]+')).last;
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(photo.caption.isEmpty ? 'No caption' : photo.caption),
              const SizedBox(height: 8),
              Text(
                '${photo.sectionKey} • ${photo.itemKey}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onDeletePressed == null
                      ? null
                      : () => onDeletePressed!(photo),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
