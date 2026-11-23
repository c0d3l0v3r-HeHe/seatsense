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
  static const _pages = [PlanPage(), ExplorePage(), HotspotsPage(), AboutPage()];
  static const _dest = [
    (Icons.directions_bus_outlined, Icons.directions_bus, 'Plan'),
    (Icons.route_outlined, Icons.route, 'Routes'),
    (Icons.local_fire_department_outlined, Icons.local_fire_department, 'Hotspots'),
    (Icons.info_outline, Icons.info, 'About'),
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
      bottomNavigationBar: wide ? null : _PillNav(index: _tab, items: _dest, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

/// Floating black navigation bar; the current tab is a white pill with its name.
class _PillNav extends StatelessWidget {
  const _PillNav({required this.index, required this.items, required this.onTap});
  final int index;
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Container(
          height: 62,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Pal.black,
            borderRadius: BorderRadius.circular(31),
            border: context.isDark ? Border.all(color: Pal.lineDark) : null,
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))],
          ),
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                flex: i == index ? 5 : 3,
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: items[i].$3,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: i == index ? Pal.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(i == index ? items[i].$2 : items[i].$1,
                            size: 21, color: i == index ? Pal.black : Pal.white.withValues(alpha: 0.85)),
                        if (i == index) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(items[i].$3,
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: const TextStyle(color: Pal.black, fontWeight: FontWeight.w700, fontSize: 13.5)),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
