import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

abstract interface class PhotoService {
  Future<PickedPhoto?> pick();
}

class ImagePickerPhotoService implements PhotoService {
  const ImagePickerPhotoService();

  static const _allowed = {'image/jpeg', 'image/png', 'image/webp'};

  @override
  Future<PickedPhoto?> pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return null;
    final mime = file.mimeType;
    return PickedPhoto(bytes: await file.readAsBytes(), contentType: _allowed.contains(mime) ? mime! : 'image/jpeg');
  }
}
