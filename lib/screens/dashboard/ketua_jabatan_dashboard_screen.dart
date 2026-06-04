import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/mock_db_service.dart';
import '../../models/discipline_report_model.dart';
import '../../theme.dart';
import '../../utils/dialogs.dart';
import '../ketua_jabatan/bina_jadual_screen.dart';

class KetuaJabatanDashboardScreen extends ConsumerWidget {
  const KetuaJabatanDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final current = auth.currentUser!;
    final db = ref.watch(mockDbProvider);
    final reports = db.getReportsForProgram(current.program);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Log Keluar',
          onPressed: () => showLogoutConfirmation(context, ref),
        ),
        title: Text('Ketua Jabatan — ${current.program}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log Keluar',
            onPressed: () => showLogoutConfirmation(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE64A19), Color(0xFFFF7043)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
              boxShadow: EHadirTheme.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
                  ),
                  child: const Icon(Icons.corporate_fare_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Masalah Disiplin',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${reports.length} rekod dilaporkan untuk ${current.program}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bina Jadual entry
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BinaJadualScreen()),
              ),
              borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: EHadirTheme.card,
                  borderRadius: BorderRadius.circular(EHadirTheme.radiusLg),
                  border: Border.all(
                      color: EHadirTheme.primary.withValues(alpha: 0.4),
                      width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: EHadirTheme.primary.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(EHadirTheme.radiusMd),
                      ),
                      child: const Icon(Icons.calendar_view_week_rounded,
                          color: EHadirTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bina Jadual Mingguan',
                              style: TextStyle(
                                  color: EHadirTheme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                          SizedBox(height: 2),
                          Text(
                              'Susun hari, slot masa, dan bilik bagi setiap tugasan pensyarah',
                              style: TextStyle(
                                  color: EHadirTheme.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: EHadirTheme.textSecondary),
                  ],
                ),
              ),
            ),
          ),

          // Data Table
          Expanded(
            child: reports.isEmpty
                ? const Center(
                    child: Text('Tiada rekod disiplin dilaporkan.',
                        style: TextStyle(color: EHadirTheme.textSecondary)))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: EHadirTheme.card,
                            borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
                            border: Border.all(color: EHadirTheme.divider),
                          ),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                                EHadirTheme.surfaceLight),
                            dataRowMaxHeight: 80,
                            dataRowMinHeight: 60,
                            columns: const [
                              DataColumn(label: Text('Tarikh', style: TextStyle(fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Nama Pelajar', style: TextStyle(fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Masalah Disiplin', style: TextStyle(fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Tahap Keterukan', style: TextStyle(fontWeight: FontWeight.w600))),
                              DataColumn(label: Text('Dilapor Oleh', style: TextStyle(fontWeight: FontWeight.w600))),
                            ],
                            rows: reports.map((r) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(DateFormat('dd MMM yyyy').format(r.reportedAt),
                                      style: const TextStyle(color: EHadirTheme.textSecondary, fontSize: 13))),
                                  DataCell(Text(r.studentName,
                                      style: const TextStyle(color: EHadirTheme.textPrimary, fontWeight: FontWeight.w600))),
                                  DataCell(
                                    SizedBox(
                                      width: 200,
                                      child: Text(r.issueDescription,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: EHadirTheme.textSecondary, fontSize: 13)),
                                    ),
                                  ),
                                  DataCell(_severityBadge(r.severityLevel)),
                                  DataCell(Text(r.reportedByName,
                                      style: const TextStyle(color: EHadirTheme.textSecondary, fontSize: 13))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _severityBadge(SeverityLevel severity) {
    Color color;
    switch (severity) {
      case SeverityLevel.ringan:
        color = const Color(0xFF2E7D32); // Green
        break;
      case SeverityLevel.sederhana:
        color = const Color(0xFFF57F17); // Amber/Orange
        break;
      case SeverityLevel.serius:
        color = const Color(0xFFC62828); // Red
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        severity.label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
