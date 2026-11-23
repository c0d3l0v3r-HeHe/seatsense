import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';
import 'option_page.dart';

class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _Example {
  const _Example(this.from, this.to, this.time, this.label);
  final String from, to, time, label;
}

const _examples = [
  _Example('Badarpur Border (T)', 'Saket Metro Station', '08:30', 'Badarpur → Saket, 8:30'),
  _Example('Anand Vihar Isbt', 'Shivaji Stadium Terminal ( Connaught Place )', '18:00', 'Anand Vihar → Connaught Place, 18:00'),
  _Example('Uttam Nagar Terminal', 'Karol Bagh Metro Station', '08:30', 'Uttam Nagar → Karol Bagh, 8:30'),
  _Example('Hamdard Nagar / Sangam Vihar', 'Mehrauli Terminal', '08:45', 'Sangam Vihar → Mehrauli, 8:45'),
];

class _PlanPageState extends State<PlanPage> {
  Json? _from, _to;
  String _day = 'Weekday';
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 30);
  String _pref = 'balanced';
  bool _loading = false;
  Json? _result;
  String? _error;
  int _fieldsVersion = 0;

  String get _timeStr => '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    // Deep link for demos: ?from=...&to=...&time=08:30&day=Weekday&pref=balanced
    final q = Uri.base.queryParameters;
    if (q['from'] != null && q['to'] != null) {
      _from = {'key': q['from'], 'name': q['from']};
      _to = {'key': q['to'], 'name': q['to']};
      final p = (q['time'] ?? '08:30').split(':');
      _time = TimeOfDay(hour: int.tryParse(p[0]) ?? 8, minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
      _day = q['day'] ?? _day;
      _pref = q['pref'] ?? _pref;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  Future<void> _search() async {
    if (_from == null || _to == null) {
      setState(() => _error = 'Pick where you start and where you are going.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Api.plan(from: _from!['key'], to: _to!['key'], day: _day, time: _timeStr, pref: _pref);
      setState(() {
        _result = r;
        _error = r['error'] as String?;
      });
    } catch (e) {
      setState(() => _error = 'Could not reach the planner at ${Api.base}. Is the API running? ($e)');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _useExample(_Example e) {
    final p = e.time.split(':');
    setState(() {
      _from = {'key': e.from, 'name': e.from};
      _to = {'key': e.to, 'name': e.to};
      _time = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
      _day = 'Weekday';
      _fieldsVersion++;
    });
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Where to?', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                StopField(
                  key: ValueKey('from$_fieldsVersion'),
                  label: 'From',
                  icon: Icons.trip_origin,
                  initial: _from,
                  onSelected: (v) => setState(() => _from = v),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Swap',
                    icon: const Icon(Icons.swap_vert),
                    onPressed: () => setState(() {
                      final f = _from;
                      _from = _to;
                      _to = f;
                      _fieldsVersion++;
                    }),
                  ),
                ),
                StopField(
                  key: ValueKey('to$_fieldsVersion'),
                  label: 'To',
                  icon: Icons.place,
                  initial: _to,
                  onSelected: (v) => setState(() => _to = v),
                ),
                const SizedBox(height: 16),
                Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  DaySelector(value: _day, onChanged: (d) => setState(() => _day = d)),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text('Leave at $_timeStr'),
                    onPressed: () async {
                      final p = await showTimePicker(context: context, initialTime: _time);
                      if (p != null) setState(() => _time = p);
                    },
                  ),
                ]),
                const SizedBox(height: 12),
                Text('I prefer', style: t.textTheme.labelMedium),
                const SizedBox(height: 6),
                ChoiceRow<String>(
                  options: const [
                    ('fastest', 'Fastest', Icons.bolt),
                    ('balanced', 'Balanced', Icons.balance),
                    ('comfortable', 'A seat', Icons.event_seat),
                  ],
                  value: _pref,
                  onChanged: (p) => setState(() => _pref = p),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loading ? null : _search,
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.directions_bus),
                  label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Find buses')),
                ),
                const SizedBox(height: 12),
                Text('Try an example', style: t.textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in _examples) ActionChip(label: Text(e.label), onPressed: () => _useExample(e)),
                ]),
              ]),
            ),
          ),
        ),
      ),
      if (_error != null) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: ErrorBox(_error!))),
      if (_result != null && (_result!['options'] as List).isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_result!['from']['name']} → ${_result!['to']['name']}',
                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const LevelLegend(),
            ]),
          ),
        ),
        SliverList.builder(
          itemCount: (_result!['options'] as List).length,
          itemBuilder: (ctx, i) => OptionCard((_result!['options'] as List)[i] as Json),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    ]);
  }
}

class StopField extends StatelessWidget {
  const StopField({super.key, required this.label, required this.icon, required this.onSelected, this.initial});
  final String label;
  final IconData icon;
  final Json? initial;
  final ValueChanged<Json> onSelected;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Json>(
      initialValue: TextEditingValue(text: initial?['name'] ?? ''),
      displayStringForOption: (o) => o['name'] as String,
      optionsBuilder: (v) async {
        if (v.text.trim().length < 2) return const <Json>[];
        try {
          return await Api.stops(v.text.trim());
        } catch (_) {
          return const <Json>[];
        }
      },
      onSelected: onSelected,
      fieldViewBuilder: (ctx, ctrl, focus, submit) => TextField(
        controller: ctrl,
        focusNode: focus,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
      ),
      optionsViewBuilder: (ctx, select, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320, maxWidth: 560),
            child: ListView(padding: EdgeInsets.zero, shrinkWrap: true, children: [
              for (final o in options)
                ListTile(
                  leading: const Icon(Icons.directions_bus_outlined),
                  title: Text(o['name'] as String),
                  subtitle: Text([
                    '${o['routes']} routes',
                    if ((o['also_called'] as List).isNotEmpty) 'also: ${(o['also_called'] as List).take(2).join(' · ')}',
                  ].join('  ·  '), maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => select(o),
                ),
            ]),
          ),
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
    final t = Theme.of(context);
    final legs = (o['legs'] as List).cast<Json>();
    final stretches = [for (final l in legs) ...(l['stretches'] as List).cast<Json>()];
    final crowded = asInt(o['crowded_min']), standing = asInt(o['standing_min']), ride = asInt(o['ride_min']);
    final busy = o['busiest_stretch'] as Json;
    final summary = crowded > 0
        ? 'Crowded for $crowded of $ride min on board · worst: ${busy['from']} → ${busy['to']}'
        : standing > 0
            ? 'Standing room for $standing of $ride min · no crowded stretch'
            : 'Seats likely the whole way';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OptionPage(o))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  child: Text('${o['total_min']} min',
                      style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                ),
                CrowdBadge(asInt(o['level'])),
              ]),
              Text('${o['depart']} → ${o['arrive']}  ·  ${o['transfers'] == 0 ? 'no change' : '${o['transfers']} change'}',
                  style: t.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (final tag in (o['tags'] as List))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: t.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(6)),
                    child: Text('$tag', style: TextStyle(fontSize: 12, color: t.colorScheme.onSecondaryContainer)),
                  ),
                ConfidenceChip(o['confidence'] as String),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (var i = 0; i < legs.length; i++) ...[
                  if (i > 0) const Icon(Icons.chevron_right, size: 18),
                  RouteChip(legs[i]),
                ],
              ]),
              const SizedBox(height: 12),
              StretchBar(stretches),
              const SizedBox(height: 8),
              Text(summary, style: t.textTheme.bodySmall),
              if (o['tip'] != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: t.colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(Icons.lightbulb_outline, size: 18, color: t.colorScheme.onTertiaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(o['tip'] as String,
                            style: TextStyle(color: t.colorScheme.onTertiaryContainer, fontSize: 13))),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class RouteChip extends StatelessWidget {
  const RouteChip(this.leg, {super.key});
  final Json leg;

  @override
  Widget build(BuildContext context) {
    final lv = asInt(leg['level']);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: levelColors[lv], width: 2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.directions_bus, size: 16),
        const SizedBox(width: 4),
        Text('${leg['number']} ${arrow(leg['direction'] as String)}', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Icon(levelIcons[lv], size: 15, color: levelColors[lv]),
        const SizedBox(width: 4),
        Text('${leg['ride_min']} min', style: const TextStyle(fontSize: 12)),
      ]),
    );
  }
}
