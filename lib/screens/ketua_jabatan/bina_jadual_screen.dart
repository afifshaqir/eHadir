import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/department.dart';
import '../../models/lecturer_assignment.dart';
import '../../models/timetable_entry.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/curriculum_service.dart';
import '../../services/mock_db_service.dart';
import '../../services/seed_data.dart';
import '../../theme.dart';

/// Ketua Jabatan: pulls every LecturerAssignment under their department,
/// lets them place each one on the weekly timetable (day + period range +
/// room), and saves the resulting [TimetableEntry] documents to Firestore.
class BinaJadualScreen extends ConsumerStatefulWidget {
  const BinaJadualScreen({super.key});

  @override
  ConsumerState<BinaJadualScreen> createState() => _BinaJadualScreenState();
}

class _BinaJadualScreenState extends ConsumerState<BinaJadualScreen> {
  bool _seeding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSeed());
  }

  /// Ensures KJ has data even when no Ketua Program has assigned subjects
  /// yet — pre-populates the DED roster from the JAN-JUN 2026 senarai.
  Future<void> _autoSeed() async {
    final curriculum = ref.read(curriculumServiceProvider);
    setState(() => _seeding = true);
    try {
      await curriculum.seedAssignmentsIfEmpty(SeedData.dedAssignments);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat seed: $e'),
            backgroundColor: EHadirTheme.rejected,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _forceSeed() async {
    final curriculum = ref.read(curriculumServiceProvider);
    setState(() => _seeding = true);
    try {
      for (final a in SeedData.dedAssignments) {
        await curriculum.upsertAssignment(a);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${SeedData.dedAssignments.length} tugasan DED dimuat.'),
              backgroundColor: EHadirTheme.approved),
        );
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).currentUser!;
    final department = user.program; // KJ stores dept name in `program`
    final curriculum = ref.read(curriculumServiceProvider);
    final programKeys = Department.programsOf[department] ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bina Jadual'),
        actions: [
          IconButton(
            tooltip: 'Muat semula tugasan DED',
            icon: const Icon(Icons.cloud_download_rounded),
            onPressed: _seeding ? null : _forceSeed,
          ),
        ],
      ),
      body: Column(
        children: [
          _DeptHeader(department: department, programKeys: programKeys),
          if (_seeding) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: StreamBuilder<List<LecturerAssignment>>(
              stream: curriculum.streamAssignmentsForDepartment(department),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final assignments = snap.data ?? const <LecturerAssignment>[];
                if (assignments.isEmpty) {
                  return _EmptyHint(onSeed: _forceSeed);
                }
                // Group by program so KJ can scan one course at a time.
                final byProgram = <String, List<LecturerAssignment>>{};
                for (final a in assignments) {
                  byProgram.putIfAbsent(a.program, () => []).add(a);
                }
                final programs = byProgram.keys.toList()..sort();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: programs.length,
                  itemBuilder: (ctx, i) {
                    final program = programs[i];
                    final list = byProgram[program]!
                      ..sort((a, b) =>
                          a.lecturerName.compareTo(b.lecturerName));
                    return _ProgramBlock(
                      program: program,
                      assignments: list,
                      kj: user,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  DEPARTMENT HEADER
// ═══════════════════════════════════════════════════════════════

class _DeptHeader extends StatelessWidget {
  final String department;
  final List<String> programKeys;
  const _DeptHeader({required this.department, required this.programKeys});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE64A19), Color(0xFFFF7043)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
        boxShadow: EHadirTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('JABATAN',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text(department,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: programKeys
                .map((p) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(p,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PROGRAM BLOCK
// ═══════════════════════════════════════════════════════════════

class _ProgramBlock extends StatelessWidget {
  final String program;
  final List<LecturerAssignment> assignments;
  final AppUser kj;
  const _ProgramBlock(
      {required this.program, required this.assignments, required this.kj});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: EHadirTheme.card,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
        border: Border.all(color: EHadirTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: EHadirTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: EHadirTheme.primary, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(program,
                      style: const TextStyle(
                          color: EHadirTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
                Text('${assignments.length}',
                    style: const TextStyle(
                        color: EHadirTheme.textSecondary,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(height: 1),
          ...assignments.map((a) => _AssignmentRow(assignment: a, kj: kj)),
        ],
      ),
    );
  }
}

class _AssignmentRow extends ConsumerWidget {
  final LecturerAssignment assignment;
  final AppUser kj;
  const _AssignmentRow({required this.assignment, required this.kj});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculum = ref.read(curriculumServiceProvider);

    return StreamBuilder<List<TimetableEntry>>(
      stream: curriculum.streamEntriesForLecturer(assignment.lecturerId),
      builder: (ctx, snap) {
        final placed = (snap.data ?? const <TimetableEntry>[])
            .where((e) => e.assignmentId == assignment.id)
            .toList();

        return InkWell(
          onTap: () => _openPlacement(context, ref, existing: placed),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${assignment.subjectCode} — ${assignment.subjectName}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: EHadirTheme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${assignment.lecturerName} • ${assignment.studentClass}',
                            style: const TextStyle(
                                color: EHadirTheme.textSecondary,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _PlacedBadge(count: placed.length),
                  ],
                ),
                if (placed.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: placed
                          .map((e) => _SlotPill(
                              entry: e,
                              onDelete: () => curriculum.deleteEntry(e.id)))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPlacement(BuildContext context, WidgetRef ref,
      {required List<TimetableEntry> existing}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlacementSheet(assignment: assignment, kj: kj),
    );
  }
}

class _PlacedBadge extends StatelessWidget {
  final int count;
  const _PlacedBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final c = count == 0 ? EHadirTheme.textSecondary : EHadirTheme.approved;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              count == 0
                  ? Icons.add_circle_outline_rounded
                  : Icons.check_circle_rounded,
              size: 12,
              color: c),
          const SizedBox(width: 4),
          Text(count == 0 ? 'Belum' : '$count slot',
              style: TextStyle(
                  color: c, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SlotPill extends StatelessWidget {
  final TimetableEntry entry;
  final VoidCallback onDelete;
  const _SlotPill({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final dateStr = DateFormat('EEE, d MMM').format(entry.date);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: EHadirTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EHadirTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(dateStr,
              style: const TextStyle(
                  color: EHadirTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text('${fmt(entry.startTime)}–${fmt(entry.endTime)}',
              style: const TextStyle(
                  color: EHadirTheme.textPrimary, fontSize: 11)),
          const SizedBox(width: 6),
          if (entry.room.isNotEmpty)
            Text(entry.room,
                style: const TextStyle(
                    color: EHadirTheme.textSecondary, fontSize: 11)),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 14),
            color: EHadirTheme.rejected,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PLACEMENT SHEET — day / period range / room
// ═══════════════════════════════════════════════════════════════

class _PlacementSheet extends ConsumerStatefulWidget {
  final LecturerAssignment assignment;
  final AppUser kj;
  const _PlacementSheet({required this.assignment, required this.kj});

  @override
  ConsumerState<_PlacementSheet> createState() => _PlacementSheetState();
}

class _PlacementSheetState extends ConsumerState<_PlacementSheet> {
  DateTime? _date;
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  String? _room;
  bool _saving = false;
  List<TimetableEntry> _conflicts = [];

  bool get _canSave =>
      _date != null && _room != null && _room!.isNotEmpty && !_saving;

  Future<void> _pickDate() async {
    final dt = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: EHadirTheme.primary),
        ),
        child: child!,
      ),
    );
    if (dt != null) setState(() => _date = dt);
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(context: context, initialTime: _start);
    if (t != null) {
      setState(() {
        _start = t;
        // keep end after start
        final endMin = _end.hour * 60 + _end.minute;
        final startMin = t.hour * 60 + t.minute;
        if (endMin <= startMin) {
          _end = TimeOfDay(hour: (t.hour + 1).clamp(0, 23), minute: t.minute);
        }
      });
    }
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(context: context, initialTime: _end);
    if (t != null) setState(() => _end = t);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _conflicts = [];
    });

    final curriculum = ref.read(curriculumServiceProvider);
    final candidate = TimetableEntry(
      id: '',
      assignmentId: widget.assignment.id,
      subjectCode: widget.assignment.subjectCode,
      subjectName: widget.assignment.subjectName,
      lecturerId: widget.assignment.lecturerId,
      lecturerName: widget.assignment.lecturerName,
      program: widget.assignment.program,
      studentClass: widget.assignment.studentClass,
      room: _room!.trim(),
      date: _date!,
      startTime: _start,
      endTime: _end,
      assignedBy: widget.kj.id,
    );

    final all = await curriculum
        .streamEntriesForDepartment(widget.kj.program)
        .first;
    final conflicts =
        CurriculumService.findConflicts(candidate: candidate, existing: all);

    if (conflicts.isNotEmpty) {
      setState(() {
        _conflicts = conflicts;
        _saving = false;
      });
      return;
    }

    await curriculum.upsertEntry(candidate);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${widget.assignment.subjectCode} disusun ke ${DateFormat('d MMM').format(_date!)}.'),
          backgroundColor: EHadirTheme.approved,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(mockDbProvider);
    final rooms = db.rooms;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (ctx, controller) => Container(
        decoration: const BoxDecoration(
          color: EHadirTheme.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: EHadirTheme.divider,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.assignment.subjectCode} — ${widget.assignment.subjectName}',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: EHadirTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.assignment.lecturerName} • ${widget.assignment.studentClass}',
              style: const TextStyle(
                  color: EHadirTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),

            // ── 1) DATE ────────────────────────────────────
            const _SectionLabel('Pilih Tarikh & Masa'),
            const SizedBox(height: 8),
            _DateCard(date: _date, onTap: _pickDate),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _TimeCard(
                        label: 'Masa Mula',
                        time: _start,
                        onTap: _pickStart)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded,
                      color: EHadirTheme.textSecondary),
                ),
                Expanded(
                    child: _TimeCard(
                        label: 'Masa Tamat',
                        time: _end,
                        onTap: _pickEnd)),
              ],
            ),
            const SizedBox(height: 20),

            // ── 2) ROOM ────────────────────────────────────
            const _SectionLabel('Pilih Bilik'),
            const SizedBox(height: 8),
            ...rooms.map((r) {
              final selected = _room == r.name;
              return GestureDetector(
                onTap: () => setState(() => _room = r.name),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? EHadirTheme.primary.withValues(alpha: 0.10)
                        : EHadirTheme.card,
                    borderRadius:
                        BorderRadius.circular(EHadirTheme.radiusMd),
                    border: Border.all(
                      color: selected
                          ? EHadirTheme.primary
                          : EHadirTheme.divider,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.name,
                                style: const TextStyle(
                                    color: EHadirTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              '${r.building} · ${r.typeLabel} · ${r.capacity} pax',
                              style: const TextStyle(
                                  color: EHadirTheme.textSecondary,
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle_rounded,
                            color: EHadirTheme.primary, size: 20),
                    ],
                  ),
                ),
              );
            }),

            if (_conflicts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: EHadirTheme.rejected.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
                  border: Border.all(
                      color: EHadirTheme.rejected.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⚠️ Konflik Jadual',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: EHadirTheme.rejected)),
                    const SizedBox(height: 4),
                    ..._conflicts.map((c) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '• ${c.subjectCode} (${c.lecturerName}) — ${DateFormat('d MMM').format(c.date)} '
                            '${_fmt(c.startTime)}–${_fmt(c.endTime)}, ${c.room}',
                            style: const TextStyle(
                                color: EHadirTheme.textPrimary, fontSize: 12),
                          ),
                        )),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _canSave ? _save : null,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_saving ? 'Menyimpan…' : 'Simpan ke Jadual'),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: EHadirTheme.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 15));
}

class _DateCard extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onTap;
  const _DateCard({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: EHadirTheme.card,
          borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
          border: Border.all(color: EHadirTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: EHadirTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(EHadirTheme.radiusSm),
              ),
              child: const Icon(Icons.calendar_today_rounded,
                  color: EHadirTheme.accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tarikh',
                      style: TextStyle(
                          color: EHadirTheme.textSecondary, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    date != null
                        ? DateFormat('EEEE, dd MMMM yyyy').format(date!)
                        : 'Tekan untuk pilih tarikh',
                    style: TextStyle(
                      color: date != null
                          ? EHadirTheme.textPrimary
                          : EHadirTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeCard(
      {required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: EHadirTheme.card,
          borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
          border: Border.all(color: EHadirTheme.divider),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    color: EHadirTheme.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                  color: EHadirTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final VoidCallback onSeed;
  const _EmptyHint({required this.onSeed});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_outlined,
                  size: 64,
                  color: EHadirTheme.textSecondary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              const Text(
                'Tiada tugasan dari Ketua Program.',
                textAlign: TextAlign.center,
                style: TextStyle(color: EHadirTheme.textSecondary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Anda boleh muat senarai DED dari rekod JAN-JUN 2026 '
                'untuk mula menjadualkan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: EHadirTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onSeed,
                icon: const Icon(Icons.cloud_download_rounded, size: 18),
                label: const Text('Muat Tugasan DED'),
              ),
            ],
          ),
        ),
      );
}
