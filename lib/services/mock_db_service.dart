import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../models/student.dart';
import '../models/student_model.dart';
import '../models/timetable.dart';
import '../models/room.dart';
import '../models/notification.dart';
import '../models/class_slot_model.dart';
import '../models/discipline_report_model.dart';
import 'seed_data.dart';

/// In-memory data service for timetables, attendance, bookings,
/// and discipline reports. Firebase Auth handles user identity;
/// this service handles all structured app data.
class MockDatabaseService extends ChangeNotifier {

  // ─── Data Tables ────────────────────────────────────────────
  List<AppUser> users = [];
  List<Room> rooms = [];
  List<Student> students = [];
  List<StudentModel> studentModels = [];
  List<Timetable> masterTimetable = [];
  List<AppNotification> notifications = [];
  List<ClassSlotModel> classSlots = [];
  List<DisciplineReportModel> disciplineReports = [];

  MockDatabaseService() {
    _seedData();
  }

  // ═══════════════════════════════════════════════════════════
  //  SEED DATA
  // ═══════════════════════════════════════════════════════════
  void _seedData() {
    _seedUsers();
    _seedRooms();
    _seedStudents();
    _seedTimetable();
  }

  void _seedUsers() {
    users.addAll([
      AppUser(id: 'u1', name: 'Ts. Choh Jing Yi', email: 'choh@graduate.utm.my',
          role: UserRole.pensyarah, program: 'DCP — Diploma Kompetensi Elektrik (Kuasa)'),
      AppUser(id: 'u2', name: 'Dr. Afif Shaqir', email: 'afif@graduate.utm.my',
          role: UserRole.pensyarah, program: 'DGS — Diploma Teknologi Kejuruteraan Gas'),
      AppUser(id: 'u3', name: 'Pn. Siti Aminah', email: 'siti@ikm.edu.my',
          role: UserRole.admin, program: 'Global'),
      AppUser(id: 'u4', name: 'En. Ahmad Razak', email: 'ahmad@ikm.edu.my',
          role: UserRole.ketuaProgram, program: 'DCP — Diploma Kompetensi Elektrik (Kuasa)'),
      AppUser(id: 'u5', name: 'Dr. Farah Nadia', email: 'farah@ikm.edu.my',
          role: UserRole.ketuaJabatan, program: 'DCP — Diploma Kompetensi Elektrik (Kuasa)'),
      AppUser(id: 'u6', name: 'Prof. Mohd Ismail', email: 'ismail@ikm.edu.my',
          role: UserRole.timbalanPengarahAkademik, program: 'Global'),
      AppUser(id: 'u7', name: 'Prof. Irfan', email: 'irfan@graduate.utm.my',
          role: UserRole.pensyarah, program: 'DGS — Diploma Teknologi Kejuruteraan Gas'),
    ]);

    // Real DED roster from the JAN-JUN 2026 senarai
    users.addAll(SeedData.dedLecturers);
    users.add(SeedData.dedKetuaProgram);
    users.add(SeedData.kjElektrik);
  }

  void _seedRooms() {
    rooms.addAll([
      Room(id: 'r1', name: 'Bengkel Kimpalan', building: 'Blok A', capacity: 30, type: RoomType.lab,
           facilities: ['Welding Sets', 'Safety Gear']),
      Room(id: 'r2', name: 'Bilik Kuliah A1', building: 'Blok A', capacity: 40, type: RoomType.lectureHall,
           facilities: ['Projector', 'Whiteboard', 'Air-Cond']),
      Room(id: 'r3', name: 'Bilik Kuliah A2', building: 'Blok A', capacity: 40, type: RoomType.lectureHall,
           facilities: ['Projector', 'Whiteboard', 'Air-Cond']),
      Room(id: 'r4', name: 'Makmal Elektrik 1', building: 'Blok B', capacity: 30, type: RoomType.lab,
           facilities: ['Testing Equipment', 'Whiteboard']),
      Room(id: 'r5', name: 'Makmal Mekanika 1', building: 'Blok B', capacity: 30, type: RoomType.lab,
           facilities: ['Heavy Machinery', 'Safety Gear']),
    ]);
  }

  void _seedStudents() {
    // Legacy Student objects (for booking module compatibility)
    students.addAll([
      Student(id: 's1', name: 'Ali bin Abu', cohort: 'DCP — Diploma Kompetensi Elektrik (Kuasa)', email: 'ali@student.ikm.edu.my'),
      Student(id: 's2', name: 'Nurul Aisyah', cohort: 'DCP — Diploma Kompetensi Elektrik (Kuasa)', email: 'nurul@student.ikm.edu.my'),
      Student(id: 's3', name: 'Tan Wei Ming', cohort: 'DGS — Diploma Teknologi Kejuruteraan Gas', email: 'tan@student.ikm.edu.my'),
      Student(id: 's4', name: 'Raj Kumar', cohort: 'DGS — Diploma Teknologi Kejuruteraan Gas', email: 'raj@student.ikm.edu.my'),
      Student(id: 's5', name: 'Fatimah Hassan', cohort: 'DCB — Diploma Lanjutan Kompetensi Elektrik (Penjanaan)', email: 'fatimah@student.ikm.edu.my'),
      Student(id: 's6', name: 'Muhammad Haziq', cohort: 'DCP — Diploma Kompetensi Elektrik (Kuasa)', email: 'haziq@student.ikm.edu.my'),
      Student(id: 's7', name: 'Siti Rahim', cohort: 'DGS — Diploma Teknologi Kejuruteraan Gas', email: 'siti.r@student.ikm.edu.my'),
    ]);

    // Rich StudentModel objects (for attendance tracking)
    studentModels.addAll([
      StudentModel(id: 's1', name: 'Ali bin Abu', program: 'DCP — Diploma Kompetensi Elektrik (Kuasa)',
          attendanceBySubject: {'Software Engineering': ['H', 'H', 'H', 'MC', 'H', 'H', 'T', '', '', '', '', '', '', '']}),
      StudentModel(id: 's2', name: 'Nurul Aisyah', program: 'DCP — Diploma Kompetensi Elektrik (Kuasa)',
          attendanceBySubject: {'Software Engineering': ['H', 'H', 'H', 'H', 'H', 'H', 'H', '', '', '', '', '', '', '']}),
      StudentModel(id: 's6', name: 'Muhammad Haziq', program: 'DCP — Diploma Kompetensi Elektrik (Kuasa)',
          attendanceBySubject: {'Software Engineering': ['H', 'T', 'T', 'H', 'H', 'T', 'T', '', '', '', '', '', '', '']}),
      StudentModel(id: 's3', name: 'Tan Wei Ming', program: 'DGS — Diploma Teknologi Kejuruteraan Gas',
          attendanceBySubject: {'Database Systems': ['H', 'H', 'H', 'H', 'H', 'H', 'H', '', '', '', '', '', '', '']}),
      StudentModel(id: 's4', name: 'Raj Kumar', program: 'DGS — Diploma Teknologi Kejuruteraan Gas',
          attendanceBySubject: {'Database Systems': ['H', 'MC', 'H', 'H', 'H', 'H', 'T', '', '', '', '', '', '', '']}),
      StudentModel(id: 's7', name: 'Siti Rahim', program: 'DGS — Diploma Teknologi Kejuruteraan Gas',
          attendanceBySubject: {'Database Systems': ['H', 'H', 'H', 'T', 'H', 'H', 'H', '', '', '', '', '', '', '']}),
      StudentModel(id: 's5', name: 'Fatimah Hassan', program: 'DCB — Diploma Lanjutan Kompetensi Elektrik (Penjanaan)'),
      StudentModel(id: 's8', name: 'Ahmad Faiz', program: 'IMF — Diploma Industri Siapan Logam'),
      StudentModel(id: 's9', name: 'Khairul Anwar', program: 'IMF — Diploma Industri Siapan Logam'),
    ]);

    // Real DED 1A class roster from the borang kehadiran template.
    studentModels.addAll(SeedData.ded1aStudents);
  }

  void _seedTimetable() {
    masterTimetable.addAll([
      Timetable(id: 't1', subject: 'Software Engineering', lecturerId: 'u1', room: 'Makmal Elektrik 1',
          cohort: 'DCP — Diploma Kompetensi Elektrik (Kuasa)', dayOfWeek: 1,
          startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 11, minute: 0)),
      Timetable(id: 't2', subject: 'Database Systems', lecturerId: 'u2', room: 'Bilik Kuliah A1',
          cohort: 'DGS — Diploma Teknologi Kejuruteraan Gas', dayOfWeek: 1,
          startTime: const TimeOfDay(hour: 10, minute: 0), endTime: const TimeOfDay(hour: 12, minute: 0)),
      Timetable(id: 't3', subject: 'Web Development', lecturerId: 'u1', room: 'Bilik Kuliah A2',
          cohort: 'DCP — Diploma Kompetensi Elektrik (Kuasa)', dayOfWeek: 1,
          startTime: const TimeOfDay(hour: 14, minute: 0), endTime: const TimeOfDay(hour: 16, minute: 0)),
      Timetable(id: 't4', subject: 'Data Structures', lecturerId: 'u2', room: 'Makmal Elektrik 1',
          cohort: 'DGS — Diploma Teknologi Kejuruteraan Gas', dayOfWeek: 2,
          startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 11, minute: 0)),
      Timetable(id: 't5', subject: 'Operating Systems', lecturerId: 'u7', room: 'Makmal Mekanika 1',
          cohort: 'DGS — Diploma Teknologi Kejuruteraan Gas', dayOfWeek: 2,
          startTime: const TimeOfDay(hour: 11, minute: 0), endTime: const TimeOfDay(hour: 13, minute: 0)),
      Timetable(id: 't6', subject: 'Software Engineering', lecturerId: 'u1', room: 'Bengkel Kimpalan',
          cohort: 'DCP — Diploma Kompetensi Elektrik (Kuasa)', dayOfWeek: 3,
          startTime: const TimeOfDay(hour: 10, minute: 0), endTime: const TimeOfDay(hour: 12, minute: 0)),
      Timetable(id: 't7', subject: 'Network Security', lecturerId: 'u7', room: 'Bilik Kuliah A1',
          cohort: 'DGS — Diploma Teknologi Kejuruteraan Gas', dayOfWeek: 3,
          startTime: const TimeOfDay(hour: 14, minute: 0), endTime: const TimeOfDay(hour: 16, minute: 0)),
      Timetable(id: 't8', subject: 'Database Systems', lecturerId: 'u2', room: 'Bilik Kuliah A2',
          cohort: 'DGS — Diploma Teknologi Kejuruteraan Gas', dayOfWeek: 4,
          startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 11, minute: 0)),
      Timetable(id: 't9', subject: 'Web Development', lecturerId: 'u1', room: 'Makmal Elektrik 1',
          cohort: 'DCP — Diploma Kompetensi Elektrik (Kuasa)', dayOfWeek: 4,
          startTime: const TimeOfDay(hour: 11, minute: 0), endTime: const TimeOfDay(hour: 13, minute: 0)),
      Timetable(id: 't10', subject: 'Mobile App Development', lecturerId: 'u1', room: 'Makmal Mekanika 1',
          cohort: 'DCP — Diploma Kompetensi Elektrik (Kuasa)', dayOfWeek: 5,
          startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 11, minute: 0)),
    ]);
  }

  // ═══════════════════════════════════════════════════════════
  //  USER LOOKUPS
  // ═══════════════════════════════════════════════════════════

  AppUser? getUserById(String id) {
    try {
      return users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  String getLecturerName(String id) {
    return getUserById(id)?.name ?? 'Unknown';
  }

  List<AppUser> get lecturers =>
      users.where((u) => u.role == UserRole.pensyarah).toList();

  List<AppUser> get lecturersFromFirestore => users
      .where((u) => u.role == UserRole.pensyarah)
      .toList();

  /// Merge Firebase users (from AuthService.fetchAllUsers) into local list
  void mergeFirestoreUsers(List<AppUser> firestoreUsers) {
    for (final fu in firestoreUsers) {
      final idx = users.indexWhere((u) => u.id == fu.id);
      if (idx == -1) {
        users.add(fu);
      } else {
        users[idx] = fu;
      }
    }
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  //  ROOM QUERIES
  // ═══════════════════════════════════════════════════════════

  List<String> get roomNames => rooms.map((r) => r.name).toList();

  List<Room> getAvailableRooms(DateTime date, TimeOfDay startTime, TimeOfDay endTime) {
    final startMin = startTime.hour * 60 + startTime.minute;
    final endMin = endTime.hour * 60 + endTime.minute;
    Set<String> occupiedRoomNames = {};

    for (var t in masterTimetable) {
      if (t.dayOfWeek == date.weekday) {
        if (startMin < t.endMinutes && endMin > t.startMinutes) {
          occupiedRoomNames.add(t.room);
        }
      }
    }
    for (var s in classSlots) {
      if (s.date.year == date.year && s.date.month == date.month && s.date.day == date.day) {
        if (startMin < s.endMinutes && endMin > s.startMinutes) {
          occupiedRoomNames.add(s.roomId);
        }
      }
    }
    return rooms.where((r) => !occupiedRoomNames.contains(r.name)).toList();
  }

  bool isRoomOccupied(String roomName, DateTime date, TimeOfDay startTime, TimeOfDay endTime) {
    final startMin = startTime.hour * 60 + startTime.minute;
    final endMin = endTime.hour * 60 + endTime.minute;

    for (var t in masterTimetable) {
      if (t.dayOfWeek == date.weekday && t.room == roomName) {
        if (startMin < t.endMinutes && endMin > t.startMinutes) return true;
      }
    }
    
    for (var s in classSlots) {
      if (s.date.year == date.year && s.date.month == date.month &&
          s.date.day == date.day && s.roomId == roomName) {
        final sStartMin = s.startTime.hour * 60 + s.startTime.minute;
        final sEndMin = s.endTime.hour * 60 + s.endTime.minute;
        if (startMin < sEndMin && endMin > sStartMin) return true;
      }
    }
    
    return false;
  }

  // ═══════════════════════════════════════════════════════════
  //  TIMETABLE / CLASS SLOT QUERIES
  // ═══════════════════════════════════════════════════════════

  List<String> getSubjectsForLecturer(String lecturerId) {
    final fromMaster = masterTimetable
        .where((t) => t.lecturerId == lecturerId)
        .map((t) => t.subject);
    final fromSlots = classSlots
        .where((s) => s.lecturerId == lecturerId)
        .map((s) => s.subjectName);
    return {...fromMaster, ...fromSlots}.toList();
  }

  List<String> getCohortsForLecturer(String lecturerId) {
    return masterTimetable
        .where((t) => t.lecturerId == lecturerId)
        .map((t) => t.cohort)
        .toSet()
        .toList();
  }

  /// All class slots assigned to this lecturer (master + uploaded)
  List<ClassSlotModel> getClassSlotsForLecturer(String lecturerId) {
    return classSlots.where((s) => s.lecturerId == lecturerId).toList();
  }

  List<ClassSlotModel> getClassSlotsForProgram(String program) {
    return classSlots.where((s) => s.program == program).toList();
  }


  List<Timetable> getMergedTimetableForDate(DateTime date, String lecturerId) {
    List<Timetable> dailySlots = [];
    for (var t in masterTimetable) {
      if (t.dayOfWeek == date.weekday && t.lecturerId == lecturerId) {
        dailySlots.add(t);
      }
    }
    return dailySlots;
  }

  /// Upload a new class slot (Ketua Program action)
  void uploadClassSlot(ClassSlotModel slot) {
    classSlots.add(slot);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  //  STUDENT QUERIES
  // ═══════════════════════════════════════════════════════════

  List<StudentModel> getStudentsForProgram(String program) {
    return studentModels.where((s) => s.program == program).toList();
  }

  /// Students enrolled in a specific class group (e.g. "DED 1A").
  ///
  /// Falls back gracefully when the caller's class label is non-standard:
  ///   1. exact case-insensitive match on [StudentModel.studentClass]
  ///   2. trimmed / whitespace-normalised compare ("DED1A" ↔ "DED 1A")
  ///   3. if [program] is provided and steps 1-2 yield nothing, return
  ///      every student in the program so the lecturer can still mark
  ///      attendance instead of staring at an empty list
  List<StudentModel> getStudentsForClass(String studentClass,
      {String? program}) {
    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'\s+'), '').trim();

    final target = norm(studentClass);

    // Step 1 + 2
    final exact = studentModels
        .where((s) => norm(s.studentClass) == target)
        .toList();
    if (exact.isNotEmpty) {
      return exact..sort((a, b) => a.name.compareTo(b.name));
    }

    // Step 3 — program-wide fallback
    if (program != null && program.isNotEmpty) {
      return studentModels.where((s) => s.program == program).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    }

    return const [];
  }

  void updateAttendance(String studentId, String subjectId, int weekIndex, String status) {
    final idx = studentModels.indexWhere((s) => s.id == studentId);
    if (idx == -1) return;
    studentModels[idx] = studentModels[idx].copyWithAttendance(subjectId, weekIndex, status);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  //  DISCIPLINE REPORTS
  // ═══════════════════════════════════════════════════════════

  void submitDisciplineReport(DisciplineReportModel report) {
    disciplineReports.add(report);
    notifyListeners();
  }

  /// Reports visible only to same-program Ketua Program & Ketua Jabatan
  List<DisciplineReportModel> getReportsForProgram(String program) {
    return disciplineReports
        .where((r) => r.program == program)
        .toList()
      ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
  }

  /// All reports (for TPA view)
  List<DisciplineReportModel> get allDisciplineReports {
    return List.from(disciplineReports)
      ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
  }

  // ═══════════════════════════════════════════════════════════
  //  BOOKING MODULE (Module 6) — Now handled by Firestore.
  //  See: services/booking_service.dart (FirestoreBookingService)
  // ═══════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════
  //  NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════

  /// Append a notification to the in-memory feed (used by the absenteeism
  /// warning engine and other in-app triggers).
  void addNotification(AppNotification notification) {
    notifications.add(notification);
    notifyListeners();
  }

  List<AppNotification> getNotificationsForUser(String userId) {
    return notifications.where((n) => n.recipientId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int getUnreadCount(String userId) {
    return notifications.where((n) => n.recipientId == userId && !n.isRead).length;
  }

  void markNotificationRead(String notificationId) {
    final index = notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      notifications[index] = notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }
}


final mockDbProvider = ChangeNotifierProvider<MockDatabaseService>((ref) {
  return MockDatabaseService();
});
