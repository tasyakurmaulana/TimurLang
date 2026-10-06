// ============================================
// TimurLang - Weather Screen
// ============================================

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/weather_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  WeatherData? _currentWeather;
  List<WeatherForecast> _forecast = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    try {
      final current = await WeatherService.instance.getCurrentWeather(-8.108, 112.922);
      final forecast = await WeatherService.instance.getForecast(-8.108, 112.922);
      
      if (mounted) {
        setState(() {
          _currentWeather = current;
          _forecast = forecast;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Informasi Cuaca')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentWeather == null
              ? const Center(child: Text('Gagal memuat data cuaca.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentWeather!.isStormWarning)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerRed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.warning, color: Colors.white, size: 40),
                              SizedBox(height: 8),
                              Text(
                                'PERINGATAN BADAI',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              Text('Hindari pendakian dan berlindung di pos.', textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      
                      // Current Weather Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: AppTheme.skyGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(_currentWeather!.icon, style: const TextStyle(fontSize: 80)),
                            Text(
                              '${_currentWeather!.temperature}°C',
                              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              _currentWeather!.condition,
                              style: const TextStyle(fontSize: 24, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _currentWeather!.description,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const Divider(color: Colors.white24, height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _weatherDetailItem(Icons.water_drop, '${_currentWeather!.humidity.toStringAsFixed(0)}%', 'Kelembapan'),
                                _weatherDetailItem(Icons.air, '${_currentWeather!.windSpeed.toStringAsFixed(1)} km/h', 'Angin'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      const Text('Prakiraan 5 Hari Kedepan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      
                      // Forecast List
                      ..._forecast.map((f) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text('${f.date.day}/${f.date.month}', style: const TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(child: Row(
                              children: [
                                Text(f.icon, style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 8),
                                Text(f.condition, style: const TextStyle(fontSize: 12)),
                              ],
                            )),
                            Text('${f.tempMin}° / ${f.tempMax}°'),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
    );
  }

  Widget _weatherDetailItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}
