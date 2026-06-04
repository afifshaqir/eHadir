import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/lecturer_assignment.dart';
import '../../models/subject.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/curriculum_service.dart';
import '../../services/mock_db_service.dart';
import '../../services/seed_data.dart';
import '../../theme.dart';

/// Ketua Program: list lecturers in the KP's program, pick subjects from
/// the program catalog to assign each lecturer, then save to Firestore.
class TugaskanSubjekScreen extends ConsumerStatefulWidget {
  const TugaskanSubjekScreen({super.key});

  @override
  ConsumerState<TugaskanSubjekScreen> createState() =>
      _TugaskanSubjekScreenState();
}

class _TugaskanSubjekScreenState extends ConsumerState<TugaskanSubjekScreen> {
  bool _seeding = true;

  @override
  void initState() {
    super.initState();
    _ensureSeed();
  }

  Future<void> _ensureSeed() async {
    final curriculum = ref.read(curriculumServiceProvider);
    final auth = ref.read(authProvider);
    final db = ref.read(mockDbProvider);

    // Push DED subject catalog into Firestore on first run so the dropdown
    // has data even before any subject was uploaded.
    await curriculum.seedSubjectsIfEmpty(SeedData.dedSubjects);

    // Merge real registered users (Firestore) into the local list so the
    // assignment binds to a real Firebase UID whenever possible.
    try {
      final firestoreUsers = await auth.fetchAllUsers();
      db.mergeFirestoreUsers(firestoreUsers);
    } catch (_) {
      // offline or unauthenticated — keep mock seed only
    }

    if (mounted) setState(() => _seeding = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).currentUser!;
    final db = ref.watch(mockDbProvider);

    // Only lecturers in the same program as the Ketua Program
    final lecturers = db.users
        .where((u) =>
            u.role == UserRole.pensyarah && u.program == user.program)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tugaskan Subjek'),
      ),
      body: _seeding
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _ProgramHeader(program: user.program, lecturerCount: lecturers.length),
                if (lecturers.isEmpty)
                  const Expanded(child: _EmptyLecturerHint())
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: lecturers.length,
                      itemBuilder: (ctx, i) => _LecturerCard(
                        lecturer: lecturers[i],
                        kp: user,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PROGRAM HEADER
// ═══════════════════════════════════════════════════════════════

class _ProgramHeader extends StatelessWidget {
  final String program;
  final int lecturerCount;
  const _ProgramHeader({required this.program, required this.lecturerCount});

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
          const Text('PROGRAM',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text(program,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.people_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text('$lecturerCount pensyarah',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  LECTURER CARD — shows existing assignments + add-button
// ═══════════════════════════════════════════════════════════════

class _LecturerCard extends ConsumerWidget {
  final AppUser lecturer;
  final AppUser kp;
  const _LecturerCard({required this.lecturer, required this.kp});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculum = ref.read(curriculumServiceProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: EHadirTheme.card,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
        border: Border.all(color: EHadirTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: EHadirTheme.primary.withValues(alpha: 0.15),
                  child: Text(
                    lecturer.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        color: EHadirTheme.primary, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lecturer.name,
                          style: const TextStyle(
                              color: EHadirTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      Text(lecturer.email,
                          style: const TextStyle(
                              color: EHadirTheme.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      color: EHadirTheme.primary),
                  tooltip: 'Tambah subjek',
                  onPressed: () => _openAssignSheet(context, ref),
                ),
              ],
            ),
          ),
          StreamBuilder<List<LecturerAssignment>>(
            stream: curriculum.streamAssignmentsForLecturer(lecturer.id),
            builder: (ctx, snap) {
              final items = snap.data ?? const <LecturerAssignment>[];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Text('Tiada subjek ditugaskan.',
                      style: TextStyle(
                          color: EHadirTheme.textSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic)),
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: items
                      .map((a) => _AssignmentChip(
                            assignment: a,
                            onDelete: () =>
                                curriculum.deleteAssignment(a.id),
                          ))
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openAssignSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignSheet(lecturer: lecturer, kp: kp),
    );
  }
}

class _AssignmentChip extends StatelessWidget {
  final LecturerAssignment assignment;
  final VoidCallback onDelete;
  const _AssignmentChip({required this.assignment, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: EHadirTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EHadirTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(assignment.subjectCode,
                  style: const TextStyle(
                      color: EHadirTheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11)),
              Text(assignment.studentClass,
                  style: const TextStyle(
                      color: EHadirTheme.textSecondary, fontSize: 10)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 14),
            color: EHadirTheme.rejected,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
            onPressed: onDelete,
            tooltip: 'Buang',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ASSIGN BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════

class _AssignSheet extends ConsumerStatefulWidget {
  final AppUser lecturer;
  final AppUser kp;
  const _AssignSheet({required this.lecturer, required this.kp});

  @override
  ConsumerState<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends ConsumerState<_AssignSheet> {
  final Set<String> _selectedCodes = {};

  @override
  Widget build(BuildContext context) {
    final curriculum = ref.read(curriculumServiceProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (ctx, controller) => Container(
        decoration: const BoxDecoration(
          color: EHadirTheme.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: EHadirTheme.divider,
                      borderRadius: BorderRadius.circular(2))),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pilih subjek untuk ${widget.lecturer.name}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: EHadirTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(widget.kp.program,
                      style: const TextStyle(
                          color: EHadirTheme.textSecondary, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Subject>>(
                stream: curriculum.streamSubjectsForProgram(widget.kp.program),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final subjects = snap.data ?? const <Subject>[];
                  if (subjects.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Tiada subjek dalam katalog. '
                          'Sila tambah subjek baru atau hubungi pentadbir.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: EHadirTheme.textSecondary),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: controller,
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    itemCount: subjects.length,
                    itemBuilder: (ctx, i) {
                      final s = subjects[i];
                      final selected = _selectedCodes.contains(s.code);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selectedCodes.add(s.code);
                          } else {
                            _selectedCodes.remove(s.code);
                          }
                        }),
                        title: Text(s.code,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                style: const TextStyle(
                                    color: EHadirTheme.textSecondary,
                                    fontSize: 12)),
                            if (s.studentClass.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: EHadirTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(s.studentClass,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: EHadirTheme.textSecondary)),
                                ),
                              ),
                          ],
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        dense: true,
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Row(
                  children: [
                    Text('${_selectedCodes.length} dipilih',
                        style: const TextStyle(
                            color: EHadirTheme.textSecondary,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _selectedCodes.isEmpty
                          ? null
                          : () => _save(curriculum),
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Simpan'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(CurriculumService curriculum) async {
    // Look up the chosen subjects from a one-off fetch.
    final subjects = await curriculum.getSubjectsForPrograms([widget.kp.program]);
    final chosen = subjects.where((s) => _selectedCodes.contains(s.code));

    for (final s in chosen) {
      final a = LecturerAssignment(
        id: '',
        lecturerId: widget.lecturer.id,
        lecturerName: widget.lecturer.name,
        subjectCode: s.code,
        subjectName: s.name,
        program: widget.kp.program,
        studentClass: s.studentClass,
        assignedBy: widget.kp.id,
      );
      await curriculum.upsertAssignment(a);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${chosen.length} subjek ditugaskan kepada ${widget.lecturer.name}.'),
          backgroundColor: EHadirTheme.approved,
        ),
      );
    }
  }
}

class _EmptyLecturerHint extends StatelessWidget {
  const _EmptyLecturerHint();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline_rounded,
                  size: 64,
                  color: EHadirTheme.textSecondary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              const Text(
                'Tiada pensyarah dalam program ini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: EHadirTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
}
