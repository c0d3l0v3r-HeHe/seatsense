import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
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
    final t = Theme.of(context);
    final v = _view;
    return ListView(padding: const EdgeInsets.all(16), children: [
      TextField(
        controller: _q,
        decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search), labelText: 'Route number or terminal', border: OutlineInputBorder()),
        onChanged: (s) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 300), () => _loadRoutes(s));
        },
      ),
      const SizedBox(height: 8),
      if (_error != null) ErrorBox(_error!),
      SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final r in _routes)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text('${r['number']} ${arrow(r['direction'] as String)}'),
                selected: r['route'] == _route,
                onSelected: (_) => _select(r['route'] as String),
              ),
            ),
        ]),
      ),
      if (v != null) ...[
        const SizedBox(height: 12),
        Text('Route ${v['number']} ${arrow(v['direction'] as String)}',
            style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        Text('${v['from_terminal']} → ${v['towards']}  ·  ${v['n_stops']} stops  ·  ~${asInt(v['end_to_end_min'])} min end to end',
            style: t.textTheme.bodyMedium),
        Text('~${asInt(v['weekday_riders_per_day'])} e-ticket riders per weekday · ~${asInt(v['fleet_weekday'])} buses · '
            'a bus every ~${asInt(v['headway_min'])} min', style: t.textTheme.bodySmall),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DaySelector(value: _day, onChanged: (d) {
            _day = d;
            _select(_route!);
          }),
          const LevelLegend(),
        ]),
        const SizedBox(height: 12),
        Text('Busiest stretch by hour — tap a bar', style: t.textTheme.labelLarge),
        const SizedBox(height: 6),
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
        Text('Along the route at $_hour:00', style: t.textTheme.titleMedium),
        const SizedBox(height: 6),
        StretchBar((v['stretches'] as List).cast<Json>().map((s) => {...s, 'minutes': 1}).toList(), height: 14),
        const SizedBox(height: 8),
        for (final s in (v['stretches'] as List).cast<Json>())
          ListTile(
            dense: true,
            leading: Icon(levelIcons[asInt(s['level'])], color: levelColors[asInt(s['level'])]),
            title: Text('${s['from']} → ${s['to']}'),
            subtitle: Text('score ${asDouble(s['score']).round()} / 100  ·  '
                '${s['confidence'] == 'low' ? 'limited data' : '${s['confidence']} confidence'}'),
            trailing: Text(levelLabels[asInt(s['level'])]),
          ),
      ],
    ]);
  }
}
