import 'dart:convert';

class ScanResult {
  final String id;
  final String imagePath;
  final String question;
  final String answer;
  final DateTime timestamp;
  final bool byok;

  const ScanResult({
    required this.id,
    required this.imagePath,
    required this.question,
    required this.answer,
    required this.timestamp,
    this.byok = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'question': question,
        'answer': answer,
        'timestamp': timestamp.toIso8601String(),
        'byok': byok,
      };

  factory ScanResult.fromJson(Map<String, dynamic> j) => ScanResult(
        id: j['id'] as String,
        imagePath: j['imagePath'] as String,
        question: j['question'] as String,
        answer: j['answer'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
        byok: j['byok'] as bool? ?? false,
      );

  static List<ScanResult> listFromJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => ScanResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<ScanResult> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());
}
