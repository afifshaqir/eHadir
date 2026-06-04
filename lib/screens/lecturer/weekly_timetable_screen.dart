import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/timetable_entry.dart';
import '../../services/auth_service.dart';
import '../../services/curriculum_service.dart';
import '../../theme.dart';

/// Pensyarah view of the weekly timetable laid out in the IKM "STUDENT'S TIME
/// TABLE" grid: 5 rows (Mon-Fri) × 9 columns (period 1..9). Mirrors the DED 1A
/// PDF template.
class WeeklyTimetableScreen extends ConsumerWidget {
  const WeeklyTimetableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).currentUser!;
    final curriculum = ref.read(curriculumServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Jadual Mingguan"),
      ),
      body: StreamBuilder<List<TimetableEntry>>(
        stream: curriculum.streamEntriesForLecturer(user.id),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data ?? const <TimetableEntry>[];
          return Column(
            children: [
              _Header(name: user.name, program: user.program),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: _TimetableGrid(entries: entries),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  HEADER
// ═══════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final String name;
  final String program;
  const _Header({required this.name, required this.program});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: EHadirTheme.primaryGradient,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
        boxShadow: EHadirTheme.glowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('STUDENT\'S TIME TABLE',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 2)),
          const SizedBox(height: 4),
          Text(program,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_rounded,
                  color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(name,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 14),
              const Icon(Icons.event_rounded,
                  color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              const Text('SESI JAN - JUN 2026',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  GRID
// ═══════════════════════════════════════════════════════════════

class _TimetableGrid extends StatelessWidget {
  final List<TimetableEntry> entries;
  const _TimetableGrid({required this.entries});

  static const double _kDayColW = 56;
  static const double _kPeriodW = 130;
  static const double _kHeaderH = 56;
  static const double _kRowH = 96;

  /// Build a per-day list of segments: each segment either represents an entry
  /// (spanning N periods) or a blank gap (1 period). Caller can render them
  /// left-to-right without overlap.
  List<_Segment> _segmentsForDay(SchoolDay day) {
    final dayEntries = entries.where((e) => e.day == day).toList()
      ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
    final out = <_Segment>[];
    int cursor = 1;
    for (final e in dayEntries) {
      if (e.startPeriod > cursor) {
        out.add(_Segment.blank(cursor, e.startPeriod - 1));
      }
      out.add(_Segment.entry(e));
      cursor = e.endPeriod + 1;
    }
    if (cursor <= 9) {
      out.add(_Segment.blank(cursor, 9));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EHadirTheme.card,
        border: Border.all(color: EHadirTheme.divider),
        borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
      ),
      child: Column(
        children: [
          // Header row: time labels
          Row(
            children: [
              const SizedBox(width: _kDayColW, height: _kHeaderH),
              for (final p in Period.all)
                Container(
                  width: _kPeriodW,
                  height: _kHeaderH,
                  decoration: BoxDecoration(
                    color: EHadirTheme.surfaceLight,
                    border: Border(
                      left: BorderSide(color: EHadirTheme.divider),
                      bottom: BorderSide(color: EHadirTheme.divider),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${p.index}',
                          style: const TextStyle(
                              color: EHadirTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                      Text(p.label(),
                          style: const TextStyle(
                              color: EHadirTheme.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
          // Rows per day
          for (final day in SchoolDay.values)
            Row(
              children: [
                Container(
                  width: _kDayColW,
                  height: _kRowH,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: EHadirTheme.surfaceLight,
                    border: Border(
                      top: BorderSide(color: EHadirTheme.divider),
                    ),
                  ),
                  child: Text(day.short,
                      style: const TextStyle(
                          color: EHadirTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ),
                ..._segmentsForDay(day).map((seg) => Container(
                      width: _kPeriodW * seg.span,
                      height: _kRowH,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: EHadirTheme.divider),
                          top: BorderSide(color: EHadirTheme.divider),
                        ),
                        color: seg.entry == null
                            ? Colors.white
                            : EHadirTheme.primary.withValues(alpha: 0.06),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: seg.entry == null
                          ? const SizedBox.shrink()
                          : _EntryCell(entry: seg.entry!),
                    )),
              ],
            ),
        ],
      ),
    );
  }
}

class _Segment {
  final int start;
  final int end;
  final TimetableEntry? entry;
  const _Segment._(this.start, this.end, this.entry);
  factory _Segment.blank(int s, int e) => _Segment._(s, e, null);
  factory _Segment.entry(TimetableEntry e) =>
      _Segment._(e.startPeriod, e.endPeriod, e);
  int get span => end - start + 1;
}

class _EntryCell extends StatelessWidget {
  final TimetableEntry entry;
  const _EntryCell({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry.room.isNotEmpty)
          Text(entry.room.toUpperCase(),
              style: const TextStyle(
                  color: EHadirTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(entry.subjectCode,
                    style: const TextStyle(
                        color: EHadirTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(entry.studentClass,
                    style: const TextStyle(
                        color: EHadirTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        Text(entry.lecturerName.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: EHadirTheme.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}
