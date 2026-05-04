import 'package:flutter/material.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';

import 'screens.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = PersistentTabController(initialIndex: 0);

    return PersistentTabView(
      context,
      controller: controller,
      screens: const [DiariosScreen(), PerfilScreen(), ConfiguracionScreen()],
      items: [
        PersistentBottomNavBarItem(icon: const Icon(Icons.newspaper), title: 'Diarios'),
        PersistentBottomNavBarItem(icon: const Icon(Icons.person), title: 'Perfil'),
        PersistentBottomNavBarItem(icon: const Icon(Icons.settings), title: 'Ajustes'),
      ],
      navBarStyle: NavBarStyle.style6,
    );
  }
}
