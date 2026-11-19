import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../models/student.dart';
import '../../models/sabaq_log.dart';
import '../../utils/quran_data.dart';
import '../../utils/student_utils.dart';
import '../../widgets/log_sabaq_sheet.dart';
import '../../widgets/log_sabqi_sheet.dart';
import '../../widgets/log_manzil_sheet.dart';
import '../../widgets/mark_student_sheet.dart';
import 'edit_student_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  final String studentId;

  const StudentDetailScreen({Key? key, required this.studentId}) : super(key: key);

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen>
    with SingleTickerProviderStateMixin {
  int? _selectedJuzForPages;
  bool _isFabExpanded = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;


  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );
    
    // Direct untruncated fetch of this student's full log history
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().syncSingleStudentLogs(widget.studentId);
    });
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() => _isFabExpanded = !_isFabExpanded);
    if (_isFabExpanded) {
      _fabAnimationController.forward();
    } else {
      _fabAnimationController.reverse();
    }
  }

  void _openLessonSheet(BuildContext context, Student student, AppProvider provider, int initialTab) {
    if (_isFabExpanded) _toggleFab();

    Widget sheet;
    switch (initialTab) {
      case 0:
        sheet = SabaqBottomSheet(studentId: student.id, student: student);
        break;
      case 1:
        sheet = SabqiBottomSheet(studentId: student.id, student: student);
        break;
      case 2:
        sheet = ManzilBottomSheet(studentId: student.id, student: student);
        break;
      case 3:
        sheet = MarkStudentBottomSheet(studentId: student.id, student: student);
        break;
      default:
        sheet = SabaqBottomSheet(studentId: student.id, student: student);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final studentId = widget.studentId;
    final student = provider.students.firstWhere(
      (s) => s.id == studentId,
      orElse: () => Student(
        id: studentId,
        fullName: 'Student Detail',
        institutionId: '',
        isPersonal: false,
      ),
    );

    final logs = provider.getLogsForStudent(studentId);
    if (student.fullName.contains('Abdullah Farhan')) {
      debugPrint('[DiagAbdullah] TOTAL LOGS: ${logs.length}');
      for (var i = 0; i < logs.length; i++) {
        final l = logs[i];
        debugPrint('[DiagAbdullah] [$i] Date: ${l.date} | Status: ${l.status} | Sabaq: "${l.sabaq}" | CleanSabaq: "${l.cleanSabaqText}" | Manzil: ${l.parsedManzil}');
      }
    }
    final sabqiPool = provider.getSabqiPagesForStudent(studentId, limit: 100);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => provider.refresh(),
              child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                 SliverAppBar(
                  expandedHeight: 240.0,
                  pinned: true,
                  backgroundColor: AppColors.primaryDark,
                  iconTheme: const IconThemeData(color: Colors.white),
                  elevation: 0,
                  actions: [
                    if (provider.profile?.role == 'admin' ||
                        provider.profile?.role == 'super_admin' ||
                        provider.profile?.id == student.teacherId)
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: Colors.white),
                        tooltip: 'Edit Student Details',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditStudentScreen(studentId: studentId),
                          ),
                        ),
                      ),
                  ],
                  title: LayoutBuilder(
                    builder: (context, constraints) {
                      final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
                      if (settings == null) return const SizedBox.shrink();
                      final deltaExtent = settings.maxExtent - settings.minExtent;
                      final t = (1.0 - (settings.currentExtent - settings.minExtent) / deltaExtent).clamp(0.0, 1.0);
                      return Opacity(
                        opacity: t,
                        child: Text(
                          student.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: LayoutBuilder(
                      builder: (context, constraints) {
                        final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
                        final deltaExtent = settings!.maxExtent - settings.minExtent;
                        final t = (1.0 - (settings.currentExtent - settings.minExtent) / deltaExtent).clamp(0.0, 1.0);

                        final parent = student.parentName ?? 'Not Registered';
                        final teacher = student.teacherName ?? 'Assigned';
                        final phone = (student.contactNumber != null && student.contactNumber!.trim().isNotEmpty)
                            ? ' • Phone: ${student.contactNumber}'
                            : '';

                        return Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primaryDark, AppColors.primary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Opacity(
                            opacity: (1.0 - t).clamp(0.0, 1.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 48),
                                Hero(
                                  tag: 'student_avatar_${student.id}',
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [AppColors.primaryLight, AppColors.primary],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : '?',
                                          style: const TextStyle(
                                            fontSize: 26,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Hero(
                                    tag: 'student_name_${student.id}',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Text(
                                        student.fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Parent: $parent • Teacher: $teacher$phone',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (student.streak > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.orange.withOpacity(0.35)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.local_fire_department_rounded,
                                          color: Colors.orangeAccent,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${student.streak} Day Streak',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    height: 74.0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Container(
                        padding: const EdgeInsets.all(6.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF23262A)
                              : const Color(0xFFF4F4F5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: TabBar(
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF2C2F34)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          labelColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF18181B),
                          unselectedLabelColor: const Color(0xFF71717A),
                          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          tabs: const [
                            Tab(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.grid_view_rounded, size: 16),
                                    SizedBox(width: 4),
                                    Text('Overview'),
                                  ],
                                ),
                              ),
                            ),
                            Tab(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.blur_on_rounded, size: 16),
                                    SizedBox(width: 4),
                                    Text('Freshness'),
                                  ],
                                ),
                              ),
                            ),
                            Tab(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.history_rounded, size: 16),
                                    SizedBox(width: 4),
                                    Text('Records'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: true,
              child: TabBarView(
              children: [
                // TAB 1: OVERVIEW (Goals + Sabaq Para Heatmap)
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- HERO HEADER: Today's Daily Task Checklist or Absent/Sick Status Card ---
                      Builder(
                        builder: (context) {
                          final todayStatus = student.todayStatus;
                          final isAbsentOrLeave = ['absent', 'sick', 'other', 'no_lesson'].contains(todayStatus);

                          if (isAbsentOrLeave) {
                            final statusText = todayStatus == 'no_lesson' ? 'No Lesson' : (todayStatus != null ? todayStatus[0].toUpperCase() + todayStatus.substring(1) : 'Absent');
                            Color badgeColor = AppColors.danger;
                            if (todayStatus == 'sick') badgeColor = AppColors.warning;
                            else if (todayStatus == 'no_lesson') badgeColor = AppColors.info;
                            else if (todayStatus == 'other') badgeColor = Colors.orange;

                            final logs = provider.getLogsForStudent(student.id);
                            final todayStr = getLocalToday();
                            final todayLog = logs.where((l) => (l.date.contains('T') ? l.date.split('T')[0] : l.date) == todayStr).firstOrNull;
                            
                            String reasonText = '';
                            if (todayLog?.sabaq != null && todayLog!.sabaq!.startsWith('[SKIPPED:')) {
                              reasonText = todayLog.sabaq!
                                  .replaceAll('[PRESERVE_STREAK]', '')
                                  .replaceAll('[SKIPPED:', '')
                                  .replaceAll(']', '')
                                  .trim();
                            } else {
                              reasonText = statusText;
                            }

                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      todayStatus == 'sick' ? Icons.sick_outlined : Icons.person_off_rounded,
                                      color: badgeColor,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "TODAY'S ATTENDANCE STATUS",
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          statusText,
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: badgeColor,
                                          ),
                                        ),
                                        if (reasonText.isNotEmpty && reasonText != statusText) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            reasonText,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: badgeColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) => MarkStudentBottomSheet(
                                          studentId: student.id,
                                          student: student,
                                        ),
                                      );
                                    },
                                    child: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          }

                          final isHafiz = student.progressPercent >= 100;
                          final sGoal = isHafiz ? 0.0 : (student.sabaqGoal ?? provider.defaultSabaqGoal);
                          final sqGoal = isHafiz ? 0.0 : (student.sabqiGoal ?? provider.defaultSabqiGoal);
                          final mGoal = student.manzilGoal ?? provider.defaultManzilGoal;

                          final sabaqDone = student.todaySabaqPages >= sGoal && sGoal > 0;
                          final sabqiDone = student.todaySabqiPages >= sqGoal && sqGoal > 0;
                          final manzilDone = student.todayManzilPages >= mGoal && mGoal > 0;

                          final completedCount = (sabaqDone ? 1 : 0) + (sabqiDone ? 1 : 0) + (manzilDone ? 1 : 0);
                          final totalTasks = (sGoal > 0 ? 1 : 0) + (sqGoal > 0 ? 1 : 0) + (mGoal > 0 ? 1 : 0);
                          final progressRatio = totalTasks > 0 ? (completedCount / totalTasks) : 0.0;

                          final todayStr = getLocalToday();
                          final isAcknowledged = provider.getAcknowledgedIds(todayStr).contains(student.id);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.12)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.deepPurple.withOpacity(0.03),
                                      blurRadius: 30,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            SizedBox(
                                              width: 84,
                                              height: 84,
                                              child: CircularProgressIndicator(
                                                value: progressRatio,
                                                strokeWidth: 6,
                                                strokeCap: StrokeCap.round,
                                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                                backgroundColor: Theme.of(context).dividerColor.withOpacity(0.1),
                                              ),
                                            ),
                                            Text(
                                              '${completedCount}/${totalTasks}',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "TODAY'S TASK CHECKLIST",
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1.1,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$completedCount of $totalTasks met',
                                                style: const TextStyle(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 4,
                                                children: [
                                                  if (!isHafiz) _buildMiniStatusBadge('Sabaq', sabaqDone, student.todaySabaqPages, sGoal),
                                                  if (!isHafiz) _buildMiniStatusBadge('Sabqi', sabqiDone, student.todaySabqiPages, sqGoal),
                                                  _buildMiniStatusBadge('Muraja', manzilDone, student.todayManzilPages, mGoal),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (completedCount < totalTasks) ...[
                                      const SizedBox(height: 14),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isAcknowledged ? AppColors.danger : AppColors.primary,
                                            side: BorderSide(
                                              color: isAcknowledged ? AppColors.danger : AppColors.primary,
                                              width: 1.5,
                                            ),
                                            backgroundColor: isAcknowledged
                                                ? AppColors.danger.withValues(alpha: 0.08)
                                                : AppColors.primary.withValues(alpha: 0.04),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                          onPressed: () async {
                                            if (isAcknowledged) {
                                              await provider.unacknowledgeStudent(student.id, todayStr);
                                            } else {
                                              await provider.acknowledgeStudent(student.id, todayStr);
                                            }
                                          },
                                          icon: Icon(
                                            isAcknowledged ? Icons.check_circle_rounded : Icons.task_alt_rounded,
                                            size: 18,
                                          ),
                                          label: Text(
                                            isAcknowledged ? 'Confirmed Pending (Acknowledged)' : 'Confirm Pending Lessons',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                "Today's Lessons",
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Column(
                                children: [
                                  if (!isHafiz) ...[
                                    _buildLessonChecklistItem(
                                      'Sabaq',
                                      student.todaySabaqPages,
                                      student.sabaqGoal ?? provider.defaultSabaqGoal,
                                      Icons.book_outlined,
                                      AppColors.primary,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildLessonChecklistItem(
                                      'Sabaq Para',
                                      student.todaySabqiPages,
                                      student.sabqiGoal ?? provider.defaultSabqiGoal,
                                      Icons.history_rounded,
                                      AppColors.info,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  _buildLessonChecklistItem(
                                    'Muraja',
                                    student.todayManzilPages,
                                    student.manzilGoal ?? provider.defaultManzilGoal,
                                    Icons.trending_up_rounded,
                                    AppColors.success,
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // --- ASYMMETRICAL STATS ROW (2/3 Wide Card + 1/3 Compact Pill) ---
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.08)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.deepPurple.withValues(alpha: 0.02),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final streak = student.streak;
                                        Color streakColor;
                                        IconData streakIcon = Icons.local_fire_department_rounded;
                                        
                                        if (streak >= 30) {
                                          streakColor = const Color(0xFFD946EF); // Master (Magenta)
                                          streakIcon = Icons.emoji_events_rounded;
                                        } else if (streak >= 14) {
                                          streakColor = const Color(0xFF06B6D4); // Legend (Cyan)
                                          streakIcon = Icons.diamond_rounded;
                                        } else if (streak >= 7) {
                                          streakColor = const Color(0xFFFF8C00); // Hot (Orange)
                                          streakIcon = Icons.local_fire_department_rounded;
                                        } else if (streak >= 3) {
                                          streakColor = const Color(0xFF64748B); // Warm (Silver/Slate)
                                          streakIcon = Icons.auto_awesome_rounded;
                                        } else {
                                          streakColor = const Color(0xFFCD7F32); // Ember (Bronze)
                                          streakIcon = Icons.bolt_rounded;
                                        }

                                        return _buildCompactStatColumn(
                                          'Honored Streak',
                                          '${student.streak} days',
                                          streakIcon,
                                          streakColor,
                                        );
                                      },
                                    ),
                                    _buildCompactStatColumn(
                                      'Avg. Pages',
                                      '${(student.todaySabaqPages > 0 ? student.todaySabaqPages : 1.2).toStringAsFixed(1)}/d',
                                      Icons.trending_up_rounded,
                                      AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 24),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Health',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.success.withValues(alpha: 0.8),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Builder(
                                      builder: (context) {
                                        final juzFreshness = provider.getJuzMemoryStatusForStudent(student.id);
                                        int totalMemorizedPages = 0;
                                        int freshOrStalePages = 0;
                                        
                                        // Retrieve the pageFreshness mapping calculated internally for freshness calculations
                                        // Since getJuzMemoryStatusForStudent summarizes per Juz, we can sum memorizedPagesCount
                                        // and sum the pages that are fresh/stale.
                                        // But wait, getJuzMemoryStatusForStudent has freshPercent.
                                        // Let's calculate directly from getJuzMemoryStatusForStudent.
                                        // Each Juz item contains: 'level' ('fresh', 'stale', 'weak', 'neglected', 'studied', 'never')
                                        // and 'memorizedPagesCount'.
                                        // Wait, the level is the worst level in that Juz.
                                        // If we want a precise page-by-page health calculation, let's write a simple helper or do it here.
                                        // Let's compute page-level freshness:
                                        final logs = provider.getLogsForStudent(student.id);
                                        final pageFreshness = <int, String>{};
                                        
                                        // Pass 1: Studied baseline
                                        for (final log in logs) {
                                          if ((log.status == 'baseline' || log.status == 'baseline_sabqi') && log.sabaq != null) {
                                            final pages = getPagesFromSabaqString(log.sabaq ?? '');
                                            for (final p in pages) {
                                              pageFreshness[p] = 'studied';
                                            }
                                          }
                                        }
                                        
                                        final now = DateTime.now();
                                        // Pass 2: Real logs (Sabaq, Sabqi, Manzil)
                                        for (final log in logs.reversed) {
                                          if (log.status == 'baseline' || log.status == 'baseline_sabqi') continue;
                                          final logDate = DateTime.tryParse(log.date) ?? now;
                                          final diffDays = now.difference(logDate).inDays.abs();
                                          
                                          String level = 'neglected';
                                          if (diffDays <= 3) {
                                            level = 'fresh';
                                          } else if (diffDays <= 7) {
                                            level = 'stale';
                                          } else if (diffDays <= 14) {
                                            level = 'weak';
                                          }
                                          
                                          if (log.sabaq != null) {
                                            final pages = getPagesFromSabaqString(log.sabaq ?? '');
                                            for (final p in pages) {
                                              pageFreshness[p] = level;
                                            }
                                          }
                                          final parsed = log.parsedManzil;
                                          if (parsed != null) {
                                            if (parsed['manzilPages'] is List) {
                                              for (final item in parsed['manzilPages'] as List) {
                                                final p = item is Map ? (item['page'] as num?)?.toInt() : null;
                                                if (p != null) pageFreshness[p] = level;
                                              }
                                            }
                                            if (parsed['sabqi'] is List) {
                                              for (final item in parsed['sabqi'] as List) {
                                                final text = item is String ? item : (item is Map ? (item['sabaq'] as String?) : null);
                                                if (text != null) {
                                                  final m = RegExp(r'Page (\d+)').firstMatch(text);
                                                  if (m != null) {
                                                    final p = int.tryParse(m.group(1) ?? '');
                                                    if (p != null) pageFreshness[p] = level;
                                                  }
                                                }
                                              }
                                            }
                                            if (parsed['manzil'] is String) {
                                              final matches = RegExp(r'Juz\s+(\d+)').allMatches(parsed['manzil'] as String);
                                              for (final m in matches) {
                                                final juz = int.tryParse(m.group(1) ?? '');
                                                if (juz != null) {
                                                  final pages = getPagesForJuz(juz);
                                                  for (final p in pages) {
                                                    pageFreshness[p] = level;
                                                  }
                                                }
                                              }
                                            }
                                          }
                                        }
                                        
                                        totalMemorizedPages = pageFreshness.length;
                                        freshOrStalePages = pageFreshness.values.where((lvl) => lvl == 'fresh' || lvl == 'stale').length;
                                        
                                        final healthVal = totalMemorizedPages > 0
                                            ? ((freshOrStalePages / totalMemorizedPages) * 100).round()
                                            : 0;

                                        return Text(
                                          '$healthVal%',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.success,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Current Goal Card / Hafiz Honoring Card (Harmonized Brand Indigo Palette & Soft Border)
                      Builder(
                        builder: (context) {
                          final isHafiz = student.progressPercent >= 100;
                          if (isHafiz) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.primaryDark], // Match current goal card theme
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.35),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                                    ),
                                    child: const Icon(
                                      Icons.workspace_premium_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "HAFIZ AL-QUR'AN",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Memorization Completed successfully!",
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.9),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            "30 Juzs (604 Pages) Memorized",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final milestone = provider.getJuzMilestoneForStudent(studentId);
                          final activeJuzId = milestone?['id'] ?? (student.currentJuz ?? 1);
                          final juzMeta = getJuzInfo(activeJuzId);
                          final count = milestone?['count'] as int? ?? 0;
                          final total = milestone?['total'] as int? ?? 20;
                          final percent = milestone?['percent'] as int? ?? 0;

                           return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                            ),
                                            child: const Icon(Icons.track_changes_rounded, color: Colors.white, size: 24),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'CURRENT GOAL',
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.75),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 1.1,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Juz $activeJuzId: ${juzMeta.arabicName}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                      ),
                                      child: Text(
                                        '$percent%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  height: 10,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Stack(
                                    children: [
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final targetWidth = constraints.maxWidth * (percent / 100.0);
                                          return Container(
                                            width: targetWidth,
                                            height: double.infinity,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(99),
                                              boxShadow: [
                                                if (percent > 0)
                                                  BoxShadow(
                                                    color: Colors.white.withValues(alpha: 0.5),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 1),
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '$count / $total pages completed',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      '${student.uniqueCount} of 30 Juzs',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      const SizedBox(height: 8),

                      // Sabaq Para Heatmap
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Sabaq Para Heatmap', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                            onPressed: () => _showSabaqParaLegendDialog(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (sabqiPool.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                              SizedBox(width: 12),
                              Expanded(child: Text('Log Sabaq lessons with page numbers to populate the 20-page Sabaq Para pool.', style: TextStyle(fontSize: 13))),
                            ],
                          ),
                        )
                      else
                        Builder(
                          builder: (context) {
                            final juzGroups = <int, List<Map<String, dynamic>>>{};
                            for (final item in sabqiPool) {
                              final j = item['juz'] as int? ?? 1;
                              juzGroups.putIfAbsent(j, () => []).add(item);
                            }
                            final sortedJuzNums = juzGroups.keys.toList()..sort();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: sortedJuzNums.map((juzNum) {
                                final juzMeta = getJuzInfo(juzNum);
                                final pages = juzGroups[juzNum]!;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                              ),
                                              child: Text(
                                                'Juz $juzNum (${juzMeta.arabicName})',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Divider(
                                                color: AppColors.primary.withValues(alpha: 0.2),
                                                thickness: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      GridView.builder(
                                        shrinkWrap: true,
                                        padding: EdgeInsets.zero,
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 5,
                                          crossAxisSpacing: 8,
                                          mainAxisSpacing: 8,
                                          childAspectRatio: 0.9,
                                        ),
                                        itemCount: pages.length,
                                        itemBuilder: (context, index) {
                                          final item = pages[index];
                                          final pageNum = item['page'] ?? 0;
                                          final surah = item['surahName'] ?? '';
                                          final reps = item['reps'] ?? 0;
                                          final level = item['level'] ?? 'critical';

                                          Color bg;
                                          Color border;
                                          Color text;

                                          final isDark = Theme.of(context).brightness == Brightness.dark;

                                          if (level == 'mastered') {
                                            bg = const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08);
                                            border = const Color(0xFF10B981).withValues(alpha: isDark ? 0.3 : 0.2);
                                            text = isDark ? const Color(0xFF34D399) : const Color(0xFF047857);
                                          } else if (level == 'good') {
                                            bg = const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.15 : 0.08);
                                            border = const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.3 : 0.2);
                                            text = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
                                          } else if (level == 'warning') {
                                            bg = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.08);
                                            border = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.3 : 0.2);
                                            text = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
                                          } else {
                                            bg = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.15 : 0.08);
                                            border = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.3 : 0.2);
                                            text = isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
                                          }

                                          return Container(
                                            decoration: BoxDecoration(
                                              color: bg,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: border, width: 1.2),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.02),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Pg $pageNum',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: text,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                                  child: Text(
                                                    surah,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color: isDark ? Colors.white60 : Colors.black54,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: text.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '$reps rep${reps == 1 ? '' : 's'}',
                                                    style: TextStyle(
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.bold,
                                                      color: text,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ).animate().fadeIn(delay: 180.ms),
                    ],
                  ),
                ),

                // TAB 2: FRESHNESS
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      StatefulBuilder(
                        builder: (context, setState) {
                          final juzFreshnessList = provider.getJuzMemoryStatusForStudent(studentId);

                          int freshCount = 0;
                          int staleCount = 0;
                          int weakCount = 0;
                          int neglectedCount = 0;
                          int studiedCount = 0;
                          int unmemorizedCount = 0;

                          for (int i = 0; i < 30; i++) {
                            final status = (i < juzFreshnessList.length) ? juzFreshnessList[i] : {'level': 'never'};
                            final level = status['level'] as String? ?? 'never';
                            switch (level) {
                              case 'fresh': freshCount++; break;
                              case 'stale': staleCount++; break;
                              case 'weak': weakCount++; break;
                              case 'neglected': neglectedCount++; break;
                              case 'studied':
                              case 'active':
                                studiedCount++;
                                break;
                              default: unmemorizedCount++; break;
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Freshness Breakdown', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: _buildFreshnessSummaryBadge('Fresh', '$freshCount', const Color(0xFF10B981))),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildFreshnessSummaryBadge('Stale', '$staleCount', const Color(0xFF6EE7B7))),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildFreshnessSummaryBadge('Weak', '$weakCount', const Color(0xFFF59E0B))),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildFreshnessSummaryBadge('Neglected', '$neglectedCount', const Color(0xFFEF4444))),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Muraja Freshness Heatmap', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                                    onPressed: () => _showFreshnessLegendDialog(context),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.only(top: 4),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  crossAxisSpacing: 6,
                                  mainAxisSpacing: 6,
                                  childAspectRatio: 0.98,
                                ),
                                itemCount: 30,
                                itemBuilder: (context, index) {
                                  final juzNum = index + 1;
                                  final juzMeta = getJuzInfo(juzNum);
                                  final status = (index < juzFreshnessList.length) ? juzFreshnessList[index] : {'level': 'never'};
                                  final level = status['level'] as String? ?? 'never';
                                  final reps = status['revisionCount'] ?? 0;

                                  Color bg;
                                  Color border;
                                  Color text;

                                  switch (level) {
                                    case 'fresh':
                                      bg = const Color(0xFF10B981);
                                      border = const Color(0xFF059669);
                                      text = Colors.white;
                                      break;
                                    case 'stale':
                                      bg = const Color(0xFF6EE7B7);
                                      border = const Color(0xFF34D399);
                                      text = const Color(0xFF064E3B);
                                      break;
                                    case 'weak':
                                      bg = const Color(0xFFF59E0B);
                                      border = const Color(0xFFD97706);
                                      text = Colors.white;
                                      break;
                                    case 'neglected':
                                      bg = const Color(0xFFEF4444);
                                      border = const Color(0xFFDC2626);
                                      text = Colors.white;
                                      break;
                                    case 'studied':
                                      bg = const Color(0xFF818CF8);
                                      border = const Color(0xFF6366F1);
                                      text = Colors.white;
                                      break;
                                    case 'active':
                                      bg = const Color(0xFF4F46E5);
                                      border = const Color(0xFF3730A3);
                                      text = Colors.white;
                                      break;
                                    default:
                                      final isDark = Theme.of(context).brightness == Brightness.dark;
                                      bg = isDark ? Colors.grey.shade900 : Colors.grey.shade200;
                                      border = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
                                      text = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
                                  }

                                  final freshPercent = status['freshPercent'] ?? 0;

                                  Widget cardContent = Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$juzNum',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: text,
                                        ),
                                      ),
                                      Text(
                                        juzMeta.arabicName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: text,
                                        ),
                                      ),
                                      Text(
                                        '$reps reps',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                          color: text.withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  );

                                  if (level != 'never' && level != 'active' && freshPercent > 0 && freshPercent < 100) {
                                    cardContent = Stack(
                                      children: [
                                        Positioned.fill(
                                          child: Padding(
                                            padding: const EdgeInsets.only(bottom: 6.0),
                                            child: cardContent,
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.bottomCenter,
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            height: 3,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: text.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(1.5),
                                            ),
                                            child: FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: freshPercent / 100.0,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: text,
                                                  borderRadius: BorderRadius.circular(1.5),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return InkWell(
                                    onTap: () => _showJuzPagewiseModal(context, juzNum, provider),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: bg,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: border, width: 1.0),
                                      ),
                                      child: cardContent,
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ).animate().fadeIn(delay: 200.ms),
                    ],
                  ),
                ),

                // TAB 3: ACTIVITY LOGS
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ActivityLogsTable(studentId: studentId, provider: provider),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
            // ── Blur + scrim overlay (appears when FAB is expanded) ──
            AnimatedOpacity(
              opacity: _isFabExpanded ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              child: IgnorePointer(
                ignoring: !_isFabExpanded,
                child: GestureDetector(
                  onTap: _toggleFab,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.38),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: _buildExpandableFab(context, student, provider),

      ),
    );
  }

  Widget _buildExpandableFab(BuildContext context, Student student, AppProvider provider) {
    final isHafiz = student.progressPercent >= 100;
    final subButtons = [
      if (!isHafiz)
        (
          label: 'Sabaq',
          icon: Icons.menu_book_rounded,
          color: AppColors.primary,
          tab: 0,
        ),
      if (!isHafiz)
        (
          label: 'Sabaq Para',
          icon: Icons.history_rounded,
          color: const Color(0xFF8B5CF6),
          tab: 1,
        ),
      (
        label: 'Muraja',
        icon: Icons.history_edu_rounded,
        color: const Color(0xFF059669),
        tab: 2,
      ),
      (
        label: 'Mark Student',
        icon: Icons.person_off_rounded,
        color: const Color(0xFFE11D48),
        tab: 3,
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Sub-buttons (revealed when FAB is expanded)
        ...subButtons.map((btn) {
          return AnimatedBuilder(
            animation: _fabAnimation,
            builder: (context, child) {
              final progress = _fabAnimation.value;
              final scale = Curves.easeOutBack.transform(progress.clamp(0.0, 1.0));
              final opacity = progress.clamp(0.0, 1.0);
              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.bottomRight,
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Label chip
                  AnimatedBuilder(
                    animation: _fabAnimation,
                    builder: (context, child) => Opacity(
                      opacity: _fabAnimation.value.clamp(0.0, 1.0),
                      child: child,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        btn.label,
                        style: TextStyle(
                          color: btn.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Icon button
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: FloatingActionButton(
                      heroTag: 'fab_${btn.label}',
                      mini: true,
                      backgroundColor: btn.color,
                      onPressed: () => _openLessonSheet(context, student, provider, btn.tab),
                      child: Icon(btn.icon, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        // Main FAB
        FloatingActionButton(
          heroTag: 'fab_main',
          backgroundColor: AppColors.primary,
          onPressed: _toggleFab,
          child: AnimatedBuilder(
            animation: _fabAnimation,
            builder: (context, _) {
              return Transform.rotate(
                angle: _fabAnimation.value * 0.785398, // 45 degrees
                child: Icon(
                  _isFabExpanded ? Icons.close_rounded : Icons.edit_note_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showJuzPagewiseModal(BuildContext context, int juzNum, AppProvider provider) {
    final juzMeta = getJuzInfo(juzNum);
    final allPagesRepeatCounts = provider.getAllPagesRepeatCountsForStudent(widget.studentId);
    final juzPages = getPagesForJuz(juzNum);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.book_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Juz $juzNum (${juzMeta.arabicName})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'Pagewise Repeat Counts',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final maxReps = juzPages.map((p) => allPagesRepeatCounts[p] ?? 0).reduce(math.max);
                final minReps = juzPages.map((p) => allPagesRepeatCounts[p] ?? 0).reduce(math.min);
                final completedPages = juzPages.where((p) => (allPagesRepeatCounts[p] ?? 0) == maxReps).toList();
                final missingPages = juzPages.where((p) => (allPagesRepeatCounts[p] ?? 0) < maxReps).toList();

                if (maxReps > minReps) {
                  final firstHalfPages = juzNum == 1
                      ? [for (int i = 1; i <= 11; i++) i]
                      : juzNum == 30
                          ? [for (int i = 582; i <= 593; i++) i]
                          : [for (int i = (juzNum - 1) * 20 + 2; i <= (juzNum - 1) * 20 + 11; i++) i];

                  final secondHalfPages = juzNum == 1
                      ? [for (int i = 12; i <= 21; i++) i]
                      : juzNum == 30
                          ? [for (int i = 594; i <= 604; i++) i]
                          : [for (int i = (juzNum - 1) * 20 + 12; i <= juzNum * 20 + 1; i++) i];

                  final missingInFirst = missingPages.where((p) => firstHalfPages.contains(p)).toList();
                  final missingInSecond = missingPages.where((p) => secondHalfPages.contains(p)).toList();

                  String missingText = 'Missing: ${missingPages.map((p) => 'Pg $p').join(', ')}';
                  if (missingInFirst.length == missingPages.length) {
                    missingText = 'Missing First Half: ${missingPages.map((p) => 'Pg $p').join(', ')}';
                  } else if (missingInSecond.length == missingPages.length) {
                    missingText = 'Missing Second Half: ${missingPages.map((p) => 'Pg $p').join(', ')}';
                  }

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Cycle: Level $maxReps',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.warning),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${completedPages.length} of ${juzPages.length} pages revised. $missingText',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'All pages fully revised to Level $minReps!',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              itemCount: juzPages.length,
              itemBuilder: (context, idx) {
                final pageNum = juzPages[idx];
                final info = getSabaqiPageInfo(pageNum);
                final surahName = info['surahName'] as String? ?? '';
                final pageReps = allPagesRepeatCounts[pageNum] ?? 0;

                Color levelColor = AppColors.danger;
                if (pageReps >= 5) {
                  levelColor = AppColors.success;
                } else if (pageReps >= 3) {
                  levelColor = AppColors.info;
                } else if (pageReps >= 1) {
                  levelColor = AppColors.warning;
                }

                return Container(
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: levelColor),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Pg $pageNum',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: levelColor),
                      ),
                      Text(
                        surahName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                      Text(
                        '$pageReps rep${pageReps == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: levelColor),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonProgressCard(
    String label,
    num progress,
    num goal,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = goal > 0 ? (progress / goal).clamp(0.0, 1.0) : 0.0;
    final isCompleted = progress >= goal && goal > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCompleted
              ? [
                  color.withValues(alpha: isDark ? 0.12 : 0.06),
                  color.withValues(alpha: isDark ? 0.04 : 0.01),
                ]
              : [
                  isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
                  isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? color.withValues(alpha: isDark ? 0.4 : 0.25)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isCompleted
                ? color.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 10,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                progress % 1 == 0 ? progress.toInt().toString() : progress.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              if (isCompleted)
                Text(
                  progress == 1 ? ' Page' : ' Pages',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                )
              else
                Text(
                  '/${goal % 1 == 0 ? goal.toInt() : goal} P',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white30 : Colors.black38,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 5,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2.5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2.5),
                  boxShadow: [
                    if (percent > 0)
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStat(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(title, maxLines: 1, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildLessonChecklistItem(
    String label,
    num progress,
    num goal,
    IconData icon,
    Color color,
  ) {
    if (goal == 0) return const SizedBox.shrink();
    final percent = goal > 0 ? (progress / goal).clamp(0.0, 1.0) : 0.0;
    final isCompleted = progress >= goal && goal > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '$progress / $goal pgs',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? AppColors.success : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 6,
                    backgroundColor: Theme.of(context).dividerColor.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollingProgressCard(
    String label,
    num progress,
    num goal,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = goal > 0 ? (progress / goal).clamp(0.0, 1.0) : 0.0;
    final isCompleted = progress >= goal && goal > 0;

    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isCompleted
            ? color.withOpacity(isDark ? 0.12 : 0.06)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? color.withOpacity(isDark ? 0.4 : 0.25)
              : Theme.of(context).dividerColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 8,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                '$progress / $goal pgs',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatColumn(String title, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatusBadge(String label, bool isDone, num progress, num goal) {
    if (goal == 0) return const SizedBox.shrink();
    final color = isDone ? AppColors.success : (progress > 0 ? AppColors.warning : Colors.grey);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isDone ? Icons.check_circle_rounded : (progress > 0 ? Icons.play_circle_filled_rounded : Icons.circle_outlined),
          color: color,
          size: 13,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }


  Widget _buildLogSectionHeader(String title, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildFreshnessSummaryBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  void _showFreshnessLegendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: const Row(
          children: [
            Icon(Icons.style_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Freshness Legend',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLegendItem('Fresh (<= 3 days ago)', const Color(0xFF10B981), Colors.white),
              const SizedBox(height: 8),
              _buildLegendItem('Stale (4 - 7 days ago)', const Color(0xFF6EE7B7), const Color(0xFF064E3B)),
              const SizedBox(height: 8),
              _buildLegendItem('Weak (8 - 14 days ago)', const Color(0xFFF59E0B), Colors.white),
              const SizedBox(height: 8),
              _buildLegendItem('Neglected (> 14 days ago)', const Color(0xFFEF4444), Colors.white),
              const SizedBox(height: 8),
              _buildLegendItem('Studied (Baseline)', const Color(0xFF818CF8), Colors.white),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return _buildLegendItem(
                    'Unmemorized',
                    isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                    isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showSabaqParaLegendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: const Row(
          children: [
            Icon(Icons.style_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sabaq Para Legend',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLegendItem('Mastered (Strong recall)', const Color(0xFF10B981), Colors.white),
              const SizedBox(height: 8),
              _buildLegendItem('Good (Minor hesitations)', const Color(0xFF3B82F6), Colors.white),
              const SizedBox(height: 8),
              _buildLegendItem('Warning (Needs revision)', const Color(0xFFF59E0B), Colors.white),
              const SizedBox(height: 8),
              _buildLegendItem('Critical (Many mistakes)', const Color(0xFFEF4444), Colors.white),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color bg, Color textColor) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ],
    );
  }
}

class ActivityLogsTable extends StatefulWidget {
  final String studentId;
  final AppProvider provider;
  final String? targetMonth;

  const ActivityLogsTable({Key? key, required this.studentId, required this.provider, this.targetMonth}) : super(key: key);

  @override
  State<ActivityLogsTable> createState() => ActivityLogsTableState();
}

class ActivityLogsTableState extends State<ActivityLogsTable> {
  String? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.targetMonth;
  }

  Widget _buildBookTableRowFromRow(BuildContext context, Map<String, dynamic> row) {
    final type = row['type'] as String;
    final int dayNum = row['dayNum'] as int;
    final DateTime d = row['dateObject'] as DateTime;
    final SabaqLog? log = row['log'] as SabaqLog?;
    final isWeekend = row['isWeekend'] as bool? ?? false;
    final isHoliday = row['isHoliday'] as bool? ?? false;

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayOfWeek = weekdays[d.weekday - 1];

    if (type == 'holiday' || type == 'weekend') {
      final label = type == 'holiday' ? 'Holiday' : 'Off Day';
      final bg = type == 'holiday' ? AppColors.warning.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.05);
      final txtColor = type == 'holiday' ? AppColors.warning : Colors.grey;

      return Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 36,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$dayNum', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: txtColor)),
                  Text(dayOfWeek.toLowerCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: txtColor.withValues(alpha: 0.7))),
                ],
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: txtColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: txtColor)),
              ),
            ),
          ],
        ),
      );
    }

    if (type == 'empty' || log == null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 36,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$dayNum', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                  Text(dayOfWeek.toLowerCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey)),
                ],
              ),
            ),
            const Expanded(flex: 3, child: Text('—', style: TextStyle(color: Colors.grey, fontSize: 12))),
            const Expanded(flex: 3, child: Text('—', style: TextStyle(color: Colors.grey, fontSize: 12))),
            const Expanded(flex: 3, child: Text('—', style: TextStyle(color: Colors.grey, fontSize: 12))),
          ],
        ),
      );
    }

    return _buildBookTableRow(context, log, dayNum, dayOfWeek, isHoliday: isHoliday, isWeekend: isWeekend);
  }

  Widget _buildBookTableRow(BuildContext context, SabaqLog log, int dayNum, String dayOfWeek, {bool isHoliday = false, bool isWeekend = false}) {
    String? getJuzStatus(int jNum, List<int> loggedPages) {
      final juzPages = getPagesForJuz(jNum);
      if (juzPages.isEmpty) return null;
      final jLogged = loggedPages.where((p) => getJuzForPage(p) == jNum).toList()..sort();
      if (jLogged.length == juzPages.length && jLogged.every((p) => juzPages.contains(p))) {
        return 'Full';
      }
      if (jNum == 1) {
        if (jLogged.length == 11 && jLogged.every((p) => p >= 1 && p <= 11)) {
          return 'First';
        }
        if (jLogged.length == 10 && jLogged.every((p) => p >= 12 && p <= 21)) {
          return 'Second';
        }
        return null;
      }
      if (jNum == 30) {
        if (jLogged.length == 12 && jLogged.every((p) => p >= 582 && p <= 593)) {
          return 'First';
        }
        if (jLogged.length == 11 && jLogged.every((p) => p >= 594 && p <= 604)) {
          return 'Second';
        }
        return null;
      }
      if (juzPages.length >= 20) {
        final firstHalf = juzPages.sublist(0, 10);
        final secondHalf = juzPages.sublist(10, 20);
        if (jLogged.length == 10 && jLogged.every((p) => firstHalf.contains(p))) {
          return 'First';
        }
        if (jLogged.length == 10 && jLogged.every((p) => secondHalf.contains(p))) {
          return 'Second';
        }
      }
      return null;
    }

    final parsed = log.parsedManzil;
    final sabqiItems = (parsed != null && parsed['sabqi'] is List) ? (parsed['sabqi'] as List) : [];
    final manzilItems = (parsed != null && parsed['manzilPages'] is List) ? (parsed['manzilPages'] as List) : [];
    final manzilJuzStr = (parsed != null && parsed['manzil'] is String) ? parsed['manzil'] as String : '';

    final isAttendance = log.status == 'absent' || log.status == 'sick' || log.status == 'other' || log.status == 'no_lesson';
    final preserveStreak = log.sabaq != null && log.sabaq.contains('[PRESERVE_STREAK]');
    Color rowBg = Colors.transparent;
    if (isAttendance) {
      if (preserveStreak) {
        rowBg = AppColors.success.withValues(alpha: 0.06);
      } else {
        rowBg = AppColors.danger.withValues(alpha: 0.06);
      }
    } else if (isHoliday) {
      rowBg = AppColors.warning.withValues(alpha: 0.08);
    } else if (isWeekend) {
      rowBg = Colors.grey.withValues(alpha: 0.05);
    }

    Color? dateColor;
    if (isHoliday) {
      dateColor = AppColors.warning;
    } else if (isWeekend) {
      dateColor = Colors.grey;
    }

    // Extract dayOfWeek if empty or fallback
    String dayLabel = dayOfWeek;
    try {
      final dt = DateTime.parse(log.date);
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      dayLabel = weekdays[dt.weekday - 1];
    } catch (_) {}

    // Format date string for details dialog
    String formattedDate = log.date;

    // Compact Sabaq text (e.g. "P13, P14 (2:84 - 2:88)")
    String sabaqSummary = '—';
    if (log.cleanSabaqText.isNotEmpty) {
      final sabaqStr = log.cleanSabaqText;
      final pages = getPagesFromSabaqString(log.sabaq ?? '');
      final pStr = pages.isNotEmpty ? pages.map((p) => 'P$p').join(', ') : '';
      
      // Extract Surah and Ayah range: e.g. "Surah Al-Baqarah (Ayah 84-88)" -> "(2:84 - 2:88)"
      final match = RegExp(r'Surah\s+(.*?)\s+\(Ayah\s+(\d+)-(\d+)\)').firstMatch(sabaqStr);
      if (match != null) {
        final surahName = match.group(1) ?? '';
        final ayahFrom = match.group(2) ?? '';
        final ayahTo = match.group(3) ?? '';
        final surahMeta = quranSurahs.firstWhere(
          (s) => s.name.toLowerCase() == surahName.toLowerCase(),
          orElse: () => quranSurahs.first,
        );
        final sNum = surahMeta.number;
        sabaqSummary = '$pStr\n($sNum:$ayahFrom - $sNum:$ayahTo)';
      } else if (pStr.isNotEmpty) {
        sabaqSummary = '$pStr\n(${log.cleanSabaqText})';
      } else {
        sabaqSummary = log.cleanSabaqText;
      }
    } else if (log.status != 'good') {
      sabaqSummary = log.status;
    } else {
      sabaqSummary = '—';
    }

    // Compact Sabaq Para summary (e.g. "20Pgs\n(Pg 1-21)")
    String sabqiSummary = '—';
    final activeSabqiItems = sabqiItems.where((item) {
      final text = item is String ? item : (item is Map ? (item['sabaq'] as String? ?? '') : '');
      return !text.contains('[SKIPPED');
    }).toList();

    if (activeSabqiItems.isNotEmpty) {
      final pages = <int>[];
      for (final item in activeSabqiItems) {
        final text = item is String ? item : (item is Map ? (item['sabaq'] as String? ?? '') : '');
        final m = RegExp(r'Page (\d+)').firstMatch(text);
        if (m != null) {
          final p = int.tryParse(m.group(1) ?? '');
          if (p != null) pages.add(p);
        }
      }
      if (pages.isNotEmpty) {
        pages.sort();
        sabqiSummary = '${pages.length}Pgs\n(Pg ${pages.first}-${pages.last})';
      } else {
        sabqiSummary = '${activeSabqiItems.length}Pgs';
      }
    } else if (sabqiItems.isNotEmpty) {
      Map? skippedItem;
      for (final item in sabqiItems) {
        if (item is Map) {
          final s = item['sabaq']?.toString() ?? '';
          if (s.contains('[SKIPPED')) {
            skippedItem = item;
            break;
          }
        }
      }
      if (skippedItem != null) {
        final rawSabaq = skippedItem['sabaq']?.toString() ?? '';
        sabqiSummary = rawSabaq.replaceAll(' [PRESERVE_STREAK]', '').replaceAll('[PRESERVE_STREAK]', '').trim();
      } else {
        sabqiSummary = 'Skipped';
      }
    }

    // Compact Muraja summary
    // Single Juz: e.g. "J30 - 12Pgs\n(Pg 1-12)"
    // Multi-Juz:  e.g. "J28, J29 - 33Pgs\n(12Pgs, 21Pgs)"
    String murajaSummary = '—';
    if (manzilJuzStr.isNotEmpty) {
      final matches = RegExp(r'Juz\s+(\d+)').allMatches(manzilJuzStr);
      if (matches.isNotEmpty) {
        final juzNums = matches.map((m) => 'J${m.group(1)}').join(', ');
        final totalPgs = matches.length * 20;
        murajaSummary = '$juzNums - ${totalPgs}Pgs';
      } else {
        murajaSummary = manzilJuzStr;
      }
    } else if (manzilItems.isNotEmpty) {
      final juzGroupMap = <int, int>{}; // juzNum -> count of pages
      final pageList = <int>[];

      for (final item in manzilItems) {
        final p = item is Map ? (item['page'] as num?)?.toInt() : null;
        if (p != null && p != -1) {
          pageList.add(p);
          final j = getJuzForPage(p);
          juzGroupMap[j] = (juzGroupMap[j] ?? 0) + 1;
        }
      }

      if (pageList.isNotEmpty) {
        pageList.sort();
        final sortedJuzs = juzGroupMap.keys.toList()..sort();

        if (sortedJuzs.length == 1) {
          final juzNum = sortedJuzs.first;
          final stat = getJuzStatus(juzNum, pageList);
          if (stat == 'First') {
            murajaSummary = 'J$juzNum - 10Pgs (First)';
          } else if (stat == 'Second') {
            murajaSummary = 'J$juzNum - 10Pgs (Second)';
          } else if (stat == 'Full') {
            final juzPages = getPagesForJuz(juzNum);
            murajaSummary = 'J$juzNum - ${juzPages.length}Pgs (Full)';
          } else {
            murajaSummary = 'J$juzNum - ${pageList.length}Pgs\n(Pg ${pageList.first}-${pageList.last})';
          }
        } else {
          final jPrefix = sortedJuzs.map((j) => 'J$j').join(', ');
          final totalPgs = pageList.length;
          final statuses = <String>[];
          for (final j in sortedJuzs) {
            final stat = getJuzStatus(j, pageList);
            if (stat != null) {
              statuses.add(stat);
            } else {
              final count = pageList.where((p) => getJuzForPage(p) == j).length;
              statuses.add('${count}Pgs');
            }
          }
          murajaSummary = '$jPrefix - ${totalPgs}Pgs (${statuses.join(', ')})';
        }
      } else {
        Map? skippedItem;
        for (final item in manzilItems) {
          if (item is Map && item['page'] == -1) {
            skippedItem = item;
            break;
          }
        }
        if (skippedItem != null) {
          final sName = skippedItem['surahName'] as String? ?? 'Skipped';
          murajaSummary = sName.replaceAll(' [PRESERVE_STREAK]', '').replaceAll('[PRESERVE_STREAK]', '').trim();
        }
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color statusBg = const Color(0xFFFEE2E2);
    Color statusTextColor = const Color(0xFF991B1B);
    Color statusBorderColor = const Color(0xFFFCA5A5);

    if (isAttendance) {
      if (log.status == 'no_lesson') {
        statusBg = isDark ? const Color(0xFF2D231E) : const Color(0xFFFFF7ED);
        statusTextColor = isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C);
        statusBorderColor = isDark ? const Color(0xFFC2410C) : const Color(0xFFFFEDD5);
      } else if (preserveStreak) {
        statusBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);
        statusTextColor = isDark ? const Color(0xFF10B981) : const Color(0xFF15803D);
        statusBorderColor = isDark ? const Color(0xFF047857) : const Color(0xFF86EFAC);
      } else {
        statusBg = isDark ? const Color(0xFF3B1A1A) : const Color(0xFFFEE2E2);
        statusTextColor = isDark ? const Color(0xFFEF4444) : const Color(0xFF991B1B);
        statusBorderColor = isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5);
      }
    }

    String reasonText = '';
    if (log.sabaq.contains('[SKIPPED:')) {
      final match = RegExp(r'\[SKIPPED:\s*(.*?)\]').firstMatch(log.sabaq);
      if (match != null) {
        reasonText = match.group(1) ?? '';
        reasonText = reasonText.replaceAll(' [PRESERVE_STREAK]', '').replaceAll('[PRESERVE_STREAK]', '').trim();
        if (reasonText.startsWith('Sick - ')) {
          reasonText = reasonText.substring(7);
        } else if (reasonText.toLowerCase() == 'sick' || reasonText.toLowerCase() == 'absent' || reasonText.toLowerCase() == 'other' || reasonText.toLowerCase() == 'no lesson' || reasonText.toLowerCase() == 'no_lesson') {
          reasonText = '';
        }
      }
    }

    return Container(
      color: rowBg,
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      child: isAttendance
          ? Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$dayNum', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: dateColor)),
                      Text(
                        dayLabel.toLowerCase(),
                        style: TextStyle(fontSize: 10, color: dateColor ?? Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusBorderColor,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          log.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: statusTextColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (reasonText.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reasonText,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Date Column - Leftmost edge
                SizedBox(
                  width: 36,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$dayNum', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: dateColor)),
                      Text(
                        dayLabel.toLowerCase(),
                        style: TextStyle(fontSize: 10, color: dateColor ?? Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                // Sabaq (New) Column - Tappable
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: sabaqSummary != '—'
                        ? () {
                            final rawSabaq = log.sabaq ?? '';
                            final cleanText = log.cleanSabaqText;

                            // Extract lines info
                            String lineInfo = '—';
                            final lineMatch = RegExp(r'(\d+)\s*Line\(s\)').firstMatch(rawSabaq);
                            if (lineMatch != null) {
                              lineInfo = '${lineMatch.group(1)} Line(s)';
                            }

                            // Extract pages info
                            final pages = getPagesFromSabaqString(rawSabaq);
                            final pageStr = pages.isNotEmpty ? pages.map((p) => 'Page $p').join(', ') : '—';

                            // Extract page count info
                            String pageCountInfo = '—';
                            final pageCountMatch = RegExp(r'\((\d+(\.\d+)?)\s*Page[s]?\)').firstMatch(rawSabaq);
                            if (pageCountMatch != null) {
                              final val = double.tryParse(pageCountMatch.group(1) ?? '');
                              if (val != null) {
                                pageCountInfo = '${val.toStringAsFixed(2)} Page(s)';
                              } else {
                                pageCountInfo = '${pageCountMatch.group(1)} Page(s)';
                              }
                            } else if (pages.isNotEmpty) {
                              pageCountInfo = '${pages.length} Page(s)';
                            }

                            // Extract heardBy info
                            String heardBy = '—';
                            final heardMatch = RegExp(r'Heard by:\s*(.+)').firstMatch(rawSabaq);
                            if (heardMatch != null) {
                              heardBy = heardMatch.group(1)?.trim() ?? '—';
                            } else if (log.teacherName != null && log.teacherName!.isNotEmpty) {
                              heardBy = log.teacherName!;
                            }

                            // Build detailed sabaq items
                            final items = <String>[
                              'Surah & Ayahs: $cleanText',
                              'Page(s): $pageStr',
                              'Page Count: $pageCountInfo',
                              'Line Count: $lineInfo',
                              'Heard By: $heardBy',
                            ];

                            _showCellDetailsDialog(context, formattedDate, 'Sabaq Lesson Details', items, AppColors.primary, log: log, fieldType: 'sabaq');
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: Text(
                        sabaqSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),

                // Sabaq Para Column - Tappable
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: sabqiSummary != '—'
                        ? () {
                            final defaultHeardBy = (log.teacherName != null && log.teacherName!.isNotEmpty) ? log.teacherName! : 'Teacher';
                            final grouped = <String, List<int>>{};

                            if (sabqiItems.isNotEmpty) {
                              for (final item in sabqiItems) {
                                String text = '';
                                String heardBy = defaultHeardBy;
                                if (item is String) {
                                  text = item;
                                } else if (item is Map) {
                                  text = item['sabaq'] as String? ?? '';
                                  if (item['heardBy'] != null && (item['heardBy'] as String).isNotEmpty) {
                                    heardBy = item['heardBy'] as String;
                                  }
                                }
                                final m = RegExp(r'Page (\d+)').firstMatch(text);
                                if (m != null) {
                                  final p = int.tryParse(m.group(1) ?? '');
                                  if (p != null) {
                                    grouped.putIfAbsent(heardBy, () => []).add(p);
                                  }
                                }
                              }
                            }

                            final items = <String>[];
                            if (grouped.isNotEmpty) {
                              grouped.forEach((heardBy, pages) {
                                pages.sort();
                                String pageRange = '';
                                if (pages.length == 1) {
                                  pageRange = 'Page ${pages.first}';
                                } else {
                                  pageRange = 'Pages ${pages.first}-${pages.last} (${pages.length} pgs)';
                                }
                                items.add('$pageRange — Heard by $heardBy');
                              });
                            } else {
                              items.add('$sabqiSummary — Heard by $defaultHeardBy');
                            }

                            _showCellDetailsDialog(context, formattedDate, 'Sabaq Para Details', items, AppColors.info, log: log, fieldType: 'sabqi');
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: Text(
                        sabqiSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: sabqiSummary != '—'
                                  ? (Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF60A5FA)
                                      : const Color(0xFF2563EB))
                                  : Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ),

                // Muraja Column - Tappable
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: murajaSummary != '—'
                        ? () {
                            final defaultHeardBy = (log.teacherName != null && log.teacherName!.isNotEmpty) ? log.teacherName! : 'Teacher';
                            final grouped = <String, List<int>>{};
                            if (manzilItems.isNotEmpty) {
                              for (final item in manzilItems) {
                                if (item is Map) {
                                  final p = (item['page'] as num?)?.toInt();
                                  final heardBy = (item['heardBy'] as String?)?.isNotEmpty == true ? item['heardBy'] as String : defaultHeardBy;
                                  if (p != null && p != -1) {
                                    final juzId = getJuzForPage(p);
                                    final key = "$juzId|$heardBy";
                                    grouped.putIfAbsent(key, () => []).add(p);
                                  }
                                }
                              }
                            }

                            final items = <dynamic>[];
                            if (grouped.isNotEmpty) {
                              final keys = grouped.keys.toList()
                                ..sort((a, b) {
                                  final juzA = int.parse(a.split('|')[0]);
                                  final juzB = int.parse(b.split('|')[0]);
                                  return juzA.compareTo(juzB);
                                });

                              for (final key in keys) {
                                final parts = key.split('|');
                                final juzId = int.parse(parts[0]);
                                final heardBy = parts[1];
                                final pages = grouped[key]!..sort();
                                final juzMeta = getJuzInfo(juzId);

                                String pageRange = '';
                                if (pages.length == 1) {
                                  pageRange = '${pages.first}';
                                } else {
                                  pageRange = '${pages.first}-${pages.last} (${pages.length} pgs)';
                                }

                                String? halfText;
                                final juzPages = getPagesForJuz(juzId);
                                if (juzPages.length >= 20) {
                                  final firstHalfPages = juzPages.sublist(0, 10);
                                  final secondHalfPages = juzPages.sublist(10, 20);
                                  if (pages.length == 10 && pages.every((p) => firstHalfPages.contains(p))) {
                                    halfText = 'First Half';
                                  } else if (pages.length == 10 && pages.every((p) => secondHalfPages.contains(p))) {
                                    halfText = 'Second Half';
                                  }
                                }

                                items.add({
                                  'juzNum': juzId,
                                  'juzName': juzMeta.arabicName,
                                  'pageRange': pageRange,
                                  'half': halfText,
                                  'heardBy': heardBy,
                                });
                              }
                            } else if (manzilJuzStr.isNotEmpty) {
                              final m = RegExp(r'Juz\s+(\d+)').firstMatch(manzilJuzStr);
                              if (m != null) {
                                final jNum = int.tryParse(m.group(1) ?? '1') ?? 1;
                                final jMeta = getJuzInfo(jNum);
                                final jPages = getPagesForJuz(jNum);
                                items.add({
                                  'juzNum': jNum,
                                  'juzName': jMeta.arabicName,
                                  'pageRange': jPages.isNotEmpty ? '${jPages.first}-${jPages.last} (20 pgs)' : 'Full Juz',
                                  'half': null,
                                  'heardBy': defaultHeardBy,
                                });
                              } else {
                                items.add(manzilJuzStr);
                              }
                            } else {
                              items.add('$murajaSummary — Heard by $defaultHeardBy');
                            }

                            _showCellDetailsDialog(context, formattedDate, 'Muraja Details', items, AppColors.success, log: log, fieldType: 'manzil');
                          }
                        : null,
                    child: Text(
                      murajaSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: murajaSummary != '—' ? AppColors.success : Colors.grey, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showCellDetailsDialog(BuildContext context, String date, String title, List<dynamic> items, Color accentColor, {SabaqLog? log, String fieldType = ''}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.description_rounded, color: accentColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$title ($date)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) {
              if (fieldType == 'manzil' && item is Map) {
                final juzNum = item['juzNum'];
                final juzName = item['juzName'];
                final pageRange = item['pageRange'];
                final half = item['half'];
                final heardBy = item['heardBy'];

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // First Line: Juz No. and Name
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Juz $juzNum',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$juzName',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Second Line: Page Range
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          'Pages: $pageRange',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color),
                        ),
                      ),
                      if (half != null) ...[
                        const SizedBox(height: 8),
                        // Third Line: First Half / Second Half
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            half,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      // Fourth Line: Who heard
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 14, color: Theme.of(context).textTheme.bodySmall?.color),
                          const SizedBox(width: 4),
                          Text(
                            'Heard by: $heardBy',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodySmall?.color),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  item.toString(),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: accentColor),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          if (log != null && fieldType.isNotEmpty)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: ctx,
                  builder: (c) => AlertDialog(
                    title: Text('Clear ${fieldType == 'sabaq' ? 'Sabaq' : fieldType == 'sabqi' ? 'Sabaq Para' : 'Muraja'}?'),
                    content: Text('This will clear the ${fieldType == 'sabaq' ? 'Sabaq' : fieldType == 'sabqi' ? 'Sabaq Para' : 'Muraja'} entry for $date. Other fields on this date will be preserved.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text('Clear', style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                );
                if (confirm != true || !ctx.mounted) return;

                final provider = context.read<AppProvider>();
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                String? result;
                if (fieldType == 'sabaq') {
                  result = await provider.mergeLog(studentId: log.studentId, date: log.date, sabaq: '');
                } else {
                  final existingManzil = log.parsedManzil ?? {};
                  final modified = Map<String, dynamic>.from(existingManzil);
                  if (fieldType == 'sabqi') {
                    modified['sabqi'] = <Map<String, dynamic>>[];
                  } else {
                    modified['manzilPages'] = <Map<String, dynamic>>[];
                  }
                  result = await provider.mergeLog(studentId: log.studentId, date: log.date, manzil: modified);
                }

                if (result == null) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('${fieldType == 'sabaq' ? 'Sabaq' : fieldType == 'sabqi' ? 'Sabaq Para' : 'Muraja'} cleared successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear: $result'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Delete', style: TextStyle(color: AppColors.danger)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableMonths = widget.provider.getAvailableMonthsForStudent(widget.studentId);
    if (widget.targetMonth != null) {
      _selectedMonth = widget.targetMonth;
    } else if (availableMonths.isNotEmpty && (_selectedMonth == null || !availableMonths.contains(_selectedMonth))) {
      _selectedMonth = availableMonths[0];
    }

    final tableRows = widget.provider.getTableRowsForStudent(widget.studentId, targetMonth: _selectedMonth);

    // Format month for display e.g. "2026-07" -> "July 2026"
    String formatMonthLabel(String monthStr) {
      try {
        final parts = monthStr.split('-');
        final year = parts[0];
        final monthIdx = int.parse(parts[1]);
        final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
        return '${months[monthIdx - 1]} $year';
      } catch (_) {
        return monthStr;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Activity Logs', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            if (availableMonths.isNotEmpty && widget.targetMonth == null)
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMonth,
                  isDense: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                  items: availableMonths.map((m) {
                    return DropdownMenuItem<String>(
                      value: m,
                      child: Text(formatMonthLabel(m)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedMonth = val;
                      });
                    }
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                // Table Header Row
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
                  color: AppColors.primary.withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      const SizedBox(width: 36, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary))),
                      const Expanded(flex: 3, child: Text('Sabaq', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary))),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Sabaq Para',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const Expanded(flex: 3, child: Text('Muraja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.success))),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tableRows.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                  itemBuilder: (context, i) {
                    final row = tableRows[i];
                    return _buildBookTableRowFromRow(context, row);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _SliverTabBarDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: overlapsContent
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: child,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: -16.0,
          child: IgnorePointer(
            child: Container(
              height: 16.0,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).scaffoldBackgroundColor,
                    Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return true;
  }
}
