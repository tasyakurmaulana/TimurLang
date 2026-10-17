-- ============================================
-- TimurLang - Supabase Database Migration
-- Jalankan query ini di Supabase Dashboard -> SQL Editor!
-- ============================================

-- 1. Tambahkan kolom baru ke tabel USERS
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_biometric_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS biometric_token TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS gunung_id TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS nama_basecamp TEXT;

-- 2. Tambahkan kolom basecamp_id ke tabel SOS_INCIDENT_LOGS
ALTER TABLE sos_incident_logs ADD COLUMN IF NOT EXISTS basecamp_id TEXT;

-- 3. Kebijakan akses (RLS) untuk tabel BASECAMP_POSTS
DROP POLICY IF EXISTS "Anyone can insert basecamps" ON basecamp_posts;
CREATE POLICY "Anyone can insert basecamps" ON basecamp_posts FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Anyone can update basecamps" ON basecamp_posts;
CREATE POLICY "Anyone can update basecamps" ON basecamp_posts FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Anyone can read basecamps" ON basecamp_posts;
CREATE POLICY "Anyone can read basecamps" ON basecamp_posts FOR SELECT USING (true);

-- 4. Kebijakan akses (RLS) untuk tabel SIMAKSI_PERMITS
DROP POLICY IF EXISTS "Anyone can insert permits" ON simaksi_permits;
CREATE POLICY "Anyone can insert permits" ON simaksi_permits FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Anyone can update permits" ON simaksi_permits;
CREATE POLICY "Anyone can update permits" ON simaksi_permits FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Anyone can read permits" ON simaksi_permits;
CREATE POLICY "Anyone can read permits" ON simaksi_permits FOR SELECT USING (true);

-- 5. Tambah Gunung Sumbing ke tabel MOUNTAINS jika belum ada
INSERT INTO mountains (id, nama_gunung, elevasi_mdpl, tingkat_bahaya, sumber_air_tersedia, status_jalur, koordinat_lat, koordinat_long, deskripsi, kuota_harian)
VALUES ('mtn-011', 'Gunung Sumbing', 3371, 'Grade 3 - Sulit', true, 'Buka', -7.384, 110.070, 'Gunung berapi aktif di Jawa Tengah dengan jalur via Garung, Dukuh Semar, dan Gajah Mungkur.', 400)
ON CONFLICT (id) DO NOTHING;
