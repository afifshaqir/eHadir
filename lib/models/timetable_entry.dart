import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Periods on the IKM timetable. 9 hourly slots from 08:00 to 17:00.
/// Period 5 (12:00-13:00) and period 7 (13:00-14:00) are usually
/// REST/BREAK and not scheduled for classes.
class Period {
  final int index;       // 1..9
  final TimeOfDay start;
  final TimeOfDay end;
  const Period(this.index, this.start, this.end);

  String label() {
    String f(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${f(start)} - ${f(end)}';
  }

  static const List<Period> all = [
    Period(1, TimeOfDay(hour: 8,  minute: 0), TimeOfDay(hour: 9,  minute: 0)),
    Period(2, TimeOfDay(hour: 9,  minute: 0), TimeOfDay(hour: 10, minute: 0)),
    Period(3, TimeOfDay(hour: 10, minute: 0), TimeOfDay(hour: 11, minute: 0)),
    Period(4, TimeOfDay(hour: 11, minute: 0), TimeOfDay(hour: 12, minute: 0)),
    Period(5, TimeOfDay(hour: 12, minute: 0), TimeOfDay(hour: 13, minute: 0)),
    Period(6, TimeOfDay(hour: 13, minute: 0), TimeOfDay(hour: 14, minute: 0)),
    Period(7, TimeOfDay(hour: 14, minute: 0), TimeOfDay(hour: 15, minute: 0)),
    Period(8, TimeOfDay(hour: 15, minute: 0), TimeOfDay(hour: 16, minute: 0)),
    Period(9, TimeOfDay(hour: 16, minute: 0), TimeOfDay(hour: 17, minute: 0)),
  ];

  static Period byIndex(int i) => all.firstWhere((p) => p.index == i, orElse: () => all.first);
}

/// Day of the academic week. Friday is half-day (RISE / co-curricular).
enum SchoolDay { mon, tue, wed, thu, fri }

extension SchoolDayX on SchoolDay {
  String get short {
    switch (this) {
      case SchoolDay.mon: return 'Mo';
      case SchoolDay.tue: return 'Tu';
      case SchoolDay.wed: return 'We';
      case SchoolDay.thu: return 'Th';
      case SchoolDay.fri: return 'Fr';
    }
  }

  String get long {
    switch (this) {
      case SchoolDay.mon: return 'Isnin';
      case SchoolDay.tue: return 'Selasa';
      case SchoolDay.wed: return 'Rabu';
      case SchoolDay.thu: return 'Khamis';
      case SchoolDay.fri: return 'Jumaat';
    }
  }

  int get weekday { // matches Dart DateTime.weekday (1=Mon)
    switch (this) {
      case SchoolDay.mon: return 1;
      case SchoolDay.tue: return 2;
      case SchoolDay.wed: return 3;
      case SchoolDay.thu: return 4;
      case SchoolDay.fri: return 5;
    }
  }

  static SchoolDay fromInt(int i) =>
      SchoolDay.values[(i - 1).clamp(0, SchoolDay.values.length - 1)];
}

/// A single placed entry on the weekly timetable produced by Ketua Jabatan.
///
/// Stores the *specific date* + start/end TimeOfDay (so KJ can schedule
/// real one-off sessions like "Monday 15 Jun 2026, 08:00–10:00"). The
/// recurring weekly grid (Mon–Fri × periods 1–9) is derived from those
/// fields on demand via [day], [startPeriod], [endPeriod].
class TimetableEntry {
  final String id;
  final String assignmentId;
  final String subjectCode;
  final String subjectName;
  final String lecturerId;
  final String lecturerName;
  final String program;
  final String studentClass;
  final String room;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String assignedBy;
  final DateTime? createdAt;

  const TimetableEntry({
    required this.id,
    required this.assignmentId,
    required this.subjectCode,
    required this.subjectName,
    required this.lecturerId,
    required this.lecturerName,
    required this.program,
    required this.studentClass,
    required this.room,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.assignedBy,
    this.createdAt,
  });

  /// Derived: day-of-week for the weekly grid.
  SchoolDay get day => SchoolDayX.fromInt(date.weekday);

  /// Derived: which period (1..9) does [startTime] fall in.
  /// Period N covers `[N+7 : 00 .. N+8 : 00)`. Times before 08:00 clamp
  /// to period 1; times at/after 17:00 clamp to period 9.
  int get startPeriod => _periodFor(startTime);
  int get endPeriod {
    // Map the END of the slot back to the *last* covered period.
    final endMin = endTime.hour * 60 + endTime.minute;
    if (endMin <= 480) return 1;        // 08:00
    if (endMin >= 17 * 60) return 9;    // 17:00
    // 09:00 → period 1 (ends at 09:00), 10:00 → period 2, etc.
    final p = ((endMin - 480 - 1) ~/ 60) + 1;
    return p.clamp(1, 9);
  }

  bool covers(int period) => period >= startPeriod && period <= endPeriod;
  int get spanPeriods => endPeriod - startPeriod + 1;

  int get startMinutes => startTime.hour * 60 + startTime.minute;
  int get endMinutes => endTime.hour * 60 + endTime.minute;

  static int _periodFor(TimeOfDay t) {
    final m = t.hour * 60 + t.minute;
    if (m < 480) return 1;
    if (m >= 17 * 60) return 9;
    return ((m - 480) ~/ 60) + 1;
  }

  factory TimetableEntry.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    // Backwards-compat: read legacy `day` + period fields if present.
    final dateField = d['date'];
    final DateTime date = dateField is Timestamp
        ? dateField.toDate()
        : DateTime.now();
    final startMin = ((d['startMinutes'] as num?) ??
            (((d['startPeriod'] as num?) ?? 1).toInt() * 60 + 7 * 60))
        .toInt();
    final endMin = ((d['endMinutes'] as num?) ??
            (((d['endPeriod'] as num?) ?? 1).toInt() * 60 + 8 * 60))
        .toInt();
    return TimetableEntry(
      id: doc.id,
      assignmentId: d['assignmentId'] ?? '',
      subjectCode: d['subjectCode'] ?? '',
      subjectName: d['subjectName'] ?? '',
      lecturerId: d['lecturerId'] ?? '',
      lecturerName: d['lecturerName'] ?? '',
      program: d['program'] ?? '',
      studentClass: d['studentClass'] ?? '',
      room: d['room'] ?? '',
      date: date,
      startTime: TimeOfDay(hour: startMin ~/ 60, minute: startMin % 60),
      endTime: TimeOfDay(hour: endMin ~/ 60, minute: endMin % 60),
      assignedBy: d['assignedBy'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'assignmentId': assignmentId,
        'subjectCode': subjectCode,
        'subjectName': subjectName,
        'lecturerId': lecturerId,
        'lecturerName': lecturerName,
        'program': program,
        'studentClass': studentClass,
        'room': room,
        // Normalise to midnight so date-equality queries work.
        'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        // Derived helpers for legacy readers / dashboards.
        'day': day.weekday,
        'startPeriod': startPeriod,
        'endPeriod': endPeriod,
        'assignedBy': assignedBy,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };
}
