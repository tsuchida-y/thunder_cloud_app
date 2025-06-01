class AdvancedWeatherData {
  final double cape;
  final double liftedIndex;
  final double convectiveInhibition;
  final double temperature;
  final double humidity;
  
  AdvancedWeatherData({
    required this.cape,
    required this.liftedIndex,
    required this.convectiveInhibition,
    required this.temperature,
    required this.humidity,
  });
  
  factory AdvancedWeatherData.fromMap(Map<String, dynamic> map) {
    return AdvancedWeatherData(
      cape: (map['cape'] ?? 0.0).toDouble(),
      liftedIndex: (map['lifted_index'] ?? 0.0).toDouble(),
      convectiveInhibition: (map['convective_inhibition'] ?? 0.0).toDouble(),
      temperature: (map['temperature'] ?? 20.0).toDouble(),
      humidity: (map['humidity'] ?? 50.0).toDouble(),
    );
  }
}