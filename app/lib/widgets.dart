import 'dart:math';

import 'package:flutter/material.dart';

import 'api.dart';

const levelLabels = ['Seats likely', 'Standing room', 'Crowded'];
const levelColors = [Color(0xFF0CA30C), Color(0xFFFAB219), Color(0xFFD03B3B)];
const levelIcons = [Icons.event_seat, Icons.accessibility_new, Icons.groups];
const dayTypes = ['Weekday', 'Saturday', 'Sunday'];

Color onLevel(int l) => l == 1 ? const Color(0xFF3A2A00) : Colors.white;

int asInt(dynamic v) => (v as num).round();
double asDouble(dynamic v) => (v as num).toDouble();

String arrow(String direction) => direction == 'UP' ? '↑' : (direction == 'DOWN' ? '↓' : '');

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
      decoration: BoxDecoration(color: levelColors[level], borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(levelIcons[level], size: small ? 14 : 18, color: fg),
        const SizedBox(width: 6),
        Text(levelLabels[level],
            style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: small ? 12 : 14)),
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
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return Tooltip(
      message: 'Based on how many tickets sit behind this estimate',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: c)),
      ]),
    );
  }
}

/// Horizontal strip: one block per stretch, width = minutes, colour = crowding level.
class StretchBar extends StatelessWidget {
  const StretchBar(this.stretches, {super.key, this.height = 10});
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
              flex: max(1, (asDouble(s['minutes']) * 10).round()),
              child: Tooltip(
                message: '${s['from']} → ${s['to']}: ${levelLabels[asInt(s['level'])]}',
                child: Container(
                  height: height,
                  margin: const EdgeInsets.only(right: 1),
                  color: levelColors[asInt(s['level'])]
                      .withValues(alpha: s['confidence'] == 'low' ? 0.4 : 1.0),
                ),
              ),
            ),
        ],
      ),
    );
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      height: 110,
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
                    color: levelColors[asInt(h['level'])]
                        .withValues(alpha: asInt(h['hour']) == selected ? 1.0 : 0.55),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    border: asInt(h['hour']) == selected ? Border.all(color: Colors.black87, width: 1.5) : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(asInt(h['hour']) % 3 == 0 ? '${h['hour']}' : '',
                    style: TextStyle(fontSize: 10, color: muted)),
              ]),
            ),
          ),
      ]),
    );
  }
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

/// A row of choice chips that wraps on narrow phones (instead of a squeezed segmented button).
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({super.key, required this.options, required this.value, required this.onChanged});
  final List<(T, String, IconData?)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in options)
          ChoiceChip(
            avatar: o.$3 == null ? null : Icon(o.$3, size: 18),
            label: Text(o.$2),
            selected: o.$1 == value,
            showCheckmark: false,
            onSelected: (_) => onChanged(o.$1),
          ),
      ]);
}

class ErrorBox extends StatelessWidget {
  const ErrorBox(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.cloud_off),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ]),
        ),
      );
}

class LevelLegend extends StatelessWidget {
  const LevelLegend({super.key});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 6, children: [
        for (var i = 0; i < 3; i++) CrowdBadge(i, small: true),
      ]);
}
