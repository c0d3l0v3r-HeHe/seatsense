import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'results_page.dart';

class _Example {
  const _Example(this.from, this.to, this.time, this.label, this.icon);
  final String from, to, time, label;
  final IconData icon;
}

const _examples = [
  _Example('Badarpur Border (T)', 'Saket Metro Station', '08:30', 'Badarpur → Saket', Icons.work),
  _Example('Anand Vihar Isbt', 'Shivaji Stadium Terminal ( Connaught Place )', '18:00', 'Anand Vihar → Connaught Place',
      Icons.home),
  _Example('Uttam Nagar Terminal', 'Karol Bagh Metro Station', '08:30', 'Uttam Nagar → Karol Bagh', Icons.history),
];

const _prefs = [
  ('fastest', 'Fastest', Icons.bolt, 'time first'),
  ('balanced', 'Balanced', Icons.balance, 'time + comfort'),
  ('comfortable', 'A seat', Icons.event_seat, 'least crowded'),
];

String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Calls the planner and opens the results. Returns an error message, or null on success.
Future<String?> runSearch(BuildContext context,
    {required String from, required String to, required String day, required String time, required String pref, int? openDetail}) async {
  try {
    final r = await Api.plan(from: from, to: to, day: day, time: time, pref: pref);
    if (!context.mounted) return null;
    if ((r['options'] as List?)?.isNotEmpty ?? false) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ResultsPage(result: r, day: day, time: time, pref: pref, openDetail: openDetail)));
      return null;
    }
    return (r['error'] as String?) ?? 'No bus found between these places.';
  } catch (e) {
    return 'Could not reach the planner at ${Api.base}. Is the API running? ($e)';
  }
}

/// Uber-style home: mode toggle, "Where to?" bar, recent trips, suggestions, ways to plan.
class PlanPage extends StatefulWidget {
  const PlanPage({super.key, this.onOpenTab});
  final ValueChanged<int>? onOpenTab;

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 30);
  int? _busy; // index of the recent trip being searched
  String? _error;

  @override
  void initState() {
    super.initState();
    // Deep link for demos: ?from=...&to=...&time=08:30&day=Weekday&pref=balanced[&detail=0]
    final q = Uri.base.queryParameters;
    if (q['from'] != null && q['to'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final err = await runSearch(context,
            from: q['from']!,
            to: q['to']!,
            day: q['day'] ?? 'Weekday',
            time: q['time'] ?? '08:30',
            pref: q['pref'] ?? 'balanced',
            openDetail: int.tryParse(q['detail'] ?? ''));
        if (mounted) setState(() => _error = err);
      });
    }
  }

  void _openSearch({String pref = 'balanced', _Example? e}) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TripSearchPage(
              initialTime: _time,
              initialPref: pref,
              from: e == null ? null : {'key': e.from, 'name': e.from},
              to: e == null ? null : {'key': e.to, 'name': e.to},
            )));
  }

  Future<void> _runExample(int i) async {
    final e = _examples[i];
    setState(() {
      _busy = i;
      _error = null;
    });
    final err = await runSearch(context, from: e.from, to: e.to, day: 'Weekday', time: e.time, pref: 'balanced');
    if (mounted) {
      setState(() {
        _busy = null;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 10, bottom: 16), children: [
          // Rides | Delivery-style toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const _ModeTab(icon: Icons.directions_bus, label: 'Trips', selected: true),
              const SizedBox(width: 22),
              _ModeTab(icon: Icons.route, label: 'Routes', selected: false, onTap: () => widget.onOpenTab?.call(1)),
            ]),
          ),
          const SizedBox(height: 14),
          // Where to? bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: context.field,
              borderRadius: BorderRadius.circular(30),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => _openSearch(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
                  child: Row(children: [
                    const Icon(Icons.search, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Where to?', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600))),
                    Material(
                      color: context.bg,
                      shape: const StadiumBorder(),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () async {
                          final p = await showTimePicker(context: context, initialTime: _time);
                          if (p != null) setState(() => _time = p);
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.schedule, size: 17),
                            const SizedBox(width: 6),
                            Text(_hhmm(_time), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                            const Icon(Icons.keyboard_arrow_down, size: 20),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (_error != null) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: ErrorBox(_error!)),
          // recent trips (Work / Home rows in Uber)
          for (var i = 0; i < _examples.length; i++) ...[
            InkWell(
              onTap: _busy == null ? () => _runExample(i) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: context.field, shape: BoxShape.circle),
                    child: _busy == i
                        ? Padding(padding: const EdgeInsets.all(11), child: CircularProgressIndicator(strokeWidth: 2, color: context.fg))
                        : Icon(_examples[i].icon, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_examples[i].label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
                      Text('Weekday · leave ${_examples[i].time}', style: TextStyle(fontSize: 13, color: context.muted)),
                    ]),
                  ),
                ]),
              ),
            ),
            if (i < _examples.length - 1) Padding(padding: const EdgeInsets.only(left: 70), child: Divider(color: context.line)),
          ],
          const SizedBox(height: 8),
          Container(height: 8, color: context.field),
          const SizedBox(height: 18),
          // Suggestions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Expanded(child: Text('Suggestions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                InkWell(
                  onTap: () => _openSearch(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Text('See all', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _SuggestTile(icon: Icons.bolt, label: 'Fastest', onTap: () => _openSearch(pref: 'fastest')),
                _SuggestTile(icon: Icons.event_seat, label: 'A seat', onTap: () => _openSearch(pref: 'comfortable')),
                _SuggestTile(icon: Icons.route, label: 'Routes', onTap: () => widget.onOpenTab?.call(1)),
                _SuggestTile(icon: Icons.local_fire_department, label: 'Hotspots', onTap: () => widget.onOpenTab?.call(2)),
              ]),
              const SizedBox(height: 26),
              const Text('Ways to plan with SeatSense', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
            ]),
          ),
          SizedBox(
            height: 196,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
              _WayCard(
                icon: Icons.wb_twilight,
                title: 'Beat the 9 am crush',
                body: 'See which bus still has seats',
                onTap: () => _openSearch(pref: 'comfortable', e: _examples[0]),
              ),
              _WayCard(
                icon: Icons.more_time,
                title: 'Leave 15 min later',
                body: 'Every trip shows if waiting helps',
                onTap: () => _runExample(0),
              ),
              _WayCard(
                icon: Icons.insights,
                title: 'Check a route',
                body: 'Crowding hour by hour',
                onTap: () => widget.onOpenTab?.call(1),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Crowding levels come from October 2026 Delhi bus e-tickets.',
                    style: TextStyle(fontSize: 12.5, color: context.muted)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.icon, required this.label, required this.selected, this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: selected ? context.fg : Colors.transparent, width: 2.5))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 24, color: selected ? context.fg : context.muted),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontSize: 19, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? context.fg : context.muted)),
          ]),
        ),
      );
}

class _SuggestTile extends StatelessWidget {
  const _SuggestTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Column(children: [
              Container(
                height: 58,
                decoration: BoxDecoration(color: context.field, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Icon(icon, size: 28)),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

class _WayCard extends StatelessWidget {
  const _WayCard({required this.icon, required this.title, required this.body, required this.onTap});
  final IconData icon;
  final String title, body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 220,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                height: 120,
                decoration: BoxDecoration(color: context.field, borderRadius: BorderRadius.circular(12)),
                child: Stack(children: [
                  Positioned(right: -10, bottom: -14, child: Icon(icon, size: 110, color: context.line)),
                  Positioned(left: 14, top: 14, child: Icon(icon, size: 34, color: context.fg)),
                ]),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
                const Icon(Icons.arrow_forward, size: 16),
              ]),
              Text(body, style: TextStyle(fontSize: 12.5, color: context.muted)),
            ]),
          ),
        ),
      );
}

/// "Plan your trip" screen (Uber's destination search): origin, destination, time, day, priority.
class TripSearchPage extends StatefulWidget {
  const TripSearchPage({super.key, this.from, this.to, required this.initialTime, this.initialPref = 'balanced'});
  final Json? from, to;
  final TimeOfDay initialTime;
  final String initialPref;

  @override
  State<TripSearchPage> createState() => _TripSearchPageState();
}

class _TripSearchPageState extends State<TripSearchPage> {
  late Json? _from = widget.from, _to = widget.to;
  String _day = 'Weekday';
  late TimeOfDay _time = widget.initialTime;
  late String _pref = widget.initialPref;
  bool _loading = false;
  String? _error;
  int _fieldsVersion = 0;

  Future<void> _search() async {
    if (_from == null || _to == null) {
      setState(() => _error = 'Pick where you start and where you are going.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await runSearch(context, from: _from!['key'], to: _to!['key'], day: _day, time: _hhmm(_time), pref: _pref);
    if (mounted) {
      setState(() {
        _loading = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan your trip')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
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
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              SelectPill(
                label: 'Leave at ${_hhmm(_time)}',
                icon: Icons.schedule,
                selected: true,
                onTap: () async {
                  final p = await showTimePicker(context: context, initialTime: _time);
                  if (p != null) setState(() => _time = p);
                },
              ),
            ]),
            const SizedBox(height: 10),
            DaySelector(value: _day, onChanged: (d) => setState(() => _day = d)),
            const SizedBox(height: 20),
            const SectionLabel('Prioritise'),
            Row(children: [
              for (var i = 0; i < _prefs.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                    child: _PrefTile(pref: _prefs[i], selected: _pref == _prefs[i].$1, onTap: () => setState(() => _pref = _prefs[i].$1))),
              ],
            ]),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _loading ? null : _search,
              child: _loading
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.bg))
                  : const Text('Find buses'),
            ),
            if (_error != null) ...[const SizedBox(height: 12), ErrorBox(_error!)],
          ]),
        ),
      ),
    );
  }
}

/// Origin and destination in one grey block, joined by a dotted line (Uber style).
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
            StopField(key: ValueKey('from$version'), hint: 'Pickup stop', initial: from, onSelected: onFrom),
            Divider(height: 1, color: context.line),
            StopField(key: ValueKey('to$version'), hint: 'Where to?', initial: to, onSelected: onTo),
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
