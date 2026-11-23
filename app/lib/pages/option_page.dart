import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';

/// One trip, SIStrans-style: a black summary header, then every leg as a stop-by-stop timeline
/// whose line is coloured by how crowded each stretch usually is.
class OptionPage extends StatelessWidget {
  const OptionPage(this.o, {super.key});
  final Json o;

  @override
  Widget build(BuildContext context) {
    final legs = (o['legs'] as List).cast<Json>();
    final later = (o['later'] as List).cast<Json>();
    const grey = Color(0xFFB0B0B0);
    return Scaffold(
      backgroundColor: context.isDark ? Pal.cardDark : Pal.white,
      body: ListView(padding: EdgeInsets.zero, children: [
        Container(
          color: Pal.black,
          padding: EdgeInsets.fromLTRB(8, MediaQuery.paddingOf(context).top + 4, 16, 44),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back, color: Pal.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Text('${o['total_min']} min',
                          style: const TextStyle(color: Pal.white, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1)),
                      const Spacer(),
                      CrowdBadge(asInt(o['level'])),
                    ]),
                    Text(
                      '${o['depart']} – ${o['arrive']}  ·  ${o['transfers'] == 0 ? 'no change' : '${o['transfers']} change'}'
                      '${(o['tags'] as List).isEmpty ? '' : '  ·  ${(o['tags'] as List).join(', ')}'}',
                      style: const TextStyle(color: grey, fontSize: 14),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      _Stat('On board', '${o['ride_min']} min'),
                      _Stat('Waiting', '~${o['wait_min']} min'),
                      _Stat('Standing', '${o['standing_min']} min'),
                      _Stat('Crowded', '${o['crowded_min']} min'),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -24),
          child: Container(
            decoration: BoxDecoration(
              color: context.isDark ? Pal.cardDark : Pal.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Expanded(child: SectionLabel('Route detail')),
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: ConfidenceChip(o['confidence'] as String)),
                  ]),
                  for (var i = 0; i < legs.length; i++) ...[
                    if (i > 0) _ChangeRow(prev: legs[i - 1], next: legs[i]),
                    _LegBlock(legs[i]),
                  ],
                  if (later.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const SectionLabel('Leave a little later?'),
                    _LaterRow(
                        label: 'As planned', depart: '${o['depart']}', total: o['total_min'], level: asInt(o['level']), crowded: o['crowded_min']),
                    for (final l in later)
                      _LaterRow(
                          label: '+${l['offset_min']} min',
                          depart: '${l['depart']}',
                          total: l['total_min'],
                          level: asInt(l['level']),
                          crowded: l['crowded_min']),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Crowding = typical riders per bus on each stretch for this hour and day type, from October 2026 '
                    'e-tickets. Faded line = limited data. Times are estimated from tickets bought on the same bus.',
                    style: TextStyle(fontSize: 12, color: context.muted, height: 1.4),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2E2E2E))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(color: Pal.white, fontWeight: FontWeight.w800, fontSize: 15)),
            Text(label, style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 11.5)),
          ]),
        ),
      );
}

class _LegBlock extends StatelessWidget {
  const _LegBlock(this.leg);
  final Json leg;

  @override
  Widget build(BuildContext context) {
    final walk = asInt(leg['walk_min']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: context.field, borderRadius: BorderRadius.circular(14), boxShadow: softShadow),
        child: Row(children: [
          BusChip('${leg['number']}', '${leg['direction']}', large: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('towards ${leg['towards']}',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text('Every ~${asInt(leg['headway_min'])} min · wait ~${leg['wait_min']} min · ${leg['stops']} stops · ${leg['ride_min']} min',
                  style: TextStyle(fontSize: 12, color: context.muted)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 4),
      StopTimeline(
        stretches: (leg['stretches'] as List).cast<Json>(),
        startTime: '${leg['board_time']}',
        endTime: '${leg['alight_time']}',
        firstCaption: walk > 0 ? 'Board here · walk $walk min to the stop' : 'Board here',
        lastCaption: 'Get off here',
      ),
    ]);
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.prev, required this.next});
  final Json prev, next;

  @override
  Widget build(BuildContext context) {
    final walk = asInt(next['walk_min']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        SizedBox(width: 44, child: Icon(walk > 0 ? Icons.directions_walk : Icons.sync_alt, color: context.fg)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Change to bus ${next['number']}${walk > 0 ? ' · walk $walk min' : ''} · wait ~${next['wait_min']} min',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
        ),
      ]),
    );
  }
}

class _LaterRow extends StatelessWidget {
  const _LaterRow({required this.label, required this.depart, required this.total, required this.level, required this.crowded});
  final String label, depart;
  final dynamic total, crowded;
  final int level;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: context.isDark ? Pal.fieldDark : Pal.white, border: Border.all(color: context.line), borderRadius: BorderRadius.circular(12), boxShadow: softShadow),
        child: Row(children: [
          SizedBox(
            width: 92,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Leave $depart', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              Text(label, style: TextStyle(fontSize: 11.5, color: context.muted)),
            ]),
          ),
          SizedBox(width: 58, child: Text('$total min', style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text('$crowded min crowded', style: TextStyle(fontSize: 12, color: context.muted))),
          CrowdBadge(level, small: true),
        ]),
      );
}
