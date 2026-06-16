import 'study_mode.dart';

/// A completed (or abandoned) study session — the atomic unit of learning data.
class StudySession {
  final StudyMode mode;
  final String subject;
  final int focusedMin;
  final int goalMin;
  final int hour; // 0–23, when the session ended
  final int? accuracy; // quiz mode: 0–100
  final DateTime date;
  final bool abandoned;

  const StudySession({
    required this.mode,
    required this.subject,
    required this.focusedMin,
    required this.goalMin,
    required this.hour,
    required this.date,
    this.accuracy,
    this.abandoned = false,
  });

  Map<String, dynamic> toMap() => {
        'mode': mode.name,
        'subject': subject,
        'focusedMin': focusedMin,
        'goalMin': goalMin,
        'hour': hour,
        'accuracy': accuracy,
        'date': date.toIso8601String(),
        'abandoned': abandoned,
      };

  factory StudySession.fromMap(Map<String, dynamic> m) => StudySession(
        mode: StudyMode.values.firstWhere((e) => e.name == m['mode'], orElse: () => StudyMode.free),
        subject: m['subject'] as String? ?? '기타',
        focusedMin: (m['focusedMin'] as num?)?.toInt() ?? 0,
        goalMin: (m['goalMin'] as num?)?.toInt() ?? 0,
        hour: (m['hour'] as num?)?.toInt() ?? 20,
        accuracy: (m['accuracy'] as num?)?.toInt(),
        date: DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime(2026),
        abandoned: m['abandoned'] as bool? ?? false,
      );
}
