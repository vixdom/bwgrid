class BuildInfo {
  // Provide BUILD_TIMESTAMP as an ISO8601 string via --dart-define
  // Example: --dart-define=BUILD_TIMESTAMP=2025-08-22T11:23:00Z
  static const String timestampRaw = String.fromEnvironment('BUILD_TIMESTAMP');

  static DateTime? get buildTime {
    if (timestampRaw.isEmpty) return null;
    try {
      return DateTime.parse(timestampRaw).toLocal();
    } catch (_) {
      return null;
    }
  }

  static String? get formatted {
    final t = buildTime;
    if (t == null) return null;
    String two(int v) => v.toString().padLeft(2, '0');
    final hh = two(t.hour);
    final mm = two(t.minute);
    final dd = two(t.day);
    final mon = two(t.month);
    final yy = t.year.toString().substring(2);
    return '$hh:$mm $dd $mon $yy';
  }
}
