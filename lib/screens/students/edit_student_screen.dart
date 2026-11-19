import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../models/student.dart';
import '../../../providers/app_provider.dart';
import '../../../utils/quran_data.dart';
import '../../../utils/student_utils.dart'; // Import to reuse getJuzForPage
import 'package:go_router/go_router.dart';
import 'baseline_settings_screen.dart';

class EditStudentScreen extends StatefulWidget {
  final String studentId;

  const EditStudentScreen({Key? key, required this.studentId}) : super(key: key);

  @override
  State<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _parentController;
  late TextEditingController _contactController;
  late TextEditingController _sabaqGoalController;
  late TextEditingController _sabqiGoalController;
  late TextEditingController _manzilGoalController;

  bool _isPersonal = false;
  String? _selectedTeacherId;
  bool _isLoading = false;

  // Baseline data stored locally before saving
  List<int> _parsedSabaqBaseline = [];
  List<int> _parsedSabqiBaseline = [];

  // Originals loaded at screen open — used to detect changes
  List<int> _originalSabaqBaseline = [];
  List<int> _originalSabqiBaseline = [];

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    final student = provider.students.firstWhere(
      (s) => s.id == widget.studentId,
      orElse: () => Student(id: widget.studentId, fullName: '', institutionId: '', isPersonal: false),
    );

    _nameController = TextEditingController(text: student.fullName);
    _parentController = TextEditingController(text: student.parentName ?? '');
    _contactController = TextEditingController(text: student.contactNumber ?? '');
    String formatGoal(double? val) {
      if (val == null) return '';
      return val % 1 == 0 ? val.toInt().toString() : val.toString();
    }

    final defaultSabaqGoal = provider.profile?.defaultSabaqGoal ?? 1.0;
    final defaultSabqiGoal = provider.profile?.defaultSabqiGoal ?? 1.0;
    final defaultManzilGoal = provider.profile?.defaultManzilGoal ?? 20.0;

    _sabaqGoalController = TextEditingController(
      text: formatGoal(student.sabaqGoal ?? defaultSabaqGoal),
    );
    _sabqiGoalController = TextEditingController(
      text: formatGoal(student.sabqiGoal ?? defaultSabqiGoal),
    );
    _manzilGoalController = TextEditingController(
      text: formatGoal(student.manzilGoal ?? defaultManzilGoal),
    );

    _isPersonal = student.isPersonal;
    _selectedTeacherId = student.teacherId;

    // Load baseline pages from database logs
    final existingLogs = provider.getLogsForStudent(widget.studentId);
    debugPrint('EDIT_STUDENT_SCREEN: Loaded ${existingLogs.length} logs for studentId: ${widget.studentId}');
    for (final l in existingLogs) {
      if (l.status.contains('baseline')) {
        debugPrint('EDIT_STUDENT_SCREEN: found baseline log - status: ${l.status}, date: ${l.date}, sabaq: "${l.sabaq}"');
      }
    }
    _parsedSabaqBaseline = existingLogs
        .where((l) => l.status == 'baseline')
        .map((l) => getPagesFromSabaqString(l.sabaq))
        .expand((x) => x)
        .toList()..sort();

    _parsedSabqiBaseline = existingLogs
        .where((l) => l.status == 'baseline_sabqi')
        .map((l) => getPagesFromSabaqString(l.sabaq))
        .expand((x) => x)
        .toList()..sort();

    debugPrint('EDIT_STUDENT_SCREEN: _parsedSabaqBaseline pgs count = ${_parsedSabaqBaseline.length}, _parsedSabqiBaseline pgs count = ${_parsedSabqiBaseline.length}');

    // Snapshot originals so we can skip saveBaseline if nothing changed
    _originalSabaqBaseline = List<int>.from(_parsedSabaqBaseline);
    _originalSabqiBaseline = List<int>.from(_parsedSabqiBaseline);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _parentController.dispose();
    _contactController.dispose();
    _sabaqGoalController.dispose();
    _sabqiGoalController.dispose();
    _manzilGoalController.dispose();
    super.dispose();
  }

  /// Returns true if both sorted int lists contain the same elements.
  bool _listsEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<int> _getPagesInJuz(int juzNum) {
    final List<int> pages = [];
    for (int p = 1; p <= 604; p++) {
      if (getJuzForPage(p) == juzNum) {
        pages.add(p);
      }
    }
    return pages;
  }

  

  Future<void> _deleteStudent() async {
    final name = _nameController.text.trim();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student?'),
        content: Text(
          'Are you sure you want to permanently delete $name? '
          'This will also delete all of their activity logs and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<AppProvider>();
      final error = await provider.deleteStudent(widget.studentId);

      if (!mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: AppColors.danger),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name deleted successfully.')),
        );
        if (mounted) {
          context.go('/students');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final provider = context.read<AppProvider>();
      final sGoal = _sabaqGoalController.text.trim();
      final sqGoal = _sabqiGoalController.text.trim();
      final mGoal = _manzilGoalController.text.trim();

      // 1. Update general info
      final updateErr = await provider.updateStudent(
        studentId: widget.studentId,
        fullName: _nameController.text.trim(),
        parentName: _parentController.text.trim().isNotEmpty ? _parentController.text.trim() : null,
        contactNumber: _contactController.text.trim().isNotEmpty ? _contactController.text.trim() : null,
        teacherId: _selectedTeacherId,
        sabaqGoal: sGoal.isNotEmpty ? double.tryParse(sGoal) : null,
        sabqiGoal: sqGoal.isNotEmpty ? double.tryParse(sqGoal) : null,
        manzilGoal: mGoal.isNotEmpty ? double.tryParse(mGoal) : null,
        isPersonal: _isPersonal,
      );

      if (updateErr != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update student: $updateErr'), backgroundColor: AppColors.danger),
          );
        }
        return;
      }

      // 2. Only update baseline if pages actually changed
      final baselineChanged =
          !_listsEqual(_parsedSabaqBaseline, _originalSabaqBaseline) ||
          !_listsEqual(_parsedSabqiBaseline, _originalSabqiBaseline);

      if (baselineChanged) {
        final baselineErr = await provider.saveBaseline(
          studentId: widget.studentId,
          sabaqPages: _parsedSabaqBaseline,
          sabqiPages: _parsedSabqiBaseline,
        );

        if (mounted) {
          if (baselineErr != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to save baseline: $baselineErr'), backgroundColor: AppColors.danger),
            );
            return;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(baselineChanged
                ? 'Student details & baseline updated successfully'
                : 'Student details updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final teachers = provider.institutionPeople['teachers'] as List? ?? [];
    final currentUserId = provider.profile?.id;
    final isTeacher = provider.profile?.role == 'teacher';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasOtherPersonalProfile = provider.students.any((s) => s.isPersonal && s.id != widget.studentId);

    // If teacher, teacherId is fixed to currentUserId. Otherwise it can be edited.
    final actualTeacherId = isTeacher ? currentUserId : _selectedTeacherId;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Edit Student Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : AppColors.textMainLight,
      ),
      body: SafeArea(
        bottom: true,
        child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: isDark ? const Color(0xFF2C2F34) : const Color(0xFFF4F4F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Form Card
                  Card(
                    elevation: 0,
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: (isDark ? AppColors.borderDark : AppColors.borderLight).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Basic Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textMainLight,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Student Full Name *',
                              hintText: 'e.g. Abdullah Ahmad',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Student name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _parentController,
                            decoration: const InputDecoration(
                              labelText: 'Parent/Guardian Name',
                              hintText: 'e.g. Ahmad Ibrahim',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _contactController,
                            decoration: const InputDecoration(
                              labelText: 'Contact Number',
                              hintText: 'e.g. +91 9876543210',
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          if (isTeacher)
                            DropdownButtonFormField<String>(
                              value: currentUserId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Assign Teacher',
                              ),
                              items: [
                                DropdownMenuItem<String>(
                                  value: currentUserId,
                                  child: Text(provider.profile?.fullName ?? 'Me'),
                                )
                              ],
                              onChanged: null,
                            )
                          else
                            DropdownButtonFormField<String?>(
                              value: actualTeacherId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Assign Teacher',
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Unassigned (Open for all)'),
                                ),
                                ...teachers.map((t) {
                                  return DropdownMenuItem<String?>(
                                    value: t['id'] as String?,
                                    child: Text(t['full_name'] ?? 'Unknown Teacher'),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedTeacherId = val;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Goals Card
                  Card(
                    elevation: 0,
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: (isDark ? AppColors.borderDark : AppColors.borderLight).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target Goals (Pages)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textMainLight,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _sabaqGoalController,
                            decoration: const InputDecoration(
                              labelText: 'Custom Sabaq Goal (Pages)',
                              hintText: 'Leave blank to use default goal',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (val) {
                              if (val != null && val.trim().isNotEmpty) {
                                final n = double.tryParse(val);
                                if (n == null || n <= 0) {
                                  return 'Must be a positive number';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _sabqiGoalController,
                            decoration: const InputDecoration(
                              labelText: 'Custom Sabaq Para Goal (Pages)',
                              hintText: 'Leave blank to use default goal',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (val) {
                              if (val != null && val.trim().isNotEmpty) {
                                final n = double.tryParse(val);
                                if (n == null || n <= 0) {
                                  return 'Must be a positive number';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _manzilGoalController,
                            decoration: const InputDecoration(
                              labelText: 'Custom Muraja Goal (Pages)',
                              hintText: 'Leave blank to use default goal (e.g. 20)',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (val) {
                              if (val != null && val.trim().isNotEmpty) {
                                final n = double.tryParse(val);
                                if (n == null || n <= 0) {
                                  return 'Must be a positive number';
                                }
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Baseline Modal Trigger Card
                  Card(
                    elevation: 0,
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: (isDark ? AppColors.borderDark : AppColors.borderLight).withValues(alpha: 0.5),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.style_rounded, color: AppColors.primary, size: 20),
                      ),
                      title: Text(
                        'Set Memorization Baseline',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textMainLight,
                        ),
                      ),
                      subtitle: Text(
                        _parsedSabaqBaseline.isEmpty && _parsedSabqiBaseline.isEmpty
                            ? 'Configure pre-existing memorized pages'
                            : 'Muraja: ${(_parsedSabaqBaseline.length / 20).toStringAsFixed(1)} Juz (${_parsedSabaqBaseline.length} pgs) • Sabaq Para: ${_parsedSabqiBaseline.length} pgs',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BaselineSettingsScreen(studentId: widget.studentId),
                          ),
                        );
                        if (updated == true) {
                          final provider = context.read<AppProvider>();
                          final existingLogs = provider.getLogsForStudent(widget.studentId);
                          setState(() {
                            _parsedSabaqBaseline = existingLogs
                                .where((l) => l.status == 'baseline')
                                .map((l) => getPagesFromSabaqString(l.sabaq))
                                .expand((x) => x)
                                .toList()..sort();

                            _parsedSabqiBaseline = existingLogs
                                .where((l) => l.status == 'baseline_sabqi')
                                .map((l) => getPagesFromSabaqString(l.sabaq))
                                .expand((x) => x)
                                .toList()..sort();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  CheckboxListTile(
                    title: const Text('Personal Profile'),
                    subtitle: Text(
                      hasOtherPersonalProfile
                          ? 'You already have another student assigned as your personal profile.'
                          : 'This account will only be visible to you and excluded from all reports.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).disabledColor,
                      ),
                    ),
                    value: _isPersonal,
                    onChanged: hasOtherPersonalProfile
                        ? null
                        : (val) {
                            setState(() {
                              _isPersonal = val ?? false;
                            });
                          },
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _saveAll,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Save All Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isLoading ? null : _deleteStudent,
                    icon: const Icon(Icons.delete_forever_rounded, size: 20),
                    label: const Text('Delete Student Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
