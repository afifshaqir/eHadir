import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/booking_service.dart';
import '../../models/class_slot_model.dart';
import '../../theme.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';

class MyTimetableScreen extends ConsumerWidget {
  final Function(String slotId) onTakeAttendance;

  const MyTimetableScreen({super.key, required this.onTakeAttendance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final currentUser = auth.currentUser!;
    final bookingService = ref.read(firestoreBookingProvider);

    // Choose the right Firestore stream based on the user's role
    final Stream<List<ClassSlotModel>> slotsStream =
        currentUser.role == UserRole.ketuaProgram
            ? bookingService.streamClassSlotsForProgram(currentUser.program)
            : bookingService.streamClassSlotsForLecturer(currentUser.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            title: Text('Jadual Saya'),
            floating: true,
          ),
          // Stream directly from Firestore — live updates on every change
          SliverToBoxAdapter(
            child: StreamBuilder<List<ClassSlotModel>>(
              stream: slotsStream,
              builder: (context, snapshot) {
                // Loading state
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                // Error state
                if (snapshot.hasError) {
                  return SizedBox(
                    height: 300,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 48, color: EHadirTheme.rejected),
                          const SizedBox(height: 16),
                          Text('Ralat memuatkan jadual.',
                              style: const TextStyle(color: EHadirTheme.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }

                final slots = snapshot.data ?? [];

                // Empty state
                if (slots.isEmpty) {
                  return SizedBox(
                    height: 300,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy_rounded,
                              size: 64, color: EHadirTheme.textSecondary.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          const Text('Tiada jadual ditemui.',
                              style: TextStyle(color: EHadirTheme.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }

                // Slot list
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: slots
                            .map((slot) => _TimetableCard(
                                  slot: slot,
                                  onTakeAttendance: onTakeAttendance,
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TimetableCard extends StatelessWidget {
  final ClassSlotModel slot;
  final Function(String slotId) onTakeAttendance;

  const _TimetableCard({required this.slot, required this.onTakeAttendance});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: EHadirTheme.card,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
        border: Border.all(color: EHadirTheme.divider),
        boxShadow: EHadirTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date box (Indigo pill badge)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: EHadirTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(DateFormat('MMM').format(slot.date).toUpperCase(),
                          style: const TextStyle(
                              color: EHadirTheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                      Text(DateFormat('dd').format(slot.date),
                          style: const TextStyle(
                              color: EHadirTheme.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slot.subjectName,
                          style: const TextStyle(
                              color: EHadirTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.room_rounded,
                              size: 16, color: Color(0xFFF59E0B)), // Orange location pin
                          const SizedBox(width: 4),
                          Text(slot.roomId,
                              style: const TextStyle(
                                  color: EHadirTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(width: 14),
                          const Icon(Icons.schedule_rounded,
                              size: 16, color: Color(0xFF3B82F6)), // Blue clock
                          const SizedBox(width: 4),
                          Text(slot.timeRangeFormatted,
                              style: const TextStyle(
                                  color: EHadirTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.school_rounded,
                              size: 16, color: Color(0xFF10B981)), // Emerald book/program
                          const SizedBox(width: 4),
                          Text('Program: ${slot.program}',
                              style: const TextStyle(
                                  color: EHadirTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Action row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFC),
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(EHadirTheme.radiusLg),
                  bottomRight: Radius.circular(EHadirTheme.radiusLg)),
              border: Border(top: BorderSide(color: EHadirTheme.divider)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    onTakeAttendance(slot.id);
                  },
                  icon: const Icon(Icons.fact_check_rounded, size: 16, color: Colors.white),
                  label: const Text('Ambil Kehadiran'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EHadirTheme.approved, // Emerald Green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
