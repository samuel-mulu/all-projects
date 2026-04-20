import 'package:flutter_application_pharmacy/features/reports/controllers/sales_report_controller.dart';
import 'package:flutter_application_pharmacy/services/firebase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

void main() {
  late SalesReportController controller;
  late MockFirebaseService mockFirebaseService;

  setUp(() {
    mockFirebaseService = MockFirebaseService();
    when(() => mockFirebaseService.fetchExpenses()).thenAnswer((_) async => []);
  });

  test('initial state is loading', () {
    when(() => mockFirebaseService.fetchSales()).thenAnswer((_) async => []);

    controller = SalesReportController(firebaseService: mockFirebaseService);

    expect(controller.isLoading, true);
  });

  test('filters daily sales and calculates summary metrics', () async {
    final mockSales = [
      {
        'sellingPrice': 100.0,
        'date': '2024-01-01',
        'paymentMethod': 'Cash',
      },
      {
        'sellingPrice': 50.5,
        'date': '2024-01-01',
        'paymentMethod': 'Credit',
      },
      {
        'sellingPrice': 25.0,
        'date': '2024-01-02',
        'paymentMethod': 'Cash',
      },
    ];

    final mockExpenses = [
      {
        'amount': 20.0,
        'date': '2024-01-01',
        'paymentMethod': 'Cash',
        'reason': 'Transport',
      },
      {
        'amount': 10.0,
        'date': '2024-01-15',
        'paymentMethod': 'Cash',
        'reason': 'Packaging',
      },
    ];

    when(() => mockFirebaseService.fetchSales()).thenAnswer((_) async => mockSales);
    when(() => mockFirebaseService.fetchExpenses()).thenAnswer((_) async => mockExpenses);

    controller = SalesReportController(firebaseService: mockFirebaseService);
    await Future<void>.delayed(Duration.zero);

    controller.setSelectedDate(DateTime(2024, 1, 1));

    expect(controller.selectedPeriod, ReportPeriod.daily);
    expect(controller.filteredSales.length, 2);
    expect(controller.periodRevenue, 150.5);
    expect(controller.periodExpense, 20.0);
    expect(controller.periodTransactions, 2);
    expect(controller.creditSalesCount, 1);
    expect(controller.selectedMonthExpense, 30.0);
    expect(controller.isLoading, false);
  });

  test('filters monthly sales and calculates averages', () async {
    final mockSales = [
      {
        'sellingPrice': 100.0,
        'date': '2024-05-15',
        'paymentMethod': 'Cash',
      },
      {
        'sellingPrice': 50.0,
        'date': '2024-05-02',
        'paymentMethod': 'Credit',
      },
      {
        'sellingPrice': 75.0,
        'date': '2024-06-01',
        'paymentMethod': 'Cash',
      },
    ];

    final mockExpenses = [
      {
        'amount': 30.0,
        'date': '2024-05-03',
        'paymentMethod': 'Cash',
        'reason': 'Fuel',
      },
      {
        'amount': 20.0,
        'date': '2024-06-02',
        'paymentMethod': 'Mobile Banking',
        'reason': 'Rent',
      },
    ];

    when(() => mockFirebaseService.fetchSales()).thenAnswer((_) async => mockSales);
    when(() => mockFirebaseService.fetchExpenses()).thenAnswer((_) async => mockExpenses);

    controller = SalesReportController(firebaseService: mockFirebaseService);
    await Future<void>.delayed(Duration.zero);

    controller.setSelectedDate(DateTime(2024, 5, 20));
    controller.setPeriod(ReportPeriod.monthly);

    expect(controller.filteredSales.length, 2);
    expect(controller.periodRevenue, 150.0);
    expect(controller.periodExpense, 30.0);
    expect(controller.periodTransactions, 2);
    expect(controller.averageTransactionValue, 75.0);
    expect(controller.creditSalesCount, 1);
    expect(controller.selectedPeriodLabel, 'May 2024');
  });

  test('payment filter updates cards and history', () async {
    final mockSales = [
      {
        'sellingPrice': 100.0,
        'date': '2024-01-01',
        'paymentMethod': 'Cash',
      },
      {
        'sellingPrice': 50.0,
        'date': '2024-01-01',
        'paymentMethod': 'Mobile Banking',
      },
      {
        'sellingPrice': 25.0,
        'date': '2024-01-01',
        'paymentMethod': 'Credit',
      },
    ];

    final mockExpenses = [
      {
        'amount': 10.0,
        'date': '2024-01-01',
        'paymentMethod': 'Cash',
        'reason': 'Transport',
      },
      {
        'amount': 12.0,
        'date': '2024-01-01',
        'paymentMethod': 'Mobile Banking',
        'reason': 'Fuel',
      },
    ];

    when(() => mockFirebaseService.fetchSales()).thenAnswer((_) async => mockSales);
    when(() => mockFirebaseService.fetchExpenses()).thenAnswer((_) async => mockExpenses);

    controller = SalesReportController(firebaseService: mockFirebaseService);
    await Future<void>.delayed(Duration.zero);

    controller.setSelectedDate(DateTime(2024, 1, 1));
    controller.setPaymentFilter('Cash');

    expect(controller.filteredSales.length, 1);
    expect(controller.periodRevenue, 100.0);
    expect(controller.periodTransactions, 1);
    expect(controller.periodExpense, 10.0);

    controller.setPaymentFilter('Credit');

    expect(controller.filteredSales.length, 1);
    expect(controller.periodRevenue, 25.0);
    expect(controller.periodTransactions, 1);
    expect(controller.periodExpense, 0.0);
  });
}
