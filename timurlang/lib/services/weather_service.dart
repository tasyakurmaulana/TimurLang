// ============================================
// TimurLang - Weather Service (Mock OpenWeather)
// ============================================

import 'dart:math';

class WeatherData {
  final double temperature;
  final double humidity;
  final double windSpeed;
  final String condition;
  final String description;
  final String icon;
  final bool isStormWarning;
  final DateTime lastUpdated;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.condition,
    required this.description,
    required this.icon,
    required this.isStormWarning,
    required this.lastUpdated,
  });
}

class WeatherForecast {
  final DateTime date;
  final double tempMin;
  final double tempMax;
  final String condition;
  final String icon;

  WeatherForecast({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.condition,
    required this.icon,
  });
}

class WeatherService {
  static final WeatherService instance = WeatherService._internal();
  WeatherService._internal();

  final _random = Random();

  /// Get current weather for mountain coordinates (mock)
  Future<WeatherData> getCurrentWeather(double lat, double lon) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));

    final conditions = [
      ('Cerah', 'Langit cerah, cocok untuk pendakian', '☀️', false),
      ('Berawan', 'Berawan sebagian, jarak pandang cukup baik', '⛅', false),
      ('Mendung', 'Mendung tebal, kemungkinan hujan ringan', '☁️', false),
      ('Hujan Ringan', 'Gerimis, jalur mungkin licin', '🌧️', false),
      ('Hujan Lebat', 'Hujan deras, waspada banjir bandang', '⛈️', true),
      ('Kabut Tebal', 'Jarak pandang sangat rendah, hati-hati', '🌫️', false),
      ('Badai', 'PERINGATAN: Badai kuat, hindari jalur terbuka', '🌪️', true),
    ];

    final idx = _random.nextInt(conditions.length);
    final (condition, desc, icon, storm) = conditions[idx];

    // Temperature based on elevation (higher = colder)
    final baseTemp = 28.0 - (lat.abs() * 0.5);
    final temp = baseTemp - _random.nextDouble() * 10;

    return WeatherData(
      temperature: double.parse(temp.toStringAsFixed(1)),
      humidity: 60 + _random.nextDouble() * 35,
      windSpeed: 5 + _random.nextDouble() * 25,
      condition: condition,
      description: desc,
      icon: icon,
      isStormWarning: storm,
      lastUpdated: DateTime.now(),
    );
  }

  /// Get 5-day forecast (mock)
  Future<List<WeatherForecast>> getForecast(double lat, double lon) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final conditions = ['Cerah', 'Berawan', 'Hujan Ringan', 'Mendung', 'Cerah'];
    final icons = ['☀️', '⛅', '🌧️', '☁️', '☀️'];

    return List.generate(5, (i) {
      final date = DateTime.now().add(Duration(days: i + 1));
      final baseTemp = 15 + _random.nextDouble() * 10;
      return WeatherForecast(
        date: date,
        tempMin: double.parse((baseTemp - 5).toStringAsFixed(1)),
        tempMax: double.parse((baseTemp + 5).toStringAsFixed(1)),
        condition: conditions[i],
        icon: icons[i],
      );
    });
  }
}
