class WeatherData {
  final String weather;
  final String detailedWeather;
  final double temperature;
  final double humidity;
  final double pressure;
  final int clouds;
  
  WeatherData({
    required this.weather,
    required this.detailedWeather,
    required this.temperature,
    required this.humidity,
    required this.pressure,
    required this.clouds,
  });
  
  factory WeatherData.fromMap(Map<String, dynamic> map) {
    return WeatherData(
      weather: map['weather'] ?? '',
      detailedWeather: map['detailed_weather'] ?? '',
      temperature: (map['temperature'] ?? 0.0).toDouble(),
      humidity: (map['humidity'] ?? 0.0).toDouble(),
      pressure: (map['atmospheric_pressure'] ?? 1013.25).toDouble(),
      clouds: map['clouds'] ?? 0,
    );
  }
}