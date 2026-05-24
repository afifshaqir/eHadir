import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../services/auth_service.dart';
import '../../services/mock_db_service.dart';
import '../../services/booking_service.dart';
import '../../models/user.dart';
import '../../models/class_slot_model.dart';
import '../../theme.dart';
import '../../utils/dialogs.dart';

class KetuaProgramDashboardScreen extends ConsumerStatefulWidget {
  const KetuaProgramDashboardScreen({super.key});

  @override
  ConsumerState<KetuaProgramDashboardScreen> createState() =>
      _KetuaProgramDashboardScreenState();
}

class _KetuaProgramDashboardScreenState
    extends ConsumerState<KetuaProgramDashboardScreen> with SingleTickerProviderStateMixin {
  
  // Form State
  int _currentStep = 0;
  final _uuid = const Uuid();
  bool _isSubmitting = false;
  bool _submitted = false;

  final _subjectCtrl = TextEditingController();
  String? _selectedLecturerId;
  String? _selectedLecturerName;
  DateTime? _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  String? _selectedRoom;

  // Lecturers from Firestore
  List<AppUser> _lecturers = [];
  bool _loadingLecturers = true;

  // Animation
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
    final auth = ref.read(authProvider);
    final db = ref.read(mockDbProvider);
    final allUsers = await auth.fetchAllUsers();
    
    if (mounted) {
      setState(() {
        final firestoreLecs = allUsers.where((u) => u.role == UserRole.pensyarah).toList();
        final mockLecs = db.lecturers;
        
        final combined = <String, AppUser>{};
        for (var l in mockLecs) { combined[l.email] = l; }
        for (var l in firestoreLecs) { combined[l.email] = l; }
        
        _lecturers = combined.values.toList();
        _loadingLecturers = false;
      });
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  bool get _isStep1Valid => _subjectCtrl.text.trim().isNotEmpty && _selectedLecturerId != null;
  bool get _isStep2Valid => _selectedDate != null;
  bool get _isStep3Valid => _selectedRoom != null;

  Future<void> _submitSlot() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final bookingService = ref.read(firestoreBookingProvider);
    final auth = ref.read(authProvider);
    final current = auth.currentUser!;

    final startMin = _startTime.hour * 60 + _startTime.minute;
    final endMin = _endTime.hour * 60 + _endTime.minute;

    // Check for conflicts
    final hasConflict = await bookingService.checkConflict(
      _selectedRoom!,
      _selectedDate!,
      startMin,
      endMin,
    );

    if (hasConflict) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bilik $_selectedRoom telah digunakan pada masa ini.'),
            backgroundColor: EHadirTheme.rejected,
          ),
        );
      }
      return;
    }

    final slot = ClassSlotModel(
      id: _uuid.v4(),
      subjectName: _subjectCtrl.text.trim(),
      roomId: _selectedRoom!,
      lecturerId: _selectedLecturerId!,
      lecturerName: _selectedLecturerName!,
      program: current.program,
      date: _selectedDate!,
      startTime: _startTime,
      endTime: _endTime,
    );

    await bookingService.saveClassSlot(slot);

    if (mounted) {
      setState(() {
        _submitted = true;
        _isSubmitting = false;
      });
    }
  }

  void _resetForm() {
    setState(() {
      _currentStep = 0;
      _subjectCtrl.clear();
      _selectedLecturerId = null;
      _selectedLecturerName = null;
      _selectedDate = null;
      _selectedRoom = null;
      _submitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(authProvider).currentUser!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Log Keluar',
          onPressed: () => showLogoutConfirmation(context, ref),
        ),
        title: Text('Ketua Program — ${current.program}'),
      ),
      body: _submitted ? _buildSuccessView() : FadeTransition(
        opacity: _fadeIn,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
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
            child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Muat Naik Jadual',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Tambah slot kelas baharu ke dalam sistem',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final steps = ['Subjek', 'Tarikh', 'Bilik', 'Semakan'];
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
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 28,
                height: 28,
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
                            color: isActive ? Colors.white : EHadirTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
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
        return _buildStep1Subject(key: const ValueKey(0));
      case 1:
        return _buildStep2DateTime(key: const ValueKey(1));
      case 2:
        return _buildStep3Room(key: const ValueKey(2));
      case 3:
        return _buildStep4Review(key: const ValueKey(3));
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Step 1 ──────────────────────────────────────────────
  Widget _buildStep1Subject({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Maklumat Kelas & Pensyarah'),
        const SizedBox(height: 16),
        _cardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nama Subjek', style: TextStyle(color: EHadirTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectCtrl,
                style: const TextStyle(color: EHadirTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Contoh: Pengaturcaraan Web',
                  prefixIcon: Icon(Icons.book_outlined, color: EHadirTheme.textSecondary, size: 20),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              const Text('Pensyarah', style: TextStyle(color: EHadirTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              _loadingLecturers
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: EHadirTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLecturerId,
                          isExpanded: true,
                          hint: const Text('Pilih pensyarah', style: TextStyle(color: EHadirTheme.textSecondary)),
                          dropdownColor: EHadirTheme.card,
                          style: const TextStyle(color: EHadirTheme.textPrimary, fontSize: 15),
                          items: _lecturers.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name))).toList(),
                          onChanged: (v) {
                            final lec = _lecturers.firstWhere((l) => l.id == v);
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
        const SizedBox(height: 24),
        _navigationButtons(canNext: _isStep1Valid),
      ],
    );
  }

  // ─── Step 2 ──────────────────────────────────────────────
  Widget _buildStep2DateTime({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Pilih Tarikh & Masa'),
        const SizedBox(height: 16),
        _cardContainer(
          child: InkWell(
            onTap: () async {
              final dt = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 180)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(primary: EHadirTheme.primary),
                  ),
                  child: child!,
                ),
              );
              if (dt != null) setState(() => _selectedDate = dt);
            },
            borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: EHadirTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(EHadirTheme.radiusSm),
                  ),
                  child: const Icon(Icons.calendar_today_rounded, color: EHadirTheme.accent, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tarikh', style: TextStyle(color: EHadirTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        _selectedDate != null ? DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate!) : 'Tekan untuk pilih tarikh',
                        style: TextStyle(
                          color: _selectedDate != null ? EHadirTheme.textPrimary : EHadirTheme.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _cardContainer(
                child: InkWell(
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: _startTime);
                    if (t != null) setState(() => _startTime = t);
                  },
                  child: Column(
                    children: [
                      const Text('Masa Mula', style: TextStyle(color: EHadirTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text('${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: EHadirTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward_rounded, color: EHadirTheme.textSecondary)),
            Expanded(
              child: _cardContainer(
                child: InkWell(
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: _endTime);
                    if (t != null) setState(() => _endTime = t);
                  },
                  child: Column(
                    children: [
                      const Text('Masa Tamat', style: TextStyle(color: EHadirTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text('${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: EHadirTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _navigationButtons(canNext: _isStep2Valid, showBack: true),
      ],
    );
  }

  // ─── Step 3 ──────────────────────────────────────────────
  Widget _buildStep3Room({Key? key}) {
    final db = ref.read(mockDbProvider);
    final allRooms = db.rooms;

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Pilih Bilik'),
        const SizedBox(height: 16),
        ...allRooms.map((room) {
          final isSelected = _selectedRoom == room.name;
          return GestureDetector(
            onTap: () => setState(() => _selectedRoom = room.name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? EHadirTheme.accent.withValues(alpha: 0.15) : EHadirTheme.card,
                borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
                border: Border.all(
                  color: isSelected ? EHadirTheme.accent : EHadirTheme.divider,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(room.name, style: TextStyle(color: EHadirTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text('${room.building} · ${room.typeLabel} · ${room.capacity} pax',
                            style: const TextStyle(color: EHadirTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (isSelected) const Icon(Icons.check_circle_rounded, color: EHadirTheme.accent, size: 22),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        _navigationButtons(canNext: _isStep3Valid, showBack: true),
      ],
    );
  }

  // ─── Step 4 ──────────────────────────────────────────────
  Widget _buildStep4Review({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Semakan & Simpan'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: EHadirTheme.cardGradient,
            borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
            border: Border.all(color: EHadirTheme.divider),
          ),
          child: Column(
            children: [
              _reviewRow(Icons.book_rounded, 'Subjek', _subjectCtrl.text),
              _reviewDivider(),
              _reviewRow(Icons.person_rounded, 'Pensyarah', _selectedLecturerName ?? '—'),
              _reviewDivider(),
              _reviewRow(Icons.event_rounded, 'Tarikh', _selectedDate != null ? DateFormat('EEEE, dd MMM yyyy').format(_selectedDate!) : '—'),
              _reviewDivider(),
              _reviewRow(Icons.schedule_rounded, 'Masa', '${_startTime.hour.toString().padLeft(2,'0')}:${_startTime.minute.toString().padLeft(2,'0')} - ${_endTime.hour.toString().padLeft(2,'0')}:${_endTime.minute.toString().padLeft(2,'0')}'),
              _reviewDivider(),
              _reviewRow(Icons.room_rounded, 'Bilik', _selectedRoom ?? '—'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitSlot,
            style: ElevatedButton.styleFrom(backgroundColor: EHadirTheme.accent, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _isSubmitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Simpan Jadual', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => _currentStep = 0),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Kembali untuk Sunting'),
          ),
        ),
      ],
    );
  }

  // ─── Helpers ─────────────────────────────────────────────

  Widget _buildSuccessView() {
    return Center(
      child: FadeTransition(
        opacity: _fadeIn,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: EHadirTheme.approved.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: EHadirTheme.approved, size: 64),
            ),
            const SizedBox(height: 24),
            const Text('Jadual Berjaya Disimpan!', style: TextStyle(color: EHadirTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Jadual ini kini boleh dilihat di tab Jadual.',
                style: TextStyle(color: EHadirTheme.textSecondary, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _resetForm,
              style: ElevatedButton.styleFrom(backgroundColor: EHadirTheme.surfaceLight, foregroundColor: EHadirTheme.textPrimary, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
              child: const Text('Tambah Jadual Lain'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navigationButtons({required bool canNext, bool showBack = false}) {
    return Row(
      children: [
        if (showBack)
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _currentStep--),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Kembali'),
            ),
          ),
        if (showBack) const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: canNext ? () => setState(() => _currentStep++) : null,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text('Seterusnya'),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(color: EHadirTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700));
  }

  Widget _cardContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: EHadirTheme.card, borderRadius: BorderRadius.circular(EHadirTheme.radiusMd), border: Border.all(color: EHadirTheme.divider)),
      child: child,
    );
  }

  Widget _reviewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: EHadirTheme.textSecondary, size: 20),
          const SizedBox(width: 12),
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: EHadirTheme.textSecondary, fontSize: 14))),
          Expanded(child: Text(value, style: const TextStyle(color: EHadirTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _reviewDivider() => const Divider(color: EHadirTheme.divider, height: 16);
}
