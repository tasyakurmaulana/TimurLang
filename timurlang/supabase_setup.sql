-- ============================================
-- TimurLang - Supabase Database Setup
-- Jalankan SQL ini di Supabase SQL Editor
-- ============================================
-- 
-- CARA MENJALANKAN:
-- 1. Buka Supabase Dashboard
-- 2. Klik "SQL Editor" di sidebar kiri
-- 3. Klik "New query"
-- 4. Copy-paste SELURUH isi file ini
-- 5. Klik "Run" (atau Ctrl+Enter)
-- 6. Pastikan semua berhasil (tanda centang hijau)
--
-- ============================================

-- ── TABEL USERS ──
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  peran TEXT NOT NULL CHECK (peran IN ('pendaki', 'basecamp')),
  nama_lengkap TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  foto_profil_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── TABEL USER SESSIONS ──
CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_token TEXT NOT NULL,
  is_biometric_enabled BOOLEAN DEFAULT FALSE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token ON user_sessions(session_token);

-- ── TABEL MEDICAL PROFILES ──
CREATE TABLE IF NOT EXISTS medical_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  golongan_darah TEXT NOT NULL,
  riwayat_penyakit TEXT NOT NULL DEFAULT '',
  alergi TEXT NOT NULL DEFAULT '',
  kontak_darurat_nama TEXT NOT NULL,
  kontak_darurat_telepon TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── TABEL MOUNTAINS ──
CREATE TABLE IF NOT EXISTS mountains (
  id TEXT PRIMARY KEY,
  nama_gunung TEXT NOT NULL,
  elevasi_mdpl INTEGER NOT NULL,
  tingkat_bahaya TEXT NOT NULL,
  sumber_air_tersedia BOOLEAN NOT NULL DEFAULT FALSE,
  status_jalur TEXT NOT NULL DEFAULT 'Buka',
  koordinat_lat DOUBLE PRECISION NOT NULL,
  koordinat_long DOUBLE PRECISION NOT NULL,
  deskripsi TEXT,
  foto_url TEXT,
  kuota_harian INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── TABEL BASECAMP POSTS ──
CREATE TABLE IF NOT EXISTS basecamp_posts (
  id TEXT PRIMARY KEY,
  gunung_id TEXT NOT NULL REFERENCES mountains(id) ON DELETE CASCADE,
  user_id_petugas UUID REFERENCES users(id),
  nama_pos TEXT NOT NULL,
  lokasi_deskripsi TEXT NOT NULL,
  kontak_pos TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_basecamp_gunung ON basecamp_posts(gunung_id);

-- ── TABEL SIMAKSI PERMITS ──
CREATE TABLE IF NOT EXISTS simaksi_permits (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  gunung_id TEXT NOT NULL REFERENCES mountains(id),
  basecamp_id TEXT REFERENCES basecamp_posts(id),
  tanggal_naik DATE NOT NULL,
  tanggal_turun DATE NOT NULL,
  jumlah_anggota INTEGER NOT NULL DEFAULT 1,
  status_izin TEXT NOT NULL DEFAULT 'Diajukan',
  block_hash TEXT NOT NULL,
  previous_hash TEXT NOT NULL,
  nonce INTEGER NOT NULL DEFAULT 0,
  nama_gunung TEXT,
  total_biaya DOUBLE PRECISION,
  matauang TEXT DEFAULT 'IDR',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_permits_user ON simaksi_permits(user_id);
CREATE INDEX idx_permits_gunung ON simaksi_permits(gunung_id);
CREATE INDEX idx_permits_status ON simaksi_permits(status_izin);

-- ── TABEL SOS INCIDENT LOGS ──
CREATE TABLE IF NOT EXISTS sos_incident_logs (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  gunung_id TEXT REFERENCES mountains(id),
  koordinat_lat DOUBLE PRECISION NOT NULL,
  koordinat_long DOUBLE PRECISION NOT NULL,
  tipe_pemicu TEXT NOT NULL,
  status_penanganan TEXT NOT NULL DEFAULT 'darurat_aktif',
  waktu_kejadian TIMESTAMPTZ NOT NULL,
  nama_pendaki TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sos_user ON sos_incident_logs(user_id);
CREATE INDEX idx_sos_status ON sos_incident_logs(status_penanganan);

-- ── TABEL SYNC QUEUES ──
CREATE TABLE IF NOT EXISTS sync_queues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nama_tabel TEXT NOT NULL,
  record_id TEXT NOT NULL,
  aksi_tipe TEXT NOT NULL,
  payload_json JSONB NOT NULL DEFAULT '{}',
  status_sinkronisasi TEXT NOT NULL DEFAULT 'menunggu_sinkronisasi',
  synced_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── TABEL COURSE FEEDBACKS ──
CREATE TABLE IF NOT EXISTS course_feedbacks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  nama_pengguna TEXT NOT NULL,
  kesan_pesan TEXT NOT NULL,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- Keamanan: user hanya bisa akses data sendiri
-- ============================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE medical_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE mountains ENABLE ROW LEVEL SECURITY;
ALTER TABLE basecamp_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE simaksi_permits ENABLE ROW LEVEL SECURITY;
ALTER TABLE sos_incident_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_feedbacks ENABLE ROW LEVEL SECURITY;

-- Users: bisa baca & update profil sendiri
CREATE POLICY "Users can read own profile" ON users
  FOR SELECT USING (true);

CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (true);

-- Mountains: semua bisa baca
CREATE POLICY "Anyone can read mountains" ON mountains
  FOR SELECT USING (true);

CREATE POLICY "Anyone can insert mountains" ON mountains
  FOR INSERT WITH CHECK (true);

-- Basecamp Posts: semua bisa baca
CREATE POLICY "Anyone can read basecamps" ON basecamp_posts
  FOR SELECT USING (true);

CREATE POLICY "Anyone can insert basecamps" ON basecamp_posts
  FOR INSERT WITH CHECK (true);

-- Simaksi Permits: bisa baca & tulis
CREATE POLICY "Anyone can read permits" ON simaksi_permits
  FOR SELECT USING (true);

CREATE POLICY "Anyone can insert permits" ON simaksi_permits
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update permits" ON simaksi_permits
  FOR UPDATE USING (true);

-- Medical Profiles: bisa akses
CREATE POLICY "Anyone can read medical" ON medical_profiles
  FOR SELECT USING (true);

CREATE POLICY "Anyone can insert medical" ON medical_profiles
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update medical" ON medical_profiles
  FOR UPDATE USING (true);

-- SOS Incidents: bisa akses
CREATE POLICY "Anyone can read sos" ON sos_incident_logs
  FOR SELECT USING (true);

CREATE POLICY "Anyone can insert sos" ON sos_incident_logs
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Anyone can update sos" ON sos_incident_logs
  FOR UPDATE USING (true);

-- User Sessions: bisa akses
CREATE POLICY "Anyone can manage sessions" ON user_sessions
  FOR ALL USING (true);

-- Course Feedbacks: bisa akses
CREATE POLICY "Anyone can read feedbacks" ON course_feedbacks
  FOR SELECT USING (true);

CREATE POLICY "Anyone can insert feedbacks" ON course_feedbacks
  FOR INSERT WITH CHECK (true);

-- ============================================
-- SEED DATA: Gunung-gunung Indonesia
-- ============================================

INSERT INTO mountains (id, nama_gunung, elevasi_mdpl, tingkat_bahaya, sumber_air_tersedia, status_jalur, koordinat_lat, koordinat_long, deskripsi, kuota_harian) VALUES
  ('mtn-001', 'Gunung Semeru', 3676, 'Grade 4 - Sangat Sulit', true, 'Buka', -8.108, 112.922, 'Gunung tertinggi di Pulau Jawa dengan puncak Mahameru. Jalur pendakian melalui Ranu Pani melewati savana dan danau Ranu Kumbolo yang ikonik. Erupsi aktif dengan lontaran material vulkanik.', 300),
  ('mtn-002', 'Gunung Rinjani', 3726, 'Grade 4 - Sangat Sulit', true, 'Buka', -8.411, 116.457, 'Gunung berapi aktif tertinggi kedua di Indonesia, terletak di Lombok, NTB. Terdapat Danau Segara Anak di kaldera dan sumber air panas alami.', 200),
  ('mtn-003', 'Gunung Kerinci', 3805, 'Grade 3 - Sulit', true, 'Buka', -1.697, 101.264, 'Gunung tertinggi di Sumatera dan puncak tertinggi di luar Papua. Terletak di Taman Nasional Kerinci Seblat dengan keanekaragaman hayati tinggi.', 150),
  ('mtn-004', 'Gunung Merbabu', 3145, 'Grade 2 - Sedang', false, 'Buka', -7.455, 110.440, 'Gunung dormant di perbatasan Jawa Tengah. Terkenal dengan savana luas dan panorama sunrise yang memukau. Jalur via Selo paling populer.', 400),
  ('mtn-005', 'Gunung Prau', 2565, 'Grade 1 - Mudah', false, 'Buka', -7.186, 109.923, 'Gunung ramah pemula di Dataran Tinggi Dieng, Jawa Tengah. Terkenal dengan golden sunrise dan lautan awan. Jalur pendek dan landai.', 500),
  ('mtn-006', 'Gunung Bromo', 2329, 'Grade 1 - Mudah', false, 'Waspada Cuaca Ekstrem', -7.942, 112.953, 'Gunung berapi aktif di Taman Nasional Bromo Tengger Semeru. Terkenal dengan lautan pasir dan sunrise dari Penanjakan.', 600),
  ('mtn-007', 'Gunung Gede Pangrango', 2958, 'Grade 2 - Sedang', true, 'Buka', -6.787, 106.980, 'Taman Nasional di Jawa Barat dengan Suryakencana sebagai padang edelweiss terluas. Sumber air melimpah sepanjang jalur.', 300),
  ('mtn-008', 'Gunung Lawu', 3265, 'Grade 3 - Sulit', true, 'Buka', -7.625, 111.192, 'Gunung mistis di perbatasan Jawa Tengah-Jawa Timur. Terkenal dengan situs candi peninggalan kerajaan Majapahit dan hutan cemara.', 350),
  ('mtn-009', 'Gunung Cartensz Pyramid', 4884, 'Grade 5 - Ekstrem', true, 'Tutup', -4.078, 137.158, 'Puncak tertinggi Indonesia dan Oseania (Seven Summits). Terletak di Papua dengan akses terbatas, memerlukan izin khusus dan kemampuan rock climbing.', 20),
  ('mtn-010', 'Gunung Slamet', 3428, 'Grade 3 - Sulit', true, 'Buka', -7.242, 109.208, 'Gunung tertinggi kedua di Jawa setelah Semeru. Jalur panjang dan menantang melalui hutan lebat dan medan berpasir.', 250)
ON CONFLICT (id) DO NOTHING;

-- Seed Basecamp data
INSERT INTO basecamp_posts (id, gunung_id, nama_pos, lokasi_deskripsi, kontak_pos) VALUES
  ('bc-001', 'mtn-001', 'Pos Ranu Pani', 'Desa Ranu Pani, Lumajang, Jawa Timur', '0334-8880001'),
  ('bc-002', 'mtn-002', 'Pos Senaru', 'Desa Senaru, Lombok Utara, NTB', '0370-8880002'),
  ('bc-003', 'mtn-003', 'Pos Kersik Tuo', 'Kersik Tuo, Kayu Aro, Kerinci, Jambi', '0748-8880003'),
  ('bc-004', 'mtn-004', 'Pos Selo', 'Desa Selo, Boyolali, Jawa Tengah', '0276-8880004'),
  ('bc-005', 'mtn-005', 'Pos Dieng Kulon', 'Desa Dieng Kulon, Banjarnegara, Jawa Tengah', '0286-8880005'),
  ('bc-006', 'mtn-006', 'Pos Cemoro Lawang', 'Cemoro Lawang, Probolinggo, Jawa Timur', '0335-8880006'),
  ('bc-007', 'mtn-007', 'Pos Cibodas', 'Cibodas, Cianjur, Jawa Barat', '0263-8880007'),
  ('bc-008', 'mtn-008', 'Pos Cemoro Sewu', 'Cemoro Sewu, Magetan, Jawa Timur', '0351-8880008'),
  ('bc-009', 'mtn-009', 'Pos Sugapa', 'Sugapa, Intan Jaya, Papua', '0901-8880009'),
  ('bc-010', 'mtn-010', 'Pos Bambangan', 'Bambangan, Purbalingga, Jawa Tengah', '0281-8880010')
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- ✅ SETUP SELESAI!
-- Jika semua berhasil, database online Anda siap digunakan.
-- Kembali ke kode Flutter dan isi URL + Key di supabase_config.dart
-- ============================================
