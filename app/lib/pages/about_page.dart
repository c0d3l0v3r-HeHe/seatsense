import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  String _pct(dynamic v) => v == null ? '–' : '${((v as num) * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return FutureBuilder<Json>(
      future: Api.meta(),
      builder: (ctx, snap) {
        final m = snap.data;
        final d = m?['data'] as Json?;
        final hv = (m?['validation']?['holdout_week'] ?? {}) as Map;
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('How SeatSense works', style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (snap.hasError) ErrorBox('Could not reach the API at ${Api.base}.'),
          _Step(Icons.confirmation_number_outlined, 'Every ticket is a trip',
              'Each e-ticket says where a rider got on and where they planned to get off, and when.'
              '${d == null ? '' : ' October 2026: ${d['tickets']} tickets, ${d['route_directions']} route-directions.'}'),
          const _Step(Icons.route, 'Stop order and travel time from the tickets',
              'Tickets bought minutes apart on the same bus tell us which stop comes next and how long it takes.'),
          const _Step(Icons.groups_outlined, 'Count who is on board',
              'Each rider is counted on every stretch between their two stops, for each hour, and averaged over the month '
              'for weekdays, Saturdays and Sundays. Dividing by the buses that serve the route gives riders per bus.'),
          const _Step(Icons.traffic_outlined, 'Three levels anyone understands',
              'Score 0–100: the share of rider-trips that are less crowded. Below 50 = seats likely, 50–80 = standing room, '
              'above 80 = crowded.'),
          const _Step(Icons.verified_outlined, 'Honest about uncertainty',
              'Each estimate carries a confidence level from the number of tickets behind it. Thin routes are never shown as '
              '"empty": in ranking they count as standing room.'),
          const SizedBox(height: 8),
          const LevelLegend(),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Checked against a week it never saw', style: t.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Learned from 5–23 Oct weekdays, predicted 26–30 Oct:'),
                Text('• same crowding level as reality: ${_pct(hv['level_agreement'])} of stretch-hours'),
                Text('• correlation with actual riders: ${hv['pearson_r'] ?? '–'}'),
                Text('• busiest 10% of stretch-hours found: ${_pct(hv['busiest_10pct_found'])}'),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Limits: e-tickets are a few percent of riders (cash, passes and free pink tickets are missing), so levels are '
            'relative, not head counts. Stop names come from tickets, not GTFS, so there is no map yet. Travel times are '
            'estimates.',
            style: t.textTheme.bodySmall,
          ),
        ]);
      },
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.icon, this.title, this.body);
  final IconData icon;
  final String title, body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(child: Icon(icon)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(body),
            ]),
          ),
        ]),
      );
}
