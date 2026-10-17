// ============================================
// TimurLang - Image Helper Utility
// Handles Base64 / Network / File image providers
// ============================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageHelper {
  /// Converts an XFile from ImagePicker to a base64 Data URI string.
  /// Automatically compresses via quality/max dimensions in picker.
  static Future<String> xFileToBase64(XFile file) async {
    final Uint8List bytes = await file.readAsBytes();
    final String base64String = base64Encode(bytes);
    final String extension = file.name.split('.').last.toLowerCase();
    final String mimeType = (extension == 'png') ? 'image/png' : 'image/jpeg';
    return 'data:$mimeType;base64,$base64String';
  }

  /// Extracts pure Uint8List from base64 (with or without 'data:image/...;base64,' prefix)
  static Uint8List? bytesFromBase64(String? base64OrDataUri) {
    if (base64OrDataUri == null || base64OrDataUri.trim().isEmpty) return null;
    try {
      String clean = base64OrDataUri.trim();
      if (clean.contains(',')) {
        clean = clean.split(',')[1];
      }
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  /// Returns an appropriate ImageProvider for a given string (base64 Data URI, HTTP/HTTPS URL)
  static ImageProvider? getImageProvider(String? source) {
    if (source == null || source.trim().isEmpty) return null;
    final String trimmed = source.trim();

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return NetworkImage(trimmed);
    }

    final bytes = bytesFromBase64(trimmed);
    if (bytes != null) {
      return MemoryImage(bytes);
    }

    return null;
  }
}
