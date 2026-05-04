import 'package:flutter/material.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';

import 'screens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeIndex = 0;

  final List<Widget> _screens = const [
    DiariosScreen(),
    PerfilScreen(),
    ConfiguracionScreen(),
  ];

  final List<IconData> _icons = const [
    Icons.newspaper,
    Icons.person,
    Icons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_activeIndex],
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => setState(() => _activeIndex = 0),
        tooltip: 'Ir a diarios',
        child: const Icon(Icons.home),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: AnimatedBottomNavigationBar(
        icons: _icons,
        activeIndex: _activeIndex,
        gapLocation: GapLocation.end,
        notchSmoothness: NotchSmoothness.verySmoothEdge,
        leftCornerRadius: 24,
        rightCornerRadius: 0,
        activeColor: Theme.of(context).colorScheme.primary,
        inactiveColor: Colors.grey.shade500,
        onTap: (index) => setState(() => _activeIndex = index),
      ),
    );
  }
}
