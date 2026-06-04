import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/department.dart';
import '../models/lecturer_assignment.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';

/// Firestore-backed service for the academic curriculum data layer:
///  • `subjects/{code}`              — master subject catalog (per program)
///  • `lecturerAssignments/{id}`     — Ketua Program's lecturer↔subject pairings
///  • `timetableEntries/{id}`        — Ketua Jabatan's weekly schedule
class CurriculumService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _subjectsCol     = 'subjects';
  static const String _assignmentsCol  = 'lecturerAssignments';
  static const String _timetableCol    = 'timetableEntries';

  // ─── Subjects (catalog) ─────────────────────────────────────

  Stream<List<Subject>> streamSubjectsForProgram(String program) {
    return _db
        .collection(_subjectsCol)
        .where('program', isEqualTo: program)
        .snapshots()
        .map((s) => s.docs.map(Subject.fromFirestore).toList()
          ..sort((a, b) => a.code.compareTo(b.code)));
  }

  Future<List<Subject>> getSubjectsForPrograms(List<String> programs) async {
    if (programs.isEmpty) return const [];
    // Firestore `whereIn` caps at 30 items — diploma deps stay under that.
    final snap = await _db
        .collection(_subjectsCol)
        .where('program', whereIn: programs)
        .get();
    return snap.docs.map(Subject.fromFirestore).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }

  Future<void> upsertSubject(Subject s) async {
    await _db.collection(_subjectsCol).doc(s.code).set(s.toFirestore());
    notifyListeners();
  }

  /// Bulk-load seed subjects if the collection is empty. Safe to call on boot.
  Future<void> seedSubjectsIfEmpty(Iterable<Subject> seed) async {
    final snap = await _db.collection(_subjectsCol).limit(1).get();
    if (snap.docs.isNotEmpty) return;
    final batch = _db.batch();
    for (final s in seed) {
      batch.set(_db.collection(_subjectsCol).doc(s.code), s.toFirestore());
    }
    await batch.commit();
  }

  /// Bulk-load seed lecturer assignments if the collection is empty.
  /// Uses each assignment's [id] field as the document id so re-seeding
  /// is idempotent (won't duplicate).
  Future<void> seedAssignmentsIfEmpty(Iterable<LecturerAssignment> seed) async {
    final snap = await _db.collection(_assignmentsCol).limit(1).get();
    if (snap.docs.isNotEmpty) return;
    final batch = _db.batch();
    for (final a in seed) {
      batch.set(_db.collection(_assignmentsCol).doc(a.id), a.toFirestore());
    }
    await batch.commit();
  }

  // ─── Lecturer ↔ Subject assignments (Ketua Program) ────────

  Stream<List<LecturerAssignment>> streamAssignmentsForProgram(String program) {
    return _db
        .collection(_assignmentsCol)
        .where('program', isEqualTo: program)
        .snapshots()
        .map((s) => s.docs.map(LecturerAssignment.fromFirestore).toList());
  }

  Stream<List<LecturerAssignment>> streamAssignmentsForLecturer(String lecturerId) {
    return _db
        .collection(_assignmentsCol)
        .where('lecturerId', isEqualTo: lecturerId)
        .snapshots()
        .map((s) => s.docs.map(LecturerAssignment.fromFirestore).toList());
  }

  /// All assignments for every program in a department (Ketua Jabatan view).
  Stream<List<LecturerAssignment>> streamAssignmentsForDepartment(String department) {
    final programKeys = Department.programsOf[department] ?? const [];
    if (programKeys.isEmpty) {
      return Stream.value(const []);
    }
    return _db
        .collection(_assignmentsCol)
        .snapshots()
        .map((s) => s.docs
            .map(LecturerAssignment.fromFirestore)
            .where((a) => programKeys.contains(Department.programKeyOf(a.program)))
            .toList());
  }

  Future<String> upsertAssignment(LecturerAssignment a) async {
    if (a.id.isNotEmpty) {
      await _db.collection(_assignmentsCol).doc(a.id).set(a.toFirestore());
      notifyListeners();
      return a.id;
    } else {
      final doc = await _db.collection(_assignmentsCol).add(a.toFirestore());
      notifyListeners();
      return doc.id;
    }
  }

  Future<void> deleteAssignment(String id) async {
    await _db.collection(_assignmentsCol).doc(id).delete();
    // Also cascade-delete any timetable entries pointing to it.
    final children = await _db
        .collection(_timetableCol)
        .where('assignmentId', isEqualTo: id)
        .get();
    final batch = _db.batch();
    for (final c in children.docs) {
      batch.delete(c.reference);
    }
    await batch.commit();
    notifyListeners();
  }

  // ─── Timetable entries (Ketua Jabatan) ──────────────────────

  Stream<List<TimetableEntry>> streamEntriesForLecturer(String lecturerId) {
    return _db
        .collection(_timetableCol)
        .where('lecturerId', isEqualTo: lecturerId)
        .snapshots()
        .map((s) => s.docs.map(TimetableEntry.fromFirestore).toList());
  }

  Stream<List<TimetableEntry>> streamEntriesForClass(String studentClass) {
    return _db
        .collection(_timetableCol)
        .where('studentClass', isEqualTo: studentClass)
        .snapshots()
        .map((s) => s.docs.map(TimetableEntry.fromFirestore).toList());
  }

  Stream<List<TimetableEntry>> streamEntriesForDepartment(String department) {
    final programKeys = Department.programsOf[department] ?? const [];
    if (programKeys.isEmpty) return Stream.value(const []);
    return _db
        .collection(_timetableCol)
        .snapshots()
        .map((s) => s.docs
            .map(TimetableEntry.fromFirestore)
            .where((e) => programKeys.contains(Department.programKeyOf(e.program)))
            .toList());
  }

  Future<String> upsertEntry(TimetableEntry e) async {
    if (e.id.isNotEmpty) {
      await _db.collection(_timetableCol).doc(e.id).set(e.toFirestore());
      notifyListeners();
      return e.id;
    } else {
      final doc = await _db.collection(_timetableCol).add(e.toFirestore());
      notifyListeners();
      return doc.id;
    }
  }

  Future<void> deleteEntry(String id) async {
    await _db.collection(_timetableCol).doc(id).delete();
    notifyListeners();
  }

  /// Conflict check: would scheduling [candidate] clash with another entry
  /// for the same lecturer, same room, or same student class?
  /// Pass [existing] entries fetched from the relevant streams.
  static List<TimetableEntry> findConflicts({
    required TimetableEntry candidate,
    required Iterable<TimetableEntry> existing,
  }) {
    bool overlaps(TimetableEntry a, TimetableEntry b) {
      if (a.day != b.day) return false;
      return a.startPeriod <= b.endPeriod && b.startPeriod <= a.endPeriod;
    }

    return existing.where((e) {
      if (e.id == candidate.id) return false;
      if (!overlaps(e, candidate)) return false;
      return e.lecturerId == candidate.lecturerId ||
          e.room.toLowerCase() == candidate.room.toLowerCase() ||
          e.studentClass.toLowerCase() == candidate.studentClass.toLowerCase();
    }).toList();
  }
}

final curriculumServiceProvider =
    ChangeNotifierProvider<CurriculumService>((ref) => CurriculumService());
