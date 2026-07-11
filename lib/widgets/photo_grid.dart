import 'dart:io';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/workspace_models.dart';

class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    super.key,
    required this.photos,
    this.emptyLabel = 'No photos added yet.',
    this.onAddPhoto,
    this.addButtonKey,
    this.onRemovePhoto,
  });

  final List<InspectionPhotoView> photos;
  final String emptyLabel;
  final VoidCallback? onAddPhoto;
  final Key? addButtonKey;
  final ValueChanged<InspectionPhotoView>? onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final items = List<InspectionPhotoView>.of(photos);
    if (items.isEmpty) {
      return _EmptyPhotoState(
        label: emptyLabel,
        onAddPhoto: onAddPhoto,
        addButtonKey: addButtonKey,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 840
            ? 3
            : constraints.maxWidth >= 540
            ? 2
            : 1;
        return GridView.builder(
          itemCount: items.length + (onAddPhoto == null ? 0 : 1),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.08,
          ),
          itemBuilder: (context, index) {
            if (index == items.length) {
              return _AddPhotoCard(
                onAddPhoto: onAddPhoto!,
                addButtonKey: addButtonKey,
              );
            }
            final photo = items[index];
            return _PhotoCard(
              photo: photo,
              index: index + 1,
              onRemovePhoto: onRemovePhoto,
            );
          },
        );
      },
    );
  }
}

class _AddPhotoCard extends StatelessWidget {
  const _AddPhotoCard({required this.onAddPhoto, this.addButtonKey});

  final VoidCallback onAddPhoto;
  final Key? addButtonKey;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        key: addButtonKey,
        borderRadius: BorderRadius.circular(20),
        onTap: onAddPhoto,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: CtsPalette.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.add_a_photo_outlined,
                  color: CtsPalette.orange,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Add photo',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.photo,
    required this.index,
    this.onRemovePhoto,
  });

  final InspectionPhotoView photo;
  final int index;
  final ValueChanged<InspectionPhotoView>? onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _PhotoImage(path: photo.assetPath),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.02),
                          Colors.black.withValues(alpha: 0.35),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '#$index',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (onRemovePhoto != null)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton.filled(
                        tooltip: 'Remove ${photo.caption}',
                        onPressed: () => onRemovePhoto!(photo),
                        icon: const Icon(Icons.delete_outline),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.68),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photo.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '${photo.sectionTitle} · ${photo.itemLabel}',
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

class _PhotoImage extends StatelessWidget {
  const _PhotoImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('/') || path.startsWith('file:')) {
      return Image.file(
        File(path.replaceFirst('file://', '')),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const _MissingPhoto(),
      );
    }
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const _MissingPhoto(),
    );
  }
}

class _MissingPhoto extends StatelessWidget {
  const _MissingPhoto();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined, color: CtsPalette.slate),
    );
  }
}

class _EmptyPhotoState extends StatelessWidget {
  const _EmptyPhotoState({
    required this.label,
    this.onAddPhoto,
    this.addButtonKey,
  });

  final String label;
  final VoidCallback? onAddPhoto;
  final Key? addButtonKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: CtsPalette.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.photo_library_outlined,
              color: CtsPalette.orange,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (onAddPhoto != null) ...[
            const SizedBox(width: 14),
            OutlinedButton.icon(
              key: addButtonKey,
              onPressed: onAddPhoto,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add photo'),
            ),
          ],
        ],
      ),
    );
  }
}
