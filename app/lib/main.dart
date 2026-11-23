import 'package:flutter/material.dart';

import 'pages/about_page.dart';
import 'pages/explore_page.dart';
import 'pages/hotspots_page.dart';
import 'pages/plan_page.dart';
import 'theme.dart';

void main() => runApp(const SeatSenseApp());

class SeatSenseApp extends StatelessWidget {
  const SeatSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SeatSense · Delhi bus crowding',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // ?theme=dark|light forces a theme (handy for screenshots); otherwise follow the system.
      themeMode: switch (Uri.base.queryParameters['theme']) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      },
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
  late final _pages = [PlanPage(onOpenTab: (i) => setState(() => _tab = i)), const ExplorePage(), const HotspotsPage(), const AboutPage()];
  static const _dest = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.route_outlined, Icons.route, 'Routes'),
    (Icons.local_fire_department_outlined, Icons.local_fire_department, 'Hotspots'),
    (Icons.person_outline, Icons.person, 'About'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final body = IndexedStack(index: _tab, children: _pages);
    return Scaffold(
      body: wide
          ? Row(children: [
              NavigationRail(
                selectedIndex: _tab,
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Icon(Icons.event_seat, size: 30, color: context.fg),
                ),
                onDestinationSelected: (i) => setState(() => _tab = i),
                destinations: [
                  for (final d in _dest)
                    NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
                ],
              ),
              VerticalDivider(width: 1, color: context.line),
              Expanded(child: body),
            ])
          : body,
      bottomNavigationBar: wide ? null : _BottomNav(index: _tab, items: _dest, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

/// Uber-style bottom bar: full width, white, icon above label; the current tab is black, the rest grey.
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.items, required this.onTap});
  final int index;
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: context.bg, border: Border(top: BorderSide(color: context.line))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: items[i].$3,
                  child: InkResponse(
                    onTap: () => onTap(i),
                    containedInkWell: true,
                    highlightShape: BoxShape.rectangle,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(i == index ? items[i].$2 : items[i].$1, size: 24, color: i == index ? context.fg : context.muted),
                      const SizedBox(height: 4),
                      Text(items[i].$3,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                              color: i == index ? context.fg : context.muted)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
