import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/lecturer_assignment.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/curriculum_service.dart';
import '../../services/mock_db_service.dart';
import '../../theme.dart';
import '../../utils/dialogs.dart';
import '../ketua_program/tugaskan_subjek_screen.dart';

/// Ketua Program dashboard — Ketua Program's job is now ONLY:
///   1) Pick a lecturer from the program
///   2) Type the subject name (or pick from catalog via Tugaskan Subjek)
///   3) Save → produces a [LecturerAssignment] with no date / time / room.
///
/// Ketua Jabatan is the one who later assigns the date, time, and room.
class KetuaProgramDashboardScreen extends ConsumerStatefulWidget {
  const KetuaProgramDashboardScreen({super.key});

  @override
  ConsumerState<KetuaProgramDashboardScreen> createState() =>
      _KetuaProgramDashboardScreenState();
}

class _KetuaProgramDashboardScreenState
    extends ConsumerState<KetuaProgramDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _subjectCtrl = TextEditingController();
  final _subjectCodeCtrl = TextEditingController();
  final _classCtrl = TextEditingController();
  String? _selectedLecturerId;
  String? _selectedLecturerName;
  bool _isSubmitting = false;
  bool _submitted = false;

  List<AppUser> _lecturers = [];
  bool _loadingLecturers = true;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLecturers());
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _subjectCodeCtrl.dispose();
    _classCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadLecturers() async {
    final auth = ref.read(authProvider);
    final db = ref.read(mockDbProvider);
    final current = auth.currentUser!;

    try {
      final all = await auth.fetchAllUsers();
      db.mergeFirestoreUsers(all);
    } catch (_) {/* offline: keep seed */}

    if (!mounted) return;
    setState(() {
      // Only lecturers in this Ketua Program's program
      _lecturers = db.users
          .where((u) =>
              u.role == UserRole.pensyarah && u.program == current.program)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      _loadingLecturers = false;
    });
  }

  bool get _canSave =>
      _subjectCtrl.text.trim().isNotEmpty &&
      _selectedLecturerId != null &&
      !_isSubmitting;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSubmitting = true);

    final curriculum = ref.read(curriculumServiceProvider);
    final current = ref.read(authProvider).currentUser!;

    final assignment = LecturerAssignment(
      id: '',
      lecturerId: _selectedLecturerId!,
      lecturerName: _selectedLecturerName!,
      subjectCode: _subjectCodeCtrl.text.trim().isEmpty
          ? '—'
          : _subjectCodeCtrl.text.trim(),
      subjectName: _subjectCtrl.text.trim(),
      program: current.program,
      studentClass: _classCtrl.text.trim(),
      assignedBy: current.id,
    );

    try {
      await curriculum.upsertAssignment(assignment);
      if (mounted) {
        setState(() {
          _submitted = true;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: EHadirTheme.rejected,
          ),
        );
      }
    }
  }

  void _resetForm() {
    setState(() {
      _subjectCtrl.clear();
      _subjectCodeCtrl.clear();
      _classCtrl.clear();
      _selectedLecturerId = null;
      _selectedLecturerName = null;
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
      body: _submitted
          ? _buildSuccessView()
          : FadeTransition(
              opacity: _fadeIn,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  _buildPageHeader(),
                  const SizedBox(height: 16),
                  _buildTugaskanSubjekCard(),
                  const SizedBox(height: 20),
                  _sectionTitle('Tugaskan Subjek Baharu'),
                  const SizedBox(height: 4),
                  const Text(
                    'Isi nama subjek dan pilih pensyarah. Ketua Jabatan akan '
                    'menetapkan tarikh, masa, dan bilik selepas ini.',
                    style:
                        TextStyle(color: EHadirTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  _buildAssignmentForm(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _canSave ? _save : null,
                      icon: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded, size: 18),
                      label: Text(_isSubmitting
                          ? 'Menyimpan…'
                          : 'Simpan & Hantar ke Ketua Jabatan'),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ─── Form ────────────────────────────────────────────────

  Widget _buildAssignmentForm() {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nama Subjek',
              style:
                  TextStyle(color: EHadirTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _subjectCtrl,
            decoration: const InputDecoration(
              hintText: 'Contoh: Electrical Circuit Theory 1',
              prefixIcon: Icon(Icons.book_outlined,
                  color: EHadirTheme.textSecondary, size: 20),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kod Subjek (pilihan)',
                        style: TextStyle(
                            color: EHadirTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _subjectCodeCtrl,
                      decoration: const InputDecoration(
                        hintText: 'DEV10043',
                        prefixIcon: Icon(Icons.qr_code_2_rounded,
                            color: EHadirTheme.textSecondary, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kelas',
                        style: TextStyle(
                            color: EHadirTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _classCtrl,
                      decoration: const InputDecoration(
                        hintText: 'DED 1A',
                        prefixIcon: Icon(Icons.class_rounded,
                            color: EHadirTheme.textSecondary, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Pensyarah',
              style:
                  TextStyle(color: EHadirTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          _loadingLecturers
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ))
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
                          style:
                              TextStyle(color: EHadirTheme.textSecondary)),
                      dropdownColor: EHadirTheme.card,
                      style: const TextStyle(
                          color: EHadirTheme.textPrimary, fontSize: 15),
                      items: _lecturers
                          .map((l) => DropdownMenuItem(
                              value: l.id, child: Text(l.name)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
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
    );
  }

  // ─── Header & CTA ────────────────────────────────────────

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
            child: const Icon(Icons.assignment_ind_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tugaskan Subjek Pensyarah',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text(
                    'Tetapkan subjek yang akan diajar oleh setiap pensyarah dalam program anda',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTugaskanSubjekCard() {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TugaskanSubjekScreen()),
      ),
      borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: EHadirTheme.card,
          borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
          border: Border.all(
              color: EHadirTheme.approved.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: EHadirTheme.approved.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
              ),
              child: const Icon(Icons.library_books_rounded,
                  color: EHadirTheme.approved, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tugaskan Banyak Subjek (dari Katalog)',
                      style: TextStyle(
                          color: EHadirTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text(
                      'Pilih subjek dari senarai program dan tugaskan kepada pensyarah',
                      style: TextStyle(
                          color: EHadirTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: EHadirTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  // ─── Success view ────────────────────────────────────────

  Widget _buildSuccessView() {
    return Center(
      child: FadeTransition(
        opacity: _fadeIn,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: EHadirTheme.approved.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded,
                    color: EHadirTheme.approved, size: 64),
              ),
              const SizedBox(height: 24),
              const Text('Tugasan Berjaya Disimpan!',
                  style: TextStyle(
                      color: EHadirTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Tugasan ini akan dilihat oleh Ketua Jabatan untuk '
                'penetapan tarikh, masa, dan bilik.',
                style: TextStyle(
                    color: EHadirTheme.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _resetForm,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Tugaskan Subjek Lain'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tiny helpers ────────────────────────────────────────

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(
          color: EHadirTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700));

  Widget _cardContainer({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: EHadirTheme.card,
            borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
            border: Border.all(color: EHadirTheme.divider)),
        child: child,
      );
}
