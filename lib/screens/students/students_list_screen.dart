import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../models/student.dart';
import '../../widgets/alphabet_scrollbar.dart';
import '../../utils/student_utils.dart';
import '../../utils/quran_data.dart';
import '../../widgets/log_sabaq_sheet.dart';
import '../../widgets/log_sabqi_sheet.dart';
import '../../widgets/log_manzil_sheet.dart';
import '../../widgets/mark_student_sheet.dart';

/// Describes whether a lesson badge represents a skip and which kind.
enum _BadgeSkipType {
  none,           // not skipped
  withStreak,     // [PRESERVE_STREAK] present → styled like fully done (green)
  withoutStreak,  // skipped but no streak preservation → red icon-only badge
}

class StudentsListScreen extends StatefulWidget {
  const StudentsListScreen({Key? key}) : super(key: key);

  @override
  _StudentsListScreenState createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen> {
  String _searchQuery = '';
  String _selectedTeacher = 'All';
  final _scrollController = ScrollController();
  String? _activeLetter;
  bool _showIndicator = false;
  AppProvider? _providerReference;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _providerReference = Provider.of<AppProvider>(context, listen: false);
  }

  void _onScroll() {
    final provider = context.read<AppProvider>();
    // Show FAB only when within the first 8px; hide as soon as user scrolls
    final atTop = _scrollController.offset <= 8.0;
    provider.setFabVisible(atTop);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // Reset FAB so other tabs are unaffected using saved provider reference
    final provider = _providerReference;
    if (provider != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.setFabVisible(true);
      });
    }
    super.dispose();
  }

  void _scrollToLetter(String letter) {
    final provider = context.read<AppProvider>();
    final students = _filterStudents(provider.students);
    final sections = _buildSections(students);
    final index = sections.indexWhere((item) => item is String && item == letter);
    if (index < 0) return;

    if (!_scrollController.hasClients) return;
    final viewportH = _scrollController.position.viewportDimension;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final itemPosition = (index / sections.length) * (maxScroll + viewportH);
    final offset = itemPosition - (viewportH * 0.25);
    _scrollController.animateTo(
      offset.clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  List<Student> _filterStudents(List<Student> students) {
    final provider = context.read<AppProvider>();
    final selectedDateStr = provider.selectedDateStr;
    final list = students.where((s) {
      if (s.isPersonal == true) return false;
      final matchesSearch = s.fullName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesTeacher = _selectedTeacher == 'All' ||
          (s.teacherName != null && s.teacherName!.trim().toLowerCase() == _selectedTeacher.trim().toLowerCase());
      return matchesSearch && matchesTeacher;
    }).toList();

    // Sort alphabetically first
    list.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

    // If filterPending is active, sort pending students to the top for the selected date
    if (provider.filterPending) {
      list.sort((a, b) {
        final aLogs = provider.getLogsForStudent(a.id);
        final aLog = aLogs.where((l) => (l.date.contains('T') ? l.date.split('T')[0] : l.date) == selectedDateStr).firstOrNull;
        final aPending = aLog == null || (
          aLog.status != 'absent' &&
          aLog.status != 'sick' &&
          aLog.status != 'other' &&
          aLog.sabaq.isEmpty &&
          (aLog.parsedManzil == null || (
            ((aLog.parsedManzil!['sabqi'] as List?)?.isEmpty ?? true) &&
            ((aLog.parsedManzil!['manzilPages'] as List?)?.isEmpty ?? true)
          ))
        );
            
        final bLogs = provider.getLogsForStudent(b.id);
        final bLog = bLogs.where((l) => (l.date.contains('T') ? l.date.split('T')[0] : l.date) == selectedDateStr).firstOrNull;
        final bPending = bLog == null || (
          bLog.status != 'absent' &&
          bLog.status != 'sick' &&
          bLog.status != 'other' &&
          bLog.sabaq.isEmpty &&
          (bLog.parsedManzil == null || (
            ((bLog.parsedManzil!['sabqi'] as List?)?.isEmpty ?? true) &&
            ((bLog.parsedManzil!['manzilPages'] as List?)?.isEmpty ?? true)
          ))
        );
            
        if (aPending && !bPending) return -1;
        if (!aPending && bPending) return 1;
        return 0;
      });
    }

    return list;
  }

  List<String> _getAvailableLetters(List<Student> students) {
    final letters = <String>{};
    for (final s in students) {
      if (s.fullName.isNotEmpty) {
        letters.add(s.fullName[0].toUpperCase());
      }
    }
    final sorted = letters.toList()..sort();
    return sorted;
  }

  List<Object> _buildSections(List<Student> students) {
    final items = <Object>[];
    String? lastLetter;
    for (final s in students) {
      final letter = s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '';
      if (letter != lastLetter) {
        items.add(letter);
        lastLetter = letter;
      }
      items.add(s);
    }
    return items;
  }

  Widget _buildSectionHeader(String letter) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
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



  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (_isFirstLoad && provider.students.isNotEmpty) {
      _isFirstLoad = false;
      final profile = provider.profile;
      if (profile != null && (profile.role == 'admin' || profile.role == 'super_admin')) {
        final ownName = profile.fullName;
        final hasAssignedStudents = provider.students.any((s) => s.teacherId == profile.id);
        if (hasAssignedStudents) {
          _selectedTeacher = ownName;
        }
      }
    }
    final students = provider.students;
    final teachers = List<dynamic>.from(provider.institutionPeople['teachers'] ?? []);
    
    if (_selectedTeacher != 'All') {
      teachers.sort((a, b) {
        if (a['full_name'] == _selectedTeacher) return -1;
        if (b['full_name'] == _selectedTeacher) return 1;
        return 0;
      });
    }

    if (!provider.isSearchVisible && _searchQuery.isNotEmpty) {
      _searchQuery = '';
    }
    final filteredStudents = _filterStudents(students);
    final availableLetters = _getAvailableLetters(filteredStudents);

    return RefreshIndicator(
        onRefresh: () => provider.refresh(),
        child: Column(
          children: [


            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: provider.isSearchVisible
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search students...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Container(
              width: double.infinity,
              color: AppColors.primary.withOpacity(0.06),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedTeacher == 'All',
                      labelStyle: TextStyle(
                        color: _selectedTeacher == 'All' ? Colors.white : null,
                      ),
                      onSelected: (_) => setState(() => _selectedTeacher = 'All'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Pending'),
                      selected: provider.filterPending,
                      labelStyle: TextStyle(
                        color: provider.filterPending ? Colors.white : null,
                      ),
                      onSelected: (val) => provider.setFilterPending(val),
                    ),
                    if (provider.profile?.role == 'admin') ...[
                      ...teachers.map((t) {
                        final name = t['full_name'] as String;
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
                            labelStyle: TextStyle(
                              color: _selectedTeacher == name ? Colors.white : null,
                            ),
                            onSelected: (_) => setState(() => _selectedTeacher = name),
                          ),
                        );
                      }),
                    ] else ...[
                      if (provider.absentTeachersToday.isNotEmpty) ...[
                        if (provider.profile?.fullName != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: FilterChip(
                              label: Text(provider.profile!.fullName),
                              selected: _selectedTeacher == provider.profile!.fullName,
                              labelStyle: TextStyle(
                                color: _selectedTeacher == provider.profile!.fullName ? Colors.white : null,
                              ),
                              onSelected: (_) => setState(() => _selectedTeacher = provider.profile!.fullName),
                            ),
                          ),
                        ...provider.absentTeachersToday
                            .where((at) => at['teacher_id'] != provider.user?.id)
                            .map((at) {
                          final profile = at['profiles'] as Map<String, dynamic>?;
                          final name = profile?['full_name'] ?? 'Unknown Teacher';
                          return Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: FilterChip(
                              label: Text('$name (Absent)'),
                              selected: _selectedTeacher == name,
                              labelStyle: TextStyle(
                                color: _selectedTeacher == name ? Colors.white : null,
                              ),
                              onSelected: (_) => setState(() => _selectedTeacher = name),
                            ),
                          );
                        }),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  !provider.hasFetchedStudents
                      ? ListView.builder(
                          itemCount: 5,
                          itemBuilder: (context, index) => _buildShimmer(),
                        )
                      : filteredStudents.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline, size: 48, color: Colors.grey),
                                  SizedBox(height: 12),
                                  Text(
                                    'No students found.',
                                    style: TextStyle(color: Colors.grey, fontSize: 16),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              itemCount: _buildSections(filteredStudents).length,
                              itemBuilder: (context, index) {
                                final item = _buildSections(filteredStudents)[index];
                                if (item is String) {
                                  return _buildSectionHeader(item);
                                }
                                final student = item as Student;
                                return Dismissible(
                                  key: ValueKey('dismiss_${student.id}'),
                                  direction: DismissDirection.horizontal,
                                  confirmDismiss: (direction) async {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => MarkStudentBottomSheet(
                                        studentId: student.id,
                                        student: student,
                                      ),
                                    );
                                    return false;
                                  },
                                  background: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 24),
                                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(24.0),
                                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.person_off_rounded, color: AppColors.primary, size: 22),
                                        SizedBox(width: 8),
                                        Text('Mark Status', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                  secondaryBackground: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 24),
                                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(24.0),
                                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text('Mark Status', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                                        SizedBox(width: 8),
                                        Icon(Icons.person_off_rounded, color: AppColors.primary, size: 22),
                                      ],
                                    ),
                                  ),
                                  child: _buildStudentCard(student, provider),
                                )
                                    .animate(key: ValueKey('anim_${student.id}'))
                                    .fadeIn()
                                    .slideY(begin: 0.1, curve: Curves.easeOut);
                              },
                            ),
                  if (availableLetters.length > 1)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: AlphabetScrollbar(
                        availableLetters: availableLetters,
                        activeLetter: _activeLetter,
                        onLetterChanged: (letter) {
                          setState(() => _activeLetter = letter);
                          _scrollToLetter(letter);
                        },
                        onDragStarted: () => setState(() => _showIndicator = true),
                        onDragEnded: () => setState(() => _showIndicator = false),
                      ),
                    ),
                  if (availableLetters.length > 1)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: AlphabetScrollbar(
                        availableLetters: availableLetters,
                        activeLetter: _activeLetter,
                        onLetterChanged: (letter) {
                          setState(() => _activeLetter = letter);
                          _scrollToLetter(letter);
                        },
                        onDragStarted: () => setState(() => _showIndicator = true),
                        onDragEnded: () => setState(() => _showIndicator = false),
                      ),
                    ),
                  if (_showIndicator && _activeLetter != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: 1,
                            duration: const Duration(milliseconds: 150),
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  _activeLetter!,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
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

  Widget _buildShimmer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      height: 84,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23262A) : const Color(0xFFE9ECEC),
        borderRadius: BorderRadius.circular(16.0),
      ),
    ).animate(onPlay: (controller) => controller.repeat()).fadeIn(duration: 700.ms).fadeOut(delay: 700.ms, duration: 700.ms);
  }

  void _openQuickLog(Student student, int type) {
    final provider = context.read<AppProvider>();
    final selectedDateStr = provider.selectedDateStr;
    Widget sheet;
    switch (type) {
      case 0:
        sheet = SabaqBottomSheet(studentId: student.id, student: student, initialDate: selectedDateStr);
        break;
      case 1:
        sheet = SabqiBottomSheet(studentId: student.id, student: student, initialDate: selectedDateStr);
        break;
      case 2:
        sheet = ManzilBottomSheet(studentId: student.id, student: student, initialDate: selectedDateStr);
        break;
      default:
        return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
  }

  // Circle badge: normal count display, done state, or skip states.
  // skipType overrides the normal colour logic when the lesson was skipped.
  Widget _buildCircleBadge({
    required double count,
    required bool isDone,
    required bool isDark,
    required IconData icon,
    required VoidCallback onTap,
    _BadgeSkipType skipType = _BadgeSkipType.none,
    bool isAcknowledged = false,
  }) {
    final Color borderColor;
    final Color textColor;
    final Color bgColor;
    List<BoxShadow>? shadows;

    if (skipType == _BadgeSkipType.withStreak) {
      // Preserved-streak skip → looks like a completed lesson (green filled)
      bgColor = AppColors.primary;
      borderColor = AppColors.primary;
      textColor = Colors.white;
      shadows = [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.25),
          blurRadius: 4,
          offset: const Offset(0, 2),
        )
      ];
    } else if (skipType == _BadgeSkipType.withoutStreak) {
      // No-preservation skip → red tinted, icon only
      bgColor = isDark ? const Color(0xFF3B1A1A) : const Color(0xFFFEE2E2);
      borderColor = AppColors.danger.withValues(alpha: isDark ? 0.5 : 0.35);
      textColor = AppColors.danger;
    } else if (isDone) {
      bgColor = AppColors.primary;
      borderColor = AppColors.primary;
      textColor = Colors.white;
      shadows = [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.25),
          blurRadius: 4,
          offset: const Offset(0, 2),
        )
      ];
    } else if (isAcknowledged) {
      // Confirmed/acknowledged pending lessons → Red/Danger color
      bgColor = isDark ? const Color(0xFF3B1A1A) : const Color(0xFFFEE2E2);
      borderColor = AppColors.danger.withValues(alpha: isDark ? 0.5 : 0.35);
      textColor = AppColors.danger;
    } else if (count > 0) {
      bgColor = isDark ? const Color(0xFF1E2D27) : const Color(0xFFE8F5E9);
      borderColor = AppColors.primary.withValues(alpha: 0.5);
      textColor = isDark ? AppColors.primaryLight : AppColors.primaryDark;
    } else {
      bgColor = Colors.transparent;
      borderColor = isDark ? const Color(0xFF2C2F34) : const Color(0xFFE4E4E7);
      textColor = isDark ? const Color(0xFF78909C) : const Color(0xFF9EADB5);
    }

    // Skipped lessons never show a count — always show the icon
    final showIcon = skipType != _BadgeSkipType.none || count == 0;

    final countStr = count % 1 == 0 ? '${count.toInt()}' : '${count.toStringAsFixed(1)}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.8),
          boxShadow: shadows,
        ),
        child: showIcon
            ? Icon(
                icon,
                size: 14,
                color: textColor.withValues(alpha: skipType == _BadgeSkipType.none ? 0.8 : 1.0),
              )
            : Text(
                countStr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  height: 1.0,
                ),
              ),
      ),
    );
  }

  Widget _buildStudentCard(Student student, AppProvider provider) {
    final sabaqGoal = provider.profile?.defaultSabaqGoal ?? provider.defaultSabaqGoal;
    final sabqiGoal = provider.profile?.defaultSabqiGoal ?? provider.defaultSabqiGoal;
    final manzilGoal = provider.profile?.defaultManzilGoal ?? provider.defaultManzilGoal;

    final studentLogs = provider.getLogsForStudent(student.id);
    final isAcknowledged = provider.getAcknowledgedIds(provider.selectedDateStr).contains(student.id);

    // Look up the log for the selected date safely
    final matchingSelectedDate = studentLogs.where((l) {
      final d = l.date.contains('T') ? l.date.split('T')[0] : l.date;
      return d == provider.selectedDateStr;
    });
    final todayLog = matchingSelectedDate.isNotEmpty ? matchingSelectedDate.first : null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Status for this log specifically
    final currentStatus = todayLog?.status ?? '';
    final isAbsentOrLeave = currentStatus == 'absent' || currentStatus == 'sick' || currentStatus == 'other' || currentStatus == 'no_lesson';

    // Sabaq pages logged for this day
    final sabaqPages = (!isAbsentOrLeave && todayLog?.sabaq != null)
        ? getPagesCountFromSabaqString(todayLog!.sabaq!)
        : 0.0;

    // Sabqi pages logged for this day
    final manzilJson = todayLog?.parsedManzil;
    final sabqiItems = (manzilJson?['sabqi'] as List?);
    final sabqiPages = (!isAbsentOrLeave && sabqiItems != null)
        ? sabqiItems.length.toDouble()
        : 0.0;

    // Manzil pages logged for this day
    final manzilPageItems = (manzilJson?['manzilPages'] as List?);
    double manzilPages = 0.0;
    if (!isAbsentOrLeave && manzilJson != null) {
      if (manzilPageItems != null) {
        manzilPages += manzilPageItems.length.toDouble();
      }
      if (manzilJson['manzil'] is String) {
        final matches = RegExp(r'Juz\s+\d+').allMatches(manzilJson['manzil'] as String);
        manzilPages += matches.length * 20.0;
      }
    }

    final sabaqDone = sabaqPages >= sabaqGoal;
    final sabqiDone = sabqiPages >= sabqiGoal;
    final manzilDone = manzilPages >= manzilGoal;

    // --- Derive per-lesson skip states from today's log ---
    // Sabaq: encoded directly in the sabaq string
    final sabaqStr = todayLog?.sabaq ?? '';
    final sabaqIsSkipped = sabaqStr.startsWith('[SKIPPED:');
    final sabaqPreserved = sabaqIsSkipped && sabaqStr.contains('[PRESERVE_STREAK]');
    final sabaqSkipType = sabaqIsSkipped
        ? (sabaqPreserved ? _BadgeSkipType.withStreak : _BadgeSkipType.withoutStreak)
        : _BadgeSkipType.none;

    _BadgeSkipType _parseSkipType(List<dynamic>? items) {
      if (items == null || items.isEmpty) return _BadgeSkipType.none;
      final skippedItem = items.where((i) {
        if (i is! Map) return false;
        final sabaq = i['sabaq']?.toString() ?? '';
        final surahName = i['surahName']?.toString() ?? '';
        return sabaq.contains('[SKIPPED]') ||
            sabaq.startsWith('[SKIPPED:') ||
            surahName.startsWith('[SKIPPED:');
      });
      if (skippedItem.isEmpty) return _BadgeSkipType.none;
      final first = skippedItem.first as Map;
      final combined = '${first['sabaq'] ?? ''}${first['surahName'] ?? ''}';
      return combined.contains('[PRESERVE_STREAK]')
          ? _BadgeSkipType.withStreak
          : _BadgeSkipType.withoutStreak;
    }

    final sabqiSkipType = _parseSkipType(sabqiItems);
    final manzilSkipType = _parseSkipType(manzilPageItems);

    // Format attendance reason from stored sabaq string
    String statusText = '';
    Color statusBg = const Color(0xFFFEE2E2);
    Color statusTextColor = const Color(0xFF991B1B);

    if (isAbsentOrLeave) {
      final sabaq = todayLog?.sabaq ?? '';
      if (sabaq.startsWith('[SKIPPED:')) {
        statusText = sabaq
            .replaceAll('[PRESERVE_STREAK]', '')
            .replaceAll('[SKIPPED:', '')
            .replaceAll(']', '')
            .trim();
      } else {
        final raw = currentStatus;
        statusText = raw.isEmpty ? '' : raw[0].toUpperCase() + raw.substring(1);
      }

      if (currentStatus == 'other') {
        statusBg = isDark ? const Color(0xFF1E1B2E) : const Color(0xFFF3F0FF);
        statusTextColor = isDark ? const Color(0xFFA78BFA) : const Color(0xFF5B21B6);
      } else if (currentStatus == 'sick') {
        statusBg = isDark ? const Color(0xFF1A2330) : const Color(0xFFEFF6FF);
        statusTextColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
      } else if (currentStatus == 'no_lesson') {
        statusBg = isDark ? const Color(0xFF2D231E) : const Color(0xFFFFF7ED);
        statusTextColor = isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C);
      } else {
        statusBg = isDark ? const Color(0xFF3B1A1A) : const Color(0xFFFEE2E2);
        statusTextColor = isDark ? const Color(0xFFEF4444) : const Color(0xFF991B1B);
      }
    }

    const avatarColor = AppColors.primary;

    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE8ECEB);

    return GestureDetector(
      onTap: () => context.push('/students/${student.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: isDark
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Avatar + Streak overlay badge ───────────────────────────
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Hero(
                    tag: 'avatar_${student.id}',
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [avatarColor, avatarColor.withValues(alpha: 0.75)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (student.streak > 0)
                    Builder(
                      builder: (context) {
                        final streak = student.streak;
                        List<Color> gradientColors;
                        Color shadowColor;
                        String iconText = '⚡';
                        
                        if (streak >= 30) {
                          // Tier 5: Master / Epic (Vibrant Indigo Purple to Magenta)
                          gradientColors = const [Color(0xFF6366F1), Color(0xFFD946EF)];
                          shadowColor = const Color(0xFF6366F1);
                          iconText = '👑';
                        } else if (streak >= 14) {
                          // Tier 4: Legend / Diamond (Sleek Cyan to Royal Blue)
                          gradientColors = const [Color(0xFF06B6D4), Color(0xFF3B82F6)];
                          shadowColor = const Color(0xFF06B6D4);
                          iconText = '💎';
                        } else if (streak >= 7) {
                          // Tier 3: Hot / Gold (Vibrant Orange to Gold Yellow)
                          gradientColors = const [Color(0xFFFF8C00), Color(0xFFFFC200)];
                          shadowColor = const Color(0xFFFF8C00);
                          iconText = '🔥';
                        } else if (streak >= 3) {
                          // Tier 2: Warm / Silver (Muted Slate / Silver Teal)
                          gradientColors = const [Color(0xFF64748B), Color(0xFF94A3B8)];
                          shadowColor = const Color(0xFF64748B);
                          iconText = '✨';
                        } else {
                          // Tier 1: Ember / Bronze (Earthy Bronze/Copper Brown)
                          gradientColors = const [Color(0xFF8B5A2B), Color(0xFFCD7F32)];
                          shadowColor = const Color(0xFF8B5A2B);
                          iconText = '⚡';
                        }

                        return Positioned(
                          bottom: -4,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: gradientColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: surfaceColor,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: shadowColor.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              '$iconText $streak',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.2,
                                height: 1.0,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),

              const SizedBox(width: 14),

              // ── Bounded Center Column Layout ─────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: Student Name + Trailing Lesson Indicators / Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Hero(
                            tag: 'student_name_${student.id}',
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                student.fullName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: isDark ? AppColors.textMainDark : const Color(0xFF18181B),
                                  height: 1.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isAbsentOrLeave)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? statusBg.withValues(alpha: 0.3) : statusBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: statusTextColor.withValues(alpha: isDark ? 0.35 : 0.25),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              statusText.isEmpty
                                  ? currentStatus.isEmpty
                                      ? ''
                                      : '${currentStatus[0].toUpperCase()}${currentStatus.substring(1)}'
                                  : statusText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusTextColor,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          Builder(
                            builder: (context) {
                              final isHafiz = student.progressPercent >= 100;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isHafiz) ...[
                                    _buildCircleBadge(
                                      count: sabaqPages,
                                      isDone: sabaqDone,
                                      isDark: isDark,
                                      icon: Icons.menu_book_rounded,
                                      onTap: () => _openQuickLog(student, 0),
                                      skipType: sabaqSkipType,
                                      isAcknowledged: isAcknowledged,
                                    ),
                                    const SizedBox(width: 4),
                                    _buildCircleBadge(
                                      count: sabqiPages,
                                      isDone: sabqiDone,
                                      isDark: isDark,
                                      icon: Icons.history_rounded,
                                      onTap: () => _openQuickLog(student, 1),
                                      skipType: sabqiSkipType,
                                      isAcknowledged: isAcknowledged,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  _buildCircleBadge(
                                    count: manzilPages,
                                    isDone: manzilDone,
                                    isDark: isDark,
                                    icon: Icons.collections_bookmark_rounded,
                                    onTap: () => _openQuickLog(student, 2),
                                    skipType: manzilSkipType,
                                    isAcknowledged: isAcknowledged,
                                  ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),

                    // Row 2: Teacher Name prefaces by a small spacing block
                    if (student.teacherName != null && student.teacherName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF78909C) : const Color(0xFF9CA3AF),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                student.teacherName!,
                                style: TextStyle(
                                  color: isDark ? AppColors.textMutedDark : const Color(0xFF71717A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),

                    // Row 3: Progress track clipped inside ClipRRect & Juz label
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10.0),
                            child: LinearProgressIndicator(
                              value: student.progressPercent / 100,
                              minHeight: 5.0,
                              backgroundColor: isDark
                                  ? const Color(0xFF2C2F34)
                                  : const Color(0xFFE4E4E7),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${student.uniqueCount} Juz',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textTertiaryDark : const Color(0xFF71717A),
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
      ),
    );
  }
}
