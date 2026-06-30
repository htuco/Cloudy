import 'dart:convert';
import 'dart:async';

import 'package:cloudy/models/forecast_data.dart';
import 'package:cloudy/models/geo_data.dart';
import 'package:cloudy/models/hourly_forecast_data.dart';
import 'package:cloudy/models/weather_data.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../core/constants/api_endpoints.dart';

// API key is read from the bundled .env asset. On web/CI the value is injected
// at build time via --dart-define / the .env created by the build pipeline.
String get apiKey {
  try {
    return dotenv.env['WEATHER_API_KEY'] ?? '';
  } catch (_) {
    return '';
  }
}

class WeatherRepository {
  Future<GeoData?> getGeoData(String city) async {
    String url = '$baseUrl$geoDirect?q=$city&limit=5&appid=$apiKey';

    try {
      var res = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏱️ getGeoData timed out');
          throw TimeoutException('API request timed out');
        },
      );

      if (res.statusCode != 200) {
        debugPrint('❌ getGeoData error: ${res.statusCode} — ${res.body}');
        return null;
      }

      GeoData geoData = GeoData.fromJson(jsonDecode(res.body));
      debugPrint(geoData.toString());
      return geoData;
    } catch (e) {
      debugPrint('Exception in getGeoData: $e');
      return null;
    }
  }

  Future<WeatherData?> getWeatherData(GeoData geoData) async {
    String url =
        '$baseUrl$currentWeather?lat=${geoData.lat}&lon=${geoData.lon}&units=metric&appid=$apiKey';

    try {
      var res = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏱️ getWeatherData timed out');
          throw TimeoutException('API request timed out');
        },
      );

      if (res.statusCode != 200) {
        debugPrint('❌ getWeatherData error: ${res.statusCode} — ${res.body}');
        return null;
      }

      WeatherData weatherData = WeatherData.fromJson(jsonDecode(res.body));
      debugPrint(weatherData.toString());
      return weatherData;
    } catch (e) {
      debugPrint('Exception in getWeatherData: $e');
      return null;
    }
  }

  Future<ForecastData?> getDailyForecast(GeoData geoData, {int cnt = 7}) async {
    String url =
        '$baseUrl$dailyForecast?lat=${geoData.lat}&lon=${geoData.lon}&cnt=$cnt&units=metric&appid=$apiKey';

    try {
      var res = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏱️ getDailyForecast timed out');
          throw TimeoutException('API request timed out');
        },
      );

      if (res.statusCode != 200) {
        debugPrint('Daily forecast endpoint returned ${res.statusCode}, using hourly fallback');
        return null;
      }

      ForecastData forecastData = ForecastData.fromJson(jsonDecode(res.body));
      debugPrint('✅ Daily forecast: $forecastData');
      return forecastData;
    } catch (e) {
      debugPrint('Exception in getDailyForecast: $e');
      return null;
    }
  }

  Future<HourlyForecastData?> getHourlyForecast(GeoData geoData) async {
    String url =
        '$baseUrl$forecast?lat=${geoData.lat}&lon=${geoData.lon}&units=metric&appid=$apiKey';

    try {
      var res = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏱️ getHourlyForecast timed out');
          throw TimeoutException('API request timed out');
        },
      );

      if (res.statusCode != 200) {
        debugPrint('Error getting hourly forecast: ${res.statusCode}');
        return null;
      }

      HourlyForecastData data = HourlyForecastData.fromJson(jsonDecode(res.body));
      debugPrint('✅ Hourly forecast: ${data.list?.length ?? 0} items');
      return data;
    } catch (e) {
      debugPrint('Exception in getHourlyForecast: $e');
      return null;
    }
  }

  /// Build daily forecast from hourly 3h data by grouping per day
  ForecastData _buildDailyFromHourly(HourlyForecastData hourly) {
    if (hourly.list == null || hourly.list!.isEmpty) {
      return ForecastData(list: []);
    }

    // Group by date
    final Map<String, List<HourlyItem>> grouped = {};
    for (final item in hourly.list!) {
      final date = DateTime.fromMillisecondsSinceEpoch((item.dt ?? 0) * 1000);
      final key = '${date.year}-${date.month}-${date.day}';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(item);
    }

    final List<DailyForecast> dailyList = [];
    for (final entry in grouped.entries) {
      final items = entry.value;
      double minTemp = double.infinity;
      double maxTemp = double.negativeInfinity;
      double totalHumidity = 0;
      double totalSpeed = 0;
      double maxPop = 0;

      for (final item in items) {
        final temp = item.main?.temp ?? 0;
        if (temp < minTemp) minTemp = temp;
        if (temp > maxTemp) maxTemp = temp;
        totalHumidity += item.main?.humidity ?? 0;
        totalSpeed += item.wind?.speed ?? 0;
        if ((item.pop ?? 0) > maxPop) maxPop = item.pop ?? 0;
      }

      // Use noon item for representative weather, or first item
      final noonItem = items.firstWhere(
        (i) {
          final h = DateTime.fromMillisecondsSinceEpoch((i.dt ?? 0) * 1000).hour;
          return h >= 11 && h <= 14;
        },
        orElse: () => items[items.length ~/ 2],
      );

      dailyList.add(DailyForecast(
        dt: noonItem.dt,
        temp: DailyTemp(
          day: noonItem.main?.temp,
          min: minTemp == double.infinity ? null : minTemp,
          max: maxTemp == double.negativeInfinity ? null : maxTemp,
          night: items.last.main?.temp,
          morn: items.first.main?.temp,
        ),
        humidity: (totalHumidity / items.length).round(),
        speed: totalSpeed / items.length,
        pop: maxPop,
        weather: noonItem.weather
            ?.map((w) => DailyWeather(
                  id: w.id,
                  main: w.main,
                  description: w.description,
                  icon: w.icon,
                ))
            .toList(),
      ));
    }

    debugPrint('✅ Built ${dailyList.length} daily forecasts from hourly data');
    return ForecastData(list: dailyList, cnt: dailyList.length);
  }

  Future<Map<String, dynamic>?> apiCall(String city) async {
    try {
      final GeoData? geoData = await getGeoData(city);
      if (geoData == null) return null;

      // Fetch all data in parallel
      final results = await Future.wait([
        getWeatherData(geoData),
        getDailyForecast(geoData),
        getHourlyForecast(geoData),
      ]);

      final current = results[0] as WeatherData?;
      ForecastData? daily = results[1] as ForecastData?;
      final hourly = results[2] as HourlyForecastData?;

      // Fallback: if daily forecast fails (401), build from hourly data
      if (daily == null && hourly != null) {
        debugPrint('⚡ Using hourly-to-daily fallback');
        daily = _buildDailyFromHourly(hourly);
      }

      return {
        'current': current,
        'daily': daily,
        'hourly': hourly,
      };
    } catch (e) {
      debugPrint('Exception in apiCall: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> apiCallByCoords({
    required double lat,
    required double lon,
  }) async {
    try {
      debugPrint('🌐 [apiCallByCoords] START');
      final geoData = GeoData(lat: lat, lon: lon);

      debugPrint('🌐 [apiCallByCoords] Running 3 parallel API calls...');
      final results = await Future.wait([
        getWeatherData(geoData),
        getDailyForecast(geoData),
        getHourlyForecast(geoData),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('⏱️ apiCallByCoords timed out waiting for API responses');
          throw TimeoutException('Overall API timeout');
        },
      );

      debugPrint('🌐 [apiCallByCoords] All 3 API calls completed');
      final current = results[0] as WeatherData?;
      ForecastData? daily = results[1] as ForecastData?;
      final hourly = results[2] as HourlyForecastData?;
      debugPrint('🌐 [apiCallByCoords] Parsed - current=${current?.name}, daily=${daily?.list?.length}, hourly=${hourly?.list?.length}');

      if (daily == null && hourly != null) {
        debugPrint('⚡ [apiCallByCoords] Using hourly-to-daily fallback');
        daily = _buildDailyFromHourly(hourly);
        debugPrint('⚡ [apiCallByCoords] Fallback created ${daily.list?.length} days');
      }

      debugPrint('🌐 [apiCallByCoords] DONE - returning data');
      return {
        'current': current,
        'daily': daily,
        'hourly': hourly,
      };
    } catch (e) {
      debugPrint('❌ [apiCallByCoords] Exception: $e');
      return null;
    }
  }
}
