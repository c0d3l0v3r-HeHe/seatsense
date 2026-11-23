import 'dart:math';

import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';

const levelLabels = ['Seats likely', 'Standing room', 'Crowded'];
const levelColors = [Color(0xFF05944F), Color(0xFFFFC043), Color(0xFFE11900)];
const levelIcons = [Icons.event_seat, Icons.accessibility_new, Icons.groups];
const dayTypes = ['Weekday', 'Saturday', 'Sunday'];

Color onLevel(int l) => l == 1 ? const Color(0xFF241A00) : Colors.white;

int asInt(dynamic v) => (v as num).round();
double asDouble(dynamic v) => (v as num).toDouble();

String arrow(String direction) => direction == 'UP' ? '↑' : (direction == 'DOWN' ? '↓' : '');

/// "08:32" + 7.4 min -> "08:39"
String addMinutes(String hhmm, double minutes) {
  final p = hhmm.split(':');
  final t = (int.parse(p[0]) * 60 + int.parse(p[1]) + minutes.round()) % (24 * 60);
  return '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}';
}

/// Crowding level as colour + icon + words, never colour alone.
class CrowdBadge extends StatelessWidget {
  const CrowdBadge(this.level, {super.key, this.small = false});
  final int level;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final fg = onLevel(level);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 3 : 6),
      decoration: BoxDecoration(color: levelColors[level], borderRadius: BorderRadius.circular(20), boxShadow: smallShadow),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(levelIcons[level], size: small ? 13 : 16, color: fg),
        const SizedBox(width: 5),
        Text(levelLabels[level], style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: small ? 11.5 : 13)),
      ]),
    );
  }
}

class ConfidenceChip extends StatelessWidget {
  const ConfidenceChip(this.confidence, {super.key});
  final String confidence;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (confidence) {
      'high' => ('High confidence', Icons.verified_outlined),
      'medium' => ('Medium confidence', Icons.info_outline),
      _ => ('Limited data', Icons.warning_amber_rounded),
    };
    return Tooltip(
      message: 'Based on how many tickets sit behind this estimate',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: context.muted),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: context.muted)),
      ]),
    );
  }
}

/// Small grey pill (tags such as "Best match").
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.inverse = false});
  final String text;
  final bool inverse;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: inverse ? context.fg : context.field, borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: inverse ? context.bg : context.fg)),
      );
}

/// Bus number in a black block, e.g. [bus 717A ↓].
class BusChip extends StatelessWidget {
  const BusChip(this.number, this.direction, {super.key, this.large = false});
  final String number, direction;
  final bool large;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: large ? 12 : 7, vertical: large ? 7 : 4),
        decoration: BoxDecoration(color: context.fg, borderRadius: BorderRadius.circular(large ? 10 : 7), boxShadow: smallShadow),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.directions_bus, size: large ? 20 : 14, color: context.bg),
          SizedBox(width: large ? 6 : 3),
          Text('$number ${arrow(direction)}'.trim(),
              style: TextStyle(color: context.bg, fontWeight: FontWeight.w800, fontSize: large ? 18 : 12.5)),
        ]),
      );
}

/// Horizontal strip: one block per stretch, width = minutes, colour = crowding level.
class StretchBar extends StatelessWidget {
  const StretchBar(this.stretches, {super.key, this.height = 8});
  final List<Json> stretches;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Row(
        children: [
          for (final s in stretches)
            Expanded(
              flex: max(1, (asDouble(s['minutes'] ?? 1) * 10).round()),
              child: Tooltip(
                message: '${s['from']} → ${s['to']}: ${levelLabels[asInt(s['level'])]}',
                child: Container(
                  height: height,
                  margin: const EdgeInsets.only(right: 1),
                  color: levelColors[asInt(s['level'])].withValues(alpha: s['confidence'] == 'low' ? 0.4 : 1.0),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// MyStop-style itinerary line: start ● [bus 34] ━━ ⇄ [bus 717A] ━━ ⚑ end, the line coloured by crowding.
class ItineraryLine extends StatelessWidget {
  const ItineraryLine(this.legs, {super.key});
  final List<Json> legs;

  Widget _node(BuildContext c, IconData i) => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: c.isDark ? Pal.fieldDark : Pal.white, shape: BoxShape.circle, border: Border.all(color: c.line), boxShadow: smallShadow),
        child: Icon(i, size: 15, color: c.fg),
      );

  @override
  Widget build(BuildContext context) {
    final first = legs.first, last = legs.last;
    final small = TextStyle(fontSize: 11.5, color: context.muted);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('${first['board_stop']}', style: small, maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 12),
        Flexible(
            child: Text('${last['alight_stop']}',
                style: small, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        _node(context, Icons.trip_origin),
        for (var i = 0; i < legs.length; i++) ...[
          if (i > 0) _node(context, Icons.sync_alt),
          const SizedBox(width: 4),
          BusChip('${legs[i]['number']}', '${legs[i]['direction']}'),
          const SizedBox(width: 4),
          Expanded(
            flex: max(1, asInt(legs[i]['ride_min'])),
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: StretchBar((legs[i]['stretches'] as List).cast<Json>(), height: 6),
            ),
          ),
        ],
        _node(context, Icons.flag),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Text('${first['board_time']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.fg)),
        if (legs.length > 1) ...[
          const Spacer(),
          Flexible(
            flex: 6,
            child: Text('change at ${legs[1]['board_stop']}',
                style: small, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ),
        ],
        const Spacer(),
        Text('${last['alight_time']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.fg)),
      ]),
    ]);
  }
}

/// SIStrans-style stop list: stops on a vertical line, the line between them coloured by crowding.
/// Runs of stretches with the same level are grouped; tap a group to list the stops inside it.
class StopTimeline extends StatelessWidget {
  const StopTimeline({
    super.key,
    required this.stretches,
    this.startTime,
    this.endTime,
    this.firstCaption,
    this.lastCaption,
    this.firstIcon = Icons.radio_button_checked,
    this.lastIcon = Icons.location_on,
    this.showScores = false,
  });
  final List<Json> stretches;
  final String? startTime, endTime, firstCaption, lastCaption;
  final IconData firstIcon, lastIcon;
  final bool showScores;

  @override
  Widget build(BuildContext context) {
    // group consecutive stretches with the same level
    final groups = <List<Json>>[];
    for (final s in stretches) {
      if (groups.isEmpty || asInt(groups.last.last['level']) != asInt(s['level'])) {
        groups.add([s]);
      } else {
        groups.last.add(s);
      }
    }
    final rows = <Widget>[];
    var elapsed = 0.0;
    for (var g = 0; g < groups.length; g++) {
      final grp = groups[g];
      final isFirst = g == 0;
      final lv = asInt(grp.first['level']);
      final prevColor = isFirst ? null : levelColors[asInt(groups[g - 1].first['level'])];
      rows.add(_StopRow(
        name: '${grp.first['from']}',
        time: startTime == null ? null : addMinutes(startTime!, elapsed),
        caption: isFirst ? firstCaption : 'Crowding changes here',
        icon: isFirst ? firstIcon : null,
        above: prevColor,
        below: levelColors[lv],
        strong: isFirst,
      ));
      final mins = grp.fold<double>(0, (a, s) => a + asDouble(s['minutes'] ?? 0));
      rows.add(_GroupRow(stretches: grp, startTime: startTime, startElapsed: elapsed, showScores: showScores));
      elapsed += mins;
    }
    rows.add(_StopRow(
      name: '${stretches.last['to']}',
      time: endTime ?? (startTime == null ? null : addMinutes(startTime!, elapsed)),
      caption: lastCaption,
      icon: lastIcon,
      above: levelColors[asInt(stretches.last['level'])],
      below: null,
      strong: true,
    ));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

const _railW = 44.0;

class _Rail extends StatelessWidget {
  const _Rail({this.above, this.below, this.node});
  final Color? above, below;
  final Widget? node;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: _railW,
        child: Column(children: [
          Expanded(child: Container(width: 5, color: above ?? Colors.transparent)),
          ?node,
          Expanded(child: Container(width: 5, color: below ?? Colors.transparent)),
        ]),
      );
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.name, this.time, this.caption, this.icon, this.above, this.below, this.strong = false});
  final String name;
  final String? time, caption;
  final IconData? icon;
  final Color? above, below;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final node = icon != null
        ? Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: context.fg, shape: BoxShape.circle, boxShadow: smallShadow),
            child: Icon(icon, size: 16, color: context.bg),
          )
        : Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
                color: context.bg, shape: BoxShape.circle, border: Border.all(color: context.fg, width: 3)),
          );
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Rail(above: above, below: below, node: node),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(name, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w700, fontSize: strong ? 15 : 14)),
              if (caption != null) Text(caption!, style: TextStyle(fontSize: 12, color: context.muted)),
            ]),
          ),
        ),
        if (time != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Center(
              child: Text(time!,
                  style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w600, fontSize: strong ? 15 : 13)),
            ),
          ),
      ]),
    );
  }
}

class _GroupRow extends StatefulWidget {
  const _GroupRow({required this.stretches, this.startTime, required this.startElapsed, this.showScores = false});
  final List<Json> stretches;
  final String? startTime;
  final double startElapsed;
  final bool showScores;

  @override
  State<_GroupRow> createState() => _GroupRowState();
}

class _GroupRowState extends State<_GroupRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final st = widget.stretches;
    final lv = asInt(st.first['level']);
    final color = levelColors[lv].withValues(alpha: st.every((s) => s['confidence'] == 'low') ? 0.45 : 1);
    final mins = st.fold<double>(0, (a, s) => a + asDouble(s['minutes'] ?? 0));
    final inner = st.length - 1; // stops passed without stopping the timeline
    final detail = [
      if (mins > 0) '~${mins.round()} min',
      if (inner > 0) '$inner ${inner == 1 ? 'stop' : 'stops'}' else '${st.length} ${st.length == 1 ? 'stretch' : 'stretches'}',
    ].join(' · ');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        onTap: inner > 0 || widget.showScores ? () => setState(() => _open = !_open) : null,
        borderRadius: BorderRadius.circular(10),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Rail(above: color, below: color),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.isDark ? Pal.fieldDark : Pal.white,
                    border: Border.all(color: context.line),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: softShadow,
                  ),
                  child: Row(children: [
                    CrowdBadge(lv, small: true),
                    const SizedBox(width: 10),
                    Expanded(child: Text(detail, style: TextStyle(fontSize: 12, color: context.muted))),
                    if (inner > 0 || widget.showScores)
                      Icon(_open ? Icons.expand_less : Icons.expand_more, size: 20, color: context.muted),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
      if (_open)
        for (var i = 0; i < st.length; i++)
          if (i > 0 || widget.showScores)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _Rail(
                  above: color,
                  below: color,
                  node: i > 0
                      ? Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(color: context.bg, shape: BoxShape.circle, border: Border.all(color: context.fg, width: 2)))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Text(
                      widget.showScores
                          ? '${st[i]['from']} → ${st[i]['to']} · score ${asDouble(st[i]['score']).round()}'
                              '${st[i]['confidence'] == 'low' ? ' · limited data' : ''}'
                          : '${st[i]['from']}',
                      style: TextStyle(fontSize: 12.5, color: context.muted),
                    ),
                  ),
                ),
                if (widget.startTime != null && i > 0)
                  Center(
                    child: Text(
                      addMinutes(widget.startTime!,
                          widget.startElapsed + st.take(i).fold<double>(0, (a, s) => a + asDouble(s['minutes'] ?? 0))),
                      style: TextStyle(fontSize: 12, color: context.muted),
                    ),
                  ),
              ]),
            ),
    ]);
  }
}

/// Small bar chart of crowding through the day; tap a bar to pick that hour.
class HourBars extends StatelessWidget {
  const HourBars({super.key, required this.byHour, required this.selected, required this.onTap});
  final List<Json> byHour;
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final h in byHour)
          Expanded(
            child: GestureDetector(
              onTap: () => onTap(asInt(h['hour'])),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Container(
                  height: max(3.0, asDouble(h['max_score']) * 0.8),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: levelColors[asInt(h['level'])].withValues(alpha: asInt(h['hour']) == selected ? 1.0 : 0.45),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    border: asInt(h['hour']) == selected ? Border.all(color: context.fg, width: 2) : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(asInt(h['hour']) % 3 == 0 ? '${h['hour']}' : '',
                    style: TextStyle(fontSize: 10, color: context.muted)),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Black-when-selected pill, like Uber's filter chips.
class SelectPill extends StatelessWidget {
  const SelectPill({super.key, required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? context.fg : context.field,
        shape: const StadiumBorder(),
        elevation: selected ? 4 : 1,
        shadowColor: const Color(0x55000000),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 16, color: selected ? context.bg : context.fg), const SizedBox(width: 6)],
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13.5, color: selected ? context.bg : context.fg)),
            ]),
          ),
        ),
      );
}

class DaySelector extends StatelessWidget {
  const DaySelector({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => ChoiceRow<String>(
        options: const [('Weekday', 'Weekday', null), ('Saturday', 'Saturday', null), ('Sunday', 'Sunday', null)],
        value: value,
        onChanged: onChanged,
      );
}

/// A row of pills that wraps on narrow phones.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({super.key, required this.options, required this.value, required this.onChanged});
  final List<(T, String, IconData?)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in options) SelectPill(label: o.$2, icon: o.$3, selected: o.$1 == value, onTap: () => onChanged(o.$1)),
      ]);
}

/// Big left-aligned page title, Uber style.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: TextStyle(fontSize: 14, color: context.muted, height: 1.35)),
          ],
        ]),
      );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );
}

class ErrorBox extends StatelessWidget {
  const ErrorBox(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(Icons.cloud_off, color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer))),
        ]),
      );
}

class LevelLegend extends StatelessWidget {
  const LevelLegend({super.key});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 6, children: [
        for (var i = 0; i < 3; i++) CrowdBadge(i, small: true),
      ]);
}
