import 'package:flutter/material.dart';

import 'pages/about_page.dart';
import 'pages/explore_page.dart';
import 'pages/hotspots_page.dart';
import 'pages/plan_page.dart';

void main() => runApp(const SeatSenseApp());

class SeatSenseApp extends StatelessWidget {
  const SeatSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2A78D6), brightness: b),
          useMaterial3: true,
          cardTheme: const CardThemeData(elevation: 0.5),
        );
    return MaterialApp(
      title: 'SeatSense · Delhi bus crowding',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // ?tab=plan|routes|hotspots|about opens a tab directly (handy for demos).
  int _tab = const {'routes': 1, 'hotspots': 2, 'about': 3}[Uri.base.queryParameters['tab']] ?? 0;
  static const _pages = [PlanPage(), ExplorePage(), HotspotsPage(), AboutPage()];
  static const _dest = [
    (Icons.directions_bus_outlined, Icons.directions_bus, 'Plan'),
    (Icons.route_outlined, Icons.route, 'Routes'),
    (Icons.local_fire_department_outlined, Icons.local_fire_department, 'Hotspots'),
    (Icons.info_outline, Icons.info, 'How it works'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final body = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: IndexedStack(index: _tab, children: _pages),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.event_seat),
          const SizedBox(width: 8),
          const Text('SeatSense', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Flexible(
            child: Text('Delhi buses, with crowding',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ]),
      ),
      body: wide
          ? Row(children: [
              NavigationRail(
                selectedIndex: _tab,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: (i) => setState(() => _tab = i),
                destinations: [
                  for (final d in _dest)
                    NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ])
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                for (final d in _dest) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
              ],
            ),
    );
  }
}
