class AppProfile {
  final String id;
  final String fullName;
  final String role;
  final String institutionId;
  final String institutionName;
  final double defaultSabaqGoal;
  final double defaultSabqiGoal;
  final double defaultManzilGoal;
  final List<int> weeklyOffDays;
  final bool isActive;

  AppProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.institutionId,
    required this.institutionName,
    this.defaultSabaqGoal = 1.0,
    this.defaultSabqiGoal = 10.0,
    this.defaultManzilGoal = 20.0,
    this.weeklyOffDays = const [],
    this.isActive = true,
  });

  factory AppProfile.fromMap(Map<String, dynamic> map) {
    final inst = map['institutions'] is Map ? map['institutions'] as Map<String, dynamic> : null;
    return AppProfile(
      id: map['id'] ?? '',
      fullName: map['full_name'] ?? map['fullName'] ?? '',
      role: map['role'] ?? '',
      institutionId: map['institution_id'] ?? map['institutionId'] ?? '',
      institutionName: inst?['name'] ?? map['institutionName'] ?? '',
      defaultSabaqGoal: (inst?['default_sabaq_goal'] ?? map['defaultSabaqGoal'] ?? 1.0).toDouble(),
      defaultSabqiGoal: (inst?['default_sabqi_goal'] ?? map['defaultSabqiGoal'] ?? 10.0).toDouble(),
      defaultManzilGoal: (inst?['default_manzil_goal'] ?? map['defaultManzilGoal'] ?? 20.0).toDouble(),
      weeklyOffDays: List<int>.from(inst?['weekly_off_days'] ?? map['weeklyOffDays'] ?? []),
      isActive: map['is_active'] ?? map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'role': role,
      'institutionId': institutionId,
      'institutionName': institutionName,
      'defaultSabaqGoal': defaultSabaqGoal,
      'defaultSabqiGoal': defaultSabqiGoal,
      'defaultManzilGoal': defaultManzilGoal,
      'weeklyOffDays': weeklyOffDays,
      'isActive': isActive,
    };
  }
}
