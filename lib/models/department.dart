/// Departments (Jabatan) at IKM Johor Bahru, mapped to the diploma /
/// certificate programs they oversee.
///
/// A Ketua Jabatan's `program` field on [AppUser] stores the *department key*
/// (e.g. "Elektrik") and uses this map to fetch every program under their
/// scope when building timetables / viewing assignments.
class Department {
  static const String elektrik = 'Jabatan Elektrik';
  static const String mekanikal = 'Jabatan Mekanikal';
  static const String marin = 'Jabatan Marin';
  static const String gas = 'Jabatan Gas';
  static const String kimpalan = 'Jabatan Kimpalan';
  static const String pembuatan = 'Jabatan Pembuatan & Logam';

  /// Department → list of program keys (matches the [kPrograms] prefixes).
  static const Map<String, List<String>> programsOf = {
    elektrik:  ['DCB', 'DCP', 'DED', 'DEK'],
    mekanikal: ['DGM', 'DPP'],
    marin:     ['DMM', 'SMM'],
    gas:       ['DGS'],
    kimpalan:  ['ITW'],
    pembuatan: ['IMF', 'SLR', 'SMI', 'SMK'],
  };

  static List<String> all = const [
    elektrik,
    mekanikal,
    marin,
    gas,
    kimpalan,
    pembuatan,
  ];

  /// Find which department a [programKey] (e.g. "DED") belongs to.
  static String? departmentOfProgram(String programKey) {
    for (final entry in programsOf.entries) {
      if (entry.value.contains(programKey)) return entry.key;
    }
    return null;
  }

  /// Extract the short program key from a full program label.
  /// e.g. "DED — Diploma Teknologi …" → "DED".
  static String programKeyOf(String fullProgram) {
    final t = fullProgram.trim();
    if (t.length < 3) return t;
    return t.split(RegExp(r'\s|—|-')).first;
  }
}
