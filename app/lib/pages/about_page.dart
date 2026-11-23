import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  String _pct(dynamic v) => v == null ? '–' : '${((v as num) * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Json>(
      future: Api.meta(),
      builder: (ctx, snap) {
        final m = snap.data;
        final d = m?['data'] as Json?;
        final hv = (m?['validation']?['holdout_week'] ?? {}) as Map;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 20, 20, 16), children: [
              const PageTitle('How it works', subtitle: 'Crowding counted from real e-tickets, not guessed.'),
              if (snap.hasError) ...[ErrorBox('Could not reach the API at ${Api.base}.'), const SizedBox(height: 12)],
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
              const SizedBox(height: 4),
              const LevelLegend(),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Pal.black, borderRadius: BorderRadius.circular(18), boxShadow: softShadow),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Checked against a week it never saw',
                      style: TextStyle(color: Pal.white, fontWeight: FontWeight.w800, fontSize: 17)),
                  const Text('Learned from 5–23 Oct weekdays, predicted 26–30 Oct',
                      style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 12.5)),
                  const SizedBox(height: 14),
                  Row(children: [
                    _Big(_pct(hv['level_agreement']), 'same level\nas reality'),
                    _Big('${hv['pearson_r'] ?? '–'}', 'correlation with\nactual riders'),
                    _Big(_pct(hv['busiest_10pct_found']), 'busiest 10%\nfound'),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),
              Text(
                'Limits: e-tickets are a few percent of riders (cash, passes and free pink tickets are missing), so levels are '
                'relative, not head counts. Stop names come from tickets, not GTFS, so there is no map yet. Travel times are '
                'estimates.',
                style: TextStyle(fontSize: 12.5, color: context.muted, height: 1.4),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _Big extends StatelessWidget {
  const _Big(this.value, this.label);
  final String value, label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: Pal.white, fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -0.5)),
          Text(label, style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 11.5, height: 1.3)),
        ]),
      );
}

class _Step extends StatelessWidget {
  const _Step(this.icon, this.title, this.body);
  final IconData icon;
  final String title, body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: context.fg, shape: BoxShape.circle, boxShadow: smallShadow),
            child: Icon(icon, color: context.bg, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              const SizedBox(height: 3),
              Text(body, style: TextStyle(color: context.muted, height: 1.4)),
            ]),
          ),
        ]),
      );
}
