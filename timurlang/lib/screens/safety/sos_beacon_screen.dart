// ============================================
// TimurLang - SOS Beacon Screen
// Layar Suar Darurat Berkedip Teks SOS Raksasa
// Dirancang untuk visibilitas maksimal Tim SAR
// ============================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/sos_incident.dart';
import '../../services/database_service.dart';

class SosBeaconScreen extends StatefulWidget {
  final SosIncident? incident;
  final String triggerType;

  const SosBeaconScreen({
    super.key,
    this.incident,
    this.triggerType = AppConstants.sosFallDetection,
  });

  @override
  State<SosBeaconScreen> createState() => _SosBeaconScreenState();
}

class _SosBeaconScreenState extends State<SosBeaconScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _pulseAnim;
  Timer? _hapticTimer;
  bool _isFlashWhite = false;
  int _strobeMode = 0; // 0 = Cepat (Strobe), 1 = Morse SOS, 2 = Tetap Terang
  Timer? _morseTimer;
  int _morseIndex = 0;

  // Pola Morse untuk SOS (... --- ...)
  // 1 = Nyala pendek, 2 = Nyala panjang, 0 = Jeda
  static const List<int> _morsePattern = [
    1, 0, 1, 0, 1, 0, 0, // S (... )
    2, 0, 2, 0, 2, 0, 0, // O (---)
    1, 0, 1, 0, 1, 0, 0, 0, 0 // S (... ) + jeda panjang
  ];

  @override
  void initState() {
    super.initState();

    // Animasi denyut / pulse untuk suar darurat
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addStatusListener((status) {
        if (_strobeMode == 0) {
          if (status == AnimationStatus.completed) {
            setState(() => _isFlashWhite = !_isFlashWhite);
            _animCtrl.reverse();
          } else if (status == AnimationStatus.dismissed) {
            setState(() => _isFlashWhite = !_isFlashWhite);
            _animCtrl.forward();
          }
        }
      });

    _pulseAnim = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );

    _startStrobe();
  }

  void _startStrobe() {
    _morseTimer?.cancel();
    _hapticTimer?.cancel();

    if (_strobeMode == 0) {
      // Mode Strobe Cepat
      _animCtrl.duration = const Duration(milliseconds: 350);
      _animCtrl.forward();

      // Getaran berkala
      _hapticTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
        HapticFeedback.heavyImpact();
      });
    } else if (_strobeMode == 1) {
      // Mode Morse SOS (... --- ...)
      _animCtrl.stop();
      _morseIndex = 0;
      _morseTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
        if (!mounted) return;
        final step = _morsePattern[_morseIndex % _morsePattern.length];
        setState(() {
          _isFlashWhite = step > 0;
        });
        if (step > 0) {
          HapticFeedback.mediumImpact();
        }
        _morseIndex++;
      });
    } else {
      // Mode Tetap Terang
      _animCtrl.stop();
      setState(() => _isFlashWhite = false);
    }
  }

  void _switchMode(int mode) {
    setState(() {
      _strobeMode = mode;
      _startStrobe();
    });
  }

  Future<void> _cancelSOS() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppTheme.safeGreen, size: 28),
            SizedBox(width: 10),
            Text('Matikan Sinyal SOS?'),
          ],
        ),
        content: const Text(
          'Pastikan Anda sudah dalam kondisi aman atau Tim SAR/Basecamp telah tiba di lokasi Anda.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tetap Aktifkan', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.safeGreen),
            child: const Text('Ya, Saya Aman (Matikan)'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      if (widget.incident != null) {
        await DatabaseService.instance.updateSOSStatus(
          widget.incident!.id,
          AppConstants.sosCancelled,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sinyal SOS telah dinonaktifkan. Tetap berhati-hati!'),
            backgroundColor: AppTheme.safeGreen,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _hapticTimer?.cancel();
    _morseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = _isFlashWhite;
    final bgColor = isWhite ? Colors.white : const Color(0xFFD50000); // Vivid Emergency Red
    final textColor = isWhite ? const Color(0xFFD50000) : Colors.white;
    final subtextColor = isWhite ? Colors.black87 : Colors.white70;

    final lat = widget.incident?.koordinatLat ?? -8.108000;
    final lng = widget.incident?.koordinatLong ?? 112.922000;
    final waktu = widget.incident?.waktuKejadian ?? DateTime.now();
    final nama = widget.incident?.namaPendaki ?? 'Pendaki TimurLang';
    final isFall = widget.triggerType == AppConstants.sosFallDetection;

    return PopScope(
      canPop: false, // Mencegah tombol back menutup layar secara tidak sengaja
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _cancelSOS();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // Header Status Darurat
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isWhite ? const Color(0xFFD50000) : Colors.black45,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isWhite ? Colors.transparent : Colors.white30,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isWhite ? Colors.white : Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '🚨 SUAR DARURAT TIM SAR AKTIF',
                      style: TextStyle(
                        color: isWhite ? Colors.white : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // Tulisan SOS Raksasa Berkedip
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    children: [
                      FittedBox(
                        child: Text(
                          'S O S',
                          style: TextStyle(
                            fontSize: 110,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            letterSpacing: 8,
                            shadows: [
                              Shadow(
                                color: isWhite
                                    ? Colors.red.withValues(alpha: 0.6)
                                    : Colors.black54,
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isFall ? 'DETEKSI JATUH • PERLU BANTUAN' : 'DARURAT MANUAL • PERLU EVAKUASI',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // Kartu Informasi Posisi & Pendaki untuk Tim SAR
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isWhite ? Colors.black.withValues(alpha: 0.08) : Colors.black45,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isWhite ? Colors.black26 : Colors.white24,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.my_location, color: textColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'KOORDINAT GPS DARURAT',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      '${lat.toStringAsFixed(6)}°, ${lng.toStringAsFixed(6)}°',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Divider(height: 16, color: Colors.white24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Korban / Pendaki:',
                              style: TextStyle(color: subtextColor, fontSize: 11),
                            ),
                            Text(
                              nama,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Waktu Sinyal:',
                              style: TextStyle(color: subtextColor, fontSize: 11),
                            ),
                            Text(
                              DateFormat('HH:mm:ss WIB').format(waktu),
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Pilihan Mode Kedap-Kedip
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _modeButton(0, '⚡ Kedap-Kedip', isWhite),
                  const SizedBox(width: 8),
                  _modeButton(1, '📡 Kode Morse', isWhite),
                  const SizedBox(width: 8),
                  _modeButton(2, '💡 Tetap Nyala', isWhite),
                ],
              ),

              const SizedBox(height: 20),

              // Tombol Matikan Alarm / Saya Baik-Baik Saja
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _cancelSOS,
                    icon: const Icon(Icons.check_circle_outline, size: 24),
                    label: const Text(
                      'SAYA SUDAH AMAN (MATIKAN SOS)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isWhite ? const Color(0xFFD50000) : Colors.white,
                      foregroundColor: isWhite ? Colors.white : const Color(0xFFD50000),
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeButton(int mode, String label, bool isWhite) {
    final isSelected = _strobeMode == mode;
    return GestureDetector(
      onTap: () => _switchMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isWhite ? const Color(0xFFD50000) : Colors.white)
              : Colors.black26,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white30,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? (isWhite ? Colors.white : const Color(0xFFD50000))
                : (isWhite ? Colors.black87 : Colors.white),
          ),
        ),
      ),
    );
  }
}
