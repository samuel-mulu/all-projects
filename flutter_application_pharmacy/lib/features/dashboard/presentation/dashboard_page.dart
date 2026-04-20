import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../auth/presentation/login_page.dart';
import '../../inventory/presentation/inventory_view.dart';
import '../../sales/presentation/sales_view.dart';
import '../../reports/presentation/reports_view.dart';
import '../../settings/presentation/settings_page.dart';
import 'dashboard_view.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  String? _inventoryMedicationId;

  final List<String> _titles = const [
    'Dashboard',
    'Inventory',
    'Sales',
    'Reports',
  ];

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _openInventory({String? medicationId}) {
    setState(() {
      _selectedIndex = 1;
      _inventoryMedicationId = medicationId;
    });
  }

  void _openSales() {
    setState(() => _selectedIndex = 2);
  }

  void _clearInventoryFocus() {
    if (_inventoryMedicationId == null) {
      return;
    }

    setState(() => _inventoryMedicationId = null);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardView(
        onOpenInventory: _openInventory,
        onOpenSales: _openSales,
      ),
      InventoryView(
        initialMedicationId: _inventoryMedicationId,
        onMedicationFocusHandled: _clearInventoryFocus,
      ),
      const SalesView(),
      const ReportsView(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsPage(),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale_rounded),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}
