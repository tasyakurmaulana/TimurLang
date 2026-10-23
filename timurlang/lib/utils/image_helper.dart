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

  static final Map<String, String> _mountainPhotoMap = {
    'andong': 'assets/images/Foto Gunung/Andong.webp',
    'argopuro': 'assets/images/Foto Gunung/Argopuro.jpg',
    'arjuno': 'assets/images/Foto Gunung/Arjuno.jpg',
    'batur': 'assets/images/Foto Gunung/Batur.webp',
    'bawakaraeng': 'assets/images/Foto Gunung/Bawakaraeng.png',
    'bismo': 'assets/images/Foto Gunung/Bismo.jpg',
    'bongkok': 'assets/images/Foto Gunung/Bongkok.jpg',
    'bukit raya': 'assets/images/Foto Gunung/Bukit Raya.webp',
    'bulu baria': 'assets/images/Foto Gunung/Bulu Baria.png',
    'bulu mopeaanooleo': 'assets/images/Foto Gunung/Bulu Mopeaanooleo.webp',
    'bulusaurung': 'assets/images/Foto Gunung/Bulusaurung.webp',
    'burangrang': 'assets/images/Foto Gunung/Burangrang.jpg',
    'cikuray': 'assets/images/Foto Gunung/Cikuray.webp',
    'ciremai': 'assets/images/Foto Gunung/Ciremai.jpg',
    'dempo': 'assets/images/Foto Gunung/Dempo.jpg',
    'gamalama': 'assets/images/Foto Gunung/Gamalama.jpg',
    'gede': 'assets/images/Foto Gunung/Gede.jpg',
    'guntur': 'assets/images/Foto Gunung/Guntur.jpeg',
    'kelud': 'assets/images/Foto Gunung/Kelud.jpg',
    'kembang': 'assets/images/Foto Gunung/Kembang.webp',
    'kerenceng': 'assets/images/Foto Gunung/Kerenceng.jpeg',
    'kerinci': 'assets/images/Foto Gunung/Kerinci.jpg',
    'latimojong': 'assets/images/Foto Gunung/Latimojong.webp',
    'lawu': 'assets/images/Foto Gunung/Lawu.webp',
    'leuser': 'assets/images/Foto Gunung/Leuser.jpeg',
    'lompobattang': 'assets/images/Foto Gunung/Lompobattang.webp',
    'merapi': 'assets/images/Foto Gunung/Merapi.jpg',
    'merbabu': 'assets/images/Foto Gunung/Merbabu.webp',
    'pangrango': 'assets/images/Foto Gunung/Pangrango.webp',
    'patuha': 'assets/images/Foto Gunung/Patuha.webp',
    'penanggungan': 'assets/images/Foto Gunung/Penanggungan.jpg',
    'prau': 'assets/images/Foto Gunung/Prau.png',
    'raung': 'assets/images/Foto Gunung/Raung.webp',
    'rinjani': 'assets/images/Foto Gunung/Rinjani.jpg',
    'rogojembangan': 'assets/images/Foto Gunung/Rogojembangan.png',
    'saeng': 'assets/images/Foto Gunung/Saeng.jpeg',
    'sagara': 'assets/images/Foto Gunung/Sagara.webp',
    'semeru': 'assets/images/Foto Gunung/Semeru.webp',
    'sibuatan': 'assets/images/Foto Gunung/Sibuatan.jpg',
    'sinabung': 'assets/images/Foto Gunung/Sinabung.jpg',
    'sindoro': 'assets/images/Foto Gunung/Sindoro.webp',
    'slamet': 'assets/images/Foto Gunung/Slamet.jpg',
    'sumbing': 'assets/images/Foto Gunung/Sumbing.webp',
    'talang': 'assets/images/Foto Gunung/Talang.webp',
    'tanggamus': 'assets/images/Foto Gunung/Tanggamus.jpeg',
    'tangkelemboke': 'assets/images/Foto Gunung/Tangkelemboke.jpg',
    'ungaran': 'assets/images/Foto Gunung/Ungaran.jpg',
  };

  /// Mencari path foto lokal asli dari assets/images/Foto Gunung/ berdasarkan nama gunung
  static String? getMountainAssetPath(String? mountainName) {
    if (mountainName == null || mountainName.trim().isEmpty) return null;
    final lower = mountainName.toLowerCase().replaceAll('gunung', '').trim();
    for (final entry in _mountainPhotoMap.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Returns an appropriate ImageProvider for a given string (asset, base64 Data URI, HTTP/HTTPS URL)
  /// or resolves from local real mountain photos in assets/images/Foto Gunung
  static ImageProvider? getImageProvider(String? source, [String? mountainName]) {
    // 1. Coba cari foto lokal asli dari nama gunung jika ada
    if (mountainName != null && mountainName.trim().isNotEmpty) {
      final assetPath = getMountainAssetPath(mountainName);
      if (assetPath != null) {
        return AssetImage(assetPath);
      }
    }

    if (source == null || source.trim().isEmpty) return null;
    final String trimmed = source.trim();

    // 2. Jika path lokal asset
    if (trimmed.startsWith('assets/')) {
      return AssetImage(trimmed);
    }

    // 3. Jika URL jaringan
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return NetworkImage(trimmed);
    }

    // 4. Jika Base64
    final bytes = bytesFromBase64(trimmed);
    if (bytes != null) {
      return MemoryImage(bytes);
    }

    return null;
  }
}
