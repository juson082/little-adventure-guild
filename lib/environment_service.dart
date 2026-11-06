import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quest_environment.dart';

/// Reads approximate location only after consent; never stores coordinates.
class EnvironmentService {
  const EnvironmentService();
  static const _location = MethodChannel('hvildir/approximate_location');

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
      // Suppress all repeat requests until expiry without storing coordinates.
      final prefs = await SharedPreferences.getInstance();
      final retryAfter = prefs.getInt('met_weather_retry_after_ms') ?? 0;
      if (DateTime.now().millisecondsSinceEpoch < retryAfter) return null;
      final uri =
          Uri.https('api.met.no', '/weatherapi/locationforecast/2.0/compact', {
        'lat': lat.toStringAsFixed(1),
        'lon': lon.toStringAsFixed(1),
      });
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 4);
      try {
        final request =
            await client.getUrl(uri).timeout(const Duration(seconds: 5));
        request.headers.set(
            HttpHeaders.userAgentHeader, 'Hvildir/1.0 pooiuytt08@naver.com');
        final response =
            await request.close().timeout(const Duration(seconds: 5));
        if (response.statusCode == HttpStatus.tooManyRequests) {
          await prefs.setInt(
              'met_weather_retry_after_ms',
              DateTime.now()
                  .add(const Duration(minutes: 30))
                  .millisecondsSinceEpoch);
          return null;
        }
        if (response.statusCode != HttpStatus.ok) return null;
        final expires = response.headers.value(HttpHeaders.expiresHeader);
        var expiry = DateTime.now().add(const Duration(hours: 3));
        if (expires != null) {
          try {
            final headerExpiry = HttpDate.parse(expires);
            if (headerExpiry.isAfter(expiry)) expiry = headerExpiry;
          } on FormatException {
            // Keep the conservative interval if the header is malformed.
          }
        }
        await prefs.setInt(
            'met_weather_retry_after_ms', expiry.millisecondsSinceEpoch);
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

/// Locationforecast returns model forecasts, not observed recent rainfall.
WeatherObservation? parseWeather(Object? data, DateTime now) {
  try {
    if (data is! Map) return null;
    final properties = data['properties'];
    if (properties is! Map || properties['timeseries'] is! List) return null;
    Map? best;
    DateTime? bestTime;
    Map? nextItem;
    DateTime? nextTime;
    for (final item in properties['timeseries'] as List) {
      if (item is! Map || item['time'] is! String || item['data'] is! Map) {
        continue;
      }
      final time = DateTime.tryParse(item['time'] as String);
      if (time == null) continue;
      if (time.isAfter(now)) {
        if (nextTime == null || time.isBefore(nextTime)) {
          nextItem = item;
          nextTime = time;
        }
        continue;
      }
      if (bestTime == null || time.isAfter(bestTime)) {
        best = item;
        bestTime = time;
      }
    }
    if (best == null &&
        nextTime != null &&
        nextTime.difference(now) <= const Duration(hours: 1)) {
      best = nextItem;
      bestTime = nextTime;
    }
    if (best == null ||
        bestTime == null ||
        now.difference(bestTime) > const Duration(hours: 3)) {
      return null;
    }
    final forecast = best['data'] as Map;
    final instant = forecast['instant'];
    if (instant is! Map || instant['details'] is! Map) return null;
    final clouds = (instant['details'] as Map)['cloud_area_fraction'];
    final wind = (instant['details'] as Map)['wind_speed'];
    final next = forecast['next_1_hours'];
    if (clouds is! num ||
        wind is! num ||
        !clouds.isFinite ||
        !wind.isFinite ||
        clouds < 0 ||
        clouds > 100 ||
        wind < 0 ||
        next is! Map ||
        next['summary'] is! Map) {
      return null;
    }
    final symbol = (next['summary'] as Map)['symbol_code'];
    if (symbol is! String || symbol.isEmpty) return null;
    final rainy = symbol.contains('rain');
    return WeatherObservation(
      code: rainy
          ? 61
          : (symbol.startsWith('clearsky') ||
                  symbol.startsWith('fair') ||
                  symbol.startsWith('partlycloudy')
              ? 1
              : 3),
      cloudCover: clouds.toDouble(),
      windKmh: wind.toDouble() * 3.6,
      recentRain: null,
    );
  } on Object {
    return null;
  }
}
