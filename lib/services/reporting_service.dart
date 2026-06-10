import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance_record.dart';
import '../models/discipline_report_model.dart';
import 'attendance_service.dart';

/// Aggregation layer for Module 3 — Reporting Module.
///
/// All queries are role-scoped by the caller (Pensyarah / Ketua Program /
/// Ketua Jabatan / TPA). Discipline reports stay in memory via
/// [MockDatabaseService]; only attendance is pulled from Firestore.
class ReportingService {
  ReportingService(this._attendance);

  final AttendanceService _attendance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _classCol = 'classAttendance';

  /// Threshold (in %) below which a student is flagged "at risk".
  /// Mirrors Dr. Osman's brief — see project-detail/Extra_input.md.
  static const double atRiskThreshold = 80;

  // ═══════════════════════════════════════════════════════════
  //  CLASS-LEVEL (Pensyarah view)
  // ═══════════════════════════════════════════════════════════

  /// Live M1..M14 percentage trend for one (subject, class) pair.
  /// Returns map of weekIndex(0..13) → present% for that week.
  Stream<List<double>> classWeeklyTrend({
    required String subjectCode,
    required String studentClass,
  }) {
    return _attendance
        .streamClassAttendance(
          subjectCode: subjectCode,
          studentClass: studentClass,
        )
        .map(_trendFromClass);
  }

  List<double> _trendFromClass(ClassAttendance? c) {
    final out = List<double>.filled(ClassAttendance.weeksPerSemester, 0);
    if (c == null) return out;
    for (int w = 0; w < ClassAttendance.weeksPerSemester; w++) {
      int taken = 0;
      int present = 0;
      c.weeks.forEach((_, list) {
        if (w >= list.length) return;
        final code = list[w];
        if (code.isEmpty) return;
        taken++;
        if (code == 'H') present++;
      });
      out[w] = taken == 0 ? 0 : (present / taken) * 100;
    }
    return out;
  }

  /// At-risk students for one class (< [atRiskThreshold] %).
  Stream<List<AtRiskStudent>> classAtRiskStudents({
    required String subjectCode,
    required String studentClass,
    required Map<String, String> studentNames, // sid → name
  }) {
    return _attendance
        .streamClassAttendance(
          subjectCode: subjectCode,
          studentClass: studentClass,
        )
        .map((c) {
      if (c == null) return const <AtRiskStudent>[];
      final out = <AtRiskStudent>[];
      c.weeks.forEach((sid, list) {
        if (list.every((e) => e.isEmpty)) return;
        final pct = c.percentageFor(sid);
        if (pct >= atRiskThreshold) return;
        final absent = list.where((e) => e == 'T').length;
        out.add(AtRiskStudent(
          studentId: sid,
          studentName: studentNames[sid] ?? sid,
          subjectName: c.subjectName,
          studentClass: c.studentClass,
          percentage: pct,
          absentCount: absent,
        ));
      });
      out.sort((a, b) => a.percentage.compareTo(b.percentage));
      return out;
    });
  }

  // ═══════════════════════════════════════════════════════════
  //  PROGRAM-LEVEL (Ketua Program view)
  // ═══════════════════════════════════════════════════════════

  /// All recorded sessions for a program. Stream-based so the dashboard
  /// recomputes whenever a lecturer marks a cell.
  Stream<List<AttendanceSession>> programSessions(String program) {
    return _attendance.streamSessionsForProgram(program);
  }

  /// Per-class average present % for the program. Reads `classAttendance`
  /// documents and groups by `studentClass`.
  Stream<Map<String, double>> programPercentageByClass(String program) {
    return _db
        .collection(_classCol)
        .where('program', isEqualTo: program)
        .snapshots()
        .map((snap) {
      final byClass = <String, List<double>>{};
      for (final doc in snap.docs) {
        final c = ClassAttendance.fromFirestore(doc);
        if (c.weeks.isEmpty) continue;
        final pcts = c.weeks.keys
            .map((sid) => c.percentageFor(sid))
            .where((p) => p > 0)
            .toList();
        if (pcts.isEmpty) continue;
        final avg = pcts.reduce((a, b) => a + b) / pcts.length;
        byClass.putIfAbsent(c.studentClass, () => []).add(avg);
      }
      return {
        for (final entry in byClass.entries)
          entry.key:
              entry.value.reduce((a, b) => a + b) / entry.value.length,
      };
    });
  }

  /// Per-lecturer average present % for the program (Ketua Jabatan view).
  Stream<Map<String, LecturerPerformance>> programPercentageByLecturer(
      String program) {
    return _db
        .collection(_classCol)
        .where('program', isEqualTo: program)
        .snapshots()
        .map((snap) {
      final byLec = <String, _LecturerAcc>{};
      for (final doc in snap.docs) {
        final c = ClassAttendance.fromFirestore(doc);
        if (c.weeks.isEmpty) continue;
        final pcts = c.weeks.keys
            .map((sid) => c.percentageFor(sid))
            .where((p) => p > 0)
            .toList();
        if (pcts.isEmpty) continue;
        final avg = pcts.reduce((a, b) => a + b) / pcts.length;
        final acc = byLec.putIfAbsent(
            c.lecturerId, () => _LecturerAcc(c.lecturerName));
        acc.add(avg);
      }
      return {
        for (final e in byLec.entries)
          e.key: LecturerPerformance(
              name: e.value.name, average: e.value.average),
      };
    });
  }

  /// Program-wide M1..M14 trend (averaged across every class).
  Stream<List<double>> programWeeklyTrend(String program) {
    return _db
        .collection(_classCol)
        .where('program', isEqualTo: program)
        .snapshots()
        .map((snap) {
      final perWeek =
          List<List<double>>.generate(ClassAttendance.weeksPerSemester, (_) => []);
      for (final doc in snap.docs) {
        final c = ClassAttendance.fromFirestore(doc);
        final trend = _trendFromClass(c);
        for (int w = 0; w < trend.length; w++) {
          if (trend[w] > 0) perWeek[w].add(trend[w]);
        }
      }
      return List<double>.generate(
        ClassAttendance.weeksPerSemester,
        (w) => perWeek[w].isEmpty
            ? 0
            : perWeek[w].reduce((a, b) => a + b) / perWeek[w].length,
      );
    });
  }

  /// At-risk students for an entire program. Requires a name lookup keyed
  /// by student id.
  Stream<List<AtRiskStudent>> programAtRiskStudents({
    required String program,
    required Map<String, String> studentNames,
  }) {
    return _db
        .collection(_classCol)
        .where('program', isEqualTo: program)
        .snapshots()
        .map((snap) {
      final out = <AtRiskStudent>[];
      for (final doc in snap.docs) {
        final c = ClassAttendance.fromFirestore(doc);
        c.weeks.forEach((sid, list) {
          if (list.every((e) => e.isEmpty)) return;
          final pct = c.percentageFor(sid);
          if (pct >= atRiskThreshold) return;
          out.add(AtRiskStudent(
            studentId: sid,
            studentName: studentNames[sid] ?? sid,
            subjectName: c.subjectName,
            studentClass: c.studentClass,
            percentage: pct,
            absentCount: list.where((e) => e == 'T').length,
          ));
        });
      }
      out.sort((a, b) => a.percentage.compareTo(b.percentage));
      return out;
    });
  }

  // ═══════════════════════════════════════════════════════════
  //  CROSS-PROGRAM (TPA view)
  // ═══════════════════════════════════════════════════════════

  /// Average present % per program — used for the TPA stacked bar.
  Stream<Map<String, double>> percentageByProgram() {
    return _db.collection(_classCol).snapshots().map((snap) {
      final byProg = <String, List<double>>{};
      for (final doc in snap.docs) {
        final c = ClassAttendance.fromFirestore(doc);
        if (c.weeks.isEmpty || c.program.isEmpty) continue;
        final pcts = c.weeks.keys
            .map((sid) => c.percentageFor(sid))
            .where((p) => p > 0)
            .toList();
        if (pcts.isEmpty) continue;
        final avg = pcts.reduce((a, b) => a + b) / pcts.length;
        byProg.putIfAbsent(c.program, () => []).add(avg);
      }
      return {
        for (final e in byProg.entries)
          e.key: e.value.reduce((a, b) => a + b) / e.value.length,
      };
    });
  }

  // ═══════════════════════════════════════════════════════════
  //  DISCIPLINE BREAKDOWN (in-memory)
  // ═══════════════════════════════════════════════════════════

  /// Count of reports per severity tier for a given collection.
  Map<SeverityLevel, int> severityBreakdown(
      Iterable<DisciplineReportModel> reports) {
    final out = {
      SeverityLevel.ringan: 0,
      SeverityLevel.sederhana: 0,
      SeverityLevel.serius: 0,
    };
    for (final r in reports) {
      out[r.severityLevel] = (out[r.severityLevel] ?? 0) + 1;
    }
    return out;
  }
}

// ──────────────────────────────────────────────────────────────
//  Value objects
// ──────────────────────────────────────────────────────────────

class AtRiskStudent {
  final String studentId;
  final String studentName;
  final String subjectName;
  final String studentClass;
  final double percentage;
  final int absentCount;

  const AtRiskStudent({
    required this.studentId,
    required this.studentName,
    required this.subjectName,
    required this.studentClass,
    required this.percentage,
    required this.absentCount,
  });
}

class LecturerPerformance {
  final String name;
  final double average;
  const LecturerPerformance({required this.name, required this.average});
}

class _LecturerAcc {
  final String name;
  final List<double> _values = [];
  _LecturerAcc(this.name);
  void add(double v) => _values.add(v);
  double get average =>
      _values.isEmpty ? 0 : _values.reduce((a, b) => a + b) / _values.length;
}

final reportingServiceProvider = Provider<ReportingService>((ref) {
  final attendance = ref.watch(attendanceServiceProvider);
  return ReportingService(attendance);
});
