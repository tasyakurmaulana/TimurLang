// ============================================
// TimurLang - Fall Detection & Emergency SOS Screen
// Professional Emergency Hub with Sensor Monitoring & Tactile SOS Trigger
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../services/sos_manager.dart';

class FallDetectionScreen extends StatefulWidget {
  const FallDetectionScreen({super.key});

  @override
  State<FallDetectionScreen> createState() => _FallDetectionScreenState();
}

class _FallDetectionScreenState extends State<FallDetectionScreen>
    with SingleTickerProviderStateMixin {
  bool _isMonitoring = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _isMonitoring = SosManager.instance.isMonitoring;
    SosManager.instance.addListener(_syncSosState);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _syncSosState() {
    if (mounted) {
      setState(() {
        _isMonitoring = SosManager.instance.isMonitoring;
      });
    }
  }

  Future<void> _toggleMonitoring() async {
    HapticFeedback.selectionClick();
    if (_isMonitoring) {
      await SosManager.instance.stopMonitoring();
    } else {
      await SosManager.instance.startMonitoring();
    }
    if (mounted) {
      setState(() {
        _isMonitoring = SosManager.instance.isMonitoring;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    SosManager.instance.removeListener(_syncSosState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Keselamatan & SOS',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Sensor Fall Detection Card ──
            _buildSensorCard(),
            const SizedBox(height: 24),

            // ── Manual SOS Activation Center ──
            _buildManualSosSection(),
            const SizedBox(height: 24),

            // ── Guidance Footer ──
            _buildGuidanceCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard() {
    final statusColor = _isMonitoring ? AppTheme.success : AppTheme.textSecondary;
    final badgeBg = _isMonitoring
        ? AppTheme.success.withValues(alpha: 0.12)
        : AppTheme.border.withValues(alpha: 0.6);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isMonitoring
              ? AppTheme.success.withValues(alpha: 0.5)
              : AppTheme.border,
          width: _isMonitoring ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isMonitoring
                      ? AppTheme.success.withValues(alpha: 0.12)
                      : AppTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isMonitoring
                        ? AppTheme.success.withValues(alpha: 0.3)
                        : AppTheme.border,
                  ),
                ),
                child: Icon(
                  _isMonitoring ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                  color: statusColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SENSOR AKSESIS 3-AXIS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Deteksi Jatuh & Benturan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isMonitoring ? 'AKTIF' : 'NONAKTIF',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _isMonitoring
                ? 'Sistem sedang memantau pergerakan ekstrim atau jatuh bebas di latar belakang. Saat terdeteksi benturan keras, sirene dan sinyal GPS akan segera disiagakan.'
                : 'Aktifkan pemantauan akselerometer untuk mendeteksi potensi kecelakaan atau jatuh di medan terjal secara otomatis, bahkan saat ponsel disimpan di saku.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Siaga Latar Belakang',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isMonitoring
                          ? 'Memantau aktif di latar belakang'
                          : 'Ketuk sakelar untuk menyalakan',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isMonitoring,
                activeThumbColor: AppTheme.success,
                activeTrackColor: AppTheme.success.withValues(alpha: 0.3),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: AppTheme.border,
                onChanged: (_) => _toggleMonitoring(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualSosSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Aktivasi Darurat Manual',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Tekan dan tahan tombol merah di bawah untuk membunyikan suar sirene dan memancarkan sinyal darurat ke Pos Basecamp.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Tactile SOS Emergency Button with Concentric Rings
          ScaleTransition(
            scale: _pulseAnimation,
            child: GestureDetector(
              onLongPress: () {
                HapticFeedback.heavyImpact();
                SosManager.instance.triggerManualSOS();
              },
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.error.withValues(alpha: 0.08),
                  border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFEF4444),
                          Color(0xFFB91C1C),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.45),
                          blurRadius: 24,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.emergency_rounded,
                          size: 38,
                          color: Colors.white,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'TAHAN UNTUK SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildGuidanceCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.textSecondary, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Gunakan tombol SOS saat berada dalam kondisi darurat nyata seperti cedera fisik, hipotermia, atau tersesat di jalur pendakian.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
