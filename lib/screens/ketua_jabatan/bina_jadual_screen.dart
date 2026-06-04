import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/department.dart';
import '../../models/lecturer_assignment.dart';
import '../../models/timetable_entry.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/curriculum_service.dart';
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
    final startLabel = Period.byIndex(entry.startPeriod).start;
    final endLabel = Period.byIndex(entry.endPeriod).end;
    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
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
          Text(entry.day.short,
              style: const TextStyle(
                  color: EHadirTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text('${fmt(startLabel)}–${fmt(endLabel)}',
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
  SchoolDay _day = SchoolDay.mon;
  int _startPeriod = 1;
  int _endPeriod = 1;
  final _roomCtrl = TextEditingController();
  bool _saving = false;
  List<TimetableEntry> _conflicts = [];

  @override
  void dispose() {
    _roomCtrl.dispose();
    super.dispose();
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
      room: _roomCtrl.text.trim(),
      day: _day,
      startPeriod: _startPeriod,
      endPeriod: _endPeriod,
      assignedBy: widget.kj.id,
    );

    // Fetch existing entries in this department for the conflict check.
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
                '${widget.assignment.subjectCode} disusun ke ${_day.long}.'),
            backgroundColor: EHadirTheme.approved),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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

            const _SectionLabel('Hari'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: SchoolDay.values
                  .map((d) => ChoiceChip(
                        label: Text(d.long),
                        selected: _day == d,
                        onSelected: (_) => setState(() => _day = d),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            const _SectionLabel('Slot Mula'),
            const SizedBox(height: 6),
            _PeriodDropdown(
              value: _startPeriod,
              onChanged: (v) => setState(() {
                _startPeriod = v;
                if (_endPeriod < v) _endPeriod = v;
              }),
            ),
            const SizedBox(height: 12),

            const _SectionLabel('Slot Tamat'),
            const SizedBox(height: 6),
            _PeriodDropdown(
              value: _endPeriod,
              min: _startPeriod,
              onChanged: (v) => setState(() => _endPeriod = v),
            ),
            const SizedBox(height: 16),

            const _SectionLabel('Bilik / Lokasi'),
            const SizedBox(height: 6),
            TextField(
              controller: _roomCtrl,
              decoration: const InputDecoration(
                hintText: 'Cth: PA BK 1, WIRING BAY 3, Bilik Kuliah A1',
              ),
            ),

            if (_conflicts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: EHadirTheme.rejected.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
                  border:
                      Border.all(color: EHadirTheme.rejected.withValues(alpha: 0.4)),
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
                            '• ${c.subjectCode} (${c.lecturerName}) — ${c.day.short} slot ${c.startPeriod}-${c.endPeriod}, ${c.room}',
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
              onPressed: _saving ? null : _save,
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
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: EHadirTheme.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.5));
}

class _PeriodDropdown extends StatelessWidget {
  final int value;
  final int min;
  final ValueChanged<int> onChanged;
  const _PeriodDropdown(
      {required this.value, required this.onChanged, this.min = 1});

  @override
  Widget build(BuildContext context) {
    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: EHadirTheme.surfaceLight,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
        border: Border.all(color: EHadirTheme.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          items: Period.all
              .where((p) => p.index >= min)
              .map((p) => DropdownMenuItem(
                    value: p.index,
                    child: Text(
                        'Slot ${p.index} — ${fmt(p.start)}-${fmt(p.end)}'),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
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
