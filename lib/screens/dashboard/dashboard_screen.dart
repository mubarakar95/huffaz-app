import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_provider.dart';
import '../../core/theme.dart';
import '../../utils/quran_data.dart';
import '../../utils/student_utils.dart';
import '../../models/student.dart';
import '../../widgets/log_sabaq_sheet.dart';
import '../../widgets/log_sabqi_sheet.dart';
import '../../widgets/log_manzil_sheet.dart';
import '../../widgets/mark_student_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load today's acknowledgements on dashboard open (runs in background, provider notifies)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final lastClassDay = _getLastClassDay(provider.weeklyOffDays, provider.holidaysSet);
      final yesterday = '${lastClassDay.year}-${lastClassDay.month.toString().padLeft(2, '0')}-${lastClassDay.day.toString().padLeft(2, '0')}';
      provider.loadAcknowledgements(today);
      provider.loadAcknowledgements(yesterday);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final profile = provider.profile;
        final data = provider.dashboardData;

        if (provider.isLoading && data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final firstName = profile?.fullName.split(' ').first ?? 'User';
        final role = profile?.role ?? 'admin';
        final recentLogs = (data?['recentLogs'] as List<dynamic>?) ?? [];
        final groupedLogs = _groupRecentLogs(recentLogs);

        final totalStudents = data?['totalStudents'] ?? 0;
        final totalAssignedStudents = data?['totalAssignedStudents'] ?? totalStudents;
        final totalTeachers = data?['totalTeachers'] ?? 0;
        final todayLoggedCount = data?['todayLoggedCount'] ?? 0;
        final todayAbsentCount = data?['todayAbsentCount'] ?? 0;
        final totalPersonalStudents = data?['totalPersonalStudents'] ?? 0;
        final todayLoggedPersonalCount = data?['todayLoggedPersonalCount'] ?? 0;
        final yesterdayLoggedPersonalCount = data?['yesterdayLoggedPersonalCount'] ?? 0;
        final yesterdayLoggedCount = data?['yesterdayLoggedCount'] ?? 0;

        final todayStr = getLocalToday();
        final lastClassDay = _getLastClassDay(provider.weeklyOffDays, provider.holidaysSet);
        final yesterdayStr = '${lastClassDay.year}-${lastClassDay.month.toString().padLeft(2, '0')}-${lastClassDay.day.toString().padLeft(2, '0')}';
        final isTeacher = role == 'teacher';

        final institutionStudents = provider.students.where((s) => s.isPersonal != true).toList();
        final personalAssignedStudents = provider.students
            .where((s) => s.teacherId == profile?.id && s.isPersonal != true)
            .toList();

        /// Evaluate whether a student has completed their 3-lesson target for [dateStr].
        /// Returns: isComplete, isExempt, pending list, and per-lesson page counts from the log.
        Map<String, dynamic> evaluateForDate(Student student, String dateStr) {
          final isHafiz = student.progressPercent >= 100;
          final sGoal = student.sabaqGoal ?? provider.defaultSabaqGoal;
          final sqGoal = student.sabqiGoal ?? provider.defaultSabqiGoal;
          final mGoal = student.manzilGoal ?? provider.defaultManzilGoal;

          final logs = provider.getLogsForStudent(student.id);
          final log = logs.where((l) => l.date.split('T')[0] == dateStr).firstOrNull;

          if (log == null) {
            return {
              'isComplete': false,
              'isExempt': false,
              'pending': isHafiz ? ['Muraja'] : ['Sabaq', 'Sabqi', 'Muraja'],
              'sabaqPages': 0.0,
              'sabqiPages': 0.0,
              'manzilPages': 0.0,
            };
          }

          final status = log.status;
          if (status == 'absent' || status == 'sick' || status == 'other') {
            return {
              'isComplete': false,
              'isExempt': true,
              'pending': <String>[],
              'sabaqPages': 0.0,
              'sabqiPages': 0.0,
              'manzilPages': 0.0,
            };
          }

          // Compute page counts from the log (works for any date)
          final isAbsent = false; // already handled above
          final sabaqStr = log.sabaq;
          final sabaqPages = sabaqStr.isNotEmpty
              ? getPagesCountFromSabaqString(sabaqStr)
              : 0.0;
          final parsedManzil = log.parsedManzil;
          final sabqiItems = parsedManzil?['sabqi'] as List?;
          final sabqiPages = (sabqiItems?.length ?? 0).toDouble();
          double manzilPages = 0.0;
          if (parsedManzil != null) {
            if (parsedManzil['manzilPages'] is List) {
              manzilPages += (parsedManzil['manzilPages'] as List).length.toDouble();
            }
            if (parsedManzil['manzil'] is String) {
              final matches = RegExp(r'Juz\s+\d+').allMatches(parsedManzil['manzil'] as String);
              manzilPages += matches.length * 20.0;
            }
          }

          final sabaqIsSkipped = sabaqStr.contains('[SKIPPED');
          final sabaqDone = sabaqIsSkipped || sabaqPages >= sGoal;

          final sabqiIsSkipped = sabqiItems != null &&
              sabqiItems.any((item) =>
                  item is Map &&
                  item['sabaq'] != null &&
                  item['sabaq'].toString().contains('[SKIPPED'));
          final sabqiDone = sabqiIsSkipped || sabqiPages >= sqGoal;

          final manzilPageItems = parsedManzil?['manzilPages'] as List?;
          final manzilIsSkipped = (manzilPageItems != null &&
                  manzilPageItems.any((item) =>
                      item is Map &&
                      (item['page'] == -1 ||
                          (item['surahName'] != null &&
                              item['surahName'].toString().contains('[SKIPPED'))))) ||
              (parsedManzil?['manzil']?.toString().contains('[SKIPPED') ?? false);
          final manzilDone = manzilIsSkipped || manzilPages >= mGoal;

          final pending = <String>[];
          if (isHafiz) {
            if (!manzilDone) pending.add('Muraja');
          } else {
            if (!sabaqDone) pending.add('Sabaq');
            if (!sabqiDone) pending.add('Sabqi');
            if (!manzilDone) pending.add('Muraja');
          }

          return {
            'isComplete': pending.isEmpty,
            'isExempt': false,
            'pending': pending,
            'sabaqPages': sabaqPages,
            'sabqiPages': sabqiPages,
            'manzilPages': manzilPages,
            'sabaqSkipped': sabaqIsSkipped,
            'sabqiSkipped': sabqiIsSkipped,
            'manzilSkipped': manzilIsSkipped,
          };
        }

        List<Map<String, dynamic>> buildIncompleteList(
            List<Student> students, String dateStr) {
          final list = <Map<String, dynamic>>[];
          for (var s in students) {
            final eval = evaluateForDate(s, dateStr);
            if (eval['isExempt'] as bool? ?? false) continue;
            if (!(eval['isComplete'] as bool)) {
              final pendingList = eval['pending'] as List<String>;
              list.add({
                'id': s.id,
                'name': s.fullName,
                'isHafiz': s.progressPercent >= 100,
                'sabaqDone': !pendingList.contains('Sabaq'),
                'sabqiDone': !pendingList.contains('Sabqi'),
                'manzilDone': !pendingList.contains('Muraja'),
                'sabaqPages': eval['sabaqPages'],
                'sabqiPages': eval['sabqiPages'],
                'manzilPages': eval['manzilPages'],
                'sabaqSkipped': eval['sabaqSkipped'],
                'sabqiSkipped': eval['sabqiSkipped'],
                'manzilSkipped': eval['manzilSkipped'],
              });
            }
          }
          return list;
        }

        int countComplete(List<Student> students, String dateStr) {
          int count = 0;
          int total = 0;
          for (var s in students) {
            final eval = evaluateForDate(s, dateStr);
            if (eval['isExempt'] as bool? ?? false) continue;
            total++;
            if (eval['isComplete'] as bool) count++;
          }
          return count;
        }

        int countPresent(List<Student> students, String dateStr) {
          int total = 0;
          for (var s in students) {
            final eval = evaluateForDate(s, dateStr);
            if (eval['isExempt'] as bool? ?? false) continue;
            total++;
          }
          return total;
        }

        // --- Today ---
        final incompletePersonalStudents = buildIncompleteList(personalAssignedStudents, todayStr);
        final todayLoggedPersonalFullCount = countComplete(personalAssignedStudents, todayStr);
        final personalPresentCount = countPresent(personalAssignedStudents, todayStr);

        final incompleteInstitutionStudents = buildIncompleteList(institutionStudents, todayStr);
        final todayLoggedInstitutionFullCount = countComplete(institutionStudents, todayStr);
        final institutionPresentCount = countPresent(institutionStudents, todayStr);

        // --- Yesterday ---
        final incompletePersonalYesterdayStudents = buildIncompleteList(personalAssignedStudents, yesterdayStr);
        final yesterdayPersonalFullCount = countComplete(personalAssignedStudents, yesterdayStr);
        final yesterdayPersonalPresentCount = countPresent(personalAssignedStudents, yesterdayStr);

        final incompleteInstitutionYesterdayStudents = buildIncompleteList(institutionStudents, yesterdayStr);
        final yesterdayInstitutionFullCount = countComplete(institutionStudents, yesterdayStr);
        final yesterdayInstitutionPresentCount = countPresent(institutionStudents, yesterdayStr);

        // Pick the right set based on role
        final todayLoggedFullCount = isTeacher ? todayLoggedPersonalFullCount : todayLoggedInstitutionFullCount;
        final totalAssignedPresentCount = isTeacher ? personalPresentCount : institutionPresentCount;
        final incompleteStudents = isTeacher ? incompletePersonalStudents : incompleteInstitutionStudents;

        final incompleteYesterdayStudents = isTeacher ? incompletePersonalYesterdayStudents : incompleteInstitutionYesterdayStudents;
        final yesterdayFullCount = isTeacher ? yesterdayPersonalFullCount : yesterdayInstitutionFullCount;
        final yesterdayPresentCount = isTeacher ? yesterdayPersonalPresentCount : yesterdayInstitutionPresentCount;


        return RefreshIndicator(
          onRefresh: () => provider.refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Hero Header & Welcoming Tone
                _buildHeroHeader(context, firstName, role, profile?.institutionName ?? ''),

                // Teacher Absence Banner
                _buildTeacherAbsenceBanner(context, provider),

                // Other Absent Teachers Banner
                _buildOtherAbsentTeachersBanner(context, provider),



                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      // 2. Metrics & Info Cards Section (Asymmetrical Visual Hierarchy)
                      _buildMetricsSection(
                        context,
                        totalStudents: totalStudents,
                        totalAssignedStudents: totalAssignedStudents,
                        totalTeachers: totalTeachers,
                        todayLoggedCount: todayLoggedCount,
                        todayAbsentCount: todayAbsentCount,
                        totalPersonalStudents: totalPersonalStudents,
                        todayLoggedPersonalCount: todayLoggedPersonalCount,
                        todayLoggedFullCount: todayLoggedFullCount,
                         todayLoggedPersonalFullCount: todayLoggedPersonalFullCount,
                        personalPresentCount: personalPresentCount,
                        totalAssignedPresentCount: totalAssignedPresentCount,
                        yesterdayLoggedPersonalCount: yesterdayLoggedPersonalCount,
                        yesterdayLoggedCount: yesterdayLoggedCount,
                        incompleteStudents: incompleteStudents,
                        incompletePersonalStudents: incompletePersonalStudents,
                        provider: provider,
                        todayStr: todayStr,
                        yesterdayStr: yesterdayStr,
                        incompleteYesterdayStudents: incompleteYesterdayStudents,
                        yesterdayFullCount: yesterdayFullCount,
                        yesterdayPresentCount: yesterdayPresentCount,
                        incompletePersonalYesterdayStudents: incompletePersonalYesterdayStudents,
                        yesterdayPersonalFullCount: yesterdayPersonalFullCount,
                        yesterdayPersonalPresentCount: yesterdayPersonalPresentCount,
                        todayLoggedInstitutionFullCount: todayLoggedInstitutionFullCount,
                        institutionPresentCount: institutionPresentCount,
                        isTeacher: isTeacher,
                        yesterdayInstitutionFullCount: yesterdayInstitutionFullCount,
                        yesterdayInstitutionPresentCount: yesterdayInstitutionPresentCount,
                      ),

                      const SizedBox(height: 32),

                      // Section Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Activity Feed',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => context.go('/students'),
                            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                            label: const Text('View All'),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.primary,
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ).animate().slideY(delay: 600.ms, begin: 0.1).fadeIn(),

                      const SizedBox(height: 12),

                      // 3. Activity Feed Log (Timeline Layout)
                      if (groupedLogs.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color ?? theme.cardColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: theme.dividerColor.withOpacity(0.08),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.hourglass_empty_rounded,
                                size: 40,
                                color: theme.colorScheme.onSurface.withOpacity(0.3),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No activity logged today yet.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 700.ms)
                      else
                        ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: groupedLogs.length,
                          itemBuilder: (context, index) {
                            final log = groupedLogs[index];
                            final isLast = index == groupedLogs.length - 1;
                            return _buildTimelineItem(context, log, isLast, index)
                                .animate()
                                .slideX(begin: 0.05, delay: (700 + index * 80).ms)
                                .fadeIn();
                          },
                        ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _groupRecentLogs(List<dynamic> rawLogs) {
    final List<Map<String, dynamic>> processed = [];
    final Map<String, List<Map<String, dynamic>>> baselineGroups = {};

    for (final raw in rawLogs) {
      final log = Map<String, dynamic>.from(raw as Map);
      final status = log['status'] as String?;

      if (status == 'baseline' || status == 'baseline_sabqi') {
        final studentId = log['student_id'] as String? ?? '';
        final createdAt = log['created_at'] as String? ?? '';
        final timeKey = createdAt.length >= 19 ? createdAt.substring(0, 19) : createdAt;
        final groupKey = '${studentId}_$timeKey';

        baselineGroups.putIfAbsent(groupKey, () => []).add(log);
      } else {
        processed.add(log);
      }
    }

    baselineGroups.forEach((groupKey, logs) {
      if (logs.isEmpty) return;

      final firstLog = logs.first;
      final student = firstLog['students'] ?? {};
      final profile = firstLog['profiles'] ?? {};

      final List<int> sabaqPages = [];
      final List<int> sabqiPages = [];

      for (final log in logs) {
        final sabaqStr = log['sabaq']?.toString() ?? '';
        final status = log['status'] as String?;
        final m = RegExp(r'Page\s+(\d+)').firstMatch(sabaqStr);
        if (m != null) {
          final p = int.tryParse(m.group(1) ?? '');
          if (p != null) {
            if (status == 'baseline') {
              sabaqPages.add(p);
            } else {
              sabqiPages.add(p);
            }
          }
        }
      }

      sabaqPages.sort();
      sabqiPages.sort();

      processed.add({
        'id': firstLog['id'],
        'student_id': firstLog['student_id'],
        'date': firstLog['date'],
        'status': 'baseline_summary',
        'created_at': firstLog['created_at'],
        'students': student,
        'profiles': profile,
        'sabaqPages': sabaqPages,
        'sabqiPages': sabqiPages,
      });
    });

    processed.sort((a, b) {
      final aTime = a['created_at']?.toString() ?? '';
      final bTime = b['created_at']?.toString() ?? '';
      return bTime.compareTo(aTime);
    });

    return processed;
  }

  String _formatPageRanges(List<int> pages) {
    if (pages.isEmpty) return '';
    final List<String> ranges = [];
    int start = pages.first;
    int prev = pages.first;
    for (int i = 1; i < pages.length; i++) {
      final curr = pages[i];
      if (curr == prev + 1) {
        prev = curr;
      } else {
        if (start == prev) {
          ranges.add('Pg $start');
        } else {
          ranges.add('Pg $start-$prev');
        }
        start = curr;
        prev = curr;
      }
    }
    if (start == prev) {
      ranges.add('Pg $start');
    } else {
      ranges.add('Pg $start-$prev');
    }
    return ranges.join(', ');
  }

  // --- UI Component: Hero Header ---
  Widget _buildHeroHeader(BuildContext context, String firstName, String role, String institutionName) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            primaryColor.withOpacity(0.85),
            primaryColor.withOpacity(0.7),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ambient Glow/Decorative circles
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            left: -50,
            bottom: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              top: MediaQuery.of(context).padding.top + kToolbarHeight - 16.0,
              bottom: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assalamu Alaikum 👋',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ).animate().fadeIn().slideY(begin: -0.2),
                          const SizedBox(height: 4),
                          Text(
                            firstName,
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.2),
                          if (institutionName.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.account_balance_rounded,
                                  size: 14,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    institutionName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withOpacity(0.85),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ).animate().fadeIn(delay: 150.ms).slideY(begin: -0.2),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            role.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.brightness_5_rounded,
                        color: Colors.amber[300],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Welcome back! Ready to track your students' memorization progress today?",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.95),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).scale(begin: const Offset(0.95, 0.95)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Component: Metrics & Info Cards Section (Visual Hierarchy & Glassmorphism) ---
  Widget _buildMetricsSection(
    BuildContext context, {
    required int totalStudents,
    required int totalAssignedStudents,
    required int totalTeachers,
    required int todayLoggedCount,
    required int todayAbsentCount,
    required int totalPersonalStudents,
    required int todayLoggedPersonalCount,
    required int todayLoggedFullCount,
    required int todayLoggedPersonalFullCount,
    required int personalPresentCount,
    required int totalAssignedPresentCount,
    required int yesterdayLoggedPersonalCount,
    required int yesterdayLoggedCount,
    required List<dynamic> incompleteStudents,
    required List<dynamic> incompletePersonalStudents,
    required AppProvider provider,
    required String todayStr,
    required String yesterdayStr,
    required List<dynamic> incompleteYesterdayStudents,
    required int yesterdayFullCount,
    required int yesterdayPresentCount,
    required List<dynamic> incompletePersonalYesterdayStudents,
    required int yesterdayPersonalFullCount,
    required int yesterdayPersonalPresentCount,
    required int todayLoggedInstitutionFullCount,
    required int institutionPresentCount,
    required bool isTeacher,
    required int yesterdayInstitutionFullCount,
    required int yesterdayInstitutionPresentCount,
  }) {
    final showPersonalProgress = totalPersonalStudents > 0 && totalAssignedStudents != totalPersonalStudents;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Check if today is weekend or holiday
    final now = DateTime.now();
    final isTodayWeekend = provider.weeklyOffDays.contains(now.weekday);
    final isTodayHoliday = provider.holidaysSet.contains(todayStr);
    final isTodayOff = isTodayWeekend || isTodayHoliday;

    // Determine if yesterday has unacknowledged pending students
    final yesterdayAckedIds = provider.getAcknowledgedIds(yesterdayStr);
    final yesterdayPendingVisible = incompleteYesterdayStudents
        .where((s) => !yesterdayAckedIds.contains(s['id'] as String))
        .toList();
    final hasYesterdayPending = yesterdayPendingVisible.isNotEmpty;

    // Calculate dynamic name for the last class day (e.g. "Yesterday" or "Thursday")
    final parsedYesterdayDate = DateTime.tryParse(yesterdayStr);
    String lastClassDayName = "Yesterday";
    if (parsedYesterdayDate != null) {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
      final isYesterday = parsedYesterdayDate.year == yesterday.year &&
          parsedYesterdayDate.month == yesterday.month &&
          parsedYesterdayDate.day == yesterday.day;
      if (!isYesterday) {
        lastClassDayName = DateFormat('EEEE').format(parsedYesterdayDate);
      }
    }
    final institutionStudents = provider.students.where((s) => s.isPersonal != true).toList();
    final personalAssignedStudents = provider.students
        .where((s) => s.teacherId == provider.profile?.id && s.isPersonal != true)
        .toList();

    final todayAckedIds = provider.getAcknowledgedIds(todayStr);
    final todayIncompleteInstitutionIds = incompleteStudents.map((s) => s['id'] as String).toSet();
    final todayAcknowledgedInstitutionCount = institutionStudents
        .where((s) => todayAckedIds.contains(s.id) && todayIncompleteInstitutionIds.contains(s.id))
        .length;

    final yesterdayIncompletePersonalIds = incompletePersonalYesterdayStudents.map((s) => s['id'] as String).toSet();
    final yesterdayAcknowledgedPersonalCount = personalAssignedStudents
        .where((s) => yesterdayAckedIds.contains(s.id) && yesterdayIncompletePersonalIds.contains(s.id))
        .length;

    final yesterdayIncompleteInstitutionIds = incompleteYesterdayStudents.map((s) => s['id'] as String).toSet();
    final yesterdayAcknowledgedInstitutionCount = institutionStudents
        .where((s) => yesterdayAckedIds.contains(s.id) && yesterdayIncompleteInstitutionIds.contains(s.id))
        .length;

    final yesterdayAcknowledgedCount = isTeacher
        ? yesterdayAcknowledgedPersonalCount
        : yesterdayAcknowledgedInstitutionCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showPersonalProgress) ...[
          // Yesterday: show tracking card if pending, compact card if all done
          if (hasYesterdayPending)
            _buildLessonTrackingCard(
              context,
              title: "$lastClassDayName Pending",
              loggedCount: yesterdayPersonalFullCount,
              totalCount: yesterdayPersonalPresentCount,
              incompleteList: incompletePersonalYesterdayStudents,
              provider: provider,
              dateStr: yesterdayStr,
            ).animate().scale(delay: 150.ms, begin: const Offset(0.98, 0.98)).fadeIn()
          else
            _buildProgressCard(
              context,
              title: lastClassDayName,
              subtitle: "Class logging status $lastClassDayName",
              loggedCount: yesterdayPersonalFullCount + yesterdayAcknowledgedPersonalCount,
              totalCount: yesterdayPersonalPresentCount,
              compact: true,
            ).animate().scale(delay: 150.ms, begin: const Offset(0.98, 0.98)).fadeIn(),

          const SizedBox(height: 16),

          if (isTodayOff)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isTodayHoliday ? Icons.celebration_rounded : Icons.weekend_rounded,
                    color: theme.colorScheme.primary.withOpacity(0.7),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTodayHoliday ? "Holiday Today" : "Weekend Off Day",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: theme.textTheme.titleMedium?.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isTodayHoliday
                              ? "Today is marked as an institution holiday."
                              : "No classes scheduled for today.",
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.grey[400] : AppColors.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().scale(delay: 200.ms, begin: const Offset(0.98, 0.98)).fadeIn()
          else ...[
            // Today: Primary 3-lesson card
            _buildLessonTrackingCard(
              context,
              title: "3 Lesson today",
              loggedCount: todayLoggedPersonalFullCount,
              totalCount: personalPresentCount,
              incompleteList: incompletePersonalStudents,
              provider: provider,
              dateStr: todayStr,
            ).animate().scale(delay: 200.ms, begin: const Offset(0.98, 0.98)).fadeIn(),

            const SizedBox(height: 16),

            // Whole Institution Progress card (admin overview)
            _buildProgressCard(
              context,
              title: "Today's Progress (All)",
              subtitle: "Overview of all enrolled students logging status",
              loggedCount: todayLoggedInstitutionFullCount + todayAcknowledgedInstitutionCount,
              totalCount: institutionPresentCount,
            ).animate().scale(delay: 250.ms, begin: const Offset(0.98, 0.98)).fadeIn(),
          ],
        ] else ...[
          // Admin with no personal assigned students: show overview progress cards instead of 3-lesson pending tracking card
          _buildProgressCard(
            context,
            title: "$lastClassDayName (All)",
            subtitle: "Overview of logging $lastClassDayName",
            loggedCount: yesterdayInstitutionFullCount + yesterdayAcknowledgedInstitutionCount,
            totalCount: yesterdayInstitutionPresentCount,
            compact: true,
          ).animate().scale(delay: 150.ms, begin: const Offset(0.98, 0.98)).fadeIn(),

          const SizedBox(height: 16),

          if (isTodayOff)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isTodayHoliday ? Icons.celebration_rounded : Icons.weekend_rounded,
                    color: theme.colorScheme.primary.withOpacity(0.7),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTodayHoliday ? "Holiday Today" : "Weekend Off Day",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: theme.textTheme.titleMedium?.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isTodayHoliday
                              ? "Today is marked as an institution holiday."
                              : "No classes scheduled for today.",
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.grey[400] : AppColors.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().scale(delay: 200.ms, begin: const Offset(0.98, 0.98)).fadeIn()
          else
            _buildProgressCard(
              context,
              title: "Today's Progress (All)",
              subtitle: "Overview of all enrolled students logging status",
              loggedCount: todayLoggedInstitutionFullCount + todayAcknowledgedInstitutionCount,
              totalCount: institutionPresentCount,
            ).animate().scale(delay: 200.ms, begin: const Offset(0.98, 0.98)).fadeIn(),
        ],


        const SizedBox(height: 16),

        // Secondary Metrics Grid Row (Total Students, Active Teachers, Absent Today)
        Row(
          children: [
            Expanded(
              child: _buildSecondaryMetricCard(
                context,
                title: 'Total Enrolled',
                value: totalStudents.toString(),
                subtitle: 'Active students',
                icon: Icons.people_outline_rounded,
                iconColor: AppColors.info,
              ).animate().scale(delay: 300.ms, begin: const Offset(0.98, 0.98)).fadeIn(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildSecondaryMetricCard(
                context,
                title: 'Staff Members',
                value: totalTeachers.toString(),
                subtitle: 'Active teachers',
                icon: Icons.assignment_ind_outlined,
                iconColor: AppColors.success,
              ).animate().scale(delay: 400.ms, begin: const Offset(0.98, 0.98)).fadeIn(),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Alarm / Warning metric (Absent Today)
        _buildFullWidthAbsentCard(
          context,
          absentCount: todayAbsentCount,
        ).animate().scale(delay: 500.ms, begin: const Offset(0.98, 0.98)).fadeIn(),
      ],
    );
  }

  Widget _buildProgressCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int loggedCount,
    required int totalCount,
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    double progressPercent = 0.0;
    if (totalCount > 0) {
      progressPercent = (loggedCount / totalCount).clamp(0.0, 1.0);
    }

    return Container(
      width: double.infinity,
      padding: compact ? const EdgeInsets.all(14) : const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  theme.colorScheme.surface,
                  theme.colorScheme.surface.withOpacity(0.8),
                ]
              : [
                  Colors.white,
                  const Color(0xFFEAF5F0),
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : theme.colorScheme.primary.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black26
                : theme.colorScheme.primary.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: compact ? 13 : null,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  compact ? '${(progressPercent * 100).toStringAsFixed(0)}%' : '${(progressPercent * 100).toStringAsFixed(0)}% Done',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
          SizedBox(height: compact ? 8 : 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$loggedCount / $totalCount',
                        style: (compact ? theme.textTheme.titleMedium : theme.textTheme.headlineMedium)?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      compact ? 'Logged' : 'Students logged today',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: compact ? 10 : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: compact ? 42 : 56,
                height: compact ? 42 : 56,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1.0,
                      backgroundColor: Colors.transparent,
                      color: (isDark ? Colors.white : theme.colorScheme.primary).withOpacity(0.08),
                      strokeWidth: compact ? 4.5 : 6,
                    ),
                    CircularProgressIndicator(
                      value: progressPercent,
                      backgroundColor: Colors.transparent,
                      color: AppColors.success,
                      strokeWidth: compact ? 4.5 : 6,
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.success,
                        size: compact ? 18 : 24,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressPercent,
                backgroundColor: (isDark ? Colors.white : theme.colorScheme.primary).withOpacity(0.08),
                color: AppColors.success,
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLessonTrackingCard(
    BuildContext context, {
    required String title,
    required int loggedCount,
    required int totalCount,
    required List<dynamic> incompleteList,
    required AppProvider provider,
    required String dateStr,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Read acknowledged IDs directly from provider (persisted to Supabase)
    final acknowledgedIds = provider.getAcknowledgedIds(dateStr);

    // Filter out acknowledged students from the visible list
    final visibleList = incompleteList.where((s) => !acknowledgedIds.contains(s['id'] as String)).toList();
    final acknowledgedCount = incompleteList.length - visibleList.length;

    // allDone = complete + acknowledged covers everyone
    final allDone = loggedCount + acknowledgedCount == totalCount;

    double progressPercent = 0.0;
    if (totalCount > 0) {
      progressPercent = ((loggedCount + acknowledgedCount) / totalCount).clamp(0.0, 1.0);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  theme.colorScheme.surface,
                  theme.colorScheme.surface.withOpacity(0.85),
                ]
              : [
                  Colors.white,
                  allDone
                      ? const Color(0xFFEAF5F0)
                      : const Color(0xFFFFF7ED),
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: allDone
              ? AppColors.success.withOpacity(0.2)
              : AppColors.warning.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: (allDone ? AppColors.success : AppColors.warning).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (allDone ? AppColors.success : AppColors.warning).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(progressPercent * 100).toStringAsFixed(0)}% Complete',
                  style: TextStyle(
                    color: allDone ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${loggedCount + acknowledgedCount} / $totalCount',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      acknowledgedCount > 0
                          ? '$loggedCount completed · $acknowledgedCount confirmed pending'
                          : 'Completed target lessons today',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 50,
                height: 50,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1.0,
                      backgroundColor: Colors.transparent,
                      color: (isDark ? Colors.white : theme.colorScheme.primary).withOpacity(0.08),
                      strokeWidth: 5,
                    ),
                    CircularProgressIndicator(
                      value: progressPercent,
                      backgroundColor: Colors.transparent,
                      color: allDone ? AppColors.success : AppColors.warning,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        color: allDone ? AppColors.success : AppColors.warning,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!allDone && visibleList.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 0.4),
            const SizedBox(height: 14),
            // Column header labels
            Padding(
              padding: const EdgeInsets.only(left: 48, right: 4),
              child: Row(
                children: [
                  const Spacer(),
                  _lessonHeaderCell('Sabaq', isDark, theme),
                  _lessonHeaderCell('Sabqi', isDark, theme),
                  _lessonHeaderCell('Muraja', isDark, theme),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Student row cards
            ...visibleList.map<Widget>((s) {
              final studentId = s['id'] as String;
              final name = s['name'] as String;
              final isHafiz = s['isHafiz'] as bool? ?? false;
              final sabaqDone = s['sabaqDone'] as bool? ?? false;
              final sabqiDone = s['sabqiDone'] as bool? ?? false;
              final manzilDone = s['manzilDone'] as bool? ?? false;
              final sabaqPages = s['sabaqPages'] as double? ?? 0;
              final sabqiPages = s['sabqiPages'] as double? ?? 0;
              final manzilPages = s['manzilPages'] as double? ?? 0;
              final sabaqSkipped = s['sabaqSkipped'] as bool? ?? false;
              final sabqiSkipped = s['sabqiSkipped'] as bool? ?? false;
              final manzilSkipped = s['manzilSkipped'] as bool? ?? false;

              // Look up the full Student object for bottom sheet
              final student = provider.students.firstWhere(
                (st) => st.id == studentId,
                orElse: () => Student(id: studentId, fullName: name, institutionId: '', isPersonal: false),
              );

              void openSheet(int type) {
                Widget sheet;
                switch (type) {
                  case 0:
                    sheet = SabaqBottomSheet(studentId: studentId, student: student, initialDate: dateStr);
                    break;
                  case 1:
                    sheet = SabqiBottomSheet(studentId: studentId, student: student, initialDate: dateStr);
                    break;
                  case 2:
                    sheet = ManzilBottomSheet(studentId: studentId, student: student, initialDate: dateStr);
                    break;
                  default:
                    return;
                }
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useRootNavigator: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => sheet,
                );
              }

              void confirmAcknowledge() {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Confirm Pending'),
                    content: Text(
                      'Confirm that $name\'s pending lessons were genuinely not completed?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          provider.acknowledgeStudent(studentId, dateStr);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Yes, Confirm'),
                      ),
                    ],
                  ),
                );
              }

              // Avatar initials
              final initials = name.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.04)
                        : AppColors.warning.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.07) : AppColors.warning.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Avatar initials bubble
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(isDark ? 0.2 : 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Name
                      Expanded(
                        child: Text(
                          name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Sabaq tile
                      if (isHafiz)
                        _lessonNaCell(isDark, theme)
                      else
                        _lessonStatusCell(
                          isDone: sabaqDone,
                          pages: sabaqPages,
                          isDark: isDark,
                          theme: theme,
                          isSkipped: sabaqSkipped,
                          onTap: sabaqDone ? null : () => openSheet(0),
                        ),
                      // Sabqi tile
                      if (isHafiz)
                        _lessonNaCell(isDark, theme)
                      else
                        _lessonStatusCell(
                          isDone: sabqiDone,
                          pages: sabqiPages,
                          isDark: isDark,
                          theme: theme,
                          isSkipped: sabqiSkipped,
                          onTap: sabqiDone ? null : () => openSheet(1),
                        ),
                      // Muraja tile
                      _lessonStatusCell(
                        isDone: manzilDone,
                        pages: manzilPages,
                        isDark: isDark,
                        theme: theme,
                        isSkipped: manzilSkipped,
                        onTap: manzilDone ? null : () => openSheet(2),
                      ),
                      const SizedBox(width: 4),
                      // Confirm icon button (fixed size, no overflow)
                      Tooltip(
                        message: 'Confirm as genuinely pending',
                        child: GestureDetector(
                          onTap: confirmAcknowledge,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(isDark ? 0.15 : 0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.success.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(Icons.check_rounded, size: 15, color: AppColors.success),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            // Acknowledged summary pill
            if (acknowledgedCount > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(isDark ? 0.12 : 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '$acknowledgedCount student${acknowledgedCount > 1 ? 's' : ''} confirmed as pending',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // --- Table cell helpers for lesson tracking ---

  Widget _lessonHeaderCell(String label, bool isDark, ThemeData theme) {
    return SizedBox(
      width: 44,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 10,
          color: isDark ? Colors.grey[400] : AppColors.textMutedLight,
        ),
      ),
    );
  }

  Widget _lessonStatusCell({
    required bool isDone,
    required double pages,
    required bool isDark,
    required ThemeData theme,
    required bool isSkipped,
    VoidCallback? onTap,
  }) {
    if (isSkipped) {
      // Skipped — light grey curved forward/redo icon inside a small box
      return SizedBox(
        width: 44,
        child: Center(
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2F34) : const Color(0xFFE4E4E7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.redo_rounded, // Skip arrow
              color: isDark ? const Color(0xFF90A4AE) : const Color(0xFF78909C),
              size: 11,
            ),
          ),
        ),
      );
    }

    final pagesText = pages % 1 == 0 ? pages.toStringAsFixed(0) : pages.toStringAsFixed(1);

    if (isDone) {
      // Completed — green circle with page count, or check icon if page count <= 0
      return SizedBox(
        width: 44,
        child: Center(
          child: pages > 0
              ? Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      pagesText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.0,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                  ),
                )
              : Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
        ),
      );
    }

    // Build the inner content
    final Widget inner;
    if (pages > 0) {
      // Partial — amber pill with page count
      inner = Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(isDark ? 0.2 : 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${pagesText}p',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309), // Highly visible amber/brown in light mode
          ),
        ),
      );
    } else {
      // Not started — grey dash
      inner = Text(
        '—',
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.grey[500] : Colors.grey[400],
        ),
      );
    }

    return SizedBox(
      width: 44,
      child: Center(
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: inner,
                ),
              )
            : inner,
      ),
    );
  }


  Widget _lessonNaCell(bool isDark, ThemeData theme) {
    return SizedBox(
      width: 44,
      child: Center(
        child: Text(
          'N/A',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            color: isDark ? Colors.grey[700] : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  // --- UI Sub-Component: Secondary Metric Cards ---
  Widget _buildSecondaryMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : theme.colorScheme.primary.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black12 : Colors.grey.withOpacity(0.06),
            blurRadius: 12,
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
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              Icon(
                Icons.trending_up_rounded,
                size: 16,
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.4),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Sub-Component: Absent Full-Width Card ---
  Widget _buildFullWidthAbsentCard(BuildContext context, {required int absentCount}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: absentCount > 0
              ? AppColors.danger.withOpacity(0.15)
              : (isDark ? Colors.white.withOpacity(0.04) : theme.colorScheme.primary.withOpacity(0.06)),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black12 : Colors.grey.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (absentCount > 0 ? AppColors.danger : Colors.grey).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: absentCount > 0 ? AppColors.danger : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  absentCount > 0 ? "$absentCount Absent Today" : "All Enrolled Present",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: absentCount > 0 ? AppColors.danger : null,
                  ),
                ),
                Text(
                  absentCount > 0
                      ? "Requires parent notification & attendance review"
                      : "Great! All students logged present today",
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.textTheme.bodySmall?.color,
          ),
        ],
      ),
    );
  }

  // --- UI Component: Activity Log Item (Modern Mobile Timeline) ---
  Widget _buildTimelineItem(
    BuildContext context,
    Map<String, dynamic> log,
    bool isLast,
    int index,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final student = log['students'] ?? {};
    final profile = log['profiles'] ?? {};

    final studentName = student['full_name'] ?? 'Unknown Student';
    final teacherName = profile['full_name'] ?? 'Unknown Teacher';
    final studentId = log['student_id'];

    final status = (log['status'] as String?)?.toLowerCase() ?? '';
    final isAttendance = status == 'absent' || status == 'sick' || status == 'other' || status == 'no_lesson';

    // Parse manzil/lesson details
    final rawManzil = log['manzil'];
    Map<String, dynamic>? parsedManzil;
    if (rawManzil is Map) {
      parsedManzil = Map<String, dynamic>.from(rawManzil);
    } else if (rawManzil is String && rawManzil.isNotEmpty) {
      try {
        final decoded = json.decode(rawManzil);
        if (decoded is Map) {
          parsedManzil = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    String displayText = '';
    if (status == 'baseline_summary') {
      final List<int> sabaqPages = List<int>.from(log['sabaqPages'] ?? []);
      final List<int> sabqiPages = List<int>.from(log['sabqiPages'] ?? []);
      final List<String> parts = [];
      if (sabaqPages.isNotEmpty) {
        parts.add('Sabaq: ${sabaqPages.length} pages (${_formatPageRanges(sabaqPages)})');
      }
      if (sabqiPages.isNotEmpty) {
        parts.add('Sabqi: ${sabqiPages.length} pages (${_formatPageRanges(sabqiPages)})');
      }
      displayText = parts.isNotEmpty ? parts.join('\n') : 'Baseline configured';
    } else if (isAttendance) {
      if (status == 'no_lesson') {
        displayText = 'No Lesson';
      } else {
        displayText = status.isNotEmpty ? '${status[0].toUpperCase()}${status.substring(1)}' : 'Absent';
      }
    } else {
      final List<String> loggedLessons = [];
      
      // 1. Sabaq
      final rawSabaq = log['sabaq'] ?? '';
      String cleanSabaq = rawSabaq.toString();
      if (cleanSabaq.contains(' - Heard by:')) {
        cleanSabaq = cleanSabaq.split(' - Heard by:')[0];
      }
      if (cleanSabaq.contains(' - ') && cleanSabaq.contains('Line(s)')) {
        cleanSabaq = cleanSabaq.split(' - ')[0];
      }
      if (cleanSabaq.trim().isNotEmpty) {
        loggedLessons.add('Sabaq: $cleanSabaq');
      }

      // 2. Sabqi (Sabaq Para)
      if (parsedManzil != null && parsedManzil['sabqi'] is List) {
        final sabqiList = parsedManzil['sabqi'] as List;
        if (sabqiList.isNotEmpty) {
          final pages = <int>[];
          for (final item in sabqiList) {
            final text = item is String ? item : (item is Map ? (item['sabaq'] as String? ?? '') : '');
            final m = RegExp(r'Page (\d+)').firstMatch(text);
            if (m != null) {
              final p = int.tryParse(m.group(1) ?? '');
              if (p != null) pages.add(p);
            }
          }
          if (pages.isNotEmpty) {
            pages.sort();
            loggedLessons.add('Sabqi: ${pages.length} Pgs (Pg ${pages.first}-${pages.last})');
          } else {
            loggedLessons.add('Sabqi: ${sabqiList.length} Pgs');
          }
        }
      }

      // 3. Muraja (Manzil)
      if (parsedManzil != null) {
        final manzilJuzStr = parsedManzil['manzil'] as String? ?? '';
        final manzilItems = parsedManzil['manzilPages'] as List? ?? [];
        if (manzilJuzStr.isNotEmpty) {
          loggedLessons.add('Muraja: $manzilJuzStr');
        } else if (manzilItems.isNotEmpty) {
          loggedLessons.add('Muraja: ${manzilItems.length} Pgs');
        }
      }

      if (loggedLessons.isNotEmpty) {
        displayText = loggedLessons.join('\n');
      } else {
        displayText = 'No sabaq logged';
      }
    }

    final initial = studentName.isNotEmpty ? studentName.substring(0, 1).toUpperCase() : 'S';

    return InkWell(
      onTap: () {
        if (studentId != null) {
          context.push('/students/$studentId');
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline Line & Indicator
            Column(
              children: [
                const SizedBox(height: 6),
                // Timeline node
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                // Timeline connector line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.colorScheme.primary.withOpacity(0.15),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  )
                else
                  const Expanded(child: SizedBox(height: 16)),
              ],
            ),
            const SizedBox(width: 14),

            // Timelined Card content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? theme.colorScheme.surface : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.04)
                          : theme.colorScheme.primary.withOpacity(0.06),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black12 : Colors.grey.withOpacity(0.04),
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
                          Expanded(
                            child: Text(
                              studentName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Text(
                            'Today', // Format log['date'] in a real app
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      RichText(
                        text: TextSpan(
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.3,
                          ),
                          children: [
                            if (status == 'baseline_summary') ...[
                              TextSpan(
                                text: 'Setup Baseline:\n',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                              ),
                              TextSpan(
                                text: displayText,
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                            ] else if (isAttendance) ...[
                              TextSpan(
                                text: 'Status: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              TextSpan(
                                text: displayText,
                                style: TextStyle(
                                  color: status == 'absent'
                                      ? Colors.redAccent
                                      : (status == 'no_lesson'
                                          ? Colors.orangeAccent
                                          : (status == 'sick' ? Colors.orangeAccent : Colors.purpleAccent)),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ] else if (displayText == 'No sabaq logged') ...[
                              TextSpan(
                                text: 'Logged: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              TextSpan(
                                text: 'No sabaq logged',
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                            ] else ...[
                              TextSpan(
                                text: displayText,
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildBadge(
                            context,
                            status == 'baseline_summary' ? 'Set by: $teacherName' : 'Heard by: $teacherName',
                            status == 'baseline_summary' ? AppColors.success : theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI Sub-Component: Styled Badge/Tag ---
  Widget _buildBadge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // --- UI Sub-Component: Teacher Absence Banner ---
  Widget _buildTeacherAbsenceBanner(BuildContext context, AppProvider provider) {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final isAbsentToday = provider.scheduledAbsences.any((a) => a['absence_date']?.toString().split('T')[0] == todayStr);
    
    if (!isAbsentToday) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.danger.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.danger,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.beach_access_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You are Marked Absent Today",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Your classes and students will be managed by coverage teachers or administrators for today.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  DateTime _getLastClassDay(List<int> weeklyOffDays, Set<String> holidaysSet) {
    var d = DateTime.now().subtract(const Duration(days: 1));
    for (int i = 0; i < 10; i++) {
      final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final isWeekend = weeklyOffDays.contains(d.weekday);
      final isHoliday = holidaysSet.contains(dateStr);
      if (!isWeekend && !isHoliday) {
        return d;
      }
      d = d.subtract(const Duration(days: 1));
    }
    return DateTime.now().subtract(const Duration(days: 1));
  }

  // --- UI Sub-Component: Other Absent Teachers Banner ---
  Widget _buildOtherAbsentTeachersBanner(BuildContext context, AppProvider provider) {
    final currentUserId = provider.user?.id;
    final otherAbsentTeachers = provider.absentTeachersToday.where((a) => a['teacher_id'] != currentUserId).toList();
    
    if (otherAbsentTeachers.isEmpty) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Absent Teachers Today",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...otherAbsentTeachers.map((a) {
            final profile = a['profiles'] as Map<String, dynamic>?;
            final name = profile?['full_name'] ?? 'Unknown Teacher';
            final teacherId = a['teacher_id'] as String;
            
            // Calculate progress stats for this teacher's class
            final teacherStudents = provider.students.where((s) => s.teacherId == teacherId).toList();
            final total = teacherStudents.length;
            final logged = teacherStudents.where((s) {
              final hasLog = (s.todayLogId != null && s.todayLogId!.isNotEmpty) ||
                  (s.todayStatus != null && s.todayStatus!.isNotEmpty) ||
                  s.todaySabaqPages > 0 ||
                  s.todaySabqiPages > 0 ||
                  s.todayManzilPages > 0;
              return hasLog;
            }).length;
            
            final percent = total > 0 ? (logged / total) : 0.0;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "$logged / $total logged",
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 5,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }
}

