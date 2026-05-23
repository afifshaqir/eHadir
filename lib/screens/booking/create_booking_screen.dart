import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/booking_service.dart';
import '../../services/auth_service.dart';
import '../../models/booking.dart';
import '../../theme.dart';

/// Module 6: 4-Step Booking Wizard
///
/// Step 1: Maklumat Kelas & Pensyarah
/// Step 2: Pilih Tarikh & Masa
/// Step 3: Pilih Bilik
/// Step 4: Pengesahan & Hantar
class CreateBookingScreen extends ConsumerStatefulWidget {
  const CreateBookingScreen({super.key});

  @override
  ConsumerState<CreateBookingScreen> createState() =>
      _CreateBookingScreenState();
}

class _CreateBookingScreenState extends ConsumerState<CreateBookingScreen>
    with SingleTickerProviderStateMixin {
  // ─── Step tracking ──────────────────────────────────────
  int _currentStep = 0;

  // ─── Step 1 state ───────────────────────────────────────
  final _subjectCtrl = TextEditingController();
  String? _selectedLecturerId;
  String? _selectedLecturerName;
  List<_LecturerOption> _lecturers = [];
  bool _loadingLecturers = true;

  // ─── Step 2 state ───────────────────────────────────────
  DateTime? _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);

  // ─── Step 3 state ───────────────────────────────────────
  String? _selectedRoom;
  static const List<String> _rooms = [
    'Bengkel Kimpalan',
    'Bilik Kuliah A1',
    'Bilik Kuliah A2',
    'Makmal Elektrik 1',
    'Makmal Mekanika 1',
  ];

  // ─── Step 4 state ───────────────────────────────────────
  bool _isSubmitting = false;

  // ─── Animation ──────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadLecturers();
  }

  Future<void> _loadLecturers() async {
    try {
      final auth = ref.read(authProvider);
      final allUsers = await auth.fetchAllUsers();
      if (mounted) {
        setState(() {
          _lecturers = allUsers
              .where((u) => u.role.name == 'pensyarah')
              .map((u) => _LecturerOption(id: u.id, name: u.name))
              .toList();
          _loadingLecturers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingLecturers = false);
      }
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ─── Validation ─────────────────────────────────────────
  bool get _isStep1Valid =>
      _subjectCtrl.text.trim().isNotEmpty && _selectedLecturerId != null;
  bool get _isStep2Valid => _selectedDate != null;
  bool get _isStep3Valid => _selectedRoom != null;

  int _timeToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ═══════════════════════════════════════════════════════════
  //  SUBMIT LOGIC
  // ═══════════════════════════════════════════════════════════

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final bookingService = ref.read(firestoreBookingProvider);

    final booking = FirestoreBooking(
      id: '', // Firestore will auto-generate
      subjectName: _subjectCtrl.text.trim(),
      lecturerId: _selectedLecturerId!,
      lecturerName: _selectedLecturerName!,
      roomId: _selectedRoom!,
      date: _selectedDate!,
      startTime: _timeToMinutes(_startTime),
      endTime: _timeToMinutes(_endTime),
    );

    try {
      await bookingService.saveBooking(booking);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Tempahan berjaya disimpan! ✅',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: EHadirTheme.approved,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } on BookingConflictException catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Konflik: ${e.message}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: EHadirTheme.rejected,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat: $e'),
            backgroundColor: EHadirTheme.rejected,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Tempah Bilik Ganti'),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: EHadirTheme.primaryGradient),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeIn,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            _buildPageHeader(),
            const SizedBox(height: 24),
            _buildProgressIndicator(),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCurrentStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: EHadirTheme.primaryGradient,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
        boxShadow: EHadirTheme.glowShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
            ),
            child: const Icon(Icons.add_business_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tempahan Bilik Ganti',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Mohon bilik untuk kelas gantian',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Progress Indicator ─────────────────────────────────
  Widget _buildProgressIndicator() {
    final steps = ['Subjek', 'Tarikh', 'Bilik', 'Hantar'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i == _currentStep;
        final isDone = i < _currentStep;
        final color = isDone
            ? EHadirTheme.approved
            : isActive
                ? EHadirTheme.accent
                : EHadirTheme.divider;

        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDone || isActive ? color : Colors.transparent,
                      border: Border.all(color: color, width: 2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: isActive
                                    ? Colors.white
                                    : EHadirTheme.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[i],
                    style: TextStyle(
                      color: isActive || isDone
                          ? EHadirTheme.textPrimary
                          : EHadirTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 18),
                    color: isDone ? EHadirTheme.approved : EHadirTheme.divider,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1(key: const ValueKey(0));
      case 1:
        return _buildStep2(key: const ValueKey(1));
      case 2:
        return _buildStep3(key: const ValueKey(2));
      case 3:
        return _buildStep4(key: const ValueKey(3));
      default:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  STEP 1: MAKLUMAT KELAS & PENSYARAH
  // ═══════════════════════════════════════════════════════════
  Widget _buildStep1({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Maklumat Kelas & Pensyarah'),
        const SizedBox(height: 16),

        // Subject name
        _cardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nama Subjek',
                  style: TextStyle(
                      color: EHadirTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectCtrl,
                style: const TextStyle(color: EHadirTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Contoh: Pengaturcaraan Web',
                  prefixIcon: Icon(Icons.book_outlined,
                      color: EHadirTheme.textSecondary, size: 20),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Lecturer dropdown
        _cardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pensyarah',
                  style: TextStyle(
                      color: EHadirTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              _loadingLecturers
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: EHadirTheme.surfaceLight,
                        borderRadius:
                            BorderRadius.circular(EHadirTheme.radiusMd),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLecturerId,
                          isExpanded: true,
                          hint: const Text('Pilih pensyarah',
                              style: TextStyle(
                                  color: EHadirTheme.textSecondary)),
                          dropdownColor: EHadirTheme.card,
                          style: const TextStyle(
                              color: EHadirTheme.textPrimary, fontSize: 15),
                          items: _lecturers
                              .map((l) => DropdownMenuItem(
                                    value: l.id,
                                    child: Text(l.name),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            final lec =
                                _lecturers.firstWhere((l) => l.id == v);
                            setState(() {
                              _selectedLecturerId = v;
                              _selectedLecturerName = lec.name;
                            });
                          },
                        ),
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _navButtons(canNext: _isStep1Valid),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STEP 2: PILIH TARIKH & MASA
  // ═══════════════════════════════════════════════════════════
  Widget _buildStep2({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Pilih Tarikh & Masa'),
        const SizedBox(height: 16),

        // Date picker tile
        _cardContainer(
          child: InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: EHadirTheme.accent.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(EHadirTheme.radiusSm),
                  ),
                  child: const Icon(Icons.calendar_today_rounded,
                      color: EHadirTheme.accent, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tarikh',
                          style: TextStyle(
                              color: EHadirTheme.textSecondary,
                              fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        _selectedDate != null
                            ? DateFormat('EEEE, dd MMMM yyyy')
                                .format(_selectedDate!)
                            : 'Tekan untuk pilih tarikh',
                        style: TextStyle(
                          color: _selectedDate != null
                              ? EHadirTheme.textPrimary
                              : EHadirTheme.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: EHadirTheme.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Time pickers side by side
        Row(
          children: [
            Expanded(
              child: _cardContainer(
                child: InkWell(
                  onTap: () => _pickTime(isStart: true),
                  child: Column(
                    children: [
                      const Text('Masa Mula',
                          style: TextStyle(
                              color: EHadirTheme.textSecondary,
                              fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(
                        _formatTime(_startTime),
                        style: const TextStyle(
                          color: EHadirTheme.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_timeToMinutes(_startTime)} min',
                        style: const TextStyle(
                            color: EHadirTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward_rounded,
                  color: EHadirTheme.textSecondary),
            ),
            Expanded(
              child: _cardContainer(
                child: InkWell(
                  onTap: () => _pickTime(isStart: false),
                  child: Column(
                    children: [
                      const Text('Masa Tamat',
                          style: TextStyle(
                              color: EHadirTheme.textSecondary,
                              fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(
                        _formatTime(_endTime),
                        style: const TextStyle(
                          color: EHadirTheme.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_timeToMinutes(_endTime)} min',
                        style: const TextStyle(
                            color: EHadirTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Duration display
        if (_timeToMinutes(_endTime) > _timeToMinutes(_startTime))
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: EHadirTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(EHadirTheme.radiusSm),
              ),
              child: Text(
                'Tempoh: ${_calcDuration()}',
                style: const TextStyle(
                    color: EHadirTheme.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
        const SizedBox(height: 28),
        _navButtons(canNext: _isStep2Valid, showBack: true),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STEP 3: PILIH BILIK
  // ═══════════════════════════════════════════════════════════
  Widget _buildStep3({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Pilih Bilik'),
        const SizedBox(height: 8),
        const Text(
          'Pilih bilik yang dikehendaki untuk kelas gantian.',
          style: TextStyle(color: EHadirTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),

        ..._rooms.map((room) {
          final isSelected = _selectedRoom == room;
          return GestureDetector(
            onTap: () => setState(() => _selectedRoom = room),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? EHadirTheme.accent.withValues(alpha: 0.15)
                    : EHadirTheme.card,
                borderRadius:
                    BorderRadius.circular(EHadirTheme.radiusMd),
                border: Border.all(
                  color: isSelected
                      ? EHadirTheme.accent
                      : EHadirTheme.divider,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? EHadirTheme.accent.withValues(alpha: 0.2)
                          : EHadirTheme.surfaceLight,
                      borderRadius:
                          BorderRadius.circular(EHadirTheme.radiusSm),
                    ),
                    child: Icon(
                      Icons.meeting_room_rounded,
                      color: isSelected
                          ? EHadirTheme.accent
                          : EHadirTheme.textSecondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      room,
                      style: TextStyle(
                        color: EHadirTheme.textPrimary,
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded,
                        color: EHadirTheme.accent, size: 24),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 28),
        _navButtons(canNext: _isStep3Valid, showBack: true),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STEP 4: PENGESAHAN & HANTAR
  // ═══════════════════════════════════════════════════════════
  Widget _buildStep4({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Pengesahan & Hantar'),
        const SizedBox(height: 16),

        // Summary card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: EHadirTheme.cardGradient,
            borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
            border: Border.all(color: EHadirTheme.divider),
          ),
          child: Column(
            children: [
              _reviewRow(Icons.book_rounded, 'Subjek',
                  _subjectCtrl.text.trim()),
              _reviewDivider(),
              _reviewRow(Icons.person_rounded, 'Pensyarah',
                  _selectedLecturerName ?? '—'),
              _reviewDivider(),
              _reviewRow(
                  Icons.event_rounded,
                  'Tarikh',
                  _selectedDate != null
                      ? DateFormat('EEEE, dd MMM yyyy')
                          .format(_selectedDate!)
                      : '—'),
              _reviewDivider(),
              _reviewRow(Icons.schedule_rounded, 'Masa',
                  '${_formatTime(_startTime)} – ${_formatTime(_endTime)}'),
              _reviewDivider(),
              _reviewRow(
                  Icons.room_rounded, 'Bilik', _selectedRoom ?? '—'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Minutes from midnight display (technical detail)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: EHadirTheme.surfaceLight,
            borderRadius: BorderRadius.circular(EHadirTheme.radiusSm),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: EHadirTheme.textSecondary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Database: startTime=${_timeToMinutes(_startTime)}, endTime=${_timeToMinutes(_endTime)} (minit dari tengah malam)',
                  style: const TextStyle(
                      color: EHadirTheme.textSecondary, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Submit button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: EHadirTheme.accent,
              disabledBackgroundColor: EHadirTheme.surfaceLight,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Hantar',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() {
              _currentStep = 0;
            }),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Kembali untuk Sunting'),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SHARED WIDGETS & HELPERS
  // ═══════════════════════════════════════════════════════════

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: EHadirTheme.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _cardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EHadirTheme.card,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
        border: Border.all(color: EHadirTheme.divider),
      ),
      child: child,
    );
  }

  Widget _reviewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: EHadirTheme.accent, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: EHadirTheme.textSecondary, fontSize: 14)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: EHadirTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _reviewDivider() =>
      const Divider(color: EHadirTheme.divider, height: 16);

  Widget _navButtons({required bool canNext, bool showBack = false}) {
    return Row(
      children: [
        if (showBack)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep--),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Kembali'),
            ),
          ),
        if (showBack) const SizedBox(width: 12),
        Expanded(
          flex: showBack ? 2 : 1,
          child: ElevatedButton(
            onPressed: canNext
                ? () => setState(() => _currentStep++)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: EHadirTheme.accent,
              disabledBackgroundColor: EHadirTheme.surfaceLight,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Seterusnya',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _calcDuration() {
    final diff = _timeToMinutes(_endTime) - _timeToMinutes(_startTime);
    if (diff <= 0) return '0';
    final hours = diff ~/ 60;
    final mins = diff % 60;
    if (mins == 0) return '$hours jam';
    return '${hours}j ${mins}m';
  }

  Future<void> _pickDate() async {
    final dt = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (ctx, child) => Theme(
        data: EHadirTheme.darkTheme.copyWith(
          colorScheme: EHadirTheme.darkTheme.colorScheme
              .copyWith(primary: EHadirTheme.accent),
        ),
        child: child!,
      ),
    );
    if (dt != null) {
      setState(() => _selectedDate = dt);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final t = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (ctx, child) => Theme(
        data: EHadirTheme.darkTheme.copyWith(
          colorScheme: EHadirTheme.darkTheme.colorScheme
              .copyWith(primary: EHadirTheme.accent),
        ),
        child: child!,
      ),
    );
    if (t != null) {
      setState(() {
        if (isStart) {
          _startTime = t;
        } else {
          _endTime = t;
        }
      });
    }
  }
}

/// Simple helper class for the lecturer dropdown.
class _LecturerOption {
  final String id;
  final String name;
  const _LecturerOption({required this.id, required this.name});
}
