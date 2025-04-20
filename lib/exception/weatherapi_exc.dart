class WeatherApiException implements Exception {
  final String message;
  WeatherApiException(this.message);

  @override
  String toString() => "WeatherApiException: $message";
}
