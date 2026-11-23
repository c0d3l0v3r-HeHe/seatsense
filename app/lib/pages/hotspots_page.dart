import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
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
    final rows = _rows ?? [];
    final maxR = rows.isEmpty ? 1.0 : rows.map((r) => asDouble(r['riders_eticket'])).reduce((a, b) => a > b ? a : b);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 20, 20, 16), children: [
          const PageTitle('Hotspots',
              subtitle: 'Crowded stretches ranked by how many riders they carry: where one more bus helps most.'),
          DaySelector(value: _day, onChanged: (d) {
            _day = d;
            _load();
          }),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            decoration: BoxDecoration(color: Pal.black, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.schedule, color: Pal.white, size: 20),
                const SizedBox(width: 8),
                Text('$_day, $_hour:00 – ${_hour + 1}:00',
                    style: const TextStyle(color: Pal.white, fontWeight: FontWeight.w800, fontSize: 17)),
              ]),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Pal.white,
                  inactiveTrackColor: const Color(0xFF444444),
                  thumbColor: Pal.white,
                  valueIndicatorColor: Pal.white,
                  valueIndicatorTextStyle: const TextStyle(color: Pal.black, fontWeight: FontWeight.w700),
                  activeTickMarkColor: Pal.black.withValues(alpha: 0.4),
                  inactiveTickMarkColor: const Color(0xFF777777),
                ),
                child: Slider(
                  value: _hour.toDouble(),
                  min: 5,
                  max: 22,
                  divisions: 17,
                  label: '$_hour:00',
                  onChanged: (x) => setState(() => _hour = x.round()),
                  onChangeEnd: (_) => _load(),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          if (_error != null) ErrorBox(_error!),
          if (_rows != null && rows.isEmpty) const Text('No crowded stretches with enough data at this hour.'),
          for (var i = 0; i < rows.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(border: Border.all(color: context.line), borderRadius: BorderRadius.circular(16)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: context.fg, shape: BoxShape.circle),
                  child: Text('${i + 1}', style: TextStyle(color: context.bg, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      BusChip('${rows[i]['number']}', '${rows[i]['direction']}'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('towards ${rows[i]['towards']}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text('${rows[i]['from']} → ${rows[i]['to']}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: asDouble(rows[i]['riders_eticket']) / maxR,
                        minHeight: 6,
                        color: levelColors[2],
                        backgroundColor: context.field,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('${rows[i]['crowded_stretches']} of ${rows[i]['n_stretches']} stretches crowded · '
                        'bus every ~${asInt(rows[i]['headway_min'])} min', style: TextStyle(fontSize: 12, color: context.muted)),
                  ]),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}
