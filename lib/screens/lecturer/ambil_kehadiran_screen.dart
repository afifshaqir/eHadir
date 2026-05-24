import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../services/mock_db_service.dart';
import '../../models/class_slot_model.dart';
import '../../theme.dart';

class AmbilKehadiranScreen extends ConsumerStatefulWidget {
  final String? initialSlotId;
  const AmbilKehadiranScreen({super.key, this.initialSlotId});

  @override
  ConsumerState<AmbilKehadiranScreen> createState() => _AmbilKehadiranScreenState();
}

class _AmbilKehadiranScreenState extends ConsumerState<AmbilKehadiranScreen> {
  String? _selectedSlotId;
  ClassSlotModel? _currentSlot;

  @override
  void initState() {
    super.initState();
    if (widget.initialSlotId != null) {
      _selectedSlotId = widget.initialSlotId;
      // Need to resolve slot after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolveSlot();
      });
    }
  }

  void _resolveSlot() {
    if (_selectedSlotId == null) return;
    final db = ref.read(mockDbProvider);
    final userId = ref.read(authProvider).currentUser!.id;
    final slots = db.getClassSlotsForLecturer(userId);
    try {
      setState(() {
        _currentSlot = slots.firstWhere((s) => s.id == _selectedSlotId);
      });
    } catch (_) {
      _currentSlot = null;
    }
  }

  @override
  void didUpdateWidget(covariant AmbilKehadiranScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSlotId != oldWidget.initialSlotId && widget.initialSlotId != null) {
       setState(() {
         _selectedSlotId = widget.initialSlotId;
       });
       _resolveSlot();
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(mockDbProvider);
    final auth = ref.watch(authProvider);
    final slots = db.getClassSlotsForLecturer(auth.currentUser!.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ambil Kehadiran'),
      ),
      body: Column(
        children: [
          // ── Selection Header ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: EHadirTheme.card,
              border: Border(bottom: BorderSide(color: EHadirTheme.divider)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pilih Kelas',
                    style: TextStyle(
                        color: EHadirTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: EHadirTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSlotId,
                      isExpanded: true,
                      hint: const Text('Sila pilih slot jadual',
                          style: TextStyle(color: EHadirTheme.textSecondary)),
                      dropdownColor: EHadirTheme.card,
                      style: const TextStyle(color: EHadirTheme.textPrimary, fontSize: 15),
                      items: slots.map((s) {
                        return DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.subjectName} (${s.program})'),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedSlotId = v;
                          _currentSlot = slots.firstWhere((s) => s.id == v);
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Data Table ───────────────────────────────────────
          Expanded(
            child: _currentSlot == null
                ? const Center(
                    child: Text('Sila pilih kelas untuk mengambil kehadiran.',
                        style: TextStyle(color: EHadirTheme.textSecondary)))
                : _buildAttendanceTable(db, _currentSlot!),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTable(MockDatabaseService db, ClassSlotModel slot) {
    final students = db.getStudentsForProgram(slot.program);

    if (students.isEmpty) {
      return const Center(
        child: Text('Tiada pelajar berdaftar untuk program ini.',
            style: TextStyle(color: EHadirTheme.textSecondary)),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: EHadirTheme.card,
              borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
              border: Border.all(color: EHadirTheme.divider),
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(EHadirTheme.surfaceLight),
              dataRowMinHeight: 60,
              dataRowMaxHeight: 60,
              columns: [
                const DataColumn(label: Text('Nama Pelajar', style: TextStyle(fontWeight: FontWeight.w600))),
                ...List.generate(14, (i) => DataColumn(label: Text('M${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600)))),
                const DataColumn(label: Text('%', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
              rows: students.map((s) {
                final pct = s.getAttendancePercentage(slot.subjectName);
                final isWarning = pct < 80.0 && pct > 0.0;
                
                return DataRow(
                  cells: [
                    DataCell(Text(s.name, style: const TextStyle(color: EHadirTheme.textPrimary))),
                    ...List.generate(14, (weekIndex) {
                      final statuses = s.attendanceBySubject[slot.subjectName] ?? List.filled(14, '');
                      final status = statuses[weekIndex];
                      
                      return DataCell(
                        _buildStatusDropdown(status, (newStatus) {
                          ref.read(mockDbProvider).updateAttendance(s.id, slot.subjectName, weekIndex, newStatus);
                        }),
                      );
                    }),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isWarning ? EHadirTheme.rejected.withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: isWarning ? EHadirTheme.rejected : EHadirTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(String currentVal, Function(String) onChanged) {
    Color getStatusColor(String val) {
      switch (val) {
        case 'H': return const Color(0xFF4CAF50);
        case 'T': return const Color(0xFFE53935);
        case 'MC': return const Color(0xFFFFB300);
        default: return EHadirTheme.textSecondary.withValues(alpha: 0.5);
      }
    }

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: currentVal.isEmpty ? null : currentVal,
        hint: const Text('-', style: TextStyle(color: EHadirTheme.textSecondary)),
        dropdownColor: EHadirTheme.card,
        icon: const SizedBox.shrink(),
        style: TextStyle(color: getStatusColor(currentVal), fontWeight: FontWeight.w700),
        items: const [
          DropdownMenuItem(value: 'H', child: Text('H')),
          DropdownMenuItem(value: 'T', child: Text('T')),
          DropdownMenuItem(value: 'MC', child: Text('MC')),
          DropdownMenuItem(value: '', child: Text('-')),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
