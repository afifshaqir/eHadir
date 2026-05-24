import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../services/auth_service.dart';
import '../../services/mock_db_service.dart';
import '../../models/discipline_report_model.dart';
import '../../theme.dart';

class LaporDisiplinScreen extends ConsumerStatefulWidget {
  const LaporDisiplinScreen({super.key});

  @override
  ConsumerState<LaporDisiplinScreen> createState() => _LaporDisiplinScreenState();
}

class _LaporDisiplinScreenState extends ConsumerState<LaporDisiplinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _uuid = const Uuid();
  bool _isSubmitting = false;

  String? _selectedStudentId;
  String? _selectedStudentName;
  SeverityLevel _selectedSeverity = SeverityLevel.ringan;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudentId == null) {
      _showSnack('Sila pilih pelajar', EHadirTheme.rejected);
      return;
    }

    setState(() => _isSubmitting = true);

    final db = ref.read(mockDbProvider);
    final auth = ref.read(authProvider);
    final current = auth.currentUser!;

    final report = DisciplineReportModel(
      id: _uuid.v4(),
      studentName: _selectedStudentName!,
      studentId: _selectedStudentId!,
      issueDescription: _descCtrl.text.trim(),
      severityLevel: _selectedSeverity,
      program: current.program, // Tied to lecturer's program
      reportedBy: current.id,
      reportedByName: current.name,
      reportedAt: DateTime.now(),
    );

    await Future.delayed(const Duration(milliseconds: 300));
    db.submitDisciplineReport(report);

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _descCtrl.clear();
        _selectedStudentId = null;
        _selectedStudentName = null;
        _selectedSeverity = SeverityLevel.ringan;
      });
      _showSnack('Laporan disiplin berjaya dihantar ke Ketua Program & Ketua Jabatan.', EHadirTheme.approved);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(mockDbProvider);
    final auth = ref.watch(authProvider);
    final current = auth.currentUser!;
    final students = db.getStudentsForProgram(current.program);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lapor Disiplin'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: EHadirTheme.pending.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
                  border: Border.all(color: EHadirTheme.pending.withValues(alpha: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: EHadirTheme.pending),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Laporan ini akan terus dihantar kepada Ketua Program (${current.program}) dan Ketua Jabatan untuk tindakan lanjut.',
                        style: const TextStyle(color: EHadirTheme.textPrimary, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Student
              _label('Pelajar'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: EHadirTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStudentId,
                    isExpanded: true,
                    hint: const Text('Pilih pelajar', style: TextStyle(color: EHadirTheme.textSecondary)),
                    dropdownColor: EHadirTheme.card,
                    style: const TextStyle(color: EHadirTheme.textPrimary, fontSize: 15),
                    items: students.map((s) {
                      return DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      final stu = students.firstWhere((s) => s.id == v);
                      setState(() {
                        _selectedStudentId = v;
                        _selectedStudentName = stu.name;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Severity
              _label('Tahap Keterukan'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: EHadirTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SeverityLevel>(
                    value: _selectedSeverity,
                    isExpanded: true,
                    dropdownColor: EHadirTheme.card,
                    style: const TextStyle(color: EHadirTheme.textPrimary, fontSize: 15),
                    items: SeverityLevel.values.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(s.label),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedSeverity = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Description
              _label('Keterangan Isu'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 5,
                style: const TextStyle(color: EHadirTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Terangkan salah laku pelajar secara terperinci...',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Sila masukkan keterangan' : null,
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitReport,
                  icon: _isSubmitting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: Text(_isSubmitting ? 'Menghantar...' : 'Hantar Laporan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EHadirTheme.rejected,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text,
        style: const TextStyle(
            color: EHadirTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600));
  }
}
