import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'results_page.dart';

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
  _Example('Badarpur Border (T)', 'Saket Metro Station', '08:30', 'Badarpur → Saket'),
  _Example('Anand Vihar Isbt', 'Shivaji Stadium Terminal ( Connaught Place )', '18:00', 'Anand Vihar → Connaught Place'),
  _Example('Uttam Nagar Terminal', 'Karol Bagh Metro Station', '08:30', 'Uttam Nagar → Karol Bagh'),
  _Example('Hamdard Nagar / Sangam Vihar', 'Mehrauli Terminal', '08:45', 'Sangam Vihar → Mehrauli'),
];

const _prefs = [
  ('fastest', 'Fastest', Icons.bolt, 'time first'),
  ('balanced', 'Balanced', Icons.balance, 'time + comfort'),
  ('comfortable', 'A seat', Icons.event_seat, 'least crowded'),
];

class _PlanPageState extends State<PlanPage> {
  Json? _from, _to;
  String _day = 'Weekday';
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 30);
  String _pref = 'balanced';
  bool _loading = false;
  String? _error;
  int _fieldsVersion = 0;

  String get _timeStr => '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    // Deep link for demos: ?from=...&to=...&time=08:30&day=Weekday&pref=balanced[&detail=0]
    final q = Uri.base.queryParameters;
    if (q['from'] != null && q['to'] != null) {
      _from = {'key': q['from'], 'name': q['from']};
      _to = {'key': q['to'], 'name': q['to']};
      final p = (q['time'] ?? '08:30').split(':');
      _time = TimeOfDay(hour: int.tryParse(p[0]) ?? 8, minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
      _day = q['day'] ?? _day;
      _pref = q['pref'] ?? _pref;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search(openDetail: int.tryParse(q['detail'] ?? '')));
    }
  }

  Future<void> _search({int? openDetail}) async {
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
      if (!mounted) return;
      if ((r['options'] as List?)?.isNotEmpty ?? false) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ResultsPage(result: r, day: _day, time: _timeStr, pref: _pref, openDetail: openDetail)));
      } else {
        setState(() => _error = (r['error'] as String?) ?? 'No bus found between these places.');
      }
    } catch (e) {
      setState(() => _error = 'Could not reach the planner at ${Api.base}. Is the API running? ($e)');
    } finally {
      if (mounted) setState(() => _loading = false);
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
    const maxW = 560.0;
    return ListView(padding: EdgeInsets.zero, children: [
      // black header in place of the map in MyStop-style apps
      Container(
        color: Pal.black,
        padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 18, 20, 52),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxW),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.event_seat, color: Pal.white, size: 24),
                SizedBox(width: 8),
                Text('SeatSense', style: TextStyle(color: Pal.white, fontSize: 20, fontWeight: FontWeight.w800)),
                Spacer(),
                Text('Delhi buses', style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 13)),
              ]),
              SizedBox(height: 26),
              Text('Where to?',
                  style: TextStyle(color: Pal.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
              SizedBox(height: 6),
              Text('See how full your bus will be before you board.',
                  style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 15)),
            ]),
          ),
        ),
      ),
      // bottom sheet
      Transform.translate(
        offset: const Offset(0, -28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxW),
            child: Container(
              decoration: BoxDecoration(
                color: context.isDark ? Pal.cardDark : Pal.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(
                  child: Container(
                      width: 40, height: 5, decoration: BoxDecoration(color: context.line, borderRadius: BorderRadius.circular(3))),
                ),
                const SizedBox(height: 16),
                _TripFields(
                  version: _fieldsVersion,
                  from: _from,
                  to: _to,
                  onFrom: (v) => setState(() => _from = v),
                  onTo: (v) => setState(() => _to = v),
                  onSwap: () => setState(() {
                    final f = _from;
                    _from = _to;
                    _to = f;
                    _fieldsVersion++;
                  }),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Material(
                    color: context.field,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () async {
                        final p = await showTimePicker(context: context, initialTime: _time);
                        if (p != null) setState(() => _time = p);
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.schedule, size: 18),
                          const SizedBox(width: 6),
                          Text('Leave at $_timeStr', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const Icon(Icons.arrow_drop_down),
                        ]),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                DaySelector(value: _day, onChanged: (d) => setState(() => _day = d)),
                const SizedBox(height: 18),
                const SectionLabel('Prioritise'),
                Row(children: [
                  for (var i = 0; i < _prefs.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: _PrefTile(pref: _prefs[i], selected: _pref == _prefs[i].$1, onTap: () => setState(() => _pref = _prefs[i].$1))),
                  ],
                ]),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _loading ? null : _search,
                  icon: _loading
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: context.bg))
                      : const Icon(Icons.directions_bus),
                  label: const Text('Find buses'),
                ),
                if (_error != null) ...[const SizedBox(height: 12), ErrorBox(_error!)],
                const SizedBox(height: 22),
                const SectionLabel('Try a trip'),
                for (final e in _examples)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _useExample(e),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: context.field, shape: BoxShape.circle),
                          child: const Icon(Icons.history, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            Text('Weekday · leave ${e.time}', style: TextStyle(fontSize: 12.5, color: context.muted)),
                          ]),
                        ),
                        Icon(Icons.chevron_right, color: context.muted),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Origin and destination in one grey block, joined by a dotted line (Uber / MyStop style).
class _TripFields extends StatelessWidget {
  const _TripFields(
      {required this.version, required this.from, required this.to, required this.onFrom, required this.onTo, required this.onSwap});
  final int version;
  final Json? from, to;
  final ValueChanged<Json> onFrom, onTo;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: context.field, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      child: Row(children: [
        Column(children: [
          Icon(Icons.circle, size: 11, color: context.fg),
          for (var i = 0; i < 4; i++)
            Container(width: 2, height: 5, margin: const EdgeInsets.symmetric(vertical: 2), color: context.muted),
          Icon(Icons.square, size: 11, color: context.fg),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(children: [
            StopField(key: ValueKey('from$version'), hint: 'Enter origin', initial: from, onSelected: onFrom),
            Divider(height: 1, color: context.line),
            StopField(key: ValueKey('to$version'), hint: 'Enter destination', initial: to, onSelected: onTo),
          ]),
        ),
        IconButton(tooltip: 'Swap', icon: const Icon(Icons.swap_vert), onPressed: onSwap),
      ]),
    );
  }
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({required this.pref, required this.selected, required this.onTap});
  final (String, String, IconData, String) pref;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? context.bg : context.fg;
    return Material(
      color: selected ? context.fg : context.field,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(children: [
            Icon(pref.$3, color: fg, size: 24),
            const SizedBox(height: 6),
            Text(pref.$2, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13.5)),
            Text(pref.$4,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: selected ? context.bg.withValues(alpha: 0.75) : context.muted, fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}

class StopField extends StatelessWidget {
  const StopField({super.key, required this.hint, required this.onSelected, this.initial});
  final String hint;
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
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5),
        decoration: InputDecoration(
          hintText: hint,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      optionsViewBuilder: (ctx, select, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 6,
          color: ctx.isDark ? Pal.fieldDark : Pal.white,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320, maxWidth: 480),
            child: ListView(padding: const EdgeInsets.symmetric(vertical: 6), shrinkWrap: true, children: [
              for (final o in options)
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: ctx.field, shape: BoxShape.circle),
                    child: const Icon(Icons.location_on_outlined, size: 18),
                  ),
                  title: Text(o['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
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
