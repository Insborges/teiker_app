import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<void> showProfileImagePickerSheet(
  BuildContext context, {
  required ValueChanged<ImageSource> onSourceSelected,
}) async {
  if (Platform.isIOS) {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (modalContext) {
        return CupertinoActionSheet(
          title: const Text('Escolher foto'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(modalContext);
                onSourceSelected(ImageSource.camera);
              },
              child: const Text('Tirar Foto'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(modalContext);
                onSourceSelected(ImageSource.gallery);
              },
              child: const Text('Escolher da Galeria'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(modalContext),
            child: const Text('Cancelar'),
          ),
        );
      },
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (modalContext) {
      return SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tirar Foto'),
              onTap: () {
                Navigator.pop(modalContext);
                onSourceSelected(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher da Galeria'),
              onTap: () {
                Navigator.pop(modalContext);
                onSourceSelected(ImageSource.gallery);
              },
            ),
          ],
        ),
      );
    },
  );
}
