import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../core/file_utils.dart';
import '../data/models/inspection_models.dart';

enum PhotoInputSource { camera, gallery, sampleOne, sampleTwo }

enum ManagedPhotoSource { camera, gallery, sampleAsset, imported }

@immutable
class ManagedInspectionPhoto {
  const ManagedInspectionPhoto({
    required this.filePath,
    required this.sectionKey,
    required this.itemKey,
    required this.caption,
    required this.capturedAt,
    required this.sortOrder,
    required this.source,
    this.originalFileName,
    this.byteLength,
  });

  final String filePath;
  final String sectionKey;
  final String itemKey;
  final String caption;
  final DateTime capturedAt;
  final int sortOrder;
  final ManagedPhotoSource source;
  final String? originalFileName;
  final int? byteLength;

  Map<String, Object?> toJson() => <String, Object?>{
    'filePath': filePath,
    'sectionKey': sectionKey,
    'itemKey': itemKey,
    'caption': caption,
    'capturedAt': capturedAt.toIso8601String(),
    'sortOrder': sortOrder,
    'source': source.name,
    'originalFileName': originalFileName,
    'byteLength': byteLength,
  };

  factory ManagedInspectionPhoto.fromJson(Map<String, Object?> json) {
    return ManagedInspectionPhoto(
      filePath: json['filePath'] as String? ?? '',
      sectionKey: json['sectionKey'] as String? ?? '',
      itemKey: json['itemKey'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      capturedAt:
          DateTime.tryParse(json['capturedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      source: _parseManagedPhotoSource(json['source'] as String?),
      originalFileName: json['originalFileName'] as String?,
      byteLength: (json['byteLength'] as num?)?.toInt(),
    );
  }

  ManagedInspectionPhoto copyWith({
    String? filePath,
    String? sectionKey,
    String? itemKey,
    String? caption,
    DateTime? capturedAt,
    int? sortOrder,
    ManagedPhotoSource? source,
    String? originalFileName,
    int? byteLength,
  }) {
    return ManagedInspectionPhoto(
      filePath: filePath ?? this.filePath,
      sectionKey: sectionKey ?? this.sectionKey,
      itemKey: itemKey ?? this.itemKey,
      caption: caption ?? this.caption,
      capturedAt: capturedAt ?? this.capturedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      source: source ?? this.source,
      originalFileName: originalFileName ?? this.originalFileName,
      byteLength: byteLength ?? this.byteLength,
    );
  }

  static ManagedPhotoSource _parseManagedPhotoSource(String? value) {
    for (final source in ManagedPhotoSource.values) {
      if (source.name == value) {
        return source;
      }
    }
    return ManagedPhotoSource.imported;
  }
}

@immutable
class PhotoBatchResult {
  const PhotoBatchResult({
    required this.savedPhotos,
    required this.skippedCount,
    required this.truncated,
  });

  final List<ManagedInspectionPhoto> savedPhotos;
  final int skippedCount;
  final bool truncated;

  int get savedCount => savedPhotos.length;
  bool get isEmpty => savedPhotos.isEmpty;

  static const empty = PhotoBatchResult(
    savedPhotos: <ManagedInspectionPhoto>[],
    skippedCount: 0,
    truncated: false,
  );
}

class PhotoServiceException implements Exception {
  PhotoServiceException(this.message, {required this.code});

  factory PhotoServiceException.cancelled(String message) =>
      PhotoServiceException(message, code: PhotoServiceErrorCode.cancelled);

  factory PhotoServiceException.limitReached(String message) =>
      PhotoServiceException(message, code: PhotoServiceErrorCode.limitReached);

  factory PhotoServiceException.notFound(String message) =>
      PhotoServiceException(message, code: PhotoServiceErrorCode.notFound);

  factory PhotoServiceException.io(String message) =>
      PhotoServiceException(message, code: PhotoServiceErrorCode.io);

  factory PhotoServiceException.invalidAsset(String message) =>
      PhotoServiceException(message, code: PhotoServiceErrorCode.invalidAsset);

  final String message;
  final PhotoServiceErrorCode code;

  @override
  String toString() => 'PhotoServiceException($code): $message';
}

enum PhotoServiceErrorCode {
  cancelled,
  limitReached,
  notFound,
  io,
  invalidAsset,
}

abstract class InspectionPhotoPicker {
  Future<XFile?> captureFromCamera({int? imageQuality});

  Future<List<XFile>> pickFromGallery({int? imageQuality});
}

class ImagePickerInspectionPhotoPicker implements InspectionPhotoPicker {
  ImagePickerInspectionPhotoPicker({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<XFile?> captureFromCamera({int? imageQuality}) {
    return _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: imageQuality ?? 90,
    );
  }

  @override
  Future<List<XFile>> pickFromGallery({int? imageQuality}) {
    return _imagePicker.pickMultiImage(imageQuality: imageQuality ?? 90);
  }
}

class FakeInspectionPhotoPicker implements InspectionPhotoPicker {
  FakeInspectionPhotoPicker({
    this.cameraPhoto,
    this.galleryPhotos = const <XFile>[],
  });

  final XFile? cameraPhoto;
  final List<XFile> galleryPhotos;

  @override
  Future<XFile?> captureFromCamera({int? imageQuality}) async => cameraPhoto;

  @override
  Future<List<XFile>> pickFromGallery({int? imageQuality}) async =>
      galleryPhotos;
}

typedef PhotoDirectoryProvider = Future<Directory> Function();

class PhotoService {
  PhotoService({
    InspectionPhotoPicker? photoPicker,
    PhotoDirectoryProvider? documentsDirectoryProvider,
    AssetBundle? assetBundle,
    int maxPhotosPerItem = AppConstants.maxPhotosPerInspectionItem,
    ImagePicker? imagePicker,
    Uuid? uuid,
  }) : _photoPicker =
           photoPicker ??
           ImagePickerInspectionPhotoPicker(imagePicker: imagePicker),
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _assetBundle = assetBundle ?? rootBundle,
       _maxPhotosPerItem = maxPhotosPerItem,
       _uuid = uuid ?? const Uuid();

  final InspectionPhotoPicker _photoPicker;
  final PhotoDirectoryProvider _documentsDirectoryProvider;
  final AssetBundle _assetBundle;
  final int _maxPhotosPerItem;
  final Uuid _uuid;

  Future<ManagedInspectionPhoto?> captureFromCamera({
    required String inspectionId,
    required String sectionKey,
    required String itemKey,
    required int currentPhotoCount,
    String caption = '',
    int sortOrder = 0,
    int? imageQuality,
  }) async {
    _assertPhotoSlotsAvailable(currentPhotoCount, 1);
    final xfile = await _photoPicker.captureFromCamera(
      imageQuality: imageQuality,
    );
    if (xfile == null) {
      return null;
    }
    return _persistManagedBytes(
      inspectionId: inspectionId,
      sectionKey: sectionKey,
      itemKey: itemKey,
      bytes: await xfile.readAsBytes(),
      caption: caption,
      sortOrder: sortOrder,
      source: ManagedPhotoSource.camera,
      originalFileName: p.basename(xfile.path),
    );
  }

  Future<PhotoBatchResult> addFromGallery({
    required String inspectionId,
    required String sectionKey,
    required String itemKey,
    required int currentPhotoCount,
    String captionPrefix = '',
    int startingSortOrder = 0,
    int? imageQuality,
  }) async {
    final selected = await _photoPicker.pickFromGallery(
      imageQuality: imageQuality,
    );
    if (selected.isEmpty) {
      return PhotoBatchResult.empty;
    }

    final remaining = _remainingSlots(currentPhotoCount);
    if (remaining <= 0) {
      throw PhotoServiceException.limitReached(
        'Photo limit reached for this item. Maximum is $_maxPhotosPerItem.',
      );
    }

    final accepted = selected.take(remaining).toList(growable: false);
    final savedPhotos = <ManagedInspectionPhoto>[];
    for (var index = 0; index < accepted.length; index++) {
      final xfile = accepted[index];
      savedPhotos.add(
        await _persistManagedBytes(
          inspectionId: inspectionId,
          sectionKey: sectionKey,
          itemKey: itemKey,
          bytes: await xfile.readAsBytes(),
          caption: captionPrefix.isEmpty
              ? ''
              : '$captionPrefix ${startingSortOrder + index + 1}',
          sortOrder: startingSortOrder + index,
          source: ManagedPhotoSource.gallery,
          originalFileName: p.basename(xfile.path),
        ),
      );
    }

    return PhotoBatchResult(
      savedPhotos: savedPhotos,
      skippedCount: selected.length - accepted.length,
      truncated: selected.length > accepted.length,
    );
  }

  Future<ManagedInspectionPhoto> addSampleAssetPhoto({
    required String inspectionId,
    required String sectionKey,
    required String itemKey,
    required String assetPath,
    required int currentPhotoCount,
    String caption = '',
    int sortOrder = 0,
  }) async {
    _assertPhotoSlotsAvailable(currentPhotoCount, 1);
    try {
      final bytes = (await _assetBundle.load(assetPath)).buffer.asUint8List();
      return _persistManagedBytes(
        inspectionId: inspectionId,
        sectionKey: sectionKey,
        itemKey: itemKey,
        bytes: bytes,
        caption: caption,
        sortOrder: sortOrder,
        source: ManagedPhotoSource.sampleAsset,
        originalFileName: p.basename(assetPath),
      );
    } on FlutterError catch (error) {
      throw PhotoServiceException.invalidAsset(
        'Unable to load sample asset "$assetPath": ${error.message}',
      );
    }
  }

  Future<ManagedInspectionPhoto> saveImportedPhoto({
    required String inspectionId,
    required String sectionKey,
    required String itemKey,
    required File sourceFile,
    required int currentPhotoCount,
    String caption = '',
    int sortOrder = 0,
  }) async {
    _assertPhotoSlotsAvailable(currentPhotoCount, 1);
    if (!await sourceFile.exists()) {
      throw PhotoServiceException.notFound(
        'Photo file does not exist: ${sourceFile.path}',
      );
    }
    return _persistManagedBytes(
      inspectionId: inspectionId,
      sectionKey: sectionKey,
      itemKey: itemKey,
      bytes: await sourceFile.readAsBytes(),
      caption: caption,
      sortOrder: sortOrder,
      source: ManagedPhotoSource.imported,
      originalFileName: p.basename(sourceFile.path),
    );
  }

  Future<Directory> resolveInspectionPhotoDirectory({
    required String inspectionId,
    required String sectionKey,
    required String itemKey,
  }) async {
    final documentsDirectory = await _documentsDirectoryProvider();
    final directory = Directory(
      p.join(
        documentsDirectory.path,
        AppConstants.databaseFolderName,
        AppConstants.inspectionsFolderName,
        inspectionId,
        'photos',
        sectionKey,
        itemKey,
      ),
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> deleteManagedPhoto(ManagedInspectionPhoto photo) async {
    final file = File(photo.filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<InspectionPhoto?> addPhoto({
    required String inspectionId,
    required String sectionKey,
    required String itemKey,
    required PhotoInputSource source,
    required int sortOrder,
    String? caption,
  }) async {
    final bytes = await _pickLegacyBytes(source);
    if (bytes == null) {
      return null;
    }

    final compressed = _compressToJpeg(bytes);
    final legacyPhotoDir = await FileUtils.inspectionPhotosDirectory(
      inspectionId,
    );
    final fileName = '${itemKey.replaceAll(':', '_')}_${_uuid.v4()}.jpg';
    final file = File(p.join(legacyPhotoDir.path, fileName));
    await file.writeAsBytes(compressed, flush: true);

    return InspectionPhoto(
      id: _uuid.v4(),
      inspectionId: inspectionId,
      sectionKey: sectionKey,
      itemKey: itemKey,
      filePath: file.path,
      caption: caption,
      sortOrder: sortOrder,
      capturedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  Future<void> deletePhoto(InspectionPhoto photo) async {
    final file = File(photo.filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Uint8List?> _pickLegacyBytes(PhotoInputSource source) async {
    switch (source) {
      case PhotoInputSource.camera:
        final cameraFile = await _photoPicker.captureFromCamera();
        return cameraFile?.readAsBytes();
      case PhotoInputSource.gallery:
        final galleryFiles = await _photoPicker.pickFromGallery();
        if (galleryFiles.isEmpty) {
          return null;
        }
        return galleryFiles.first.readAsBytes();
      case PhotoInputSource.sampleOne:
        return _readAsset(AppConstants.samplePhotoAssetOne);
      case PhotoInputSource.sampleTwo:
        return _readAsset(AppConstants.samplePhotoAssetTwo);
    }
  }

  Future<ManagedInspectionPhoto> _persistManagedBytes({
    required String inspectionId,
    required String sectionKey,
    required String itemKey,
    required Uint8List bytes,
    required String caption,
    required int sortOrder,
    required ManagedPhotoSource source,
    required String originalFileName,
  }) async {
    final directory = await resolveInspectionPhotoDirectory(
      inspectionId: inspectionId,
      sectionKey: sectionKey,
      itemKey: itemKey,
    );
    final fileName = _buildManagedPhotoFileName(
      inspectionId: inspectionId,
      sectionKey: sectionKey,
      itemKey: itemKey,
      originalFileName: originalFileName,
    );
    final file = File(p.join(directory.path, fileName));
    final outputBytes = _compressToJpeg(bytes);
    await file.writeAsBytes(outputBytes, flush: true);
    return ManagedInspectionPhoto(
      filePath: file.path,
      sectionKey: sectionKey,
      itemKey: itemKey,
      caption: caption,
      capturedAt: DateTime.now().toUtc(),
      sortOrder: sortOrder,
      source: source,
      originalFileName: originalFileName,
      byteLength: outputBytes.length,
    );
  }

  Future<Uint8List> _readAsset(String assetPath) async {
    final ByteData data = await _assetBundle.load(assetPath);
    return data.buffer.asUint8List();
  }

  Uint8List _compressToJpeg(Uint8List rawBytes) {
    final img.Image? image = img.decodeImage(rawBytes);
    if (image == null) {
      throw PhotoServiceException.invalidAsset(
        'The selected file is not a supported image.',
      );
    }

    final img.Image resized = image.width > 1600
        ? img.copyResize(image, width: 1600)
        : image;
    return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
  }

  String _buildManagedPhotoFileName({
    required String inspectionId,
    required String sectionKey,
    required String itemKey,
    required String originalFileName,
  }) {
    final safeSegment = FileUtils.sanitizeFileSegment(
      <String>[inspectionId, sectionKey, itemKey].join('_'),
    );
    return '${safeSegment}_${DateTime.now().toUtc().millisecondsSinceEpoch}_${_uuid.v4()}.jpg';
  }

  int _remainingSlots(int currentPhotoCount) {
    return _maxPhotosPerItem - currentPhotoCount;
  }

  void _assertPhotoSlotsAvailable(int currentPhotoCount, int requestedCount) {
    if (_remainingSlots(currentPhotoCount) < requestedCount) {
      throw PhotoServiceException.limitReached(
        'Photo limit reached for this item. Maximum is $_maxPhotosPerItem.',
      );
    }
  }
}
