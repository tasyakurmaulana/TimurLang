import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'services/database_service.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'services/sos_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi locale formatting untuk tanggal (Indonesia)
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    debugPrint('⚠️ Error init locale: $e');
  }

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

  // Inisialisasi Notifikasi & Siaga SOS Global
  try {
    await NotificationService.instance.initialize();
    await SosManager.instance.initialize();
  } catch (e) {
    debugPrint('⚠️ Error inisialisasi SOS Manager: $e');
  }

  runApp(const MainApp());
}
