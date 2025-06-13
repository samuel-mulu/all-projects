class WeatherModel {
  final double temperature;
  final String description;
  final String icon;

  WeatherModel({
    required this.temperature,
    required this.description,
    required this.icon,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    return WeatherModel(
      temperature: json['current']['temp'],
      description: json['current']['weather'][0]['description'],
      icon: json['current']['weather'][0]['icon'],
    );
  }
}
