import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';

/// One journey option, leg by leg, with the crowding of every stretch.
class OptionPage extends StatelessWidget {
  const OptionPage(this.o, {super.key});
  final Json o;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final legs = (o['legs'] as List).cast<Json>();
    final later = (o['later'] as List).cast<Json>();
    return Scaffold(
      appBar: AppBar(title: Text('${o['total_min']} min · ${o['depart']} → ${o['arrive']}')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(spacing: 16, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  CrowdBadge(asInt(o['level'])),
                  ConfidenceChip(o['confidence'] as String),
                  Text('On board ${o['ride_min']} min · waiting ~${o['wait_min']} min'
                      '${asInt(o['walk_min']) > 0 ? ' · walking ${o['walk_min']} min' : ''}'),
                  Text('Crowded ${o['crowded_min']} min · standing ${o['standing_min']} min'),
                ]),
              ),
            ),
            for (final leg in legs) _LegCard(leg),
            if (later.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('If you leave a little later', style: t.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _LaterRow(depart: o['depart'], total: o['total_min'], level: asInt(o['level']),
                        crowded: o['crowded_min'], label: 'As planned'),
                    for (final l in later)
                      _LaterRow(depart: l['depart'], total: l['total_min'], level: asInt(l['level']),
                          crowded: l['crowded_min'], label: '+${l['offset_min']} min'),
                  ]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Crowding = typical riders per bus on each stretch for this hour and day type, from October 2026 '
                'e-tickets. Faded blocks have limited data. Travel times are estimated from tickets bought on the same bus.',
                style: t.textTheme.bodySmall,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _LaterRow extends StatelessWidget {
  const _LaterRow({required this.depart, required this.total, required this.level, required this.crowded, required this.label});
  final dynamic depart, total, crowded;
  final int level;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 96, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          SizedBox(width: 120, child: Text('leave $depart')),
          SizedBox(width: 70, child: Text('$total min')),
          CrowdBadge(level, small: true),
          const SizedBox(width: 10),
          Expanded(child: Text('$crowded min crowded', style: const TextStyle(fontSize: 12))),
        ]),
      );
}

class _LegCard extends StatelessWidget {
  const _LegCard(this.leg);
  final Json leg;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final st = (leg['stretches'] as List).cast<Json>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.directions_bus),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Bus ${leg['number']} ${arrow(leg['direction'] as String)} towards ${leg['towards']}',
                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            CrowdBadge(asInt(leg['level']), small: true),
          ]),
          const SizedBox(height: 4),
          Text(
            [
              if (asInt(leg['walk_min']) > 0) 'Walk ${leg['walk_min']} min to the stop',
              'Bus every ~${asInt(leg['headway_min'])} min, wait ~${leg['wait_min']} min',
              '${leg['stops']} stops, ${leg['ride_min']} min',
            ].join(' · '),
            style: t.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          ConfidenceChip(leg['confidence'] as String),
          const Divider(height: 24),
          _StopLine(time: leg['board_time'], name: leg['board_stop'], board: true),
          for (final s in st)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                      width: 6,
                      color: levelColors[asInt(s['level'])].withValues(alpha: s['confidence'] == 'low' ? 0.4 : 1)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Icon(levelIcons[asInt(s['level'])], size: 16, color: levelColors[asInt(s['level'])]),
                        const SizedBox(width: 6),
                        Expanded(child: Text('to ${s['to']}', style: const TextStyle(fontSize: 13))),
                        Text(levelLabels[asInt(s['level'])], style: TextStyle(fontSize: 12, color: t.colorScheme.onSurfaceVariant)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          _StopLine(time: leg['alight_time'], name: leg['alight_stop'], board: false),
        ]),
      ),
    );
  }
}

class _StopLine extends StatelessWidget {
  const _StopLine({required this.time, required this.name, required this.board});
  final dynamic time, name;
  final bool board;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(board ? Icons.radio_button_checked : Icons.location_on, size: 18),
        const SizedBox(width: 8),
        Text('$time', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 10),
        Expanded(child: Text('${board ? 'Board at' : 'Get off at'} $name')),
      ]);
}
