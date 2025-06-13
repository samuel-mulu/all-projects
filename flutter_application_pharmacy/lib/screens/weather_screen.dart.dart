import 'package:flutter/material.dart';
import '../services/weather_service.dart';
import '../models/weather_model.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({Key? key}) : super(key: key);

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  WeatherModel? weather;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeatherData();
  }

  Future<void> _loadWeatherData() async {
    try {
      final weatherData = await WeatherService().fetchWeather(14.1057, 38.2825);
      setState(() {
        weather = weatherData;
        isLoading = false;
      });
    } catch (e) {
      print('Error: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather in Shire'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : weather == null
              ? const Center(child: Text('Failed to load weather data.'))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${weather!.temperature}°C',
                      style: const TextStyle(fontSize: 48),
                    ),
                    Text(
                      weather!.description,
                      style: const TextStyle(fontSize: 24),
                    ),
                    Image.network(
                      'https://openweathermap.org/img/wn/${weather!.icon}@2x.png',
                      height: 100,
                      width: 100,
                    ),
                  ],
                ),
    );
  }
}
