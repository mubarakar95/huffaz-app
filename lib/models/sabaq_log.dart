import 'dart:convert';

class SabaqLog {
  final String id;
  final String studentId;
  final String teacherId;
  final String teacherName;
  final String studentName;
  final String date;
  final String sabaq;
  final dynamic manzil;
  final String status;
  final DateTime createdAt;

  SabaqLog({
    required this.id,
    required this.studentId,
    required this.teacherId,
    required this.teacherName,
    required this.studentName,
    required this.date,
    required this.sabaq,
    required this.manzil,
    required this.status,
    required this.createdAt,
  });

  factory SabaqLog.fromMap(Map<String, dynamic> map) {
    return SabaqLog(
      id: map['id'] ?? '',
      studentId: map['student_id'] ?? map['studentId'] ?? '',
      teacherId: map['teacher_id'] ?? map['teacherId'] ?? '',
      teacherName: map['profiles']?['full_name'] ?? map['teacherName'] ?? '',
      studentName: map['students']?['full_name'] ?? map['studentName'] ?? '',
      date: map['date'] ?? '',
      sabaq: map['sabaq'] ?? '',
      manzil: map['manzil'],
      status: map['status'] ?? '',
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'].toString())
          : (map['createdAt'] != null ? DateTime.parse(map['createdAt'].toString()) : DateTime.now()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'studentName': studentName,
      'date': date,
      'sabaq': sabaq,
      'manzil': manzil,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic>? get parsedManzil {
    if (manzil is Map) {
      return Map<String, dynamic>.from(manzil as Map);
    }
    if (manzil is String && (manzil as String).isNotEmpty) {
      try {
        final decoded = json.decode(manzil as String);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  int get sabaqParaCount {
    final parsed = parsedManzil;
    if (parsed != null && parsed['sabqi'] is List) {
      return (parsed['sabqi'] as List).where((item) => 
        item is Map && (item['sabaq'] == null || !item['sabaq'].toString().contains('[SKIPPED]'))
      ).length;
    }
    return 0;
  }

  int get murajaCount {
    final parsed = parsedManzil;
    if (parsed != null && parsed['manzilPages'] is List) {
      return (parsed['manzilPages'] as List).where((item) => 
        item is Map && item['page'] != -1 && (item['sabaq'] == null || !item['sabaq'].toString().contains('[SKIPPED]'))
      ).length;
    }
    return 0;
  }

  String get cleanSabaqText {
    String text = sabaq.replaceAll(RegExp(r'\s*- Heard by:.*$'), '');
    text = text.replaceAll(RegExp(r'\s*-\s*\d+\s*Line\(s\).*$'), '');
    return text.trim();
  }
}
