import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class WeatherInfo {
  final String city;
  final double temperature;
  final String description;
  final double windSpeed;
  final int humidity;

  WeatherInfo({
    required this.city,
    required this.temperature,
    required this.description,
    required this.windSpeed,
    required this.humidity,
  });

  String get summary => '$city，$description，气温${temperature.round()}°C，湿度$humidity%，风速${windSpeed.round()}m/s';
}

class WeatherService {
  /// 获取当前位置的天气信息
  Future<WeatherInfo?> getCurrentWeather() async {
    try {
      // 检查定位权限
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('定位服务未开启');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('定位权限被拒绝');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint('定位权限被永久拒绝');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // 反向地理编码获取城市名
      String city = '未知位置';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          city = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? '未知位置';
        }
      } catch (e) {
        debugPrint('反向地理编码失败: $e');
      }

      // 使用 Open-Meteo 免费天气 API（无需 API Key）
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${position.latitude}'
        '&longitude=${position.longitude}'
        '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m'
        '&timezone=auto',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        debugPrint('天气API请求失败: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      final current = data['current'];
      final temp = (current['temperature_2m'] as num).toDouble();
      final humidity = (current['relative_humidity_2m'] as num).toInt();
      final windSpeed = (current['wind_speed_10m'] as num).toDouble();
      final weatherCode = (current['weather_code'] as num).toInt();

      return WeatherInfo(
        city: city,
        temperature: temp,
        description: _weatherCodeToDescription(weatherCode),
        windSpeed: windSpeed / 3.6, // km/h -> m/s
        humidity: humidity,
      );
    } catch (e) {
      debugPrint('获取天气失败: $e');
      return null;
    }
  }

  String _weatherCodeToDescription(int code) {
    if (code == 0) return '晴天';
    if (code <= 3) return '多云';
    if (code <= 48) return '雾';
    if (code <= 57) return '毛毛雨';
    if (code <= 67) return '雨';
    if (code <= 77) return '雪';
    if (code <= 82) return '阵雨';
    if (code <= 86) return '阵雪';
    if (code >= 95) return '雷暴';
    return '多云';
  }
}
