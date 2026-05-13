/// @file permission_service.dart
/// @description Requests camera + location permissions at app startup.
///
/// Called by: main.dart (initState post-frame callback)
library;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

class PermissionService {
  PermissionService._();

  /// Request camera and GPS permissions on first launch.
  static Future<void> requestAppPermissions(BuildContext context) async {
    // Location
    final locPerm = await Geolocator.checkPermission();
    if (locPerm == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    // Camera — triggered lazily by image_picker on first use, but we pre-check here
    // to surface the dialog at a logical moment rather than mid-form.
    try {
      await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 1,
        maxHeight: 1,
        maxWidth: 1,
      );
    } catch (_) {
      // Ignore — just want the permission dialog
    }
  }
}
