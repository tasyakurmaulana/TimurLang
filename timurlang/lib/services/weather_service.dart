// ============================================
// TimurLang - Weather Service (OpenWeatherMap API)
// ============================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherData {
  final double temperature;
  final double feelsLike;
  final double tempMin;
  final double tempMax;
  final double humidity;
  final double windSpeed;
  final double pressure;
  final int visibility;
  final String condition;
  final String description;
  final String icon;
  final bool isStormWarning;
  final DateTime lastUpdated;
  final DateTime stationTime;
  final String locationName;
  final double latitude;
  final double longitude;
  final int clouds;
  final double? rain1h;
  final int sunrise;
  final int sunset;

  WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.windSpeed,
    required this.pressure,
    required this.visibility,
    required this.condition,
    required this.description,
    required this.icon,
    required this.isStormWarning,
    required this.lastUpdated,
    required this.stationTime,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.clouds,
    this.rain1h,
    required this.sunrise,
    required this.sunset,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final weather = json['weather'][0];
    final main = json['main'];
    final wind = json['wind'];
    final sys = json['sys'];
    final coord = json['coord'] ?? {};

    // Determine storm warning based on weather condition codes
    final int weatherId = weather['id'];
    final bool isStorm = weatherId >= 200 && weatherId < 300;
    final bool isHeavyRain = weatherId == 502 || weatherId == 503 || weatherId == 504;

    final dtEpoch = json['dt'] as int? ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);

    return WeatherData(
      temperature: (main['temp'] as num).toDouble(),
      feelsLike: (main['feels_like'] as num).toDouble(),
      tempMin: (main['temp_min'] as num?)?.toDouble() ?? (main['temp'] as num).toDouble(),
      tempMax: (main['temp_max'] as num?)?.toDouble() ?? (main['temp'] as num).toDouble(),
      humidity: (main['humidity'] as num).toDouble(),
      windSpeed: (wind['speed'] as num).toDouble() * 3.6, // m/s to km/h
      pressure: (main['pressure'] as num).toDouble(),
      visibility: json['visibility'] ?? 10000,
      condition: _translateCondition(weather['main']),
      description: _translateDescription(weather['description'], weatherId),
      icon: _getWeatherEmoji(weatherId, weather['icon']),
      isStormWarning: isStorm || isHeavyRain,
      lastUpdated: DateTime.now(),
      stationTime: DateTime.fromMillisecondsSinceEpoch(dtEpoch * 1000),
      locationName: json['name'] ?? 'Tidak Diketahui',
      latitude: (coord['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (coord['lon'] as num?)?.toDouble() ?? 0.0,
      clouds: json['clouds']?['all'] ?? 0,
      rain1h: json['rain']?['1h']?.toDouble(),
      sunrise: sys['sunrise'] ?? 0,
      sunset: sys['sunset'] ?? 0,
    );
  }

  /// Translate weather main condition to Indonesian
  static String _translateCondition(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return 'Cerah';
      case 'clouds':
        return 'Berawan';
      case 'rain':
        return 'Hujan';
      case 'drizzle':
        return 'Gerimis';
      case 'thunderstorm':
        return 'Badai Petir';
      case 'snow':
        return 'Salju';
      case 'mist':
        return 'Kabut Tipis';
      case 'smoke':
        return 'Berasap';
      case 'haze':
        return 'Kabut Asap';
      case 'dust':
        return 'Berdebu';
      case 'fog':
        return 'Kabut Tebal';
      case 'sand':
        return 'Badai Pasir';
      case 'ash':
        return 'Abu Vulkanik';
      case 'squall':
        return 'Angin Kencang';
      case 'tornado':
        return 'Tornado';
      default:
        return condition;
    }
  }

  /// Provide hiking-relevant descriptions in Indonesian
  static String _translateDescription(String desc, int weatherId) {
    // Group by weather ID for more specific descriptions
    if (weatherId >= 200 && weatherId < 300) {
      return 'PERINGATAN: Badai petir, hindari area terbuka dan puncak gunung!';
    } else if (weatherId >= 300 && weatherId < 400) {
      return 'Gerimis ringan, jalur mungkin licin. Gunakan jas hujan.';
    } else if (weatherId >= 500 && weatherId < 505) {
      if (weatherId == 500) {
        return 'Hujan ringan, waspada jalur licin.';
      } else if (weatherId == 501) {
        return 'Hujan sedang, jalur bisa licin dan berlumpur.';
      } else {
        return 'Hujan lebat! Waspada banjir bandang dan tanah longsor.';
      }
    } else if (weatherId >= 520 && weatherId < 532) {
      return 'Hujan deras mendadak, segera cari tempat berlindung.';
    } else if (weatherId >= 600 && weatherId < 700) {
      return 'Turun salju, suhu sangat dingin. Siapkan perlengkapan ekstra.';
    } else if (weatherId >= 700 && weatherId < 800) {
      if (weatherId == 741 || weatherId == 701) {
        return 'Kabut tebal, jarak pandang rendah. Hati-hati di jalur sempit.';
      }
      return 'Kondisi atmosfer buruk, jarak pandang terbatas.';
    } else if (weatherId == 800) {
      return 'Langit cerah, kondisi ideal untuk pendakian.';
    } else if (weatherId == 801) {
      return 'Sedikit berawan, cuaca cukup baik untuk pendakian.';
    } else if (weatherId == 802) {
      return 'Berawan sebagian, kondisi masih aman untuk pendakian.';
    } else if (weatherId == 803 || weatherId == 804) {
      return 'Mendung tebal, kemungkinan hujan. Siapkan jas hujan.';
    }
    return desc;
  }

  /// Map weather condition ID to emoji
  static String _getWeatherEmoji(int id, String iconCode) {
    if (id >= 200 && id < 300) return '⛈️';
    if (id >= 300 && id < 400) return '🌦️';
    if (id >= 500 && id < 600) return '🌧️';
    if (id >= 600 && id < 700) return '❄️';
    if (id == 701 || id == 741) return '🌫️';
    if (id >= 700 && id < 800) return '🌪️';
    if (id == 800) {
      // Check if it's night
      return iconCode.contains('n') ? '🌙' : '☀️';
    }
    if (id == 801) return iconCode.contains('n') ? '☁️' : '⛅';
    if (id == 802) return '⛅';
    if (id >= 803) return '☁️';
    return '🌡️';
  }

  /// Get OpenWeatherMap icon URL
  String get iconUrl => 'https://openweathermap.org/img/wn/${_getIconCode()}@2x.png';

  String _getIconCode() {
    // Fallback, not used since we use emojis
    return '01d';
  }
}

class HourlyForecast {
  final DateTime time;
  final double temperature;
  final String condition;
  final String icon;
  final double pop; // 0.0 - 1.0 (Probability of Precipitation)

  HourlyForecast({
    required this.time,
    required this.temperature,
    required this.condition,
    required this.icon,
    required this.pop,
  });
}

class WeatherForecast {
  final DateTime date;
  final double tempMin;
  final double tempMax;
  final double humidity;
  final double windSpeed;
  final String condition;
  final String icon;
  final int weatherId;
  final double pop; // Probability of precipitation

  WeatherForecast({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.windSpeed,
    required this.condition,
    required this.icon,
    required this.weatherId,
    required this.pop,
  });
}

class WeatherService {
  static final WeatherService instance = WeatherService._internal();
  WeatherService._internal();

  // OpenWeatherMap API Key
  static const String _apiKey = '918bb744f0079b7ad28f2a9f2ed1ee56';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  /// Determine and request location permissions, return current position with high accuracy
  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Layanan lokasi (GPS) tidak aktif. Aktifkan GPS Anda.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Izin lokasi ditolak. Berikan izin lokasi untuk data cuaca akurat.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Izin lokasi ditolak permanen. Buka Pengaturan > Aplikasi > TimurLang > Izin untuk mengaktifkan.',
      );
    }

    // Coba dapatkan posisi terbaru dengan akurasi tinggi
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      // Fallback ke posisi terakhir jika timeout di dalam ruangan
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) return lastPos;
      rethrow;
    }
  }

  /// Get current weather from OpenWeatherMap using device GPS location
  Future<WeatherData> getCurrentWeather(double? lat, double? lon) async {
    double latitude;
    double longitude;

    if (lat != null && lon != null && lat != 0 && lon != 0) {
      latitude = lat;
      longitude = lon;
    } else {
      // Get current location from GPS
      final position = await _getCurrentPosition();
      latitude = position.latitude;
      longitude = position.longitude;
    }

    final url = Uri.parse(
      '$_baseUrl/weather?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric&lang=id',
    );

    final response = await http.get(url).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Koneksi timeout. Periksa jaringan internet Anda.'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return WeatherData.fromJson(data);
    } else if (response.statusCode == 401) {
      throw Exception('API key tidak valid. Hubungi pengembang.');
    } else if (response.statusCode == 429) {
      throw Exception('Terlalu banyak permintaan. Coba lagi nanti.');
    } else {
      throw Exception('Gagal memuat data cuaca (${response.statusCode}).');
    }
  }

  /// Get current weather for a specific named location
  Future<WeatherData> getWeatherByCity(String cityName) async {
    final url = Uri.parse(
      '$_baseUrl/weather?q=$cityName&appid=$_apiKey&units=metric&lang=id',
    );

    final response = await http.get(url).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Koneksi timeout. Periksa jaringan internet Anda.'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return WeatherData.fromJson(data);
    } else if (response.statusCode == 404) {
      throw Exception('Lokasi "$cityName" tidak ditemukan.');
    } else {
      throw Exception('Gagal memuat data cuaca (${response.statusCode}).');
    }
  }

  /// Get forecast for a specific named location
  Future<List<WeatherForecast>> getForecastByCity(String cityName) async {
    final url = Uri.parse(
      '$_baseUrl/forecast?q=$cityName&appid=$_apiKey&units=metric&lang=id',
    );

    final response = await http.get(url).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Koneksi timeout. Periksa jaringan internet Anda.'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return _parseForecast(data);
    } else {
      throw Exception('Gagal memuat prakiraan untuk "$cityName".');
    }
  }

  /// Get 5-day forecast from OpenWeatherMap (3-hour intervals → aggregated per day)
  Future<List<WeatherForecast>> getForecast(double? lat, double? lon) async {
    double latitude;
    double longitude;

    if (lat != null && lon != null && lat != 0 && lon != 0) {
      latitude = lat;
      longitude = lon;
    } else {
      final position = await _getCurrentPosition();
      latitude = position.latitude;
      longitude = position.longitude;
    }

    final url = Uri.parse(
      '$_baseUrl/forecast?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric&lang=id',
    );

    final response = await http.get(url).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Koneksi timeout. Periksa jaringan internet Anda.'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return _parseForecast(data);
    } else {
      throw Exception('Gagal memuat prakiraan cuaca (${response.statusCode}).');
    }
  }

  /// Parse 3-hour forecast data into daily forecast (aggregate per day)
  List<WeatherForecast> _parseForecast(Map<String, dynamic> data) {
    final List<dynamic> list = data['list'];
    final Map<String, List<Map<String, dynamic>>> dailyMap = {};

    for (final item in list) {
      final dt = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
      final dayKey = '${dt.year}-${dt.month}-${dt.day}';

      // Skip today
      final today = DateTime.now();
      if (dt.year == today.year && dt.month == today.month && dt.day == today.day) {
        continue;
      }

      dailyMap.putIfAbsent(dayKey, () => []);
      dailyMap[dayKey]!.add(item as Map<String, dynamic>);
    }

    final List<WeatherForecast> forecasts = [];

    for (final entry in dailyMap.entries) {
      if (forecasts.length >= 5) break;

      final items = entry.value;
      double minTemp = double.infinity;
      double maxTemp = double.negativeInfinity;
      double totalHumidity = 0;
      double totalWind = 0;
      double maxPop = 0;

      // Find the most frequent weather condition (around midday preferred)
      Map<String, dynamic>? middayItem;
      int middayDiff = 24;

      for (final item in items) {
        final main = item['main'];
        final temp = (main['temp'] as num).toDouble();
        if (temp < minTemp) minTemp = temp;
        if (temp > maxTemp) maxTemp = temp;
        totalHumidity += (main['humidity'] as num).toDouble();
        totalWind += (item['wind']['speed'] as num).toDouble() * 3.6;

        final pop = (item['pop'] as num?)?.toDouble() ?? 0;
        if (pop > maxPop) maxPop = pop;

        final dt = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
        final diff = (dt.hour - 12).abs();
        if (diff < middayDiff) {
          middayDiff = diff;
          middayItem = item;
        }
      }

      final weather = middayItem?['weather']?[0] ?? items[0]['weather'][0];
      final weatherId = weather['id'] as int;
      final iconCode = weather['icon'] as String;

      forecasts.add(WeatherForecast(
        date: DateTime.fromMillisecondsSinceEpoch(items[0]['dt'] * 1000),
        tempMin: double.parse(minTemp.toStringAsFixed(1)),
        tempMax: double.parse(maxTemp.toStringAsFixed(1)),
        humidity: totalHumidity / items.length,
        windSpeed: totalWind / items.length,
        condition: WeatherData._translateCondition(weather['main']),
        icon: WeatherData._getWeatherEmoji(weatherId, iconCode),
        weatherId: weatherId,
        pop: maxPop,
      ));
    }

    return forecasts;
  }

  /// Get hourly forecast from OpenWeatherMap (parsed to 8-12 time intervals for smooth curve)
  Future<List<HourlyForecast>> getHourlyForecast(double? lat, double? lon) async {
    double latitude;
    double longitude;

    if (lat != null && lon != null && lat != 0 && lon != 0) {
      latitude = lat;
      longitude = lon;
    } else {
      final position = await _getCurrentPosition();
      latitude = position.latitude;
      longitude = position.longitude;
    }

    final url = Uri.parse(
      '$_baseUrl/forecast?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric&lang=id',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseHourlyForecast(data);
      }
    } catch (_) {}

    return _generateMockHourlyForecast();
  }

  /// Get hourly forecast by city name
  Future<List<HourlyForecast>> getHourlyForecastByCity(String cityName) async {
    final url = Uri.parse(
      '$_baseUrl/forecast?q=$cityName&appid=$_apiKey&units=metric&lang=id',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseHourlyForecast(data);
      }
    } catch (_) {}

    return _generateMockHourlyForecast();
  }

  /// Parse OpenWeatherMap 3h forecast intervals into hourly slots
  List<HourlyForecast> _parseHourlyForecast(Map<String, dynamic> data) {
    final List<dynamic> list = data['list'] ?? [];
    final List<HourlyForecast> result = [];

    // Take up to 10 intervals (up to 30 hours)
    for (int i = 0; i < list.length && i < 10; i++) {
      final item = list[i];
      final dt = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
      final main = item['main'] ?? {};
      final weatherList = item['weather'] as List<dynamic>?;
      final weather = (weatherList != null && weatherList.isNotEmpty) ? weatherList[0] : {};
      final int weatherId = weather['id'] ?? 800;
      final String iconCode = weather['icon'] ?? '01d';
      final double pop = (item['pop'] as num?)?.toDouble() ?? 0.0;

      result.add(HourlyForecast(
        time: dt,
        temperature: (main['temp'] as num?)?.toDouble() ?? 25.0,
        condition: WeatherData._translateCondition(weather['main'] ?? 'Clear'),
        icon: WeatherData._getWeatherEmoji(weatherId, iconCode),
        pop: pop,
      ));
    }

    return result.isEmpty ? _generateMockHourlyForecast() : result;
  }

  /// Fallback hourly generator if network or API error occurs
  List<HourlyForecast> _generateMockHourlyForecast() {
    final now = DateTime.now();
    final List<HourlyForecast> result = [];
    final baseTemps = [25.0, 25.0, 25.0, 25.0, 24.0, 24.0, 23.0, 26.0, 28.0, 31.0];
    final pops = [0.08, 0.11, 0.18, 0.31, 0.33, 0.33, 0.24, 0.15, 0.10, 0.05];
    final emojis = ['🌙', '☁️', '☁️', '🌧️', '🌧️', '🌧️', '⛅', '☀️', '☀️', '⛅'];

    for (int i = 0; i < 8; i++) {
      result.add(HourlyForecast(
        time: now.add(Duration(hours: i + 1)),
        temperature: baseTemps[i % baseTemps.length],
        condition: 'Berawan Sebagian',
        icon: emojis[i % emojis.length],
        pop: pops[i % pops.length],
      ));
    }
    return result;
  }
}
