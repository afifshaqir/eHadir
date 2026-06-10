import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/attendance_record.dart';
import '../../models/discipline_report_model.dart';
import '../../models/lecturer_assignment.dart';
import '../../models/user.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/curriculum_service.dart';
import '../../services/mock_db_service.dart';
import '../../services/reporting_service.dart';
import '../../theme.dart';

/// Module 3 — Reporting Module.
///
/// Role-scoped analytical dashboard:
///   • Pensyarah    → own assigned classes
///   • Ketua Program → program-wide
///   • Ketua Jabatan → program + lecturer performance
///   • TPA          → cross-program comparison
///   • Admin        → falls back to TPA view
class ReportingScreen extends ConsumerWidget {
  const ReportingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.currentUser;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (user.role) {
      case UserRole.pensyarah:
        return _PensyarahReport(user: user);
      case UserRole.ketuaProgram:
        return _KetuaProgramReport(user: user);
      case UserRole.ketuaJabatan:
        return _KetuaJabatanReport(user: user);
      case UserRole.timbalanPengarahAkademik:
      case UserRole.admin:
        return const _TPAReport();
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  PENSYARAH — own classes
// ═══════════════════════════════════════════════════════════════

class _PensyarahReport extends ConsumerStatefulWidget {
  final AppUser user;
  const _PensyarahReport({required this.user});

  @override
  ConsumerState<_PensyarahReport> createState() => _PensyarahReportState();
}

class _PensyarahReportState extends ConsumerState<_PensyarahReport> {
  LecturerAssignment? _selected;

  @override
  Widget build(BuildContext context) {
    final curriculum = ref.watch(curriculumServiceProvider);

    return StreamBuilder<List<LecturerAssignment>>(
      stream: curriculum.streamAssignmentsForLecturer(widget.user.id),
      builder: (ctx, snap) {
        final assignments = snap.data ?? const <LecturerAssignment>[];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (assignments.isEmpty) {
          return const _EmptyState(
            icon: Icons.insights_rounded,
            message:
                'Belum ada subjek ditugaskan kepada anda — laporan akan muncul '
                'sebaik sahaja Ketua Program menugaskan kelas.',
          );
        }

        _selected ??= assignments.first;
        final sel = _selected!;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            _HeroHeader(
              title: 'Statistik Kelas Saya',
              subtitle:
                  '${assignments.length} kelas ditugaskan · ${widget.user.program.split(' ').first}',
              icon: Icons.bar_chart_rounded,
            ),
            const SizedBox(height: 16),
            _ClassSwitcher(
              assignments: assignments,
              selected: sel,
              onChanged: (a) => setState(() => _selected = a),
            ),
            const SizedBox(height: 16),
            _ClassKpiRow(assignment: sel),
            const SizedBox(height: 16),
            _SectionTitle('Trend Mingguan (M1 – M14)'),
            const SizedBox(height: 8),
            _WeeklyTrendCard(
              subjectCode: sel.subjectCode,
              studentClass: sel.studentClass,
            ),
            const SizedBox(height: 16),
            _SectionTitle('Pelajar Berisiko (< 80%)'),
            const SizedBox(height: 8),
            _AtRiskCard(assignment: sel),
          ],
        );
      },
    );
  }
}

class _ClassSwitcher extends StatelessWidget {
  final List<LecturerAssignment> assignments;
  final LecturerAssignment selected;
  final ValueChanged<LecturerAssignment> onChanged;
  const _ClassSwitcher({
    required this.assignments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: EHadirTheme.card,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
        border: Border.all(color: EHadirTheme.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected.id.isEmpty
              ? '${selected.subjectCode}__${selected.studentClass}'
              : selected.id,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded,
              color: EHadirTheme.textSecondary),
          items: assignments.map((a) {
            final key = a.id.isEmpty
                ? '${a.subjectCode}__${a.studentClass}'
                : a.id;
            return DropdownMenuItem(
              value: key,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: EHadirTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(a.subjectCode,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: EHadirTheme.primary)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${a.subjectName} · ${a.studentClass}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: EHadirTheme.textPrimary)),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (key) {
            if (key == null) return;
            final next = assignments.firstWhere((a) =>
                (a.id.isEmpty
                    ? '${a.subjectCode}__${a.studentClass}'
                    : a.id) ==
                key);
            onChanged(next);
          },
        ),
      ),
    );
  }
}

class _ClassKpiRow extends ConsumerWidget {
  final LecturerAssignment assignment;
  const _ClassKpiRow({required this.assignment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance = ref.watch(attendanceServiceProvider);

    return StreamBuilder<ClassAttendance?>(
      stream: attendance.streamClassAttendance(
        subjectCode: assignment.subjectCode,
        studentClass: assignment.studentClass,
      ),
      builder: (ctx, snap) {
        final c = snap.data;
        final totalStudents = c?.weeks.length ?? 0;
        double avg = 0;
        int atRisk = 0;
        int taken = 0;
        if (c != null && totalStudents > 0) {
          double sum = 0;
          for (final sid in c.weeks.keys) {
            final pct = c.percentageFor(sid);
            sum += pct;
            if (pct > 0 && pct < ReportingService.atRiskThreshold) atRisk++;
            taken += c.weeks[sid]!.where((e) => e.isNotEmpty).length;
          }
          avg = sum / totalStudents;
        }

        return Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Purata Kehadiran',
                value: '${avg.toStringAsFixed(0)}%',
                icon: Icons.percent_rounded,
                color: avg >= ReportingService.atRiskThreshold
                    ? EHadirTheme.approved
                    : EHadirTheme.rejected,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                label: 'Pelajar Berisiko',
                value: '$atRisk',
                icon: Icons.warning_amber_rounded,
                color: atRisk == 0
                    ? EHadirTheme.approved
                    : EHadirTheme.rejected,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                label: 'Sesi Diambil',
                value: '$taken',
                icon: Icons.fact_check_rounded,
                color: EHadirTheme.primary,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WeeklyTrendCard extends ConsumerWidget {
  final String subjectCode;
  final String studentClass;
  const _WeeklyTrendCard({
    required this.subjectCode,
    required this.studentClass,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reporting = ref.watch(reportingServiceProvider);
    return _ChartCard(
      child: StreamBuilder<List<double>>(
        stream: reporting.classWeeklyTrend(
          subjectCode: subjectCode,
          studentClass: studentClass,
        ),
        builder: (ctx, snap) {
          final data = snap.data ?? const <double>[];
          if (data.every((d) => d == 0)) {
            return const _EmptyChart(
                text: 'Tiada kehadiran direkodkan lagi untuk kelas ini.');
          }
          return _LineTrendChart(values: data);
        },
      ),
    );
  }
}

class _AtRiskCard extends ConsumerWidget {
  final LecturerAssignment assignment;
  const _AtRiskCard({required this.assignment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(mockDbProvider);
    final reporting = ref.watch(reportingServiceProvider);
    final students = db.getStudentsForClass(assignment.studentClass,
        program: assignment.program);
    final nameMap = {for (final s in students) s.id: s.name};

    return StreamBuilder<List<AtRiskStudent>>(
      stream: reporting.classAtRiskStudents(
        subjectCode: assignment.subjectCode,
        studentClass: assignment.studentClass,
        studentNames: nameMap,
      ),
      builder: (ctx, snap) {
        final list = snap.data ?? const <AtRiskStudent>[];
        if (list.isEmpty) {
          return _InfoCard(
            color: EHadirTheme.approved,
            icon: Icons.check_circle_rounded,
            text:
                'Tiada pelajar di bawah 80%. Teruskan menggalakkan kehadiran!',
          );
        }
        return _AtRiskList(items: list);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  KETUA PROGRAM — program-wide
// ═══════════════════════════════════════════════════════════════

class _KetuaProgramReport extends ConsumerWidget {
  final AppUser user;
  const _KetuaProgramReport({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reporting = ref.watch(reportingServiceProvider);
    final db = ref.watch(mockDbProvider);
    final students = db.getStudentsForProgram(user.program);
    final nameMap = {for (final s in students) s.id: s.name};
    final reports = db.getReportsForProgram(user.program);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _HeroHeader(
          title: 'Statistik Program',
          subtitle: user.program,
          icon: Icons.school_rounded,
        ),
        const SizedBox(height: 16),
        _ProgramKpiRow(program: user.program, disciplineCount: reports.length),
        const SizedBox(height: 16),
        _SectionTitle('Purata Kehadiran Mengikut Kelas'),
        const SizedBox(height: 8),
        _ChartCard(
          child: StreamBuilder<Map<String, double>>(
            stream: reporting.programPercentageByClass(user.program),
            builder: (ctx, snap) {
              final data = snap.data ?? const {};
              if (data.isEmpty) {
                return const _EmptyChart(
                    text: 'Belum ada data kehadiran untuk program ini.');
              }
              return _BarBreakdownChart(data: data);
            },
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle('Trend Mingguan Program'),
        const SizedBox(height: 8),
        _ChartCard(
          child: StreamBuilder<List<double>>(
            stream: reporting.programWeeklyTrend(user.program),
            builder: (ctx, snap) {
              final data = snap.data ?? const <double>[];
              if (data.every((d) => d == 0)) {
                return const _EmptyChart(
                    text: 'Belum ada trend mingguan untuk dipaparkan.');
              }
              return _LineTrendChart(values: data);
            },
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle('Laporan Disiplin'),
        const SizedBox(height: 8),
        _DisciplineBreakdownSection(reports: reports),
        const SizedBox(height: 16),
        _SectionTitle('Pelajar Berisiko (< 80%)'),
        const SizedBox(height: 8),
        StreamBuilder<List<AtRiskStudent>>(
          stream: reporting.programAtRiskStudents(
            program: user.program,
            studentNames: nameMap,
          ),
          builder: (ctx, snap) {
            final list = snap.data ?? const <AtRiskStudent>[];
            if (list.isEmpty) {
              return _InfoCard(
                color: EHadirTheme.approved,
                icon: Icons.check_circle_rounded,
                text: 'Tiada pelajar di bawah 80% dalam program ini.',
              );
            }
            return _AtRiskList(items: list);
          },
        ),
      ],
    );
  }
}

class _ProgramKpiRow extends ConsumerWidget {
  final String program;
  final int disciplineCount;
  const _ProgramKpiRow({
    required this.program,
    required this.disciplineCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reporting = ref.watch(reportingServiceProvider);

    return StreamBuilder<Map<String, double>>(
      stream: reporting.programPercentageByClass(program),
      builder: (ctx, snap) {
        final data = snap.data ?? const <String, double>{};
        final avg = data.isEmpty
            ? 0.0
            : data.values.reduce((a, b) => a + b) / data.length;
        final atRiskClasses =
            data.values.where((v) => v < ReportingService.atRiskThreshold).length;

        return Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Purata Program',
                value: '${avg.toStringAsFixed(0)}%',
                icon: Icons.percent_rounded,
                color: avg >= ReportingService.atRiskThreshold
                    ? EHadirTheme.approved
                    : EHadirTheme.rejected,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                label: 'Kelas Berisiko',
                value: '$atRiskClasses',
                icon: Icons.warning_amber_rounded,
                color: atRiskClasses == 0
                    ? EHadirTheme.approved
                    : EHadirTheme.rejected,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                label: 'Lapor Disiplin',
                value: '$disciplineCount',
                icon: Icons.gavel_rounded,
                color: EHadirTheme.primary,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  KETUA JABATAN — adds lecturer performance
// ═══════════════════════════════════════════════════════════════

class _KetuaJabatanReport extends ConsumerWidget {
  final AppUser user;
  const _KetuaJabatanReport({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reporting = ref.watch(reportingServiceProvider);
    final db = ref.watch(mockDbProvider);
    final reports = db.getReportsForProgram(user.program);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _HeroHeader(
          title: 'Statistik Jabatan',
          subtitle: user.program,
          icon: Icons.corporate_fare_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFFE64A19), Color(0xFFFF7043)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        const SizedBox(height: 16),
        _ProgramKpiRow(program: user.program, disciplineCount: reports.length),
        const SizedBox(height: 16),
        _SectionTitle('Prestasi Pensyarah'),
        const SizedBox(height: 8),
        _LecturerPerformanceCard(program: user.program),
        const SizedBox(height: 16),
        _SectionTitle('Trend Mingguan Program'),
        const SizedBox(height: 8),
        _ChartCard(
          child: StreamBuilder<List<double>>(
            stream: reporting.programWeeklyTrend(user.program),
            builder: (ctx, snap) {
              final data = snap.data ?? const <double>[];
              if (data.every((d) => d == 0)) {
                return const _EmptyChart(
                    text: 'Belum ada trend mingguan untuk dipaparkan.');
              }
              return _LineTrendChart(values: data);
            },
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle('Laporan Disiplin'),
        const SizedBox(height: 8),
        _DisciplineBreakdownSection(reports: reports),
      ],
    );
  }
}

class _LecturerPerformanceCard extends ConsumerWidget {
  final String program;
  const _LecturerPerformanceCard({required this.program});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reporting = ref.watch(reportingServiceProvider);
    return StreamBuilder<Map<String, LecturerPerformance>>(
      stream: reporting.programPercentageByLecturer(program),
      builder: (ctx, snap) {
        final data = snap.data ?? const <String, LecturerPerformance>{};
        if (data.isEmpty) {
          return _InfoCard(
            color: EHadirTheme.textSecondary,
            icon: Icons.info_outline_rounded,
            text: 'Belum ada data prestasi pensyarah.',
          );
        }
        final sorted = data.entries.toList()
          ..sort((a, b) => b.value.average.compareTo(a.value.average));
        return Container(
          decoration: BoxDecoration(
            color: EHadirTheme.card,
            borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
            border: Border.all(color: EHadirTheme.divider),
          ),
          child: Column(
            children: [
              for (final e in sorted)
                _LecturerRow(name: e.value.name, average: e.value.average),
            ],
          ),
        );
      },
    );
  }
}

class _LecturerRow extends StatelessWidget {
  final String name;
  final double average;
  const _LecturerRow({required this.name, required this.average});

  @override
  Widget build(BuildContext context) {
    final color = average >= ReportingService.atRiskThreshold
        ? EHadirTheme.approved
        : EHadirTheme.rejected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: EHadirTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 80,
              height: 6,
              child: LinearProgressIndicator(
                value: (average / 100).clamp(0.0, 1.0),
                backgroundColor: EHadirTheme.surfaceLight,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(
              '${average.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TPA — cross-program
// ═══════════════════════════════════════════════════════════════

class _TPAReport extends ConsumerWidget {
  const _TPAReport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reporting = ref.watch(reportingServiceProvider);
    final db = ref.watch(mockDbProvider);
    final allReports = db.allDisciplineReports;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _HeroHeader(
          title: 'Pemantauan Global',
          subtitle: 'Semua Program · ${allReports.length} laporan disiplin',
          icon: Icons.stars_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFFF57F17), Color(0xFFFFD54F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle('Purata Kehadiran Mengikut Program'),
        const SizedBox(height: 8),
        _ChartCard(
          child: StreamBuilder<Map<String, double>>(
            stream: reporting.percentageByProgram(),
            builder: (ctx, snap) {
              final data = snap.data ?? const {};
              if (data.isEmpty) {
                return const _EmptyChart(
                    text: 'Belum ada data merentas program.');
              }
              return _BarBreakdownChart(data: data, abbreviate: true);
            },
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle('Pecahan Laporan Disiplin (Semua Program)'),
        const SizedBox(height: 8),
        _DisciplineDonutCard(reports: allReports),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════

class _HeroHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient? gradient;
  const _HeroHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient ?? EHadirTheme.primaryGradient,
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
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            color: EHadirTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800),
      );
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EHadirTheme.card,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
        border: Border.all(color: EHadirTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(EHadirTheme.radiusSm),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.0)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: EHadirTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final Widget child;
  const _ChartCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(14, 18, 18, 14),
      decoration: BoxDecoration(
        color: EHadirTheme.card,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
        border: Border.all(color: EHadirTheme.divider),
      ),
      child: child,
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String text;
  const _EmptyChart({required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: EHadirTheme.textSecondary, fontSize: 12)),
      );
}

class _InfoCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  const _InfoCard({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 60,
                color: EHadirTheme.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: EHadirTheme.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─── Charts ──────────────────────────────────────────────────

class _LineTrendChart extends StatelessWidget {
  /// Length must be `ClassAttendance.weeksPerSemester` (14).
  final List<double> values;
  const _LineTrendChart({required this.values});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (int i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) => FlLine(
            color: EHadirTheme.divider,
            strokeWidth: 1,
            dashArray: const [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 25,
              getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                  style: const TextStyle(
                      color: EHadirTheme.textSecondary, fontSize: 9)),
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (v, _) {
                final w = v.toInt();
                if (w < 0 || w >= values.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('M${w + 1}',
                      style: const TextStyle(
                          color: EHadirTheme.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: EHadirTheme.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                radius: 3,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: EHadirTheme.primary,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: EHadirTheme.primary.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarBreakdownChart extends StatelessWidget {
  final Map<String, double> data;
  final bool abbreviate;
  const _BarBreakdownChart({required this.data, this.abbreviate = false});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < entries.length; i++) {
      final pct = entries[i].value;
      final color = pct >= ReportingService.atRiskThreshold
          ? EHadirTheme.approved
          : EHadirTheme.rejected;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: pct,
              width: 18,
              color: color,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: 100,
                color: EHadirTheme.surfaceLight,
              ),
            ),
          ],
        ),
      );
    }
    return BarChart(
      BarChartData(
        maxY: 100,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) => FlLine(
            color: EHadirTheme.divider,
            strokeWidth: 1,
            dashArray: const [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 25,
              getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                  style: const TextStyle(
                      color: EHadirTheme.textSecondary, fontSize: 9)),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) {
                  return const SizedBox.shrink();
                }
                final raw = entries[i].key;
                final label = abbreviate
                    ? raw.split(' ').first
                    : raw.length > 9
                        ? raw.substring(0, 9)
                        : raw;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label,
                      style: const TextStyle(
                          color: EHadirTheme.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600)),
                );
              },
            ),
          ),
        ),
        barGroups: groups,
      ),
    );
  }
}

class _DisciplineDonutCard extends StatelessWidget {
  final List<DisciplineReportModel> reports;
  const _DisciplineDonutCard({required this.reports});

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return _InfoCard(
        color: EHadirTheme.approved,
        icon: Icons.check_circle_rounded,
        text: 'Tiada laporan disiplin direkodkan.',
      );
    }
    final ringan =
        reports.where((r) => r.severityLevel == SeverityLevel.ringan).length;
    final sederhana =
        reports.where((r) => r.severityLevel == SeverityLevel.sederhana).length;
    final serius =
        reports.where((r) => r.severityLevel == SeverityLevel.serius).length;
    final total = reports.length;

    final sections = <PieChartSectionData>[
      if (ringan > 0)
        PieChartSectionData(
          value: ringan.toDouble(),
          color: const Color(0xFF2E7D32),
          title: '$ringan',
          titleStyle: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
          radius: 38,
        ),
      if (sederhana > 0)
        PieChartSectionData(
          value: sederhana.toDouble(),
          color: const Color(0xFFF57F17),
          title: '$sederhana',
          titleStyle: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
          radius: 38,
        ),
      if (serius > 0)
        PieChartSectionData(
          value: serius.toDouble(),
          color: const Color(0xFFC62828),
          title: '$serius',
          titleStyle: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
          radius: 38,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EHadirTheme.card,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
        border: Border.all(color: EHadirTheme.divider),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 32,
                    sectionsSpace: 2,
                    startDegreeOffset: -90,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$total',
                        style: const TextStyle(
                            color: EHadirTheme.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    const Text('jumlah',
                        style: TextStyle(
                            color: EHadirTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Legend(
                    color: const Color(0xFF2E7D32),
                    label: 'Ringan',
                    count: ringan),
                const SizedBox(height: 8),
                _Legend(
                    color: const Color(0xFFF57F17),
                    label: 'Sederhana',
                    count: sederhana),
                const SizedBox(height: 8),
                _Legend(
                    color: const Color(0xFFC62828),
                    label: 'Serius',
                    count: serius),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// KP / KJ section combining the severity donut + filter chips + a
/// scrollable list of the actual discipline reports. Tapping a donut wedge
/// or a chip filters the list. Same widget for both roles.
class _DisciplineBreakdownSection extends StatefulWidget {
  final List<DisciplineReportModel> reports;
  const _DisciplineBreakdownSection({required this.reports});

  @override
  State<_DisciplineBreakdownSection> createState() =>
      _DisciplineBreakdownSectionState();
}

class _DisciplineBreakdownSectionState
    extends State<_DisciplineBreakdownSection> {
  SeverityLevel? _filter;
  bool _expanded = true;

  static const _maxCollapsed = 3;

  Color _colorFor(SeverityLevel s) {
    switch (s) {
      case SeverityLevel.ringan:
        return const Color(0xFF2E7D32);
      case SeverityLevel.sederhana:
        return const Color(0xFFF57F17);
      case SeverityLevel.serius:
        return const Color(0xFFC62828);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = widget.reports;
    if (reports.isEmpty) {
      return _InfoCard(
        color: EHadirTheme.approved,
        icon: Icons.check_circle_rounded,
        text: 'Tiada laporan disiplin direkodkan.',
      );
    }

    final ringan = reports
        .where((r) => r.severityLevel == SeverityLevel.ringan)
        .length;
    final sederhana = reports
        .where((r) => r.severityLevel == SeverityLevel.sederhana)
        .length;
    final serius = reports
        .where((r) => r.severityLevel == SeverityLevel.serius)
        .length;

    final filtered = _filter == null
        ? reports
        : reports.where((r) => r.severityLevel == _filter).toList();
    final visible = _expanded || filtered.length <= _maxCollapsed
        ? filtered
        : filtered.take(_maxCollapsed).toList();

    return Container(
      decoration: BoxDecoration(
        color: EHadirTheme.card,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
        border: Border.all(color: EHadirTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Donut + legend ───────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: _TappableDonut(
                    ringan: ringan,
                    sederhana: sederhana,
                    serius: serius,
                    total: reports.length,
                    selected: _filter,
                    onTap: (s) => setState(() {
                      _filter = (_filter == s) ? null : s;
                      _expanded = true;
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LegendChip(
                        color: _colorFor(SeverityLevel.ringan),
                        label: 'Ringan',
                        count: ringan,
                        selected: _filter == SeverityLevel.ringan,
                        onTap: () => setState(() {
                          _filter = _filter == SeverityLevel.ringan
                              ? null
                              : SeverityLevel.ringan;
                          _expanded = true;
                        }),
                      ),
                      const SizedBox(height: 6),
                      _LegendChip(
                        color: _colorFor(SeverityLevel.sederhana),
                        label: 'Sederhana',
                        count: sederhana,
                        selected: _filter == SeverityLevel.sederhana,
                        onTap: () => setState(() {
                          _filter = _filter == SeverityLevel.sederhana
                              ? null
                              : SeverityLevel.sederhana;
                          _expanded = true;
                        }),
                      ),
                      const SizedBox(height: 6),
                      _LegendChip(
                        color: _colorFor(SeverityLevel.serius),
                        label: 'Serius',
                        count: serius,
                        selected: _filter == SeverityLevel.serius,
                        onTap: () => setState(() {
                          _filter = _filter == SeverityLevel.serius
                              ? null
                              : SeverityLevel.serius;
                          _expanded = true;
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: EHadirTheme.divider),

          // ─── Filter status row ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
            child: Row(
              children: [
                Icon(
                  _filter == null
                      ? Icons.list_alt_rounded
                      : Icons.filter_alt_rounded,
                  size: 14,
                  color: _filter == null
                      ? EHadirTheme.textSecondary
                      : _colorFor(_filter!),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _filter == null
                        ? 'Semua laporan (${filtered.length})'
                        : 'Ditapis: ${_filter!.label} (${filtered.length})',
                    style: TextStyle(
                      color: _filter == null
                          ? EHadirTheme.textSecondary
                          : _colorFor(_filter!),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_filter != null)
                  GestureDetector(
                    onTap: () => setState(() => _filter = null),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Icon(Icons.close_rounded,
                          size: 16, color: EHadirTheme.textSecondary),
                    ),
                  ),
              ],
            ),
          ),

          // ─── Reports list ─────────────────────────────────
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
              child: Text(
                'Tiada laporan ${_filter!.label.toLowerCase()}.',
                style: const TextStyle(
                    color: EHadirTheme.textSecondary, fontSize: 12),
              ),
            )
          else
            for (int i = 0; i < visible.length; i++) ...[
              _ReportRow(report: visible[i], color: _colorFor(visible[i].severityLevel)),
              if (i < visible.length - 1)
                const Divider(height: 1, color: EHadirTheme.divider),
            ],

          // ─── Show more / less ─────────────────────────────
          if (filtered.length > _maxCollapsed)
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: EHadirTheme.divider),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _expanded
                          ? 'Tunjuk kurang'
                          : 'Lihat semua (${filtered.length})',
                      style: const TextStyle(
                          color: EHadirTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: EHadirTheme.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TappableDonut extends StatelessWidget {
  final int ringan;
  final int sederhana;
  final int serius;
  final int total;
  final SeverityLevel? selected;
  final ValueChanged<SeverityLevel> onTap;
  const _TappableDonut({
    required this.ringan,
    required this.sederhana,
    required this.serius,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  PieChartSectionData _section({
    required SeverityLevel level,
    required int count,
    required Color color,
  }) {
    final isSel = selected == level;
    return PieChartSectionData(
      value: count.toDouble(),
      color: isSel ? color : color.withValues(alpha: selected == null ? 1.0 : 0.35),
      title: '$count',
      titleStyle: const TextStyle(
          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
      radius: isSel ? 44 : 38,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = <PieChartSectionData>[
      if (ringan > 0)
        _section(
            level: SeverityLevel.ringan,
            count: ringan,
            color: const Color(0xFF2E7D32)),
      if (sederhana > 0)
        _section(
            level: SeverityLevel.sederhana,
            count: sederhana,
            color: const Color(0xFFF57F17)),
      if (serius > 0)
        _section(
            level: SeverityLevel.serius,
            count: serius,
            color: const Color(0xFFC62828)),
    ];
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sections: sections,
            centerSpaceRadius: 32,
            sectionsSpace: 2,
            startDegreeOffset: -90,
            pieTouchData: PieTouchData(
              touchCallback: (event, response) {
                if (!event.isInterestedForInteractions) return;
                final idx = response?.touchedSection?.touchedSectionIndex;
                if (idx == null || idx < 0) return;
                // Map visible index back to severity level (sections are
                // added in order ringan → sederhana → serius, skipping zeros).
                final order = [
                  if (ringan > 0) SeverityLevel.ringan,
                  if (sederhana > 0) SeverityLevel.sederhana,
                  if (serius > 0) SeverityLevel.serius,
                ];
                if (idx < order.length) onTap(order[idx]);
              },
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$total',
                style: const TextStyle(
                    color: EHadirTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const Text('jumlah',
                style: TextStyle(
                    color: EHadirTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _LegendChip({
    required this.color,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(EHadirTheme.radiusSm),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.6)
                : EHadirTheme.divider,
          ),
        ),
        child: Row(
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: selected ? color : EHadirTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            Text('$count',
                style: TextStyle(
                    color: selected ? color : EHadirTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final DisciplineReportModel report;
  final Color color;
  const _ReportRow({required this.report, required this.color});

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReportDetailSheet(report: report, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showDetail(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(report.studentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: EHadirTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800)),
                      ),
                      Text(
                        DateFormat('dd MMM').format(report.reportedAt),
                        style: const TextStyle(
                            color: EHadirTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(report.issueDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: EHadirTheme.textSecondary,
                          fontSize: 12,
                          height: 1.3)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border:
                              Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                        child: Text(report.severityLevel.label,
                            style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('oleh ${report.reportedByName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: EHadirTheme.textSecondary,
                                fontSize: 11,
                                fontStyle: FontStyle.italic)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportDetailSheet extends StatelessWidget {
  final DisciplineReportModel report;
  final Color color;
  const _ReportDetailSheet({required this.report, required this.color});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EHadirTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(report.studentName,
                      style: const TextStyle(
                          color: EHadirTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Text(report.severityLevel.label,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'ID Pelajar: ${report.studentId}',
              style: const TextStyle(
                  color: EHadirTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 18),
            const Text('Keterangan',
                style: TextStyle(
                    color: EHadirTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EHadirTheme.surfaceLight,
                borderRadius: BorderRadius.circular(EHadirTheme.radiusSm),
              ),
              child: Text(report.issueDescription,
                  style: const TextStyle(
                      color: EHadirTheme.textPrimary,
                      fontSize: 13,
                      height: 1.45)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MetaTile(
                    icon: Icons.calendar_today_rounded,
                    label: 'Tarikh',
                    value: DateFormat('dd MMM yyyy, HH:mm')
                        .format(report.reportedAt),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetaTile(
                    icon: Icons.person_rounded,
                    label: 'Dilapor Oleh',
                    value: report.reportedByName,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MetaTile(
              icon: Icons.school_rounded,
              label: 'Program',
              value: report.program,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _MetaTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: EHadirTheme.surfaceLight,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusSm),
      ),
      child: Row(
        children: [
          Icon(icon, color: EHadirTheme.textSecondary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: EHadirTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6)),
                const SizedBox(height: 1),
                Text(value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: EHadirTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _Legend({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: EHadirTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
        Text('$count',
            style: const TextStyle(
                color: EHadirTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _AtRiskList extends StatelessWidget {
  final List<AtRiskStudent> items;
  const _AtRiskList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EHadirTheme.card,
        borderRadius: BorderRadius.circular(EHadirTheme.radiusMd),
        border: Border.all(color: EHadirTheme.divider),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _AtRiskRow(item: items[i]),
            if (i < items.length - 1)
              const Divider(height: 1, color: EHadirTheme.divider),
          ],
        ],
      ),
    );
  }
}

class _AtRiskRow extends StatelessWidget {
  final AtRiskStudent item;
  const _AtRiskRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final pct = item.percentage;
    final color =
        pct < 50 ? EHadirTheme.rejected : EHadirTheme.pending;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(EHadirTheme.radiusSm),
            ),
            child: const Icon(Icons.person_rounded,
                color: EHadirTheme.textSecondary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.studentName,
                    style: const TextStyle(
                        color: EHadirTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${item.studentClass} · ${item.subjectName} · ${item.absentCount} sesi T',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: EHadirTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(EHadirTheme.radiusSm),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text('${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
