import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/app_provider.dart';
import '../models/student.dart';
import '../models/sabaq_log.dart';
import '../utils/quran_data.dart';
import '../utils/student_utils.dart';

class SabaqBottomSheet extends StatefulWidget {
  final String studentId;
  final Student student;
  final String? initialDate;

  const SabaqBottomSheet({
    Key? key,
    required this.studentId,
    required this.student,
    this.initialDate,
  }) : super(key: key);

  @override
  _SabaqBottomSheetState createState() => _SabaqBottomSheetState();
}

class _SabaqBottomSheetState extends State<SabaqBottomSheet> {
  bool _isLoading = false;
  late String _date = widget.initialDate ?? getLocalToday();

  final TextEditingController _ayahFromCtrl = TextEditingController(text: '1');
  final TextEditingController _ayahToCtrl   = TextEditingController(text: '1');

  int _surahFrom = 1;
  int _ayahFrom = 1;
  int _surahTo = 1;
  int _ayahTo = 1;
  double? _targetPages;
  int _estimatedLines = 0;
  double _estimatedPages = 0;
  String? _heardBy;

  bool _isSabaqSkipped = false;
  String _skipReason = 'Khatam Juz';
  String _skipSickDetail = '';
  String _skipOtherDetail = '';
  bool _preserveStreakSabaq = true;

  bool _isDirty = false;
  ({int surahNum, int ayahNum})? _lastSuggestion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _init() {
    final provider = context.read<AppProvider>();
    _loadFromProvider(provider);
    _syncInBackground();
  }

  void _loadFromProvider(AppProvider provider) {
    final teachers = provider.institutionPeople['teachers'] ?? [];
    final profileName = provider.profile?.fullName;
    final teacherNames = teachers.map<String>((t) => t['full_name'] as String).toList();
    String? defaultTeacher;
    if (profileName != null && teacherNames.contains(profileName)) {
      defaultTeacher = profileName;
    } else if (teachers.isNotEmpty) {
      defaultTeacher = teachers.first['full_name'];
    }

    if (mounted) {
      setState(() {
        _heardBy = _heardBy ?? defaultTeacher;
      });
    }
  }

  Future<void> _syncInBackground() async {
    try {
      final provider = context.read<AppProvider>();
      await provider.syncSingleStudentLogs(widget.studentId);
      if (!mounted) return;
      _loadFromProvider(provider);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ayahFromCtrl.dispose();
    _ayahToCtrl.dispose();
    super.dispose();
  }

  int _getPageForAyah(int surahNum, int ayahNum) => getPageForAyah(surahNum, ayahNum);

  void _recalcLines() {
    final pageSpan = calculatePageSpanFromAyahs(_surahFrom, _ayahFrom, _surahTo, _ayahTo);
    final lines = (pageSpan * 15.0).round().clamp(0, 9060);

    setState(() {
      _estimatedLines = lines;
      _estimatedPages = pageSpan;
    });
  }

  void _updateAyahFromAndRecalc(int newSurah, int newAyah) {
    setState(() {
      _isDirty = true;
      _surahFrom = newSurah;
      _ayahFrom = newAyah;
      _ayahFromCtrl.text = newAyah.toString();
      
      if (_targetPages != null) {
        final result = calculateEndAyahByPages(_surahFrom, _ayahFrom, _targetPages!);
        _surahTo = result.surahNum;
        _ayahTo = result.ayahNum;
        _ayahToCtrl.text = result.ayahNum.toString();
      }
    });
    _recalcLines();
  }

  void _applyTargetPages(double? pages) {
    setState(() {
      _isDirty = true;
      _targetPages = pages;
    });
    if (pages == null || pages <= 0) return;
    final safeAyah = _ayahFrom.clamp(1, quranSurahs[_surahFrom - 1].ayahCount);
    final result = calculateEndAyahByPages(_surahFrom, safeAyah, pages);
    setState(() {
      _surahTo = result.surahNum;
      _ayahTo = result.ayahNum;
    });
    _ayahToCtrl.text = result.ayahNum.toString();
    _recalcLines();
  }

  void _updateDateAndSuggestion(String newDate) {
    setState(() => _date = newDate);
    final provider = context.read<AppProvider>();
    final logs = provider.getLogsForStudent(widget.studentId);
    final milestone = provider.getJuzMilestoneForStudent(widget.studentId);
    final activeJuzId = milestone?['id'] as int?;

    final suggestion = _computeSuggestedSabaq(logs, activeJuzId, newDate);
    final safeAyah = suggestion.ayahNum
        .clamp(1, quranSurahs[suggestion.surahNum - 1].ayahCount);
    final endResult =
        calculateEndAyahByPages(suggestion.surahNum, safeAyah, 1.0);

    final startPage = getPageForAyah(suggestion.surahNum, safeAyah);
    final isStartOfPage = safeAyah == 1 || getPageForAyah(suggestion.surahNum, safeAyah - 1) != startPage;
    final target = isStartOfPage ? 1.0 : null;

    setState(() {
      _isDirty = false;
      _lastSuggestion = suggestion;
      _surahFrom = suggestion.surahNum;
      _ayahFrom = safeAyah;
      _surahTo = endResult.surahNum;
      _ayahTo = endResult.ayahNum;
      _targetPages = target;
    });
    _ayahFromCtrl.text = safeAyah.toString();
    _ayahToCtrl.text   = endResult.ayahNum.toString();
    _recalcLines();
  }

  ({int surahNum, int ayahNum}) _computeSuggestedSabaq(
      List<SabaqLog> logs, int? activeJuzId, String targetDate) {
    final logsWithPages = <({SabaqLog log, int pageNum})>[];
    for (final l in logs) {
      if (l.date.compareTo(targetDate) > 0) continue;
      if (l.sabaq.isEmpty) continue;
      if (l.sabaq.startsWith('[SKIPPED')) continue;
      final pages = getPagesFromSabaqString(l.sabaq);
      if (pages.isEmpty) continue;
      final pageNum = pages.last;
      logsWithPages.add((log: l, pageNum: pageNum));
    }

    if (logsWithPages.isEmpty) {
      if (activeJuzId != null && activeJuzId >= 1 && activeJuzId <= 30) {
        final juzInfo = getJuzInfo(activeJuzId);
        final startSurah = findQuranSurah(juzInfo.startSurah);
        if (startSurah != null) {
          return (surahNum: startSurah.number, ayahNum: juzInfo.startAyah);
        }
      }
      return (surahNum: 1, ayahNum: 1);
    }

    // Sort: newest date first, then baseline_sabqi prioritized over baseline, then highest page
    logsWithPages.sort((a, b) {
      final dateCmp = b.log.date.compareTo(a.log.date);
      if (dateCmp != 0) return dateCmp;
      
      if (a.log.status == 'baseline_sabqi' && b.log.status != 'baseline_sabqi') return -1;
      if (b.log.status == 'baseline_sabqi' && a.log.status != 'baseline_sabqi') return 1;
      
      return b.pageNum.compareTo(a.pageNum);
    });
    final latest = logsWithPages.first;

    if (activeJuzId != null && activeJuzId >= 1 && activeJuzId <= 30) {
      final latestJuz = getJuzForPage(latest.pageNum);
      if (latestJuz != activeJuzId) {
        final juzInfo = getJuzInfo(activeJuzId);
        final startSurah = findQuranSurah(juzInfo.startSurah);
        if (startSurah != null) {
          return (surahNum: startSurah.number, ayahNum: juzInfo.startAyah);
        }
      }
    }

    final segments = latest.log.sabaq.split(' | ');
    final lastSegment = segments.last;

    QuranSurah? findSurah(String name) {
      final lower = name.trim().toLowerCase();
      for (final s in quranSurahs) {
        if (s.name.toLowerCase() == lower) return s;
      }
      for (final s in quranSurahs) {
        final c = s.name.toLowerCase();
        if (c.startsWith(lower) || lower.startsWith(c)) return s;
      }
      String strip(String t) =>
          t.replaceAll(RegExp(r"['\-\s]"), '').toLowerCase();
      final stripped = strip(name);
      for (final s in quranSurahs) {
        if (strip(s.name) == stripped) return s;
      }
      return null;
    }

    ({int surahNum, int ayahNum})? advance(QuranSurah? meta, int ayahTo) {
      if (meta == null) return null;
      int nextSurah = meta.number;
      int nextAyah = ayahTo + 1;
      if (nextAyah > meta.ayahCount) {
        if (nextSurah < 114) { nextSurah += 1; nextAyah = 1; }
        else { return (surahNum: 114, ayahNum: 6); }
      }
      return (surahNum: nextSurah, ayahNum: nextAyah);
    }

    final matchA =
        RegExp(r'Surah\s+(.*?)\s+\(Ayah\s+(\d+)-(\d+)\)')
            .firstMatch(lastSegment);
    if (matchA != null) {
      final result = advance(
        findSurah(matchA.group(1) ?? ''),
        int.tryParse(matchA.group(3) ?? '') ?? 1,
      );
      if (result != null) return result;
    }

    final matchB =
        RegExp(r'^(.*?)\s+\(\d+\)\s+to\s+(.*?)\s+\((\d+)\)')
            .firstMatch(lastSegment);
    if (matchB != null) {
      final result = advance(
        findSurah(matchB.group(2) ?? ''),
        int.tryParse(matchB.group(3) ?? '') ?? 1,
      );
      if (result != null) return result;
    }

    final nextPage = (latest.pageNum + 1).clamp(1, 604);
    for (final s in quranSurahs) {
      for (int a = 1; a <= s.ayahCount; a++) {
        if (getPageForAyah(s.number, a) == nextPage) {
          return (surahNum: s.number, ayahNum: a);
        }
      }
    }

    return (surahNum: 1, ayahNum: 1);
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<AppProvider>();

      String sabaqString = '';
      if (_isSabaqSkipped) {
        String reasonText = _skipReason;
        if (_skipReason == 'Sick' && _skipSickDetail.isNotEmpty) {
          reasonText = 'Sick - $_skipSickDetail';
        } else if (_skipReason == 'Other' && _skipOtherDetail.isNotEmpty) {
          reasonText = _skipOtherDetail;
        }
        final preserveStr = (_preserveStreakSabaq || _skipReason == 'Khatam Juz') ? ' [PRESERVE_STREAK]' : '';
        sabaqString = '[SKIPPED: $reasonText]$preserveStr - Heard by: ${_heardBy ?? ''}';
      } else {
        final startPage = _getPageForAyah(_surahFrom, _ayahFrom);
        final endPage = _getPageForAyah(_surahTo, _ayahTo);
        final pageRangeStr = startPage == endPage ? '$endPage' : '$startPage-$endPage';
        final fromSurahName = quranSurahs[_surahFrom - 1].name;
        final toSurahName = quranSurahs[_surahTo - 1].name;
        if (_surahFrom == _surahTo) {
          sabaqString = 'Surah $fromSurahName (Ayah $_ayahFrom-$_ayahTo) [Page $pageRangeStr] - $_estimatedLines Line(s) (${_estimatedPages.toStringAsFixed(2)} Page) - Heard by: ${_heardBy ?? ''}';
        } else {
          sabaqString = '$fromSurahName ($_ayahFrom) to $toSurahName ($_ayahTo) [Page $pageRangeStr] - $_estimatedLines Line(s) (${_estimatedPages.toStringAsFixed(2)} Page) - Heard by: ${_heardBy ?? ''}';
        }
      }

      final result = await provider.mergeLog(
        studentId: widget.studentId,
        date: _date,
        sabaq: sabaqString,
      );

      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sabaq logged successfully')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final provider = context.watch<AppProvider>();
    final logs = provider.getLogsForStudent(widget.studentId);
    final milestone = provider.getJuzMilestoneForStudent(widget.studentId);
    final activeJuzId = milestone?['id'] as int?;

    final suggestion = _computeSuggestedSabaq(logs, activeJuzId, _date);
    if (_lastSuggestion == null ||
        _lastSuggestion!.surahNum != suggestion.surahNum ||
        _lastSuggestion!.ayahNum != suggestion.ayahNum) {
      _lastSuggestion = suggestion;
      if (!_isDirty) {
        final safeAyah = suggestion.ayahNum
            .clamp(1, quranSurahs[suggestion.surahNum - 1].ayahCount);
        final endResult =
            calculateEndAyahByPages(suggestion.surahNum, safeAyah, 1.0);

        final startPage = getPageForAyah(suggestion.surahNum, safeAyah);
        final isStartOfPage = safeAyah == 1 ||
            getPageForAyah(suggestion.surahNum, safeAyah - 1) != startPage;
        final target = isStartOfPage ? 1.0 : null;

        _surahFrom = suggestion.surahNum;
        _ayahFrom = safeAyah;
        _surahTo = endResult.surahNum;
        _ayahTo = endResult.ayahNum;
        _targetPages = target;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _ayahFromCtrl.text = safeAyah.toString();
            _ayahToCtrl.text = endResult.ayahNum.toString();
            _recalcLines();
          }
        });
      }
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            bottom: true,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                  child: Row(
                    children: [
                      Icon(Icons.menu_book_rounded,
                          color: theme.colorScheme.primary, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Log Sabaq',
                                style: theme.textTheme.titleLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              widget.student.fullName,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
                            _updateDateAndSuggestion(picked.toIso8601String().substring(0, 10));
                          }
                        },
                        icon: Icon(Icons.calendar_today_rounded,
                            size: 14, color: theme.colorScheme.primary),
                        label: Text(_date,
                            style: theme.textTheme.bodyMedium),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildSabaqForm(),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Submit Sabaq'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  SabaqLog? _getExistingLog() {
    final provider = context.read<AppProvider>();
    final logs = provider.getLogsForStudent(widget.studentId);
    try {
      return logs.firstWhere((l) => l.date == _date && l.sabaq.isNotEmpty);
    } catch (_) {
      return null;
    }
  }

  Widget _buildExistingLogCard(SabaqLog log) {
    final theme = Theme.of(context);
    final isAbsent = log.status == 'absent' || log.status == 'sick' || log.status == 'other';
    final bgColor = isAbsent ? AppColors.danger.withValues(alpha: 0.06) : AppColors.primary.withValues(alpha: 0.06);
    final borderColor = isAbsent ? AppColors.danger.withValues(alpha: 0.25) : AppColors.primary.withValues(alpha: 0.25);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              log.cleanSabaqText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isAbsent ? AppColors.danger : theme.textTheme.bodyLarge?.color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _deleteExistingSabaq(log),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExistingSabaq(SabaqLog log) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear Sabaq?'),
        content: const Text('This will clear the Sabaq log entry for today. Other logged fields (like Sabaq Para/Muraja) on this date will be preserved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Clear', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final provider = context.read<AppProvider>();
      final result = await provider.mergeLog(studentId: log.studentId, date: log.date, sabaq: '');
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sabaq cleared successfully')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear: $result'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSabaqForm() {
    final teachers = context.read<AppProvider>().institutionPeople['teachers'] ?? [];
    final existingLog = _getExistingLog();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      children: [
        if (existingLog != null) _buildExistingLogCard(existingLog),
        _buildSkipToggle(
          label: "Skip today's Sabaq",
          value: _isSabaqSkipped,
          onChanged: (v) => setState(() {
            _isSabaqSkipped = v;
            if (!v) _recalcLines();
          }),
        ),

        if (_isSabaqSkipped) ...[
          const SizedBox(height: 12),
          _buildSectionLabel('Reason for skipping'),
          const SizedBox(height: 6),
          _buildDropdown<String>(
            value: _skipReason,
            items: const ['Khatam Juz', 'Sick', 'Absent', 'Other'],
            labelBuilder: (v) => v == 'Khatam Juz' ? 'Khatam Juz (Completed Juz)' : v,
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _skipReason = v;
                if (v == 'Khatam Juz') _preserveStreakSabaq = true;
              });
            },
          ),
          if (_skipReason == 'Sick') ...[
            const SizedBox(height: 12),
            _buildSectionLabel('Specify Sickness / Illness'),
            const SizedBox(height: 6),
            _buildTextField(hint: 'e.g. Fever, Flu', onChanged: (v) => _skipSickDetail = v),
          ],
          if (_skipReason == 'Other') ...[
            const SizedBox(height: 12),
            _buildSectionLabel('Specify Reason'),
            const SizedBox(height: 6),
            _buildTextField(hint: 'Enter reason', onChanged: (v) => _skipOtherDetail = v),
          ],
          const SizedBox(height: 12),
          _buildPreserveStreakToggle(
            value: _preserveStreakSabaq,
            disabled: _skipReason == 'Khatam Juz',
            onChanged: (v) => setState(() => _preserveStreakSabaq = v),
          ),
        ] else ...[
          const SizedBox(height: 16),
          _buildSectionLabel('Select Surah'),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Expanded(
                flex: 3,
                child: _buildSurahDropdown(
                  value: _surahFrom,
                  onChanged: (v) {
                    if (v == null) return;
                    _updateAyahFromAndRecalc(v, 1);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _buildNumberField(
                  controller: _ayahFromCtrl,
                  min: 1,
                  max: quranSurahs[_surahFrom - 1].ayahCount,
                  onChanged: (v) {
                    _updateAyahFromAndRecalc(_surahFrom, v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSectionLabel('End Surah'),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildSurahDropdown(
                  value: _surahTo,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() { _isDirty = true; _surahTo = v; _ayahTo = 1; _targetPages = null; });
                    _recalcLines();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _buildNumberField(
                  controller: _ayahToCtrl,
                  min: 1,
                  max: quranSurahs[_surahTo - 1].ayahCount,
                  onChanged: (v) {
                    setState(() { _isDirty = true; _ayahTo = v; _targetPages = null; });
                    _recalcLines();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          _buildSectionLabel('Target Pages (Auto-Calculates End Ayah)'),
          const SizedBox(height: 8),
          _buildTargetPagePills(),

          if (_estimatedLines > 0) ...[
            const SizedBox(height: 12),
            _buildRangeSummary(),
          ],
        ],

        const SizedBox(height: 16),
        _buildSectionLabel(_isSabaqSkipped ? 'Exemption Approved By (Teacher)' : 'Heard By (Teacher Only)'),
        const SizedBox(height: 6),
        _buildDropdown<String>(
          value: _heardBy,
          hint: 'Select Teacher',
          items: teachers.map<String>((t) => t['full_name'] as String).toList(),
          labelBuilder: (v) => v,
          onChanged: (v) => setState(() => _heardBy = v),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Target page pills ──

  Widget _buildTargetPagePills() {
    const options = <String, double?>{
      'Custom': null, '1P': 1, '2P': 2, '3P': 3, '5P': 5, '10P': 10, '20P': 20,
    };

    return Wrap(
      spacing: 8, runSpacing: 8,
      children: options.entries.map((entry) {
        final isActive = entry.value == _targetPages;
        return GestureDetector(
          onTap: () => _applyTargetPages(entry.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              entry.key,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : AppColors.primary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Range summary card ──

  Widget _buildRangeSummary() {
    final startSurahName = quranSurahs[_surahFrom - 1].name;
    final endSurahName = quranSurahs[_surahTo - 1].name;
    final startP = _getPageForAyah(_surahFrom, _ayahFrom);
    final endP = _getPageForAyah(_surahTo, _ayahTo);
    final pageRange = startP == endP ? 'Pg $startP' : 'Pg $startP–$endP';
    final rangeText = _surahFrom == _surahTo
        ? '$startSurahName ($_ayahFrom–$_ayahTo) [$pageRange]'
        : '$startSurahName ($_ayahFrom) → $endSurahName ($_ayahTo) [$pageRange]';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Range: $rangeText', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          _buildStatChip('Total Lines', '$_estimatedLines', AppColors.primary),
          const SizedBox(width: 12),
          _buildStatChip('Total Pages', _estimatedPages.toStringAsFixed(2), AppColors.success),
        ]),
      ]),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ', style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8))),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  // ── Shared UI helpers ──

  Widget _buildSkipToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          SizedBox(
            width: 20, height: 20,
            child: Checkbox(
              value: value,
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (v) => onChanged(v ?? false),
            ),
          ),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ]),
      ),
    );
  }

  Widget _buildPreserveStreakToggle({
    required bool value,
    required bool disabled,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: disabled ? null : () => onChanged(!value),
      child: Row(children: [
        SizedBox(
          width: 20, height: 20,
          child: Checkbox(
            value: value,
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: disabled ? null : (v) => onChanged(v ?? false),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Preserve Streak',
          style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500,
            color: disabled ? theme.textTheme.bodySmall?.color : null,
          ),
        ),
      ]),
    );
  }

  InputDecoration _themedInput({String? hint}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    final muted = Theme.of(context).textTheme.bodyMedium?.color;
    return Text(text,
        style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: muted ?? Colors.grey, letterSpacing: 0.3,
        ));
  }

  Widget _buildTextField({required String hint, required ValueChanged<String> onChanged}) {
    return TextField(
      decoration: _themedInput(hint: hint),
      onChanged: onChanged,
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    String? hint,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: _themedInput(hint: hint),
      isExpanded: true,
      items: items.map((item) => DropdownMenuItem<T>(
            value: item,
            child: Text(labelBuilder(item), overflow: TextOverflow.ellipsis),
          )).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSurahDropdown({required int value, required ValueChanged<int?> onChanged}) {
    return DropdownButtonFormField<int>(
      value: value,
      isExpanded: true,
      decoration: _themedInput(),
      items: quranSurahs.map((s) => DropdownMenuItem<int>(
            value: s.number,
            child: Text('${s.number}. ${s.name} (${s.ayahCount})',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          )).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: _themedInput(),
      onChanged: (v) {
        final parsed = int.tryParse(v);
        if (parsed != null) onChanged(parsed.clamp(min, max));
      },
    );
  }
}
