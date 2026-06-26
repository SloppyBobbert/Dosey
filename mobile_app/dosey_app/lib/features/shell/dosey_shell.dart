import 'package:dosey_app/features/carousel/carousel_screen.dart';
import 'package:dosey_app/features/controller/controller_screen.dart';
import 'package:dosey_app/features/log/dose_log_screen.dart';
import 'package:dosey_app/features/prescriptions/prescriptions_screen.dart';
import 'package:dosey_app/features/reminders/reminders_screen.dart';
import 'package:dosey_app/features/settings/settings_screen.dart';
import 'package:dosey_app/features/today/today_screen.dart';
import 'package:flutter/material.dart';

class DoseyShell extends StatefulWidget {
  const DoseyShell({super.key});

  @override
  State<DoseyShell> createState() => _DoseyShellState();
}

class _DoseyShellState extends State<DoseyShell> {
  int _selectedIndex = 0;

  static const _screens = [
    TodayScreen(),
    PrescriptionsScreen(),
    RemindersScreen(),
    CarouselScreen(),
    ControllerScreen(),
    DoseLogScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dosey')),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication),
            label: 'Prescriptions',
          ),
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_carousel_outlined),
            selectedIcon: Icon(Icons.view_carousel),
            label: 'Carousel',
          ),
          NavigationDestination(
            icon: Icon(Icons.memory_outlined),
            selectedIcon: Icon(Icons.memory),
            label: 'Controller',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
