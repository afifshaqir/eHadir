import '../models/lecturer_assignment.dart';
import '../models/subject.dart';
import '../models/user.dart';

/// Static seed data extracted from
///   "SENARAI NAMA PENSYARAH & KURSUS YANG DIAJAR SESI JAN JUN 2026.xlsx"
/// limited to the DED (Diploma Teknologi Kejuruteraan Elektrik —
/// Domestik Industri) program plus supporting math/Islamic-studies
/// lecturers who teach DED classes.
class SeedData {
  static const String dedProgram =
      'DED — Diploma Teknologi Kejuruteraan Elektrik (Domestik Industri)';
  static const String dcbProgram =
      'DCB — Diploma Lanjutan Kompetensi Elektrik (Penjanaan)';
  static const String dcpProgram = 'DCP — Diploma Kompetensi Elektrik (Kuasa)';
  static const String dekProgram = 'DEK — Diploma Teknologi Pembuatan Elektronik';

  // ─── DED lecturers ────────────────────────────────────────
  static final List<AppUser> dedLecturers = [
    AppUser(id: 'lec_ded_01', name: 'Ir Ts Dr. Osman bin Abu Bakar',
        email: 'osman@ikm.edu.my', role: UserRole.pensyarah, program: dedProgram),
    AppUser(id: 'lec_ded_02', name: 'Norazhar bin Md. Anuar',
        email: 'norazhar@ikm.edu.my', role: UserRole.pensyarah, program: dedProgram),
    AppUser(id: 'lec_ded_03', name: 'Norhatini binti Ibrahim',
        email: 'norhatini@ikm.edu.my', role: UserRole.pensyarah, program: dedProgram),
    AppUser(id: 'lec_ded_04', name: 'Hisham bin Dollah',
        email: 'hisham@ikm.edu.my', role: UserRole.pensyarah, program: dedProgram),
    AppUser(id: 'lec_ded_05', name: 'Syarifah binti Abdul Rahim',
        email: 'syarifah@ikm.edu.my', role: UserRole.pensyarah, program: dedProgram),
    AppUser(id: 'lec_ded_06', name: 'Mohd Shahriman bin Abdullah Sani',
        email: 'shahriman@ikm.edu.my', role: UserRole.pensyarah, program: dedProgram),
    AppUser(id: 'lec_ded_07', name: 'Norfaizal bin Borhan',
        email: 'faizal@ikm.edu.my', role: UserRole.pensyarah, program: dedProgram),
    AppUser(id: 'lec_ded_08', name: 'Zainul Idlan bin Komar',
        email: 'zainul@ikm.edu.my', role: UserRole.pensyarah, program: dedProgram),
    // Supporting units that teach DED classes
    AppUser(id: 'lec_ded_09', name: 'Rafidah binti Jemain',
        email: 'rafidah@ikm.edu.my', role: UserRole.pensyarah, program: dedProgram),
    AppUser(id: 'lec_ded_10', name: 'Azni binti Che Ali',
        email: 'azni@ikm.edu.my', role: UserRole.pensyarah, program: dedProgram),
    AppUser(id: 'lec_ded_11', name: 'Norehan binti Shamsudin',
        email: 'norehan@ikm.edu.my', role: UserRole.pensyarah, program: dedProgram),
    AppUser(id: 'lec_ded_12', name: 'Salawati binti Hasan Basari',
        email: 'salawati@ikm.edu.my', role: UserRole.pensyarah, program: dedProgram),
  ];

  /// Default Ketua Program for DED (using existing Ts. Hairi template).
  static final AppUser dedKetuaProgram = AppUser(
    id: 'kp_ded',
    name: 'Ts. Hairi bin Abdul Rahman',
    email: 'kp.ded@ikm.edu.my',
    role: UserRole.ketuaProgram,
    program: dedProgram,
  );

  /// Ketua Jabatan Elektrik — sees DED, DCB, DCP, DEK.
  /// The `program` field stores the *department* key here.
  static final AppUser kjElektrik = AppUser(
    id: 'kj_elektrik',
    name: 'Ts. Dr. Azurin bin Shukur',
    email: 'kj.elektrik@ikm.edu.my',
    role: UserRole.ketuaJabatan,
    program: 'Jabatan Elektrik',
  );

  // ─── DED subjects (from the Excel) ────────────────────────
  static final List<Subject> dedSubjects = [
    // Year 1
    Subject(code: 'DKV10213', name: 'ENGINEERING SCIENCE',                           program: dedProgram, studentClass: 'DED 1A'),
    Subject(code: 'DED10044', name: 'ELECTRICAL INSTALLATION',                       program: dedProgram, studentClass: 'DED 1A'),
    Subject(code: 'DEV10043', name: 'ELECTRICAL CIRCUIT THEORY 1',                   program: dedProgram, studentClass: 'DED 1A'),
    Subject(code: 'DEV10052', name: 'ELECTRICAL DRAWING',                            program: dedProgram, studentClass: 'DED 1A'),
    Subject(code: 'DUM10122', name: 'ENGINEERING MATHEMATICS 1',                     program: dedProgram, studentClass: 'DED 1A'),
    Subject(code: 'DUS10062', name: 'PENGHAYATAN AKIDAH',                            program: dedProgram, studentClass: 'DED 1A'),
    Subject(code: 'DUE10000', name: 'ENGLISH COMMUNICATION',                         program: dedProgram, studentClass: 'DED 1A'),
    Subject(code: 'DUY10031', name: 'CO-CURRICULUM',                                 program: dedProgram, studentClass: 'DED 1A'),
    // Year 2
    Subject(code: 'DED21052', name: 'ELECTRICAL INDUSTRIAL INSTALLATION 1',          program: dedProgram, studentClass: 'DED 2A'),
    Subject(code: 'DED21064', name: 'ELECTRICAL INDUSTRIAL INSTALLATION PRACTICE 1', program: dedProgram, studentClass: 'DED 2A'),
    Subject(code: 'DEV20072', name: 'ELECTRICITY SUPPLY ACT AND REGULATIONS',        program: dedProgram, studentClass: 'DED 2A'),
    Subject(code: 'DEV20083', name: 'ANALOGUE ELECTRONICS FUNDAMENTAL',              program: dedProgram, studentClass: 'DED 2A'),
    Subject(code: 'DUM20132', name: 'ENGINEERING MATHEMATICS 2',                     program: dedProgram, studentClass: 'DED 2A'),
    // Year 3
    Subject(code: 'DEV31053', name: 'ELECTRICAL MACHINE',                            program: dedProgram, studentClass: 'DED 3A'),
    Subject(code: 'DED30073', name: 'INTRODUCTION TO DIGITAL ELECTRONICS',           program: dedProgram, studentClass: 'DED 3A'),
    Subject(code: 'DED31082', name: 'ELECTRICAL INDUSTRIAL INSTALLATION 2',          program: dedProgram, studentClass: 'DED 3A'),
    Subject(code: 'DED31094', name: 'ELECTRICAL INDUSTRIAL INSTALLATION PRACTICE 2', program: dedProgram, studentClass: 'DED 3A'),
    Subject(code: 'DUM30183', name: 'MATHEMATICS FOR ELECTRICAL ENGINEERING',        program: dedProgram, studentClass: 'DED 3A'),
    // Year 4
    Subject(code: 'DEV40242', name: 'ADVANCE ELECTRICAL DRAWING',                    program: dedProgram, studentClass: 'DED 4A'),
    Subject(code: 'DEV40263', name: 'INDUSTRIAL AUTOMATION',                         program: dedProgram, studentClass: 'DED 4A'),
    Subject(code: 'DEV40273', name: 'ELECTRICAL MOTOR CONTROL',                      program: dedProgram, studentClass: 'DED 4A'),
    Subject(code: 'DEV40283', name: 'POWER ELECTRONICS',                             program: dedProgram, studentClass: 'DED 4A'),
    Subject(code: 'DEV41253', name: 'ELECTRICAL CIRCUIT THEORY 2',                   program: dedProgram, studentClass: 'DED 4A'),
    // Year 6
    Subject(code: 'DKV40292', name: 'PROJECT MANAGEMENT',                            program: dedProgram, studentClass: 'DED 6A'),
    Subject(code: 'DED60114', name: 'FINAL YEAR PROJECT (1)',                        program: dedProgram, studentClass: 'DED 6A'),
    Subject(code: 'DED60144', name: 'FINAL YEAR PROJECT (2)',                        program: dedProgram, studentClass: 'DED 6A'),
    Subject(code: 'DED60133', name: 'RENEWABLE ENERGY',                              program: dedProgram, studentClass: 'DED 6A'),
    Subject(code: 'DED61124', name: 'ADVANCE ELECTRICAL INSTALLATION (A)',           program: dedProgram, studentClass: 'DED 6A'),
    Subject(code: 'DED61154', name: 'ADVANCE ELECTRICAL INSTALLATION (B)',           program: dedProgram, studentClass: 'DED 6A'),
  ];

  // ─── DED lecturer ↔ subject assignments ───────────────────
  //
  // Mirrors the Excel: every (lecturer, subject, class) triple becomes one
  // LecturerAssignment seed. lecturerId here uses the mock IDs from
  // [dedLecturers] above so the seeded users line up.
  static final List<LecturerAssignment> dedAssignments = [
    // Ir Ts Dr. Osman bin Abu Bakar
    _assign('lec_ded_01', 'Ir Ts Dr. Osman bin Abu Bakar', 'DEV31053', 'ELECTRICAL MACHINE', 'DED 3A'),
    _assign('lec_ded_01', 'Ir Ts Dr. Osman bin Abu Bakar', 'DED60144', 'FINAL YEAR PROJECT (2)', 'DED 6A'),
    _assign('lec_ded_01', 'Ir Ts Dr. Osman bin Abu Bakar', 'DED60114', 'FINAL YEAR PROJECT (1)', 'DED 6A'),
    _assign('lec_ded_01', 'Ir Ts Dr. Osman bin Abu Bakar', 'DED21052', 'ELECTRICAL INDUSTRIAL INSTALLATION 1', 'DED 2A'),
    // Norazhar bin Md. Anuar
    _assign('lec_ded_02', 'Norazhar bin Md. Anuar', 'DED31082', 'ELECTRICAL INDUSTRIAL INSTALLATION 2', 'DED 3A'),
    _assign('lec_ded_02', 'Norazhar bin Md. Anuar', 'DED31094', 'ELECTRICAL INDUSTRIAL INSTALLATION PRACTICE 2', 'DED 3A'),
    // Norhatini binti Ibrahim
    _assign('lec_ded_03', 'Norhatini binti Ibrahim', 'DKV10213', 'ENGINEERING SCIENCE', 'DED 1A'),
    _assign('lec_ded_03', 'Norhatini binti Ibrahim', 'DED30073', 'INTRODUCTION TO DIGITAL ELECTRONICS', 'DED 3A'),
    _assign('lec_ded_03', 'Norhatini binti Ibrahim', 'DEV10043', 'ELECTRICAL CIRCUIT THEORY 1', 'DED 1A'),
    // Hisham bin Dollah
    _assign('lec_ded_04', 'Hisham bin Dollah', 'DEV40283', 'POWER ELECTRONICS', 'DED 4A'),
    _assign('lec_ded_04', 'Hisham bin Dollah', 'DKV40292', 'PROJECT MANAGEMENT', 'DED 6A'),
    _assign('lec_ded_04', 'Hisham bin Dollah', 'DEV20083', 'ANALOGUE ELECTRONICS FUNDAMENTAL', 'DED 2A'),
    // Syarifah binti Abdul Rahim
    _assign('lec_ded_05', 'Syarifah binti Abdul Rahim', 'DEV41253', 'ELECTRICAL CIRCUIT THEORY 2', 'DED 4A'),
    _assign('lec_ded_05', 'Syarifah binti Abdul Rahim', 'DED10044', 'ELECTRICAL INSTALLATION', 'DED 1A'),
    // Mohd Shahriman bin Abdullah Sani
    _assign('lec_ded_06', 'Mohd Shahriman bin Abdullah Sani', 'DEV40273', 'ELECTRICAL MOTOR CONTROL', 'DED 4A'),
    _assign('lec_ded_06', 'Mohd Shahriman bin Abdullah Sani', 'DED61154', 'ADVANCE ELECTRICAL INSTALLATION (B)', 'DED 6A'),
    _assign('lec_ded_06', 'Mohd Shahriman bin Abdullah Sani', 'DED61124', 'ADVANCE ELECTRICAL INSTALLATION (A)', 'DED 6A'),
    // Norfaizal bin Borhan
    _assign('lec_ded_07', 'Norfaizal bin Borhan', 'DEV10052', 'ELECTRICAL DRAWING', 'DED 1A'),
    _assign('lec_ded_07', 'Norfaizal bin Borhan', 'DEV40242', 'ADVANCE ELECTRICAL DRAWING', 'DED 4A'),
    _assign('lec_ded_07', 'Norfaizal bin Borhan', 'DEV40263', 'INDUSTRIAL AUTOMATION', 'DED 4A'),
    // Zainul Idlan bin Komar
    _assign('lec_ded_08', 'Zainul Idlan bin Komar', 'DED60133', 'RENEWABLE ENERGY', 'DED 6A'),
    _assign('lec_ded_08', 'Zainul Idlan bin Komar', 'DED21064', 'ELECTRICAL INDUSTRIAL INSTALLATION PRACTICE 1', 'DED 2A'),
    _assign('lec_ded_08', 'Zainul Idlan bin Komar', 'DEV20072', 'ELECTRICITY SUPPLY ACT AND REGULATIONS', 'DED 2A'),
    // Rafidah binti Jemain — Maths Unit
    _assign('lec_ded_09', 'Rafidah binti Jemain', 'DUM10122', 'ENGINEERING MATHEMATICS 1', 'DED 1A'),
    // Azni binti Che Ali — Islamic Studies
    _assign('lec_ded_10', 'Azni binti Che Ali', 'DUS10062', 'PENGHAYATAN AKIDAH', 'DED 1A'),
    // Norehan binti Shamsudin — Maths Unit
    _assign('lec_ded_11', 'Norehan binti Shamsudin', 'DUM20132', 'ENGINEERING MATHEMATICS 2', 'DED 2A'),
    // Salawati binti Hasan Basari — Maths Unit
    _assign('lec_ded_12', 'Salawati binti Hasan Basari', 'DUM30183', 'MATHEMATICS FOR ELECTRICAL ENGINEERING', 'DED 3A'),
  ];

  static LecturerAssignment _assign(String lecturerId, String lecturerName,
      String code, String name, String studentClass) {
    return LecturerAssignment(
      id: 'seed_${lecturerId}_$code',
      lecturerId: lecturerId,
      lecturerName: lecturerName,
      subjectCode: code,
      subjectName: name,
      program: dedProgram,
      studentClass: studentClass,
      assignedBy: dedKetuaProgram.id,
    );
  }
}

