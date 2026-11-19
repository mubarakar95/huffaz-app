/// Lightweight model for displaying teacher info in the management screen.
/// Distinct from [AppProfile] to avoid polluting profile state with
/// admin-only computed fields (student count, absence days).
class Teacher {
  final String id;
  final String fullName;
  final String role;
  final bool isActive;
  final int studentCount;
  final int absenceDaysThisMonth;

  const Teacher({
    required this.id,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.studentCount = 0,
    this.absenceDaysThisMonth = 0,
  });

  factory Teacher.fromMap(Map<String, dynamic> map) {
    return Teacher(
      id: map['id'] as String? ?? '',
      fullName: map['full_name'] ?? map['fullName'] ?? '',
      role: map['role'] as String? ?? 'teacher',
      isActive: map['is_active'] ?? map['isActive'] ?? true,
      studentCount: (map['studentCount'] as num?)?.toInt() ?? 0,
      absenceDaysThisMonth: (map['absenceDaysThisMonth'] as num?)?.toInt() ?? 0,
    );
  }
}
