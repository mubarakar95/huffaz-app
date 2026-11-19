class Student {
  final String id;
  final String fullName;
  final String? parentName;
  final String? contactNumber;
  final String institutionId;
  final String? teacherId;
  final String? teacherName;
  final bool isPersonal;
  final double? sabaqGoal;
  final double? sabqiGoal;
  final double? manzilGoal;
  final int progressPercent;
  final int uniqueCount;
  final int? currentJuz;
  final int streak;
  final String? todayStatus;
  final String? todayLogId;
  final double todaySabaqPages;
  final double todaySabqiPages;
  final double todayManzilPages;

  Student({
    required this.id,
    required this.fullName,
    this.parentName,
    this.contactNumber,
    required this.institutionId,
    this.teacherId,
    this.teacherName,
    required this.isPersonal,
    this.sabaqGoal,
    this.sabqiGoal,
    this.manzilGoal,
    this.progressPercent = 0,
    this.uniqueCount = 0,
    this.currentJuz,
    this.streak = 0,
    this.todayStatus,
    this.todayLogId,
    this.todaySabaqPages = 0.0,
    this.todaySabqiPages = 0.0,
    this.todayManzilPages = 0.0,
  });

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] ?? '',
      fullName: map['full_name'] ?? map['fullName'] ?? '',
      parentName: map['parent_name'] ?? map['parentName'],
      contactNumber: map['contact_number'] ?? map['contactNumber'],
      institutionId: map['institution_id'] ?? map['institutionId'] ?? '',
      teacherId: map['teacher_id'] ?? map['teacherId'],
      teacherName: map['profiles']?['full_name'] ?? map['teacherName'],
      isPersonal: map['is_personal'] ?? map['isPersonal'] ?? false,
      sabaqGoal: (map['sabaq_goal'] ?? map['sabaqGoal'])?.toDouble(),
      sabqiGoal: (map['sabqi_goal'] ?? map['sabqiGoal'])?.toDouble(),
      manzilGoal: (map['manzil_goal'] ?? map['manzilGoal'])?.toDouble(),
      progressPercent: map['progressPercent'] ?? 0,
      uniqueCount: map['uniqueCount'] ?? 0,
      currentJuz: map['currentJuz'],
      streak: map['streak'] ?? 0,
      todayStatus: map['todayStatus'],
      todayLogId: map['todayLogId'],
      todaySabaqPages: (map['todaySabaqPages'] ?? 0).toDouble(),
      todaySabqiPages: (map['todaySabqiPages'] ?? 0).toDouble(),
      todayManzilPages: (map['todayManzilPages'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'parentName': parentName,
      'contactNumber': contactNumber,
      'institutionId': institutionId,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'isPersonal': isPersonal,
      'sabaqGoal': sabaqGoal,
      'sabqiGoal': sabqiGoal,
      'manzilGoal': manzilGoal,
      'progressPercent': progressPercent,
      'uniqueCount': uniqueCount,
      'currentJuz': currentJuz,
      'streak': streak,
      'todayStatus': todayStatus,
      'todayLogId': todayLogId,
      'todaySabaqPages': todaySabaqPages,
      'todaySabqiPages': todaySabqiPages,
      'todayManzilPages': todayManzilPages,
    };
  }

  Student copyWith({
    String? id,
    String? fullName,
    String? institutionId,
    String? teacherId,
    String? teacherName,
    bool? isPersonal,
    String? parentName,
    String? contactNumber,
    double? sabaqGoal,
    double? sabqiGoal,
    double? manzilGoal,
    int? progressPercent,
    int? uniqueCount,
    int? currentJuz,
    int? streak,
    String? todayStatus,
    String? todayLogId,
    double? todaySabaqPages,
    double? todaySabqiPages,
    double? todayManzilPages,
  }) {
    return Student(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      parentName: parentName ?? this.parentName,
      contactNumber: contactNumber ?? this.contactNumber,
      institutionId: institutionId ?? this.institutionId,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      isPersonal: isPersonal ?? this.isPersonal,
      sabaqGoal: sabaqGoal ?? this.sabaqGoal,
      sabqiGoal: sabqiGoal ?? this.sabqiGoal,
      manzilGoal: manzilGoal ?? this.manzilGoal,
      progressPercent: progressPercent ?? this.progressPercent,
      uniqueCount: uniqueCount ?? this.uniqueCount,
      currentJuz: currentJuz ?? this.currentJuz,
      streak: streak ?? this.streak,
      todayStatus: todayStatus ?? this.todayStatus,
      todayLogId: todayLogId ?? this.todayLogId,
      todaySabaqPages: todaySabaqPages ?? this.todaySabaqPages,
      todaySabqiPages: todaySabqiPages ?? this.todaySabqiPages,
      todayManzilPages: todayManzilPages ?? this.todayManzilPages,
    );
  }
}
