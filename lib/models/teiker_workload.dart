class TeikerWorkload {
  const TeikerWorkload._();

  static const int fiftyPercent = 50;
  static const int seventyPercent = 70;
  static const int fullTime = 100;

  static const List<int> supportedPercentages = <int>[
    fiftyPercent,
    seventyPercent,
    fullTime,
  ];

  static bool isSupported(int percentage) =>
      supportedPercentages.contains(percentage);

  static int inferPercentageFromHours(double? weeklyHours) {
    if (weeklyHours == null) return fullTime;
    if (weeklyHours <= 25) return fiftyPercent;
    if (weeklyHours <= 34) return seventyPercent;
    return fullTime;
  }

  static int normalizePercentage(dynamic raw, {double? fallbackWeeklyHours}) {
    final parsed = raw is int ? raw : int.tryParse('$raw');
    if (parsed != null && isSupported(parsed)) return parsed;
    return inferPercentageFromHours(fallbackWeeklyHours);
  }

  static double weeklyHoursForPercentage(int percentage) {
    switch (percentage) {
      case fiftyPercent:
        return 21;
      case seventyPercent:
        return 29;
      case fullTime:
      default:
        return 40;
    }
  }

  static String labelForPercentage(int percentage) {
    switch (percentage) {
      case fiftyPercent:
        return 'Trabalha a 50%';
      case seventyPercent:
        return 'Trabalhar a 70%';
      case fullTime:
      default:
        return 'Trabalha 100%';
    }
  }
}
