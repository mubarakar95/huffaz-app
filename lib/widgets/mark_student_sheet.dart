import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../models/student.dart';
import '../../utils/student_utils.dart';
import '../../models/sabaq_log.dart';

class MarkStudentBottomSheet extends StatefulWidget {
  final String studentId;
  final Student student;

  const MarkStudentBottomSheet({
    Key? key,
    required this.studentId,
    required this.student,
  }) : super(key: key);

  @override
  _MarkStudentBottomSheetState createState() => _MarkStudentBottomSheetState();
}

class _MarkStudentBottomSheetState extends State<MarkStudentBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  bool _isLoading = false;
  String _date = getLocalToday();
  String _status = 'absent'; // Options: absent, sick, other
  bool _preserveStreak = true;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final needsValidation = _status == 'sick' || _status == 'other';
    if (needsValidation && !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final provider = context.read<AppProvider>();

      // Generate the exact webapp format
      String reasonText = '';
      if (_status == 'no_lesson') {
        reasonText = 'Present - No Lesson';
      } else {
        final displayStatusText = _status.substring(0, 1).toUpperCase() + _status.substring(1).toLowerCase();
        reasonText = displayStatusText;
      }

      final reasonInput = _reasonController.text.trim();
      if (_status == 'sick') {
        reasonText = reasonInput.isNotEmpty ? 'Sick - $reasonInput' : 'Sick';
      } else if (_status == 'other') {
        reasonText = reasonInput.isNotEmpty ? reasonInput : 'Other';
      }

      final preserveStr = (_status != 'absent' && _status != 'no_lesson' && _preserveStreak) ? ' [PRESERVE_STREAK]' : '';
      final skipReason = '[SKIPPED: $reasonText]$preserveStr';

      final result = await provider.mergeLog(
        studentId: widget.studentId,
        date: _date,
        sabaq: skipReason,
        status: _status,
      );

      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance marked successfully'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $result'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAttendance(String logId) async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<AppProvider>();
      final result = await provider.deleteLog(logId, widget.studentId);

      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance cleared successfully'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing attendance: $result'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppColors.surfaceDark : Colors.white;

    // Check if an attendance log exists for the chosen date
    final existingLogs = provider.getLogsForStudent(widget.studentId);
    final matchingLogs = existingLogs.where((l) {
      final logDateStr = l.date.split('T')[0];
      return logDateStr == _date && (l.status == 'absent' || l.status == 'sick' || l.status == 'other' || l.status == 'no_lesson');
    });
    final SabaqLog? existingAttendanceLog = matchingLogs.isNotEmpty ? matchingLogs.first : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            bottom: true,
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
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                      child: Row(
                        children: [
                          const Icon(Icons.person_off_rounded, color: AppColors.primary, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mark Status - ${widget.student.fullName}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  _date = picked.toIso8601String().substring(0, 10);
                                  _reasonController.clear();
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                            label: Text(_date, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (existingAttendanceLog != null) ...[
                              _buildExistingLogCard(existingAttendanceLog),
                            ],
                            const Text('Select Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2F34) : Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  RadioListTile<String>(
                                    title: const Text('Absent', style: TextStyle(fontWeight: FontWeight.w600)),
                                    value: 'absent',
                                    groupValue: _status,
                                    activeColor: AppColors.primary,
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _status = val;
                                        });
                                      }
                                    },
                                  ),
                                  const Divider(height: 1),
                                  RadioListTile<String>(
                                    title: const Text('Sick', style: TextStyle(fontWeight: FontWeight.w600)),
                                    value: 'sick',
                                    groupValue: _status,
                                    activeColor: AppColors.primary,
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _status = val;
                                          _preserveStreak = false;
                                        });
                                      }
                                    },
                                  ),
                                   const Divider(height: 1),
                                  RadioListTile<String>(
                                    title: const Text('Other', style: TextStyle(fontWeight: FontWeight.w600)),
                                    value: 'other',
                                    groupValue: _status,
                                    activeColor: AppColors.primary,
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _status = val;
                                        });
                                      }
                                    },
                                  ),
                                  const Divider(height: 1),
                                  RadioListTile<String>(
                                    title: const Text('No Lesson', style: TextStyle(fontWeight: FontWeight.w600)),
                                    value: 'no_lesson',
                                    groupValue: _status,
                                    activeColor: AppColors.primary,
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _status = val;
                                          _preserveStreak = false;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_status == 'sick' || _status == 'other') ...[
                              const Text('Reason / Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _reasonController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter reason...',
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter a reason';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (_status != 'absent') ...[
                              Builder(
                                builder: (context) {
                                  final isPreserveLocked = _status == 'no_lesson' || _status == 'sick';
                                  return CheckboxListTile(
                                    title: const Text('Preserve Streak', style: TextStyle(fontWeight: FontWeight.bold)),
                                    value: isPreserveLocked ? false : _preserveStreak,
                                    activeColor: AppColors.primary,
                                    onChanged: isPreserveLocked ? null : (val) {
                                      if (val != null) {
                                        setState(() {
                                          _preserveStreak = val;
                                        });
                                      }
                                    },
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                      child: Row(
                        children: [
                          if (existingAttendanceLog != null) ...[
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.danger.withValues(alpha: 0.1),
                                foregroundColor: AppColors.danger,
                                padding: const EdgeInsets.all(14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: _isLoading
                                  ? null
                                  : () => _deleteAttendance(existingAttendanceLog.id),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                onPressed: _isLoading ? null : _submit,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22, height: 22,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : const Text('Mark Status',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExistingLogCard(SabaqLog log) {
    final isAbsent = log.status == 'absent' || log.status == 'sick' || log.status == 'other';
    final bgColor = isAbsent ? AppColors.danger.withValues(alpha: 0.06) : AppColors.primary.withValues(alpha: 0.06);
    final borderColor = isAbsent ? AppColors.danger.withValues(alpha: 0.25) : AppColors.primary.withValues(alpha: 0.25);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            isAbsent ? Icons.person_off_rounded : Icons.check_circle_rounded,
            color: isAbsent ? AppColors.danger : AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isAbsent ? 'Already marked: ${log.cleanSabaqText}' : 'Logged: ${log.cleanSabaqText}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isAbsent ? AppColors.danger : AppColors.primary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
