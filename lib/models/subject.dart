import 'package:cloud_firestore/cloud_firestore.dart';

/// A course/subject in the IKM catalog (e.g. DED10044 — ELECTRICAL INSTALLATION).
///
/// Each subject belongs to one [program] (e.g. "DED — Diploma Teknologi
/// Kejuruteraan Elektrik (Domestik Industri)") and optionally tags the
/// targeted student class label (e.g. "DED 1A").
class Subject {
  final String code;         // e.g. DED10044
  final String name;         // e.g. ELECTRICAL INSTALLATION
  final String program;      // e.g. DED — Diploma …
  final String studentClass; // e.g. DED 1A

  const Subject({
    required this.code,
    required this.name,
    required this.program,
    this.studentClass = '',
  });

  String get displayName => '$code — $name';

  factory Subject.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Subject(
      code: doc.id,
      name: d['name'] ?? '',
      program: d['program'] ?? '',
      studentClass: d['studentClass'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'program': program,
        'studentClass': studentClass,
      };
}
