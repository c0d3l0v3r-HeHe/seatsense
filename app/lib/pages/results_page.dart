import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'option_page.dart';

const _prefLabel = {'fastest': 'Fastest', 'balanced': 'Balanced', 'comfortable': 'A seat'};

/// MyStop-style "Suggested trips": one card per option with its itinerary line.
class ResultsPage extends StatefulWidget {
  const ResultsPage(
      {super.key, required this.result, required this.day, required this.time, required this.pref, this.openDetail});
  final Json result;
  final String day, time, pref;
  final int? openDetail; // deep link: open this option's detail straight away

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  @override
  void initState() {
    super.initState();
    final i = widget.openDetail;
    final options = (widget.result['options'] as List).cast<Json>();
    if (i != null && i >= 0 && i < options.length) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OptionPage(options[i]))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final options = (r['options'] as List).cast<Json>();
    return Scaffold(
      appBar: AppBar(title: const Text('Suggested trips')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: context.field, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Column(children: [
                    Icon(Icons.circle, size: 10, color: context.fg),
                    for (var i = 0; i < 3; i++)
                      Container(width: 2, height: 4, margin: const EdgeInsets.symmetric(vertical: 2), color: context.muted),
                    Icon(Icons.square, size: 10, color: context.fg),
                  ]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${r['from']['name']}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Text('${r['to']['name']}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  Tag(widget.day, inverse: true),
                  Tag('Leave ${widget.time}', inverse: true),
                  Tag(_prefLabel[widget.pref] ?? widget.pref, inverse: true),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              const Expanded(child: LevelLegend()),
              Text('${options.length} trips', style: TextStyle(color: context.muted, fontSize: 12.5)),
            ]),
            const SizedBox(height: 12),
            for (final o in options) ...[OptionCard(o), const SizedBox(height: 12)],
          ]),
        ),
      ),
    );
  }
}

class OptionCard extends StatelessWidget {
  const OptionCard(this.o, {super.key});
  final Json o;

  @override
  Widget build(BuildContext context) {
    final legs = (o['legs'] as List).cast<Json>();
    final crowded = asInt(o['crowded_min']), standing = asInt(o['standing_min']), ride = asInt(o['ride_min']);
    final busy = o['busiest_stretch'] as Json;
    final summary = crowded > 0
        ? 'Crowded for $crowded of $ride min on board · worst: ${busy['from']} → ${busy['to']}'
        : standing > 0
            ? 'Standing room for $standing of $ride min · no crowded stretch'
            : 'Seats likely the whole way';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OptionPage(o))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${o['total_min']} min',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1)),
                  const SizedBox(height: 2),
                  Text('${o['depart']} – ${o['arrive']}  ·  ${o['transfers'] == 0 ? 'no change' : '${o['transfers']} change'}',
                      style: TextStyle(color: context.muted, fontSize: 13.5)),
                ]),
              ),
              CrowdBadge(asInt(o['level'])),
              Icon(Icons.chevron_right, color: context.muted),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              for (final tag in (o['tags'] as List)) Tag('$tag'),
              ConfidenceChip(o['confidence'] as String),
            ]),
            const SizedBox(height: 16),
            ItineraryLine(legs),
            const SizedBox(height: 12),
            Text(summary, style: TextStyle(fontSize: 12.5, color: context.muted)),
            if (o['tip'] != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: context.field, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.lightbulb_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(o['tip'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
