// ============================================
// TimurLang - Supabase Configuration
// Online database credentials
// ============================================
//
// PANDUAN SETUP:
// 1. Buka https://supabase.com dan buat akun
// 2. Klik "New Project", pilih organisasi
// 3. Isi nama project: "timurlang"
// 4. Set password database (simpan baik-baik!)
// 5. Pilih region: Southeast Asia (Singapore)
// 6. Klik "Create new project", tunggu selesai
// 7. Buka Settings → API
// 8. Copy "Project URL" → paste ke supabaseUrl
// 9. Copy "anon public" key → paste ke supabaseAnonKey
// 10. Buka SQL Editor, jalankan file supabase_setup.sql
//
// ============================================

class SupabaseConfig {
  // ⚠️ GANTI DENGAN URL DAN KEY SUPABASE ANDA!
  // Dapatkan dari: Supabase Dashboard → Settings → API
  static const String supabaseUrl = 'https://jiitishcmgssgnvdypfz.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImppaXRpc2hjbWdzc2dudmR5cGZ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2MTUyMTgsImV4cCI6MjEwNzE5MTIxOH0.crk9C2WLwKU22tX4g7MANXl4GVAbIDkEcrDf9_tCmL4';

  // Cek apakah config sudah diisi
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_SUPABASE_URL') &&
      !supabaseAnonKey.contains('YOUR_SUPABASE_ANON_KEY');
}
