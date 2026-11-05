import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'quest_environment.dart';

/// Reads an approximate foreground location only after the user opts in.
/// Coordinates are rounded before a single weather request and never stored.
class EnvironmentService {
  const EnvironmentService();
  static const _location = MethodChannel('hvildir/approximate_location');

  /// Called only after the user explicitly enables location-based weather.
  Future<bool> requestLocationPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      await _location.invokeMethod<Object?>('requestLocation');
      return await _location.invokeMethod<bool>('hasPermission') ?? false;
    } on Object {
      return false;
    }
  }

  Future<WeatherObservation?> currentWeather() async {
    if (!Platform.isAndroid) return null;
    try {
      final point =
          await _location.invokeMapMethod<String, dynamic>('getLocation');
      final lat = (point?['latitude'] as num?)?.toDouble();
      final lon = (point?['longitude'] as num?)?.toDouble();
      if (lat == null ||
          lon == null ||
          !lat.isFinite ||
          !lon.isFinite ||
          lat.abs() > 90 ||
          lon.abs() > 180) {
        return null;
      }
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': lat.toStringAsFixed(1),
        'longitude': lon.toStringAsFixed(1),
        'current': 'weather_code,cloud_cover,wind_speed_10m',
        'hourly': 'precipitation',
        'past_hours': '6',
        'forecast_hours': '1',
        'timezone': 'auto',
      });
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 4);
      try {
        final request =
            await client.getUrl(uri).timeout(const Duration(seconds: 5));
        final response =
            await request.close().timeout(const Duration(seconds: 5));
        if (response.statusCode != HttpStatus.ok) return null;
        final data = await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 5));
        if (data.length > 200000) return null;
        return parseWeather(jsonDecode(data), DateTime.now());
      } finally {
        client.close(force: true);
      }
    } on Object {
      return null;
    }
  }
}

WeatherObservation? parseWeather(Object? data, DateTime now) {
  try {
    if (data is! Map) return null;
    final current = data['current'];
    if (current is! Map) return null;
    final code = current['weather_code'];
    final clouds = current['cloud_cover'];
    final wind = current['wind_speed_10m'];
    if (code is! num ||
        clouds is! num ||
        wind is! num ||
        clouds < 0 ||
        clouds > 100 ||
        wind < 0) {
      return null;
    }
    final hourly = data['hourly'];
    var recentRain = false;
    if (hourly is Map &&
        hourly['time'] is List &&
        hourly['precipitation'] is List) {
      final times = hourly['time'] as List;
      final amounts = hourly['precipitation'] as List;
      for (var i = 0; i < times.length && i < amounts.length; i++) {
        DateTime? time;
        final offset = data['utc_offset_seconds'];
        if (times[i] is String) {
          final raw = times[i] as String;
          if (offset is num) {
            final localAsUtc = DateTime.tryParse('${raw}Z');
            time = localAsUtc?.subtract(Duration(seconds: offset.toInt()));
          } else {
            time = DateTime.tryParse(raw);
          }
        }
        final value = amounts[i];
        if (time != null &&
            value is num &&
            value > 0.1 &&
            !time.isAfter(now) &&
            now.difference(time) <= const Duration(hours: 6)) {
          recentRain = true;
        }
      }
    }
    return WeatherObservation(
        code: code.toInt(),
        cloudCover: clouds.toDouble(),
        windKmh: wind.toDouble(),
        recentRain: recentRain);
  } on Object {
    return null;
  }
}
