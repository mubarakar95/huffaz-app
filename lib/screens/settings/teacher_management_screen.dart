import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../models/teacher.dart';

// ---------------------------------------------------------------------------
// Leave thresholds — single place to change if business rules change.
// ---------------------------------------------------------------------------
const int _leaveAmberMin = 1;
const int _leaveAmberMax = 5;
const int _leaveDangerMin = 6;

class TeacherManagementScreen extends StatefulWidget {
  const TeacherManagementScreen({super.key});

  @override
  State<TeacherManagementScreen> createState() => _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends State<TeacherManagementScreen> {
  bool _showDisabled = false;

  @override
  void initState() {
    super.initState();
    // Fetch on first open; refresh even if already fetched so the month data is fresh.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchTeachers(forceRefresh: true);
    });
  }

  // -------------------------------------------------------------------------
  // Month navigation
  // -------------------------------------------------------------------------

  String _monthLabel(int year, int month) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${monthNames[month - 1]} $year';
  }

  void _prevMonth(AppProvider p) {
    var y = p.leaveReportYear;
    var m = p.leaveReportMonth - 1;
    if (m < 1) { m = 12; y--; }
    p.setLeaveReportMonth(y, m);
  }

  void _nextMonth(AppProvider p) {
    final now = DateTime.now();
    var y = p.leaveReportYear;
    var m = p.leaveReportMonth + 1;
    if (m > 12) { m = 1; y++; }
    // Don't go into the future beyond the current month.
    if (y > now.year || (y == now.year && m > now.month)) return;
    p.setLeaveReportMonth(y, m);
  }

  // -------------------------------------------------------------------------
  // Absence scheduling
  // -------------------------------------------------------------------------

  Future<void> _showScheduleAbsence(Teacher teacher) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final dateStr =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    final err = await context.read<AppProvider>().scheduleAbsenceForTeacher(
          teacherId: teacher.id,
          date: dateStr,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'Absence scheduled for ${teacher.fullName}'),
      backgroundColor: err != null ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ));
  }

  // -------------------------------------------------------------------------
  // Absence history bottom sheet
  // -------------------------------------------------------------------------

  void _showAbsenceHistory(Teacher teacher) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AbsenceHistorySheet(teacher: teacher),
    );
  }

  // -------------------------------------------------------------------------
  // Disable / re-enable flows
  // -------------------------------------------------------------------------

  Future<void> _handleDisable(Teacher teacher) async {
    final p = context.read<AppProvider>();
    // Check for assigned students
    final assignedStudents =
        p.students.where((s) => s.teacherId == teacher.id).toList();

    if (!mounted) return;

    if (assignedStudents.isNotEmpty) {
      // Show reassignment dialog
      await _showReassignDialog(teacher, assignedStudents.map((s) => s.id).toList(), p);
      return;
    }

    // No students — confirm and disable
    final confirm = await _showDisableConfirm(teacher);
    if (confirm != true || !mounted) return;

    final err = await p.disableTeacher(teacher.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? '${teacher.fullName} has been disabled'),
      backgroundColor: err != null ? AppColors.danger : AppColors.warning,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ));
  }

  Future<bool?> _showDisableConfirm(Teacher teacher) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Disable Teacher'),
        content: Text(
          'Disable ${teacher.fullName}? They will no longer be able to log into the app, '
          'but all their historical data is preserved. You can re-enable them anytime.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReassignDialog(
    Teacher teacher,
    List<String> studentIds,
    AppProvider p,
  ) async {
    final activeTeachers = p.teachers
        .where((t) => t.isActive && t.id != teacher.id)
        .toList();

    String? selectedTeacherId; // null = leave unassigned

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reassign Students'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${teacher.fullName} has ${studentIds.length} student${studentIds.length == 1 ? '' : 's'} assigned. '
                'Choose a new teacher or leave them unassigned before disabling.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                value: selectedTeacherId,
                decoration: InputDecoration(
                  labelText: 'Reassign to',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Leave unassigned'),
                  ),
                  ...activeTeachers.map((t) => DropdownMenuItem<String?>(
                        value: t.id,
                        child: Text(t.fullName),
                      )),
                ],
                onChanged: (v) => setS(() => selectedTeacherId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.warning),
              child: const Text('Reassign & Disable'),
            ),
          ],
        ),
      ),
    );

    if (proceed != true || !mounted) return;

    // Reassign students
    await p.updateStudents(studentIds, newTeacherId: selectedTeacherId);
    if (!mounted) return;

    // Then disable
    final err = await p.disableTeacher(teacher.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? '${teacher.fullName} has been disabled'),
      backgroundColor: err != null ? AppColors.danger : AppColors.warning,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ));
  }

  Future<void> _handleEnable(Teacher teacher) async {
    final err = await context.read<AppProvider>().enableTeacher(teacher.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? '${teacher.fullName} has been re-enabled'),
      backgroundColor: err != null ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ));
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isDark = p.isDarkMode;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    final activeTeachers = p.teachers.where((t) => t.isActive).toList();
    final disabledTeachers = p.teachers.where((t) => !t.isActive).toList();

    final totalAbsences = activeTeachers.fold<int>(
      0,
      (sum, t) => sum + t.absenceDaysThisMonth,
    );

    final displayedActive = activeTeachers;
    final displayedDisabled = _showDisabled ? disabledTeachers : <Teacher>[];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Teachers'),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showInviteSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: () => p.fetchTeachers(forceRefresh: true),

        color: AppColors.primary,
        child: p.isLoadingTeachers && p.teachers.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : CustomScrollView(
                slivers: [
                  // Summary strip + month switcher
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        children: [
                          // Month switcher
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left_rounded),
                                color: AppColors.primary,
                                onPressed: () => _prevMonth(p),
                              ),
                              Text(
                                _monthLabel(p.leaveReportYear, p.leaveReportMonth),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textMain,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded),
                                color: AppColors.primary,
                                onPressed: () => _nextMonth(p),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Summary cards row
                          Row(
                            children: [
                              _MetricCard(
                                label: 'Total Teachers',
                                value: '${activeTeachers.length}',
                                icon: Icons.group_rounded,
                                color: AppColors.primary,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 12),
                              _MetricCard(
                                label: 'Absences This Month',
                                value: '$totalAbsences',
                                icon: Icons.event_busy_rounded,
                                color: totalAbsences == 0
                                    ? AppColors.success
                                    : totalAbsences <= 5
                                        ? AppColors.warning
                                        : AppColors.danger,
                                isDark: isDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ).animate().fadeIn(duration: 300.ms),
                  ),

                  // Active teachers list
                  if (displayedActive.isEmpty && !p.isLoadingTeachers)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
                        child: Column(
                          children: [
                            Icon(Icons.group_off_rounded, size: 48, color: textMuted),
                            const SizedBox(height: 12),
                            Text(
                              'No teachers yet.\nTap + to invite your first teacher.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textMuted, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final teacher = displayedActive[i];
                            return _TeacherCard(
                              teacher: teacher,
                              isDark: isDark,
                              surface: surface,
                              border: border,
                              textMain: textMain,
                              textMuted: textMuted,
                              onScheduleAbsence: () => _showScheduleAbsence(teacher),
                              onViewHistory: () => _showAbsenceHistory(teacher),
                              onDisable: () => _handleDisable(teacher),
                              onEnable: null,
                            ).animate(delay: (i * 40).ms).fadeIn(duration: 250.ms).slideY(begin: 0.05);
                          },
                          childCount: displayedActive.length,
                        ),
                      ),
                    ),

                  // Disabled teachers section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _showDisabled = !_showDisabled);
                        },

                        child: Row(
                          children: [
                            Icon(
                              _showDisabled
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 18,
                              color: textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _showDisabled ? 'Hide disabled teachers' : 'Show disabled teachers',
                              style: TextStyle(fontSize: 13, color: textMuted),
                            ),
                            if (disabledTeachers.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${disabledTeachers.length}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (displayedDisabled.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final teacher = displayedDisabled[i];
                            return _TeacherCard(
                              teacher: teacher,
                              isDark: isDark,
                              surface: surface,
                              border: border,
                              textMain: textMain,
                              textMuted: textMuted,
                              isDisabled: true,
                              onScheduleAbsence: null,
                              onViewHistory: () => _showAbsenceHistory(teacher),
                              onDisable: null,
                              onEnable: () => _handleEnable(teacher),
                            ).animate(delay: (i * 40).ms).fadeIn(duration: 250.ms).slideY(begin: 0.05);
                          },
                          childCount: displayedDisabled.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
    );
  }

  void _showInviteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _InviteTeacherSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Teacher Card
// ---------------------------------------------------------------------------

class _TeacherCard extends StatelessWidget {
  final Teacher teacher;
  final bool isDark;
  final Color surface;
  final Color border;
  final Color textMain;
  final Color textMuted;
  final bool isDisabled;
  final VoidCallback? onScheduleAbsence;
  final VoidCallback? onViewHistory;
  final VoidCallback? onDisable;
  final VoidCallback? onEnable;

  const _TeacherCard({
    required this.teacher,
    required this.isDark,
    required this.surface,
    required this.border,
    required this.textMain,
    required this.textMuted,
    this.isDisabled = false,
    this.onScheduleAbsence,
    this.onViewHistory,
    this.onDisable,
    this.onEnable,
  });

  Color get _badgeColor {
    final d = teacher.absenceDaysThisMonth;
    if (d == 0) return AppColors.success;
    if (d <= _leaveAmberMax) return AppColors.warning;
    return AppColors.danger;
  }

  String get _badgeText {
    final d = teacher.absenceDaysThisMonth;
    return d == 0 ? '0 days off' : '$d day${d == 1 ? '' : 's'} off';
  }

  @override
  Widget build(BuildContext context) {
    final initials = teacher.fullName.isNotEmpty
        ? teacher.fullName.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: isDisabled ? surface.withValues(alpha: 0.5) : surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDisabled
                      ? (isDark ? AppColors.borderDark : AppColors.borderLight)
                      : AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDisabled ? textMuted : AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name + students count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            teacher.fullName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDisabled ? textMuted : textMain,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isDisabled) ...[
                          const SizedBox(width: 6),
                          _Pill(
                            label: 'Disabled',
                            color: AppColors.danger,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${teacher.studentCount} student${teacher.studentCount == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                        if (!isDisabled) ...[
                          const SizedBox(width: 8),
                          _Pill(label: _badgeText, color: _badgeColor),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              if (isDisabled && onEnable != null)
                TextButton(
                  onPressed: onEnable,
                  style: TextButton.styleFrom(foregroundColor: AppColors.success),
                  child: const Text('Re-enable'),
                )
              else if (!isDisabled)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: textMuted, size: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (v) {
                    if (v == 'absence' && onScheduleAbsence != null) onScheduleAbsence!();
                    if (v == 'history' && onViewHistory != null) onViewHistory!();
                    if (v == 'disable' && onDisable != null) onDisable!();
                  },
                  itemBuilder: (ctx) => [
                    if (onScheduleAbsence != null)
                      const PopupMenuItem(
                        value: 'absence',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.event_busy_rounded, size: 18),
                          title: Text('Schedule Absence'),
                        ),
                      ),
                    if (onViewHistory != null)
                      const PopupMenuItem(
                        value: 'history',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.history_rounded, size: 18),
                          title: Text('View Absence History'),
                        ),
                      ),
                    if (onDisable != null)
                      PopupMenuItem(
                        value: 'disable',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.block_rounded, size: 18, color: AppColors.warning),
                          title: Text(
                            'Disable Teacher',
                            style: TextStyle(color: AppColors.warning),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metric Card (summary strip)
// ---------------------------------------------------------------------------

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textMain,
                      )),
                  Text(label,
                      style: TextStyle(fontSize: 11, color: textMuted),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leave badge pill
// ---------------------------------------------------------------------------

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invite Teacher Bottom Sheet
// ---------------------------------------------------------------------------

class _InviteTeacherSheet extends StatefulWidget {
  const _InviteTeacherSheet();

  @override
  State<_InviteTeacherSheet> createState() => _InviteTeacherSheetState();
}

class _InviteTeacherSheetState extends State<_InviteTeacherSheet> {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    final err = await context.read<AppProvider>().inviteTeacher(
          email: email,
          name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Invitation sent to $email'),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final isDark = p.isDarkMode;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Invite Teacher',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: textMain)),
          const SizedBox(height: 4),
          Text(
            'An invitation will be sent. They\'ll join when they first log in with this email.',
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email address *',
              hintText: 'teacher@example.com',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              prefixIcon: const Icon(Icons.email_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Full name (optional)',
              hintText: 'e.g. Ustadh Ahmed',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              prefixIcon: const Icon(Icons.person_rounded),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Invitation', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Absence History Bottom Sheet
// ---------------------------------------------------------------------------

class _AbsenceHistorySheet extends StatefulWidget {
  final Teacher teacher;
  const _AbsenceHistorySheet({required this.teacher});

  @override
  State<_AbsenceHistorySheet> createState() => _AbsenceHistorySheetState();
}

class _AbsenceHistorySheetState extends State<_AbsenceHistorySheet> {
  List<Map<String, dynamic>>? _absences;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await context.read<AppProvider>().fetchTeacherAbsenceHistory(
          widget.teacher.id,
          year: DateTime.now().year,
        );
    if (!mounted) return;
    setState(() { _absences = list; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppProvider>().isDarkMode;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Absence History',
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700, color: textMain),
                      ),
                      Text(
                        widget.teacher.fullName,
                        style: TextStyle(fontSize: 13, color: textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          else if (_absences == null || _absences!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.event_available_rounded, size: 40, color: textMuted),
                  const SizedBox(height: 8),
                  Text('No absences recorded this year',
                      style: TextStyle(color: textMuted, fontSize: 14)),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                shrinkWrap: true,
                itemCount: _absences!.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (ctx, i) {
                  final date = _absences![i]['absence_date'] as String? ?? '';
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: const Icon(Icons.event_busy_rounded,
                        color: AppColors.warning, size: 20),
                    title: Text(date,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textMain,
                        )),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
