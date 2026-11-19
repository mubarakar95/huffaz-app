import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_provider.dart';
import '../../models/student.dart';
import '../../models/sabaq_log.dart';
import '../../core/theme.dart';
import '../../utils/student_utils.dart';
import '../../utils/quran_data.dart';
import '../students/student_detail_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedTab = 0; // 0: Daily, 1: Weekly, 2: Monthly
  String? _selectedTeacher;
  bool _sortPendingFirst = false;
  String _selectedDateStr = getLocalToday();
  String _sortColumn = 'name'; // 'name', 'sabaq', 'sabqi', 'manzil'
  bool _sortAscending = true;

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  String? _expandedStudentId;

  void _toggleSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = column == 'name';
      }
    });
  }

  void _loadReportData() {
    final provider = context.read<AppProvider>();
    if (_selectedTab == 0) {
      provider.fetchDailyReport(_selectedDateStr);
    } else if (_selectedTab == 1) {
      provider.fetchWeeklyReport(_selectedDateStr);
    } else if (_selectedTab == 2) {
      provider.fetchMonthlyReport(_selectedYear, _selectedMonth);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReportData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isAdmin = provider.isAdmin;
    final isTeacher = provider.profile?.role == 'teacher';

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final activeStudents = provider.students.where((s) => s.isPersonal != true).toList();
    final teachers = List<Map<String, dynamic>>.from(
      provider.institutionPeople['teachers'] as List? ?? [],
    ).where((t) {
      final tId = t['id'];
      final tName = t['full_name'];
      return activeStudents.any((s) => s.teacherId == tId || s.teacherName == tName);
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Date
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Reports',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    // Teacher Selection Pills (visible on all tabs)
                    if (isAdmin && teachers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.filter_list_rounded,
                              size: 14,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'TEACHER FILTER',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 9.5,
                                letterSpacing: 0.8,
                                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          children: [
                            FilterChip(
                              label: const Text('All Teachers'),
                              selected: _selectedTeacher == null,
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                color: _selectedTeacher == null ? Colors.white : null,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _selectedTeacher = null;
                                });
                              },
                            ),
                            ...teachers.map((t) {
                              final name = t['full_name'] as String? ?? 'Unknown';
                              final isAbsent = provider.absentTeachersToday.any((at) {
                                final profile = at['profiles'] as Map<String, dynamic>?;
                                return (profile?['full_name'] ?? '') == name;
                              });
                              final displayName = isAbsent ? '$name (Absent)' : name;
                              return Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: FilterChip(
                                  label: Text(displayName),
                                  selected: _selectedTeacher == name,
                                  showCheckmark: false,
                                  labelStyle: TextStyle(
                                    color: _selectedTeacher == name ? Colors.white : null,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedTeacher = name;
                                    });
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              SliverAppBar(
                backgroundColor: theme.scaffoldBackgroundColor,
                pinned: true,
                elevation: 0,
                toolbarHeight: 60,
                titleSpacing: 0,
                title: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF23262A) : const Color(0xFFECEFEF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        _buildSegment(0, 'Daily', enabled: true),
                        _buildSegment(1, 'Weekly', enabled: true),
                        _buildSegment(2, 'Monthly', enabled: true),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: _selectedTab == 0
              ? _buildDailyReportView(provider, isDark)
              : (_selectedTab == 1
                  ? _buildWeeklyReportView(provider, isDark)
                  : _buildMonthlyReportView(provider, isDark)),
        ),
      ),
    );
  }

  Widget _buildSegment(int index, String label, {required bool enabled}) {
    final isSelected = _selectedTab == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: enabled
            ? () {
                setState(() {
                  _selectedTab = index;
                });
                _loadReportData();
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2C2F34) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? (isDark ? Colors.white : const Color(0xFF1D3557))
                  : (enabled
                      ? (isDark ? Colors.white70 : const Color(0xFF455A64))
                      : Colors.grey.withValues(alpha: 0.6)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyDotStrip(List<dynamic> dailyDots, String keyColor, String keyTooltip) {
    return Center(
      child: Wrap(
        spacing: 3.0,
        runSpacing: 2,
        alignment: WrapAlignment.center,
        children: dailyDots.map((dot) {
          final colorName = dot[keyColor] as String? ?? 'grey';
          final tooltip = dot[keyTooltip] as String? ?? '';
          
          Color color;
          switch (colorName) {
            case 'green':
              color = AppColors.success;
              break;
            case 'amber':
              color = AppColors.warning;
              break;
            case 'red':
              color = AppColors.danger;
              break;
            default:
              color = Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.08);
          }

          return Tooltip(
            message: tooltip,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeeklyReportView(AppProvider provider, bool isDark) {
    if (provider.isLoadingWeekly) {
      return const Center(child: CircularProgressIndicator());
    }

    final weeklyData = provider.weeklyReportData;
    final List<dynamic> weeklyStudentsData = weeklyData['students'] ?? [];
    if (weeklyStudentsData.isEmpty) {
      return const Center(child: Text('No student weekly data found.'));
    }

    var reportList = List<Map<String, dynamic>>.from(weeklyStudentsData);

    // Filter by teacher
    if (provider.isAdmin) {
      if (_selectedTeacher != null) {
        reportList = reportList.where((item) {
          final Student s = item['student'] as Student;
          return s.teacherName == _selectedTeacher;
        }).toList();
      }
    } else if (provider.profile?.role == 'teacher') {
      final teacherId = provider.user?.id;
      final absentIds = provider.absentTeachersToday.map((at) => at['teacher_id'] as String?).toSet();
      reportList = reportList.where((item) {
        final Student s = item['student'] as Student;
        final tId = s.teacherId;
        return tId == teacherId || absentIds.contains(tId);
      }).toList();
    }
    
    reportList = reportList.where((item) {
      final Student s = item['student'] as Student;
      return s.isPersonal != true;
    }).toList();

    // Sorting weekly data
    if (_sortColumn == 'name') {
      reportList.sort((a, b) {
        final Student studentA = a['student'] as Student;
        final Student studentB = b['student'] as Student;
        return _sortAscending ? studentA.fullName.compareTo(studentB.fullName) : studentB.fullName.compareTo(studentA.fullName);
      });
    } else if (_sortColumn == 'sabaq') {
      reportList.sort((a, b) {
        final double valA = a['sabaqTotal'] as double;
        final double valB = b['sabaqTotal'] as double;
        return _sortAscending ? valA.compareTo(valB) : valB.compareTo(valA);
      });
    } else if (_sortColumn == 'sabqi') {
      reportList.sort((a, b) {
        final double valA = a['sabqiTotal'] as double;
        final double valB = b['sabqiTotal'] as double;
        return _sortAscending ? valA.compareTo(valB) : valB.compareTo(valA);
      });
    } else if (_sortColumn == 'manzil') {
      reportList.sort((a, b) {
        final double valA = a['manzilTotal'] as double;
        final double valB = b['manzilTotal'] as double;
        return _sortAscending ? valA.compareTo(valB) : valB.compareTo(valA);
      });
    }

    // Summary calculations
    double sabaqCompletionSum = 0.0;
    int sabaqCount = 0;
    double sabqiCompletionSum = 0.0;
    int sabqiCount = 0;
    double manzilCompletionSum = 0.0;
    int manzilCount = 0;
    int totalAbsences = 0;

    for (final item in reportList) {
      final sabaqTotal = item['sabaqTotal'] as double;
      final sabaqGoal = item['sabaqGoal'] as double;
      final sabqiTotal = item['sabqiTotal'] as double;
      final sabqiGoal = item['sabqiGoal'] as double;
      final manzilTotal = item['manzilTotal'] as double;
      final manzilGoal = item['manzilGoal'] as double;
      final dailyDots = item['dailyDots'] as List<dynamic>;

      if (sabaqGoal > 0) {
        final pct = (sabaqTotal / sabaqGoal) * 100;
        sabaqCompletionSum += pct > 100.0 ? 100.0 : pct;
        sabaqCount++;
      }
      if (sabqiGoal > 0) {
        final pct = (sabqiTotal / sabqiGoal) * 100;
        sabqiCompletionSum += pct > 100.0 ? 100.0 : pct;
        sabqiCount++;
      }
      if (manzilGoal > 0) {
        final pct = (manzilTotal / manzilGoal) * 100;
        manzilCompletionSum += pct > 100.0 ? 100.0 : pct;
        manzilCount++;
      }

      for (final dot in dailyDots) {
        final tooltip = dot['sabaqTooltip'] as String? ?? '';
        if (tooltip.contains('ABSENT') || tooltip.contains('SICK')) {
          totalAbsences++;
        }
      }
    }

    final double avgSabaq = sabaqCount > 0 ? (sabaqCompletionSum / sabaqCount) : 0.0;
    final double avgSabqi = sabqiCount > 0 ? (sabqiCompletionSum / sabqiCount) : 0.0;
    final double avgManzil = manzilCount > 0 ? (manzilCompletionSum / manzilCount) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards (2x2 grid)
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Sabaq Met',
                      '${avgSabaq.toStringAsFixed(1)}%',
                      Icons.menu_book_rounded,
                      AppColors.primary,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'Sabqi Met',
                      '${avgSabqi.toStringAsFixed(1)}%',
                      Icons.history_edu_rounded,
                      AppColors.primaryLight,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Muraja Met',
                      '${avgManzil.toStringAsFixed(1)}%',
                      Icons.donut_large_rounded,
                      AppColors.success,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      'Total Absences',
                      '$totalAbsences',
                      Icons.person_off_rounded,
                      AppColors.danger,
                      isDark,
                      onTap: () => _showPeriodAbsenceDetails(context, provider, reportList, isWeekly: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Table
          if (reportList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: Text('No students found.', style: TextStyle(color: Theme.of(context).hintColor)),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    // Header row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      color: AppColors.primary.withValues(alpha: 0.08),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 40,
                            child: InkWell(
                              onTap: () => _toggleSort('name'),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                  if (_sortColumn == 'name') ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                      size: 12,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 20,
                            child: InkWell(
                              onTap: () => _toggleSort('sabaq'),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Sabaq', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                  if (_sortColumn == 'sabaq') ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                      size: 12,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 20,
                            child: InkWell(
                              onTap: () => _toggleSort('sabqi'),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Sabqi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                  if (_sortColumn == 'sabqi') ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                      size: 12,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 20,
                            child: InkWell(
                              onTap: () => _toggleSort('manzil'),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Muraja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                  if (_sortColumn == 'manzil') ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                      size: 12,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: reportList.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                      itemBuilder: (context, index) {
                        final item = reportList[index];
                        final Student student = item['student'] as Student;
                        final double sabaqTotal = item['sabaqTotal'] as double;
                        final double sabaqGoal = item['sabaqGoal'] as double;
                        final double sabqiTotal = item['sabqiTotal'] as double;
                        final double sabqiGoal = item['sabqiGoal'] as double;
                        final double manzilTotal = item['manzilTotal'] as double;
                        final double manzilGoal = item['manzilGoal'] as double;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              // Student Info
                              Expanded(
                                flex: 40,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                      child: Text(
                                        student.fullName.substring(0, student.fullName.contains(' ') ? student.fullName.indexOf(' ') : student.fullName.length).substring(0, 1).toUpperCase(),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            student.fullName,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (provider.isAdmin) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              student.teacherName ?? 'No teacher',
                                              style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.w500),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Sabaq Pages count
                              Expanded(
                                flex: 20,
                                child: _buildCountAndPercentCell(sabaqTotal, sabaqGoal, isDark),
                              ),
                              // Sabqi Pages count
                              Expanded(
                                flex: 20,
                                child: _buildCountAndPercentCell(sabqiTotal, sabqiGoal, isDark),
                              ),
                              // Muraja Pages count
                              Expanded(
                                flex: 20,
                                child: _buildCountAndPercentCell(manzilTotal, manzilGoal, isDark),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Widget _buildMonthlyReportView(AppProvider provider, bool isDark) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    
    return Column(
      children: [
        // Month switcher header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          color: Theme.of(context).cardColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: AppColors.primary),
                onPressed: () {
                  setState(() {
                    if (_selectedMonth == 1) {
                      _selectedMonth = 12;
                      _selectedYear--;
                    } else {
                      _selectedMonth--;
                    }
                    _expandedStudentId = null;
                  });
                  _loadReportData();
                },
              ),
              Text(
                '${months[_selectedMonth - 1]} $_selectedYear',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                onPressed: () {
                  setState(() {
                    if (_selectedMonth == 12) {
                      _selectedMonth = 1;
                      _selectedYear++;
                    } else {
                      _selectedMonth++;
                    }
                    _expandedStudentId = null;
                  });
                  _loadReportData();
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        Expanded(
          child: provider.isLoadingMonthly
              ? const Center(child: CircularProgressIndicator())
              : Builder(builder: (context) {
                  final monthlyData = provider.monthlyReportData;
                  final List<dynamic> monthlyStudentsData = monthlyData['students'] ?? [];
                  if (monthlyStudentsData.isEmpty) {
                    return const Center(child: Text('No student monthly data found.'));
                  }

                  var reportList = List<Map<String, dynamic>>.from(monthlyStudentsData);

                  // Filter by teacher
                  if (provider.isAdmin) {
                    if (_selectedTeacher != null) {
                      reportList = reportList.where((item) {
                        final Student s = item['student'] as Student;
                        return s.teacherName == _selectedTeacher;
                      }).toList();
                    }
                  } else if (provider.profile?.role == 'teacher') {
                    final teacherId = provider.user?.id;
                    final absentIds = provider.absentTeachersToday.map((at) => at['teacher_id'] as String?).toSet();
                    reportList = reportList.where((item) {
                      final Student s = item['student'] as Student;
                      final tId = s.teacherId;
                      return tId == teacherId || absentIds.contains(tId);
                    }).toList();
                  }

                  reportList = reportList.where((item) {
                    final Student s = item['student'] as Student;
                    return s.isPersonal != true;
                  }).toList();

                  // Sorting monthly data
                  if (_sortColumn == 'name') {
                    reportList.sort((a, b) {
                      final Student studentA = a['student'] as Student;
                      final Student studentB = b['student'] as Student;
                      return _sortAscending ? studentA.fullName.compareTo(studentB.fullName) : studentB.fullName.compareTo(studentA.fullName);
                    });
                  } else if (_sortColumn == 'sabaq') {
                    reportList.sort((a, b) {
                      final double valA = a['sabaqTotal'] as double;
                      final double valB = b['sabaqTotal'] as double;
                      return _sortAscending ? valA.compareTo(valB) : valB.compareTo(valA);
                    });
                  } else if (_sortColumn == 'sabqi') {
                    reportList.sort((a, b) {
                      final double valA = a['sabqiTotal'] as double;
                      final double valB = b['sabqiTotal'] as double;
                      return _sortAscending ? valA.compareTo(valB) : valB.compareTo(valA);
                    });
                  } else if (_sortColumn == 'manzil') {
                    reportList.sort((a, b) {
                      final double valA = a['manzilTotal'] as double;
                      final double valB = b['manzilTotal'] as double;
                      return _sortAscending ? valA.compareTo(valB) : valB.compareTo(valA);
                    });
                  }

                  // Aggregates
                  double sabaqCompletionSum = 0.0;
                  int sabaqCount = 0;
                  double sabqiCompletionSum = 0.0;
                  int sabqiCount = 0;
                  double manzilCompletionSum = 0.0;
                  int manzilCount = 0;
                  int totalAbsences = 0;

                  for (final item in reportList) {
                    final double sabaqTotal = item['sabaqTotal'] as double;
                    final double sabaqGoal = item['sabaqGoal'] as double;
                    final double sabqiTotal = item['sabqiTotal'] as double;
                    final double sabqiGoal = item['sabqiGoal'] as double;
                    final double manzilTotal = item['manzilTotal'] as double;
                    final double manzilGoal = item['manzilGoal'] as double;
                    final int absent = item['absentCount'] as int;
                    final int sick = item['sickCount'] as int;

                    if (sabaqGoal > 0) {
                      final pct = (sabaqTotal / sabaqGoal) * 100;
                      sabaqCompletionSum += pct > 100.0 ? 100.0 : pct;
                      sabaqCount++;
                    }
                    if (sabqiGoal > 0) {
                      final pct = (sabqiTotal / sabqiGoal) * 100;
                      sabqiCompletionSum += pct > 100.0 ? 100.0 : pct;
                      sabqiCount++;
                    }
                    if (manzilGoal > 0) {
                      final pct = (manzilTotal / manzilGoal) * 100;
                      manzilCompletionSum += pct > 100.0 ? 100.0 : pct;
                      manzilCount++;
                    }
                    totalAbsences += (absent + sick);
                  }

                  final double avgSabaq = sabaqCount > 0 ? (sabaqCompletionSum / sabaqCount) : 0.0;
                  final double avgSabqi = sabqiCount > 0 ? (sabqiCompletionSum / sabqiCount) : 0.0;
                  final double avgManzil = manzilCount > 0 ? (manzilCompletionSum / manzilCount) : 0.0;

                  return ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // Summary cards (2x2 grid)
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  'Sabaq Met',
                                  '${avgSabaq.toStringAsFixed(1)}%',
                                  Icons.menu_book_rounded,
                                  AppColors.primary,
                                  isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  'Sabqi Met',
                                  '${avgSabqi.toStringAsFixed(1)}%',
                                  Icons.history_edu_rounded,
                                  AppColors.primaryLight,
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  'Muraja Met',
                                  '${avgManzil.toStringAsFixed(1)}%',
                                  Icons.donut_large_rounded,
                                  AppColors.success,
                                  isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  'Total Absences',
                                  '$totalAbsences',
                                  Icons.person_off_rounded,
                                  AppColors.danger,
                                  isDark,
                                  onTap: () => _showPeriodAbsenceDetails(context, provider, reportList, isWeekly: false),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Table
                      if (reportList.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Center(
                            child: Text('No students found.', style: TextStyle(color: Theme.of(context).hintColor)),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Column(
                              children: [
                                // Table Header
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 40,
                                        child: InkWell(
                                          onTap: () => _toggleSort('name'),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                              if (_sortColumn == 'name') ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                                  size: 12,
                                                  color: AppColors.primary,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 20,
                                        child: InkWell(
                                          onTap: () => _toggleSort('sabaq'),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('Sabaq', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                              if (_sortColumn == 'sabaq') ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                                  size: 12,
                                                  color: AppColors.primary,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 20,
                                        child: InkWell(
                                          onTap: () => _toggleSort('sabqi'),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('Sabqi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                              if (_sortColumn == 'sabqi') ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                                  size: 12,
                                                  color: AppColors.primary,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 20,
                                        child: InkWell(
                                          onTap: () => _toggleSort('manzil'),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('Muraja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                              if (_sortColumn == 'manzil') ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                                  size: 12,
                                                  color: AppColors.primary,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                ListView.separated(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: reportList.length,
                                  separatorBuilder: (context, index) => Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                                  itemBuilder: (context, index) {
                                    final item = reportList[index];
                                    final Student student = item['student'] as Student;
                                    final double sabaqTotal = item['sabaqTotal'] as double;
                                    final double sabaqGoal = item['sabaqGoal'] as double;
                                    final double sabqiTotal = item['sabqiTotal'] as double;
                                    final double sabqiGoal = item['sabqiGoal'] as double;
                                    final double manzilTotal = item['manzilTotal'] as double;
                                    final double manzilGoal = item['manzilGoal'] as double;
                                    final double completionPercent = item['completionPercent'] as double;

                                    final isExpanded = _expandedStudentId == student.id;

                                    final healthVal = _calculateStudentMemoryHealth(student, provider);
                                    Color healthColor = AppColors.danger;
                                    if (healthVal >= 90) {
                                      healthColor = AppColors.success;
                                    } else if (healthVal >= 70) {
                                      healthColor = AppColors.warning;
                                    }

                                    Color percentColor = AppColors.danger;
                                    if (completionPercent >= 90) {
                                      percentColor = AppColors.success;
                                    } else if (completionPercent >= 70) {
                                      percentColor = AppColors.warning;
                                    }

                                    return Column(
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              if (isExpanded) {
                                                _expandedStudentId = null;
                                              } else {
                                                _expandedStudentId = student.id;
                                              }
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            child: Row(
                                              children: [
                                                // Student info
                                                Expanded(
                                                  flex: 40,
                                                  child: Row(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 14,
                                                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                                        child: Text(
                                                          student.fullName.substring(0, student.fullName.contains(' ') ? student.fullName.indexOf(' ') : student.fullName.length).substring(0, 1).toUpperCase(),
                                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              student.fullName,
                                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                            const SizedBox(height: 3),
                                                            Row(
                                                              children: [
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                                  decoration: BoxDecoration(
                                                                    color: healthColor.withValues(alpha: 0.1),
                                                                    borderRadius: BorderRadius.circular(4),
                                                                  ),
                                                                  child: Text(
                                                                    '$healthVal% health',
                                                                    style: TextStyle(
                                                                      fontSize: 8.5,
                                                                      fontWeight: FontWeight.bold,
                                                                      color: healthColor,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Sabaq Total
                                                Expanded(
                                                  flex: 20,
                                                  child: _buildCountAndPercentCell(sabaqTotal, sabaqGoal, isDark),
                                                ),
                                                // Sabqi Total
                                                Expanded(
                                                  flex: 20,
                                                  child: _buildCountAndPercentCell(sabqiTotal, sabqiGoal, isDark),
                                                ),
                                                // Muraja Total
                                                Expanded(
                                                  flex: 20,
                                                  child: _buildCountAndPercentCell(manzilTotal, manzilGoal, isDark),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (isExpanded) ...[
                                          const Divider(height: 1),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.black.withOpacity(0.15)
                                                : Colors.grey.withOpacity(0.03),
                                            child: ActivityLogsTable(
                                              studentId: student.id,
                                              provider: provider,
                                              targetMonth: '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}',
                                            ),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                }),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildDailyReportView(AppProvider provider, bool isDark) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    if (provider.isLoadingReport) {
      return const Center(child: CircularProgressIndicator());
    }

    var reportList = provider.reportStudents;

    // Filter by teacher
    if (provider.isAdmin) {
      if (_selectedTeacher != null) {
        reportList = reportList.where((s) => s.teacherName == _selectedTeacher).toList();
      }
    } else if (provider.profile?.role == 'teacher') {
      final teacherId = provider.user?.id;
      final absentIds = provider.absentTeachersToday.map((at) => at['teacher_id'] as String?).toSet();
      reportList = reportList.where((s) {
        final tId = s.teacherId;
        return tId == teacherId || absentIds.contains(tId);
      }).toList();
    }

    // Exclude personal students completely for general view
    reportList = reportList.where((s) => s.isPersonal != true).toList();

    // Summary calculations
    final totalActive = reportList.length;
    final loggedCount = reportList.where((s) => s.todayStatus != null).length;
    final todayAckedIds = provider.getAcknowledgedIds(_selectedDateStr);
    final acknowledgedCount = reportList.where((s) => s.todayStatus == null && todayAckedIds.contains(s.id)).length;
    final absentCount = reportList.where((s) => ['absent', 'sick', 'other', 'no_lesson'].contains(s.todayStatus)).length;

    // Apply sorting
    reportList = List.from(reportList);
    if (_sortColumn == 'name') {
      reportList.sort((a, b) => _sortAscending
          ? a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase())
          : b.fullName.toLowerCase().compareTo(a.fullName.toLowerCase()));
    } else if (_sortColumn == 'sabaq') {
      reportList.sort((a, b) => _sortAscending
          ? a.todaySabaqPages.compareTo(b.todaySabaqPages)
          : b.todaySabaqPages.compareTo(a.todaySabaqPages));
    } else if (_sortColumn == 'sabqi') {
      reportList.sort((a, b) => _sortAscending
          ? a.todaySabqiPages.compareTo(b.todaySabqiPages)
          : b.todaySabqiPages.compareTo(a.todaySabqiPages));
    } else if (_sortColumn == 'manzil') {
      reportList.sort((a, b) => _sortAscending
          ? a.todayManzilPages.compareTo(b.todayManzilPages)
          : b.todayManzilPages.compareTo(a.todayManzilPages));
    }

    // Apply sort: Pending first
    if (_sortPendingFirst) {
      reportList.sort((a, b) {
        final aLogged = a.todayStatus != null ? 1 : 0;
        final bLogged = b.todayStatus != null ? 1 : 0;
        if (aLogged != bLogged) {
          return aLogged.compareTo(bLogged); // 0 (pending) comes first
        }
        return 0;
      });
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchDailyReport(_selectedDateStr),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: [
          // Summary strip
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Logged',
                  '${loggedCount + acknowledgedCount} / $totalActive',
                  Icons.edit_note_rounded,
                  AppColors.primary,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Absent / Sick',
                  '$absentCount',
                  Icons.person_off_rounded,
                  AppColors.danger,
                  isDark,
                  onTap: () => _showDailyAbsenceDetails(context, provider, reportList),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Filters row with Date Picker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Student Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Tooltip(
                message: 'Select report date',
                child: GestureDetector(
                  onTap: () async {
                    final parsed = DateTime.tryParse(_selectedDateStr) ?? DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: parsed,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      final formatted = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      setState(() {
                        _selectedDateStr = formatted;
                      });
                      _loadReportData();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_note_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          _selectedDateStr == getLocalToday()
                              ? 'Today'
                              : (_selectedDateStr == yesterdayStr
                                  ? 'Yesterday'
                                  : _selectedDateStr),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Scrollable Filter Pills Row
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                FilterChip(
                  label: const Text('Pending First'),
                  selected: _sortPendingFirst,
                  labelStyle: TextStyle(
                    color: _sortPendingFirst ? Colors.white : null,
                  ),
                  onSelected: (val) {
                    setState(() {
                      _sortPendingFirst = val;
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Table
          if (reportList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: Text(
                  'No students found.',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    // Table Header Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      color: AppColors.primary.withValues(alpha: 0.08),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 40,
                            child: InkWell(
                              onTap: () => _toggleSort('name'),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                  if (_sortColumn == 'name') ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                      size: 12,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 20,
                            child: InkWell(
                              onTap: () => _toggleSort('sabaq'),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Sabaq', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                  if (_sortColumn == 'sabaq') ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                      size: 12,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 20,
                            child: InkWell(
                              onTap: () => _toggleSort('sabqi'),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Sabqi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                  if (_sortColumn == 'sabqi') ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                      size: 12,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 20,
                            child: InkWell(
                              onTap: () => _toggleSort('manzil'),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Muraja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                  if (_sortColumn == 'manzil') ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                      size: 12,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: reportList.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                      itemBuilder: (context, idx) {
                        final student = reportList[idx];
                        return _buildReportRow(student, provider, isDark);
                      },
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 250.ms),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, bool isDark, {VoidCallback? onTap}) {
    return Ink(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountAndPercentCell(double total, double goal, bool isDark) {
    if (goal <= 0) {
      return const Center(
        child: Text(
          '-',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    final percent = (total / goal) * 100;
    final cappedPercent = percent > 100.0 ? 100.0 : percent;

    Color color = AppColors.danger;
    if (cappedPercent >= 90) {
      color = AppColors.success;
    } else if (cappedPercent >= 70) {
      color = AppColors.warning;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${total % 1 == 0 ? total.toInt() : total.toStringAsFixed(1)}\n/ ${goal % 1 == 0 ? goal.toInt() : goal.toStringAsFixed(1)}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          '${cappedPercent.toStringAsFixed(0)}% met',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  int _calculateStudentMemoryHealth(Student student, AppProvider provider) {
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

    final totalMemorizedPages = pageFreshness.length;
    final freshOrStalePages = pageFreshness.values.where((lvl) => lvl == 'fresh' || lvl == 'stale').length;

    return totalMemorizedPages > 0
        ? ((freshOrStalePages / totalMemorizedPages) * 100).round()
        : 0;
  }

  String _getAbsenceReason(String sabaqText) {
    final regExp = RegExp(r'\[SKIPPED:\s*([^\]]+)\]');
    final match = regExp.firstMatch(sabaqText);
    if (match != null && match.groupCount >= 1) {
      return match.group(1) ?? 'No reason specified';
    }
    return sabaqText.isNotEmpty ? sabaqText : 'No reason specified';
  }

  void _showDailyAbsenceDetails(BuildContext context, AppProvider provider, List<Student> reportList) {
    final absentStudents = reportList.where((s) => ['absent', 'sick', 'other', 'no_lesson'].contains(s.todayStatus)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.65,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Daily Absences & Leave Details',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedDateStr,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  Expanded(
                    child: absentStudents.isEmpty
                        ? Center(
                            child: Text(
                              'No student is marked absent or on leave today.',
                              style: TextStyle(color: theme.hintColor),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: absentStudents.length,
                            separatorBuilder: (context, index) => const Divider(height: 16),
                            itemBuilder: (context, index) {
                              final student = absentStudents[index];
                              final logs = provider.getLogsForStudent(student.id);
                              final todayLog = logs.where((l) {
                                final d = l.date.contains('T') ? l.date.split('T')[0] : l.date;
                                return d == _selectedDateStr;
                              }).firstOrNull;

                              final rawStatus = student.todayStatus ?? 'absent';
                              final statusText = rawStatus == 'no_lesson' ? 'NO LESSON' : rawStatus.toUpperCase();
                              
                              Color color = AppColors.danger;
                              if (rawStatus == 'sick') {
                                color = AppColors.warning;
                              } else if (rawStatus == 'no_lesson') {
                                color = AppColors.info;
                              } else if (rawStatus == 'other') {
                                color = Colors.orange;
                              }

                              final reason = todayLog != null ? _getAbsenceReason(todayLog.sabaq) : 'No reason specified';

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          student.fullName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (provider.isAdmin && student.teacherName != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Teacher: ${student.teacherName}',
                                      style: TextStyle(fontSize: 11, color: theme.hintColor),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.info_outline_rounded, size: 14, color: theme.hintColor),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          reason,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPeriodAbsenceDetails(BuildContext context, AppProvider provider, List<dynamic> reportList, {required bool isWeekly}) {
    final DateTime endDate = DateTime.tryParse(_selectedDateStr) ?? DateTime.now();
    final List<String> weekDates = [];
    for (int i = 6; i >= 0; i--) {
      final d = endDate.subtract(Duration(days: i));
      weekDates.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }
    final String monthPrefix = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';

    final List<Map<String, dynamic>> studentsWithAbsences = [];

    for (final item in reportList) {
      final Student student = item['student'] as Student;
      final logs = provider.getLogsForStudent(student.id);

      final periodAbsences = logs.where((l) {
        final logDate = l.date.contains('T') ? l.date.split('T')[0] : l.date;
        final isAbsentOrSick = ['absent', 'sick', 'other'].contains(l.status);
        if (!isAbsentOrSick) return false;

        if (isWeekly) {
          return weekDates.contains(logDate);
        } else {
          return logDate.startsWith(monthPrefix);
        }
      }).toList();

      if (periodAbsences.isNotEmpty) {
        periodAbsences.sort((a, b) => b.date.compareTo(a.date));

        studentsWithAbsences.add({
          'student': student,
          'absences': periodAbsences,
          'absentCount': periodAbsences.where((l) => l.status == 'absent').length,
          'sickCount': periodAbsences.where((l) => l.status == 'sick').length,
          'otherCount': periodAbsences.where((l) => l.status == 'other').length,
        });
      }
    }

    studentsWithAbsences.sort((a, b) {
      final int countA = (a['absences'] as List).length;
      final int countB = (b['absences'] as List).length;
      return countB.compareTo(countA);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isWeekly ? 'Weekly Absence Details' : 'Monthly Absence Details',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isWeekly
                        ? 'For week ending on $_selectedDateStr'
                        : 'For month: $_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  Expanded(
                    child: studentsWithAbsences.isEmpty
                        ? Center(
                            child: Text(
                              'No student absences in this period.',
                              style: TextStyle(color: theme.hintColor),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: studentsWithAbsences.length,
                            itemBuilder: (context, index) {
                              final item = studentsWithAbsences[index];
                              final Student student = item['student'] as Student;
                              final absences = item['absences'] as List<SabaqLog>;
                              final absentCount = item['absentCount'] as int;
                              final sickCount = item['sickCount'] as int;
                              final otherCount = item['otherCount'] as int;

                              final List<String> countParts = [];
                              if (absentCount > 0) countParts.add('$absentCount absent');
                              if (sickCount > 0) countParts.add('$sickCount sick');
                              if (otherCount > 0) countParts.add('$otherCount other');

                              return ExpansionTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: Text(
                                    student.fullName.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12),
                                  ),
                                ),
                                title: Text(
                                  student.fullName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                subtitle: Text(
                                  countParts.join(', '),
                                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                                ),
                                children: absences.map((log) {
                                  final logDateStr = log.date.contains('T') ? log.date.split('T')[0] : log.date;
                                  final statusText = log.status.toUpperCase();
                                  final color = log.status == 'sick' ? AppColors.warning : AppColors.danger;
                                  final reason = _getAbsenceReason(log.sabaq);
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                                    title: Row(
                                      children: [
                                        Text(
                                          logDateStr,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            statusText,
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(reason),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportRow(Student student, AppProvider provider, bool isDark) {
    final defaultSabaq = provider.profile?.defaultSabaqGoal ?? provider.defaultSabaqGoal;
    final defaultSabqi = provider.profile?.defaultSabqiGoal ?? provider.defaultSabqiGoal;
    final defaultManzil = provider.profile?.defaultManzilGoal ?? provider.defaultManzilGoal;

    final sabaqGoal = student.sabaqGoal ?? defaultSabaq;
    final sabqiGoal = student.sabqiGoal ?? defaultSabqi;
    final manzilGoal = student.manzilGoal ?? defaultManzil;

    final todayStatus = student.todayStatus;
    final isAbsentOrSick = ['absent', 'sick', 'other', 'no_lesson'].contains(todayStatus);

    // Look up today's log to fetch the reason & skip preservation info
    final logs = provider.getLogsForStudent(student.id);
    final todayLog = logs.where((l) {
      final d = l.date.contains('T') ? l.date.split('T')[0] : l.date;
      return d == _selectedDateStr;
    }).firstOrNull;

    final isAcknowledged = provider.getAcknowledgedIds(_selectedDateStr).contains(student.id);

    return InkWell(
      onTap: () => context.push('/students/${student.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Student Column (40%)
            Expanded(
              flex: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          student.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isAcknowledged) ...[
                        const SizedBox(width: 4),
                        const Tooltip(
                          message: 'Confirmed Pending',
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (provider.isAdmin && student.teacherName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      student.teacherName!,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Lesson Columns
            if (isAbsentOrSick && todayLog != null)
              Expanded(
                flex: 60, // 20 * 3
                child: _buildMergedAttendanceCell(todayStatus!, todayLog.sabaq, isDark),
              )
            else ...[
              // Sabaq
              Expanded(
                flex: 20,
                child: _buildLessonCell(
                  pages: student.todaySabaqPages,
                  goal: sabaqGoal,
                  log: todayLog,
                  type: 'sabaq',
                  isDark: isDark,
                ),
              ),

              // Sabqi
              Expanded(
                flex: 20,
                child: _buildLessonCell(
                  pages: student.todaySabqiPages,
                  goal: sabqiGoal,
                  log: todayLog,
                  type: 'sabqi',
                  isDark: isDark,
                ),
              ),

              // Muraja
              Expanded(
                flex: 20,
                child: _buildLessonCell(
                  pages: student.todayManzilPages,
                  goal: manzilGoal,
                  log: todayLog,
                  type: 'manzil',
                  isDark: isDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMergedAttendanceCell(String status, String sabaqText, bool isDark) {
    Color bg = const Color(0xFFFEE2E2);
    Color textColors = const Color(0xFF991B1B);
    Color border = const Color(0xFFFCA5A5);

    if (status == 'other') {
      bg = isDark ? const Color(0xFF1E1B2E) : const Color(0xFFF3F0FF);
      textColors = isDark ? const Color(0xFFA78BFA) : const Color(0xFF5B21B6);
      border = isDark ? const Color(0xFF5B21B6) : const Color(0xFFDDD6FE);
    } else if (status == 'sick') {
      bg = isDark ? const Color(0xFF1A2330) : const Color(0xFFEFF6FF);
      textColors = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
      border = isDark ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE);
    } else if (status == 'no_lesson') {
      bg = isDark ? const Color(0xFF2D231E) : const Color(0xFFFFF7ED);
      textColors = isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C);
      border = isDark ? const Color(0xFFC2410C) : const Color(0xFFFFEDD5);
    }

    String label = status.toUpperCase();
    if (sabaqText.startsWith('[SKIPPED:')) {
      final reason = sabaqText
          .replaceAll('[PRESERVE_STREAK]', '')
          .replaceAll('[SKIPPED:', '')
          .replaceAll(']', '')
          .trim();
      if (reason.toLowerCase() != status.toLowerCase()) {
        label = '$label - $reason';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: textColors,
          letterSpacing: 0.5,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildLessonCell({
    required double pages,
    required double goal,
    required SabaqLog? log,
    required String type,
    required bool isDark,
  }) {
    if (log == null) {
      // Not logged yet
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF23262A) : const Color(0xFFECEFEF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0xFF2C2F34) : const Color(0xFFD8DFDE)),
        ),
        child: const Text(
          '—',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      );
    }

    // Determine skip status
    bool isSkipped = false;
    bool isPreserved = false;
    String skipReason = 'Skipped';

    if (type == 'sabaq') {
      final text = log.sabaq;
      isSkipped = text.contains('[SKIPPED');
      isPreserved = isSkipped && text.contains('[PRESERVE_STREAK]');
      if (isSkipped) {
        final match = RegExp(r'\[SKIPPED:\s*(.*?)\]').firstMatch(text);
        if (match != null) {
          skipReason = match.group(1)?.replaceAll('[PRESERVE_STREAK]', '').trim() ?? 'Skipped';
        }
      }
    } else {
      final items = (log.parsedManzil?[type == 'sabqi' ? 'sabqi' : 'manzilPages'] as List?);
      if (items != null && items.isNotEmpty) {
        final skippedItem = items.where((i) {
          if (i is! Map) return false;
          final s = i['sabaq']?.toString() ?? '';
          final surah = i['surahName']?.toString() ?? '';
          return s.contains('[SKIPPED') || surah.contains('[SKIPPED');
        });
        if (skippedItem.isNotEmpty) {
          isSkipped = true;
          final first = skippedItem.first as Map;
          final combined = '${first['sabaq'] ?? ''}${first['surahName'] ?? ''}';
          isPreserved = combined.contains('[PRESERVE_STREAK]');
          
          final match = RegExp(r'\[SKIPPED:\s*(.*?)\]').firstMatch(combined);
          if (match != null) {
            skipReason = match.group(1)?.replaceAll('[PRESERVE_STREAK]', '').trim() ?? 'Skipped';
          }
        }
      }
    }

    final isDone = pages >= goal;
    final isPartial = pages > 0 && pages < goal;

    Color bg;
    Color border;
    Color textColors;
    String label;

    if (isSkipped) {
      if (isPreserved) {
        // Preserved is treated like success (green tint)
        bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
        border = AppColors.success.withValues(alpha: isDark ? 0.5 : 0.35);
        textColors = isDark ? AppColors.success : const Color(0xFF065F46);
        label = '[$skipReason]';
      } else {
        // Standard skipped is red
        bg = isDark ? const Color(0xFF3B1A1A) : const Color(0xFFFEE2E2);
        border = AppColors.danger.withValues(alpha: isDark ? 0.5 : 0.35);
        textColors = AppColors.danger;
        label = '[$skipReason]';
      }
    } else if (isDone) {
      bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
      border = AppColors.success.withValues(alpha: isDark ? 0.5 : 0.35);
      textColors = isDark ? AppColors.success : const Color(0xFF065F46);
      label = '${pages % 1 == 0 ? pages.toInt() : pages}/${goal % 1 == 0 ? goal.toInt() : goal}';
    } else if (isPartial) {
      bg = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
      border = AppColors.warning.withValues(alpha: isDark ? 0.5 : 0.35);
      textColors = isDark ? AppColors.warning : const Color(0xFF92400E);
      label = '${pages % 1 == 0 ? pages.toInt() : pages}/${goal % 1 == 0 ? goal.toInt() : goal}';
    } else {
      bg = isDark ? const Color(0xFF23262A) : const Color(0xFFECEFEF);
      border = isDark ? const Color(0xFF2C2F34) : const Color(0xFFD8DFDE);
      textColors = isDark ? const Color(0xFF78909C) : const Color(0xFF455A64);
      label = '0/${goal % 1 == 0 ? goal.toInt() : goal}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColors,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
