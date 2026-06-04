import 'package:cloud_firestore/cloud_firestore.dart';

/// A Ketua Program's decision: "this lecturer will teach this subject this semester".
///
/// Created by Ketua Program in the "Tugaskan Subjek" screen. Picked up by
/// Ketua Jabatan to schedule into the weekly timetable.
class LecturerAssignment {
  final String id;
  final String lecturerId;
  final String lecturerName;
  final String subjectCode;
  final String subjectName;
  final String program;       // e.g. "DED — Diploma …"
  final String studentClass;  // e.g. "DED 1A"
  final String assignedBy;    // Ketua Program uid
  final DateTime? createdAt;

  const LecturerAssignment({
    required this.id,
    required this.lecturerId,
    required this.lecturerName,
    required this.subjectCode,
    required this.subjectName,
    required this.program,
    required this.studentClass,
    required this.assignedBy,
    this.createdAt,
  });

  factory LecturerAssignment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LecturerAssignment(
      id: doc.id,
      lecturerId: d['lecturerId'] ?? '',
      lecturerName: d['lecturerName'] ?? '',
      subjectCode: d['subjectCode'] ?? '',
      subjectName: d['subjectName'] ?? '',
      program: d['program'] ?? '',
      studentClass: d['studentClass'] ?? '',
      assignedBy: d['assignedBy'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'lecturerId': lecturerId,
        'lecturerName': lecturerName,
        'subjectCode': subjectCode,
        'subjectName': subjectName,
        'program': program,
        'studentClass': studentClass,
        'assignedBy': assignedBy,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  LecturerAssignment copyWith({String? id, DateTime? createdAt}) =>
      LecturerAssignment(
        id: id ?? this.id,
        lecturerId: lecturerId,
        lecturerName: lecturerName,
        subjectCode: subjectCode,
        subjectName: subjectName,
        program: program,
        studentClass: studentClass,
        assignedBy: assignedBy,
        createdAt: createdAt ?? this.createdAt,
      );
}
