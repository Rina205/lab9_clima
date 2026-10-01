import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const ClimaApp());
}

class ClimaApp extends StatelessWidget {
  const ClimaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clima',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ),
      ),
      home: const ClimaHomePage(),
    );
  }
}

class ClimaHomePage extends StatefulWidget {
  const ClimaHomePage({super.key});

  @override
  State<ClimaHomePage> createState() => _ClimaHomePageState();
}

class _ClimaHomePageState extends State<ClimaHomePage> {
  final TextEditingController _cityController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  WeatherData? _weather;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocationWeather();
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocationWeather() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final position = await _determinePosition();
      final data = await _fetchWeatherByCoordinates(
        position.latitude,
        position.longitude,
      );
      setState(() {
        _weather = data;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchWeather() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập tên thành phố.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _fetchWeatherByCity(city);
      setState(() {
        _weather = data;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Dịch vụ vị trí đang tắt.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Bạn chưa cấp quyền vị trí cho ứng dụng.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Quyền vị trí đã bị từ chối vĩnh viễn.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
      ),
    );
  }

  Future<WeatherData> _fetchWeatherByCity(String city) async {
    final geoUrl = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(city)}&count=1&language=en&format=json',
    );

    final geoResponse = await http.get(geoUrl);
    if (geoResponse.statusCode != 200) {
      throw Exception('Không thể tìm thành phố.');
    }

    final body = jsonDecode(geoResponse.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      throw Exception('Không tìm thấy thành phố này.');
    }

    final location = results.first as Map<String, dynamic>;
    final lat = location['latitude'] as num;
    final lon = location['longitude'] as num;
    final cityName = location['name'] as String? ?? city;
    final country = location['country'] as String? ?? '';

    return _fetchWeatherByCoordinates(
      lat.toDouble(),
      lon.toDouble(),
      label: country.isEmpty ? cityName : '$cityName, $country',
    );
  }

  Future<WeatherData> _fetchWeatherByCoordinates(
    double latitude,
    double longitude, {
    String? label,
  }) async {
    final weatherUrl = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,weather_code,wind_speed_10m&hourly=temperature_2m&timezone=auto',
    );

    final response = await http.get(weatherUrl);
    if (response.statusCode != 200) {
      throw Exception('Không thể lấy dữ liệu thời tiết.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final current = body['current'] as Map<String, dynamic>? ?? {};
    final temperature = (current['temperature_2m'] as num?)?.toDouble() ?? 0.0;
    final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;
    final weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;

    return WeatherData(
      location: label ?? 'Vị trí hiện tại',
      temperature: temperature,
      description: _weatherDescription(weatherCode),
      icon: _weatherIcon(weatherCode),
      windSpeed: wind,
    );
  }

  String _weatherDescription(int code) {
    switch (code) {
      case 0:
        return 'Clear sky';
      case 1:
      case 2:
      case 3:
        return 'Partly cloudy';
      case 45:
      case 48:
        return 'Fog';
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
        return 'Rain';
      case 71:
      case 73:
      case 75:
      case 77:
      case 79:
        return 'Snow';
      case 80:
      case 81:
      case 82:
        return 'Heavy rain';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorm';
      default:
        return 'Weather update';
    }
  }

  IconData _weatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny_outlined;
    if (code <= 3) return Icons.wb_cloudy_outlined;
    if (code >= 45 && code <= 48) return Icons.cloud;
    if (code >= 51 && code <= 57) return Icons.grain;
    if (code >= 61 && code <= 67) return Icons.water_drop;
    if (code >= 71 && code <= 82) return Icons.ac_unit;
    if (code >= 95) return Icons.thunderstorm;
    return Icons.wb_cloudy;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Clima',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cityController,
                        onSubmitted: (_) => _searchWeather(),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Nhập tên thành phố',
                          hintStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white12,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            onPressed: _searchWeather,
                            icon: const Icon(Icons.search, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filled(
                      onPressed: _loadCurrentLocationWeather,
                      icon: const Icon(Icons.location_on_outlined),
                      tooltip: 'Vị trí hiện tại',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_errorMessage != null)
                  Expanded(
                    child: Center(
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  )
                else if (_weather != null)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _weather!.icon,
                          size: 90,
                          color: Colors.amberAccent,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '${_weather!.temperature.round()}°C',
                          style: const TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _weather!.description,
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _weather!.location,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _infoCard(
                              title: 'Wind',
                              value: '${_weather!.windSpeed.round()} km/h',
                              icon: Icons.air,
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Chưa có dữ liệu thời tiết.',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.lightBlueAccent),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WeatherData {
  final String location;
  final double temperature;
  final String description;
  final IconData icon;
  final double windSpeed;

  const WeatherData({
    required this.location,
    required this.temperature,
    required this.description,
    required this.icon,
    required this.windSpeed,
  });
}
