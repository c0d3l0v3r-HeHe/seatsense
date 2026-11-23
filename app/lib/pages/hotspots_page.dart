import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';

/// Operator view: crowded stretches carrying the most riders at a given hour (where an extra bus helps most).
class HotspotsPage extends StatefulWidget {
  const HotspotsPage({super.key});

  @override
  State<HotspotsPage> createState() => _HotspotsPageState();
}

class _HotspotsPageState extends State<HotspotsPage> {
  String _day = 'Weekday';
  int _hour = 9;
  List<Json>? _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.hotspots(_day, _hour);
      setState(() {
        _rows = r;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Could not reach the API at ${Api.base}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final rows = _rows ?? [];
    final maxR = rows.isEmpty ? 1.0 : rows.map((r) => asDouble(r['riders_eticket'])).reduce((a, b) => a > b ? a : b);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Where are buses most overloaded?', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      Text('Crowded stretches ranked by how many riders they carry. For operators deciding where an extra bus helps most.',
          style: t.textTheme.bodySmall),
      const SizedBox(height: 12),
      DaySelector(value: _day, onChanged: (d) {
        _day = d;
        _load();
      }),
      Slider(
        value: _hour.toDouble(),
        min: 5,
        max: 22,
        divisions: 17,
        label: '$_hour:00',
        onChanged: (x) => setState(() => _hour = x.round()),
        onChangeEnd: (_) => _load(),
      ),
      Text('$_day, $_hour:00 – ${_hour + 1}:00', style: t.textTheme.titleMedium),
      const SizedBox(height: 8),
      if (_error != null) ErrorBox(_error!),
      if (_rows != null && rows.isEmpty) const Text('No crowded stretches with enough data at this hour.'),
      for (var i = 0; i < rows.length; i++)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Bus ${rows[i]['number']} ${arrow(rows[i]['direction'] as String)} towards ${rows[i]['towards']}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${rows[i]['from']} → ${rows[i]['to']}', style: t.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: asDouble(rows[i]['riders_eticket']) / maxR,
                      minHeight: 6,
                      color: levelColors[2],
                      backgroundColor: levelColors[2].withValues(alpha: 0.15),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${rows[i]['crowded_stretches']} of ${rows[i]['n_stretches']} stretches crowded · '
                      'bus every ~${asInt(rows[i]['headway_min'])} min', style: t.textTheme.bodySmall),
                ]),
              ),
              const SizedBox(width: 8),
              const CrowdBadge(2, small: true),
            ]),
          ),
        ),
    ]);
  }
}
