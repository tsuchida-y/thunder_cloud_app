import 'dart:developer';
import 'package:thunder_cloud_app/services/weather/directional_weather.dart';
import 'package:thunder_cloud_app/services/weather/weather_api.dart';

final WeatherApi weatherApi = WeatherApi();
final DirectionalWeather directionalWeather = DirectionalWeather(weatherApi);

bool isCloudyConditionMet(Map<String, dynamic> weatherData) {
  final isThunderstorm = weatherData["weather"] == "Thunderstorm";
  final isCloudy = weatherData["weather"] == "Clouds" &&
      (weatherData["detailed_weather"].contains("thunderstorm") ||
          weatherData["detailed_weather"].contains("heavy rain") ||
          weatherData["detailed_weather"].contains("squalls") ||
          weatherData["detailed_weather"].contains("hail"));
  final isHot = weatherData["temperature"] > 25.0;

  return (isThunderstorm || isCloudy) && isHot;
}

Future<List<String>> fetchWeatherInDirections(
    double currentLatitude, double currentLongitude) async {
  List<String> tempMatchingCities = [];
  const directions = ["north", "south", "east", "west"];

  try {
    for (final direction in directions) {
      final weather = await directionalWeather.fetchWeatherInDirection(
          direction, currentLatitude, currentLongitude);
      log("$direction: $weather");
      if (isCloudyConditionMet(weather)) {
        tempMatchingCities.add(direction);
      }
    }
  } catch (e) {
    log("Error checking weather in directions: $e");
  }

  return tempMatchingCities;
}
