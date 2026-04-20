import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_application_pharmacy/features/reports/controllers/sales_report_controller.dart';
import 'package:flutter_application_pharmacy/services/firebase_service.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

void main() {
  late SalesReportController controller;
  late MockFirebaseService mockFirebaseService;

  setUp(() {
    mockFirebaseService = MockFirebaseService();
  });

  test('Initial state is loading', () {
    when(() => mockFirebaseService.fetchSales()).thenAnswer((_) async => []);
    controller = SalesReportController(firebaseService: mockFirebaseService);
    expect(controller.isLoading, true);
  });

  test('Calculates total revenue correctly', () async {
    final mockSales = [
      {'sellingPrice': 100.0, 'date': '2024-01-01'},
      {'sellingPrice': 50.5, 'date': '2024-01-02'},
    ];

    when(() => mockFirebaseService.fetchSales()).thenAnswer((_) async => mockSales);
    
    controller = SalesReportController(firebaseService: mockFirebaseService);
    
    // Wait for data to load
    await Future.delayed(Duration.zero);
    
    expect(controller.filteredSales.length, 2);
    expect(controller.totalRevenue, 150.5);
    expect(controller.isLoading, false);
  });

  test('Filters sales by Ethiopian month correctly', () async {
    // 2024-05-15 is Ginbot in Ethiopian calendar
    // 2024-01-15 is Tir in Ethiopian calendar
    final mockSales = [
      {'sellingPrice': 100.0, 'date': '2024-05-15'}, // Ginbot
      {'sellingPrice': 50.0, 'date': '2024-01-15'},  // Tir
    ];

    when(() => mockFirebaseService.fetchSales()).thenAnswer((_) async => mockSales);
    
    controller = SalesReportController(firebaseService: mockFirebaseService);
    await Future.delayed(Duration.zero);

    controller.setMonth('Ginbot');
    expect(controller.filteredSales.length, 1);
    expect(controller.totalRevenue, 100.0);

    controller.setMonth('Tir');
    expect(controller.filteredSales.length, 1);
    expect(controller.totalRevenue, 50.0);

    controller.setMonth('All');
    expect(controller.filteredSales.length, 2);
    expect(controller.totalRevenue, 150.0);
  });
}
