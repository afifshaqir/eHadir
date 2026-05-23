import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/booking.dart';
import 'mock_db_service.dart';
import 'package:flutter/material.dart';

final firestoreBookingProvider =
    ChangeNotifierProvider<FirestoreBookingService>((ref) {
  return FirestoreBookingService(mockDb: ref.read(mockDbProvider));
});

/// Firestore-backed booking service for Module 6.
///
/// Provides:
///   • [checkConflict] — queries the `bookings` collection for time/room overlaps
///   • [saveBooking]   — validates then persists a new booking document
class FirestoreBookingService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MockDatabaseService mockDb;

  static const String _collection = 'bookings';

  FirestoreBookingService({required this.mockDb});

  // ═══════════════════════════════════════════════════════════
  //  CONFLICT DETECTION ENGINE (CRITICAL)
  // ═══════════════════════════════════════════════════════════

  /// Queries the `bookings` collection to check if [roomId] is already
  /// booked on [date] at an overlapping time.
  ///
  /// Returns `true` if a conflict exists, using the exact overlap formula:
  ///   `(proposedStart < existingEnd) && (proposedEnd > existingStart)`
  Future<bool> checkConflict(
    String roomId,
    DateTime date,
    int startMin,
    int endMin,
  ) async {
    // Normalise the date to midnight for Firestore comparison
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayTimestamp = Timestamp.fromDate(dayStart);

    // 1. Check against master timetable and uploaded class slots
    final isOccupiedInTimetable = mockDb.isRoomOccupied(
      roomId,
      date,
      TimeOfDay(hour: startMin ~/ 60, minute: startMin % 60),
      TimeOfDay(hour: endMin ~/ 60, minute: endMin % 60),
    );

    if (isOccupiedInTimetable) {
      return true;
    }

    try {
      // Query all bookings for this room on this specific date
      final snapshot = await _db
          .collection(_collection)
          .where('roomId', isEqualTo: roomId)
          .where('date', isEqualTo: dayTimestamp)
          .get();

      // Iterate through results and check for overlap
      for (final doc in snapshot.docs) {
        final existingStart = doc['startTime'] as int;
        final existingEnd = doc['endTime'] as int;

        // Exact overlap formula from the spec
        if ((startMin < existingEnd) && (endMin > existingStart)) {
          return true; // Conflict exists!
        }
      }

      return false; // No conflict
    } catch (e) {
      debugPrint('FirestoreBookingService.checkConflict error: $e');
      // If we can't verify, assume conflict to be safe
      return true;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  SAVE BOOKING
  // ═══════════════════════════════════════════════════════════

  /// Checks for conflicts first, then saves the booking to Firestore.
  ///
  /// Throws [BookingConflictException] if the room is already booked.
  Future<void> saveBooking(FirestoreBooking booking) async {
    final hasConflict = await checkConflict(
      booking.roomId,
      booking.date,
      booking.startTime,
      booking.endTime,
    );

    if (hasConflict) {
      throw BookingConflictException(
        'Bilik ${booking.roomId} sudah ditempah pada masa tersebut. '
        'Sila pilih masa atau bilik lain.',
      );
    }

    // No conflict → save to Firestore
    await _db.collection(_collection).add(booking.toFirestore());
    notifyListeners();
  }

  /// Fetch all bookings for a specific lecturer.
  Future<List<FirestoreBooking>> getBookingsForLecturer(String lecturerId) async {
    final snapshot = await _db
        .collection(_collection)
        .where('lecturerId', isEqualTo: lecturerId)
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map(FirestoreBooking.fromFirestore).toList();
  }
}

// ═══════════════════════════════════════════════════════════
//  CUSTOM EXCEPTION
// ═══════════════════════════════════════════════════════════

class BookingConflictException implements Exception {
  final String message;
  BookingConflictException(this.message);

  @override
  String toString() => message;
}
