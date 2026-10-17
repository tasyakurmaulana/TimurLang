import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

import 'app.dart';
import 'services/database_service.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi database factory untuk web platform
  if (kIsWeb) {
    try {
      DatabaseService.initForWeb();
    } catch (e) {
      debugPrint('⚠️ Error initForWeb: $e');
    }
  }

  // Pre-inisialisasi database lokal (SQLite)
  try {
    await DatabaseService.instance.database;
  } catch (e) {
    debugPrint('⚠️ Error pre-inisialisasi SQLite: $e');
  }

  // Inisialisasi Supabase (online database)
  try {
    await SupabaseService.instance.initialize();
  } catch (e) {
    debugPrint('⚠️ Error inisialisasi Supabase: $e');
  }

  runApp(const MainApp());
}
