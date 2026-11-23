import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';

/// Route explorer: crowding along a route, hour by hour (for commuters and planners).
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<Json> _routes = [];
  String? _route;
  String _day = 'Weekday';
  int _hour = 9;
  Json? _view;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoutes('');
  }

  Future<void> _loadRoutes(String q) async {
    try {
      final r = await Api.routes(q);
      setState(() {
        _routes = r;
        _error = null;
      });
      if (_route == null && r.isNotEmpty) _select(r.first['route'] as String);
    } catch (e) {
      setState(() => _error = 'Could not reach the API at ${Api.base}.');
    }
  }

  Future<void> _select(String route) async {
    setState(() => _route = route);
    try {
      final v = await Api.route(route, _day, _hour);
      setState(() => _view = v);
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _view;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 20, 20, 16), children: [
          const PageTitle('Routes', subtitle: 'How full each stretch of a route usually is, hour by hour.'),
          TextField(
            controller: _q,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Route number or terminal'),
            onChanged: (s) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () => _loadRoutes(s));
            },
          ),
          const SizedBox(height: 12),
          if (_error != null) ErrorBox(_error!),
          SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final r in _routes)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SelectPill(
                    label: '${r['number']} ${arrow(r['direction'] as String)}',
                    selected: r['route'] == _route,
                    onTap: () => _select(r['route'] as String),
                  ),
                ),
            ]),
          ),
          if (v != null) ...[
            const SizedBox(height: 18),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BusChip('${v['number']}', '${v['direction']}', large: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${v['from_terminal']} → ${v['towards']}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.25)),
                  const SizedBox(height: 4),
                  Text('~${asInt(v['weekday_riders_per_day'])} e-ticket riders per weekday',
                      style: TextStyle(fontSize: 12.5, color: context.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Tag('${v['n_stops']} stops'),
              Tag('~${asInt(v['end_to_end_min'])} min end to end'),
              Tag('~${asInt(v['fleet_weekday'])} buses'),
              Tag('a bus every ~${asInt(v['headway_min'])} min'),
            ]),
            const SizedBox(height: 16),
            DaySelector(value: _day, onChanged: (d) {
              _day = d;
              _select(_route!);
            }),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
              decoration: BoxDecoration(border: Border.all(color: context.line), borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Busiest stretch by hour', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text('Tap a bar or drag the slider', style: TextStyle(fontSize: 12, color: context.muted)),
                const SizedBox(height: 10),
                HourBars(
                  byHour: (v['by_hour'] as List).cast<Json>(),
                  selected: _hour,
                  onTap: (h) {
                    _hour = h;
                    _select(_route!);
                  },
                ),
                Slider(
                  value: _hour.toDouble(),
                  min: 5,
                  max: 22,
                  divisions: 17,
                  label: '$_hour:00',
                  onChanged: (x) => setState(() => _hour = x.round()),
                  onChangeEnd: (_) => _select(_route!),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            SectionLabel('Along the route at $_hour:00'),
            const LevelLegend(),
            const SizedBox(height: 10),
            StretchBar((v['stretches'] as List).cast<Json>().map((s) => {...s, 'minutes': 1}).toList(), height: 10),
            const SizedBox(height: 8),
            StopTimeline(
              stretches: (v['stretches'] as List).cast<Json>(),
              firstIcon: Icons.trip_origin,
              lastIcon: Icons.flag,
              firstCaption: 'Start of the route',
              lastCaption: 'End of the route',
              showScores: true,
            ),
          ],
        ]),
      ),
    );
  }
}
