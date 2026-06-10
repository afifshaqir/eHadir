import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/attendance_record.dart';
import '../models/notification.dart';
import '../models/user.dart';
import 'mock_db_service.dart';

/// Watches per-student absent percentages and dispatches escalating
/// in-memory notifications (5% / 10% / 20%).
///
/// Routing — from project-detail/Extra_input.md:
///   tier 1 (≥5%)  → lecturer + Ketua Jabatan
///   tier 2 (≥10%) → lecturer + Ketua Program + Ketua Jabatan
///   tier 3 (≥20%) → lecturer + Ketua Program + Ketua Jabatan + TPA
///
/// Idempotent: only fires when the tier *increases* for a given
/// (student × subject × class) triple, so opening the screen a second
/// time doesn't re-spam the same warning.
class AbsenteeismWarningService {
  AbsenteeismWarningService(this._db);

  final MockDatabaseService _db;
  final _uuid = const Uuid();

  /// `studentId|subjectCode|class` → highest tier already fired (1, 2, or 3).
  final Map<String, int> _lastTier = {};

  /// Returns the absent-rate tier for [absentPct]:
  ///   0  → safe (<5%)
  ///   1  → first warning (5–9.99%)
  ///   2  → second warning (10–19.99%)
  ///   3  → third warning (≥20%)
  static int tierFor(double absentPct) {
    if (absentPct >= 20) return 3;
    if (absentPct >= 10) return 2;
    if (absentPct >= 5) return 1;
    return 0;
  }

  /// Scan the class matrix once and emit notifications for any students
  /// whose tier escalated since the last check.
  void check({
    required ClassAttendance attendance,
    required Map<String, String> studentNames,
  }) {
    attendance.weeks.forEach((sid, list) {
      final taken = list.where((e) => e.isNotEmpty).length;
      if (taken == 0) return;
      final absent = list.where((e) => e == 'T').length;
      final absentPct = (absent / taken) * 100;
      final tier = tierFor(absentPct);
      if (tier == 0) return;

      final key = '$sid|${attendance.subjectCode}|${attendance.studentClass}';
      final prev = _lastTier[key] ?? 0;
      if (tier <= prev) return;
      _lastTier[key] = tier;

      _dispatch(
        tier: tier,
        absentPct: absentPct,
        studentName: studentNames[sid] ?? sid,
        attendance: attendance,
      );
    });
  }

  /// Resets the tier cache for one class — useful when a lecturer manually
  /// clears the grid or starts a fresh semester.
  void resetForClass({
    required String subjectCode,
    required String studentClass,
  }) {
    _lastTier.removeWhere(
        (k, _) => k.endsWith('|$subjectCode|$studentClass'));
  }

  // ──────────────────────────────────────────────────────────

  void _dispatch({
    required int tier,
    required double absentPct,
    required String studentName,
    required ClassAttendance attendance,
  }) {
    final recipients = _recipientsFor(tier, attendance);
    if (recipients.isEmpty) {
      debugPrint('AbsenteeismWarning: tier $tier had no recipients '
          'for ${attendance.subjectCode}/${attendance.studentClass}');
      return;
    }
    final type = switch (tier) {
      1 => NotificationType.absenteeismWarning5,
      2 => NotificationType.absenteeismWarning10,
      _ => NotificationType.absenteeismWarning20,
    };
    final title = switch (tier) {
      1 => 'Amaran Kehadiran 5%',
      2 => 'Amaran Kehadiran 10%',
      _ => 'Amaran Kehadiran 20%',
    };
    final body = '$studentName telah mencapai '
        '${absentPct.toStringAsFixed(0)}% ketidakhadiran dalam '
        '${attendance.subjectName} (${attendance.studentClass}).';

    for (final r in recipients) {
      _db.addNotification(AppNotification(
        id: _uuid.v4(),
        recipientId: r.id,
        title: title,
        message: body,
        type: type,
        createdAt: DateTime.now(),
      ));
    }
  }

  List<AppUser> _recipientsFor(int tier, ClassAttendance attendance) {
    final out = <AppUser>[];

    // Tier 1 — lecturer + Ketua Jabatan
    final lecturer = _db.getUserById(attendance.lecturerId);
    if (lecturer != null) out.add(lecturer);
    out.addAll(_db.users.where((u) =>
        u.role == UserRole.ketuaJabatan && u.program == attendance.program));

    if (tier >= 2) {
      out.addAll(_db.users.where((u) =>
          u.role == UserRole.ketuaProgram &&
          u.program == attendance.program));
    }
    if (tier >= 3) {
      out.addAll(_db.users
          .where((u) => u.role == UserRole.timbalanPengarahAkademik));
    }
    // Deduplicate (lecturer can also be Ketua Jabatan in seed data, etc.)
    final seen = <String>{};
    return out.where((u) => seen.add(u.id)).toList();
  }
}

final absenteeismWarningServiceProvider =
    Provider<AbsenteeismWarningService>((ref) {
  final db = ref.watch(mockDbProvider);
  return AbsenteeismWarningService(db);
});
