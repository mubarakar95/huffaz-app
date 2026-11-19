import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../models/student.dart';
import '../../models/sabaq_log.dart';
import '../../utils/quran_data.dart';
import '../../utils/student_utils.dart';

class LogLessonBottomSheet extends StatefulWidget {
  final String studentId;
  final Student student;
  final int initialTab;

  const LogLessonBottomSheet({
    Key? key,
    required this.studentId,
    required this.student,
    this.initialTab = 0,
  }) : super(key: key);

  @override
  _LogLessonBottomSheetState createState() => _LogLessonBottomSheetState();
}

class _LogLessonBottomSheetState extends State<LogLessonBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String _date = getLocalToday();

  // ── Ayah field controllers (needed so they visually update when suggestion is applied)
  final TextEditingController _ayahFromCtrl = TextEditingController(text: '1');
  final TextEditingController _ayahToCtrl   = TextEditingController(text: '1');

  // ── Sabaq state
  int _surahFrom = 1;
  int _ayahFrom = 1;
  int _surahTo = 1;
  int _ayahTo = 1;
  double? _targetPages; // null = custom
  int _estimatedLines = 0;
  double _estimatedPages = 0;
  String? _heardBy;

  bool _isSabaqSkipped = false;
  String _skipReason = 'Khatam Juz';
  String _skipSickDetail = '';
  String _skipOtherDetail = '';
  bool _preserveStreakSabaq = true;

  // ── Sabqi state
  final Map<int, String> _sabqiAssignments = {};
  String? _batchHeardBy;
  bool _isSabqiSkipped = false;
  List<Map<String, dynamic>> _availableSabqiPages = [];

  // ── Manzil state
  final Map<int, String> _manzilAssignments = {};
  String? _manzilBatchHeardBy;
  int? _activeJuzFilter;
  bool _isManzilSkipped = false;
  List<Map<String, dynamic>> _availableManzilPages = [];

  // ── Status tab
  String _status = 'good';
  bool _preserveStreakStatus = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      final sabqi = provider.getSabqiPagesForStudent(widget.studentId);
      final manzil = provider.getManzilPagesForStudent(widget.studentId);
      final logs = provider.getLogsForStudent(widget.studentId);
      final milestone = provider.getJuzMilestoneForStudent(widget.studentId);
      final activeJuzId = milestone?['id'] as int?;

      final teachers = provider.institutionPeople['teachers'] ?? [];
      String? defaultTeacher;
      if (teachers.isNotEmpty) {
        defaultTeacher = teachers.first['full_name'];
      }

      // Compute suggested next sabaq position from the latest log
      final suggestion = _computeSuggestedSabaq(logs, activeJuzId, _date);
      final safeAyah = suggestion.ayahNum
          .clamp(1, quranSurahs[suggestion.surahNum - 1].ayahCount);
      final endResult =
          calculateEndAyahByPages(suggestion.surahNum, safeAyah, 1.0);

      final startPage = getPageForAyah(suggestion.surahNum, safeAyah);
      final isStartOfPage = safeAyah == 1 || getPageForAyah(suggestion.surahNum, safeAyah - 1) != startPage;
      final target = isStartOfPage ? 1.0 : null;

      setState(() {
        _availableSabqiPages = List<Map<String, dynamic>>.from(sabqi);
        _availableManzilPages = List<Map<String, dynamic>>.from(manzil);
        _heardBy = defaultTeacher;
        _batchHeardBy = defaultTeacher;
        _manzilBatchHeardBy = defaultTeacher;
        // Pre-fill sabaq with the suggested next position
        _surahFrom = suggestion.surahNum;
        _ayahFrom = safeAyah;
        _surahTo = endResult.surahNum;
        _ayahTo = endResult.ayahNum;
        _targetPages = target;
      });
      // Update controllers so the text fields visually reflect the suggestion
      _ayahFromCtrl.text = safeAyah.toString();
      _ayahToCtrl.text   = endResult.ayahNum.toString();
      _recalcLines();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ayahFromCtrl.dispose();
    _ayahToCtrl.dispose();
    super.dispose();
  }

  // ── Sabaq helpers

  int _getPageForAyah(int surahNum, int ayahNum) => getPageForAyah(surahNum, ayahNum);

  void _recalcLines() {
    // When a target pill is active, use it directly — it's exact.
    // Only fall back to the page-range approximation for custom ayah input.
    if (_targetPages != null && _targetPages! > 0) {
      final lines = (_targetPages! * 15).round().clamp(0, 9060);
      setState(() {
        _estimatedLines = lines;
        _estimatedPages = _targetPages!;
      });
      return;
    }
    final pageSpan = calculatePageSpanFromAyahs(_surahFrom, _ayahFrom, _surahTo, _ayahTo);
    final lines = (pageSpan * 15.0).round().clamp(0, 9060);

    setState(() {
      _estimatedLines = lines;
      _estimatedPages = pageSpan;
    });
  }

  void _applyTargetPages(double? pages) {
    setState(() => _targetPages = pages);
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



  /// Mirrors the web app's suggestedSabaq useMemo:
  /// finds the most recent non-skipped sabaq log, parses the ending Surah/Ayah,
  /// and returns the *next* Surah/Ayah to log.
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
    // 1. Collect logs that have a valid [Page N] tag and are not baselines
    final logsWithPages = <({SabaqLog log, int pageNum})>[];
    for (final l in logs) {
      if (l.date.compareTo(targetDate) >= 0) continue;
      if (l.sabaq.isEmpty) continue;
      if (l.sabaq.startsWith('[SKIPPED')) continue;
      final pages = getPagesFromSabaqString(l.sabaq);
      if (pages.isEmpty) continue;
      final pageNum = pages.last;
      logsWithPages.add((log: l, pageNum: pageNum));
    }

    debugPrint('[SuggestedSabaq] Total logs=${logs.length}, valid=${logsWithPages.length}');
    for (final l in logs.take(8)) {
      final preview = l.sabaq.length > 70 ? l.sabaq.substring(0, 70) : l.sabaq;
      debugPrint('[SuggestedSabaq] ${l.date} | status=${l.status} | "$preview"');
    }

    if (logsWithPages.isEmpty) return (surahNum: 1, ayahNum: 1);

    // 2. Sort: newest date first, then baseline_sabqi prioritized over baseline, then highest page
    logsWithPages.sort((a, b) {
      final dateCmp = b.log.date.compareTo(a.log.date);
      if (dateCmp != 0) return dateCmp;
      
      // Prioritize baseline_sabqi over baseline for same-date sorting
      if (a.log.status == 'baseline_sabqi' && b.log.status != 'baseline_sabqi') return -1;
      if (b.log.status == 'baseline_sabqi' && a.log.status != 'baseline_sabqi') return 1;
      
      return b.pageNum.compareTo(a.pageNum);
    });
    final latest = logsWithPages.first;
    debugPrint('[SuggestedSabaq] PICKED: ${latest.log.date} status=${latest.log.status} page=${latest.pageNum} "${latest.log.sabaq}"');

    // 3. Juz transition: if the latest log's Juz != activeJuzId, the student
    //    just completed a Juz — jump to the start page of the new active Juz.
    if (activeJuzId != null && activeJuzId >= 1 && activeJuzId <= 30) {
      final latestJuz = getJuzForPage(latest.pageNum);
      if (latestJuz != activeJuzId) {
        // Find the first page that belongs to activeJuzId
        for (int pg = 1; pg <= 604; pg++) {
          if (getJuzForPage(pg) == activeJuzId) {
            // Find the surah that starts at or before that page
            for (int i = quranSurahs.length - 1; i >= 0; i--) {
              if (quranSurahs[i].startPage <= pg) {
                return (surahNum: quranSurahs[i].number, ayahNum: 1);
              }
            }
            break;
          }
        }
      }
    }

    // 4. Parse surah+ayah from the LAST pipe-separated segment (handles merged logs)
    final segments = latest.log.sabaq.split(' | ');
    final lastSegment = segments.last;

    // Fuzzy surah finder: handles spelling variants like "Al-Baqara" vs "Al-Baqarah"
    QuranSurah? findSurah(String name) {
      final lower = name.trim().toLowerCase();
      // Tier 1: exact match
      for (final s in quranSurahs) {
        if (s.name.toLowerCase() == lower) return s;
      }
      // Tier 2: one is a prefix of the other (covers trailing 'h'/'ah' differences)
      for (final s in quranSurahs) {
        final c = s.name.toLowerCase();
        if (c.startsWith(lower) || lower.startsWith(c)) return s;
      }
      // Tier 3: strip apostrophes, hyphens, spaces and compare
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

    // Format A: "Surah Al-Baqara (Ayah 84-88) [Page 13]"
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

    // Format B: "Al-Baqara (1) to Ali 'Imran (10) [Page 55]"  (cross-surah)
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

    // 5. Fallback: start of the next page
    final nextPage = (latest.pageNum + 1).clamp(1, 604);
    for (int i = quranSurahs.length - 1; i >= 0; i--) {
      if (quranSurahs[i].startPage <= nextPage) {
        return (surahNum: quranSurahs[i].number, ayahNum: 1);
      }
    }

    return (surahNum: 1, ayahNum: 1);
  }

  // ── Submit

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

      final Map<String, dynamic> manzilData = {
        'sabqi': _sabqiAssignments.entries.map((e) => {
          'sabaq': 'Page ${e.key} - HeardBy ${e.value}',
          'heardBy': e.value,
        }).toList(),
        'manzilPages': _manzilAssignments.entries.map((e) => {
          'page': e.key,
          'juz': 1,
          'surahName': 'Unknown',
          'heardBy': e.value,
        }).toList(),
      };

      final result = await provider.submitLog(
        studentId: widget.studentId,
        date: _date,
        sabaq: sabaqString,
        manzil: jsonEncode(manzilData),
        status: _status,
      );

      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log submitted successfully')),
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

  // ── Build

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C2E) : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
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
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Log Today\'s Lesson',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                            setState(() {
                              _date = picked.toIso8601String().substring(0, 10);
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                        label: Text(_date,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  tabs: const [
                    Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'Sabaq'),
                    Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'Sabqi'),
                    Tab(icon: Icon(Icons.history_edu_rounded, size: 18), text: 'Manzil'),
                    Tab(icon: Icon(Icons.person_off_rounded, size: 18), text: 'Status'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSabaqTab(),
                      _buildSabqiTab(),
                      _buildManzilTab(),
                      _buildStatusTab(),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Submit Log',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  // ══════════════════════════════════════════════════════════
  // SABAQ TAB
  // ══════════════════════════════════════════════════════════

  Widget _buildSabaqTab() {
    final teachers = context.read<AppProvider>().institutionPeople['teachers'] ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      children: [
        // Skip toggle
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
          // Surah From
          const SizedBox(height: 16),
          _buildSectionLabel('Select Surah'),
          const SizedBox(height: 6),
          _buildSurahDropdown(
            value: _surahFrom,
            onChanged: (v) {
              if (v == null) return;
              setState(() { _surahFrom = v; _ayahFrom = 1; _surahTo = v; _ayahTo = 1; _targetPages = null; });
              _ayahFromCtrl.text = '1';
              _ayahToCtrl.text   = '1';
              _recalcLines();
            },
          ),

          // Ayah From | End Surah | Ayah To
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildSectionLabel('Ayah From'),
                  const SizedBox(height: 6),
                  _buildNumberField(
                    controller: _ayahFromCtrl,
                    min: 1,
                    max: quranSurahs[_surahFrom - 1].ayahCount,
                    onChanged: (v) { setState(() { _ayahFrom = v; _targetPages = null; }); _recalcLines(); },
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildSectionLabel('End Surah'),
                  const SizedBox(height: 6),
                  _buildSurahDropdown(
                    value: _surahTo,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() { _surahTo = v; _ayahTo = 1; _targetPages = null; });
                      _recalcLines();
                    },
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildSectionLabel('Ayah To'),
                  const SizedBox(height: 6),
                  _buildNumberField(
                    controller: _ayahToCtrl,
                    min: 1,
                    max: quranSurahs[_surahTo - 1].ayahCount,
                    onChanged: (v) { setState(() { _ayahTo = v; _targetPages = null; }); _recalcLines(); },
                  ),
                ]),
              ),
            ],
          ),

          // Target Pages pills
          const SizedBox(height: 16),
          _buildSectionLabel('Target Pages (Auto-Calculates End Ayah)'),
          const SizedBox(height: 8),
          _buildTargetPagePills(),

          // Range summary
          if (_estimatedLines > 0) ...[
            const SizedBox(height: 12),
            _buildRangeSummary(),
          ],
        ],

        // Heard By (always shown)
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

  // ── Target page pills

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

  // ── Range summary card

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

  // ══════════════════════════════════════════════════════════
  // SABQI TAB
  // ══════════════════════════════════════════════════════════

  Widget _buildSabqiTab() {
    return Column(children: [
      _buildSkipToggle(
        label: "Skip today's Sabaq Para",
        value: _isSabqiSkipped,
        onChanged: (v) => setState(() => _isSabqiSkipped = v),
      ),
      if (!_isSabqiSkipped)
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16.0), children: [
            _buildDropdown<String>(
              value: _batchHeardBy,
              hint: 'Select Teacher',
              items: (context.read<AppProvider>().institutionPeople['teachers'] ?? [])
                  .map<String>((t) => t['full_name'] as String).toList(),
              labelBuilder: (v) => v,
              onChanged: (val) => setState(() {
                _batchHeardBy = val;
                _sabqiAssignments.updateAll((key, value) => val!);
              }),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              ActionChip(
                label: const Text('All'),
                onPressed: () => setState(() {
                  for (var p in _availableSabqiPages) {
                    _sabqiAssignments[p['page']] = _batchHeardBy ?? '';
                  }
                }),
              ),
              ActionChip(
                label: const Text('Clear All'),
                onPressed: () => setState(() => _sabqiAssignments.clear()),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _availableSabqiPages.map((page) {
                final int pg = page['page'];
                final bool isSelected = _sabqiAssignments.containsKey(pg);
                return ChoiceChip(
                  label: Text('Pg $pg\n${page['surahName']}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black)),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  onSelected: (selected) => setState(() {
                    if (selected) { _sabqiAssignments[pg] = _batchHeardBy ?? ''; }
                    else { _sabqiAssignments.remove(pg); }
                  }),
                );
              }).toList(),
            ),
          ]),
        ),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  // MANZIL TAB
  // ══════════════════════════════════════════════════════════

  Widget _buildManzilTab() {
    return Column(children: [
      _buildSkipToggle(
        label: "Skip today's Manzil",
        value: _isManzilSkipped,
        onChanged: (v) => setState(() => _isManzilSkipped = v),
      ),
      if (!_isManzilSkipped)
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16.0), children: [
            _buildDropdown<String>(
              value: _manzilBatchHeardBy,
              hint: 'Select Teacher',
              items: (context.read<AppProvider>().institutionPeople['teachers'] ?? [])
                  .map<String>((t) => t['full_name'] as String).toList(),
              labelBuilder: (v) => v,
              onChanged: (val) => setState(() {
                _manzilBatchHeardBy = val;
                _manzilAssignments.updateAll((key, value) => val!);
              }),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(30, (i) => i + 1).map((juz) {
                  final hasPages = _availableManzilPages.any((p) => p['juz'] == juz);
                  if (!hasPages) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text('Juz $juz'),
                      selected: _activeJuzFilter == juz,
                      onSelected: (selected) =>
                          setState(() => _activeJuzFilter = selected ? juz : null),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _availableManzilPages
                  .where((p) => _activeJuzFilter == null || p['juz'] == _activeJuzFilter)
                  .map((page) {
                final int pg = page['page'];
                final bool isSelected = _manzilAssignments.containsKey(pg);
                return ChoiceChip(
                  label: Text('Pg $pg\n${page['surahName']}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black)),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  onSelected: (selected) => setState(() {
                    if (selected) { _manzilAssignments[pg] = _manzilBatchHeardBy ?? ''; }
                    else { _manzilAssignments.remove(pg); }
                  }),
                );
              }).toList(),
            ),
          ]),
        ),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  // STATUS TAB
  // ══════════════════════════════════════════════════════════

  Widget _buildStatusTab() {
    return ListView(padding: const EdgeInsets.all(16.0), children: [
      const Text("Today's Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 16),
      ...['good', 'absent', 'sick', 'holiday', 'other'].map((s) => RadioListTile<String>(
            title: Text(s.toUpperCase()),
            value: s,
            groupValue: _status,
            onChanged: (val) => setState(() => _status = val!),
          )),
      if (_status == 'sick' || _status == 'other')
        CheckboxListTile(
          title: const Text('Preserve streak'),
          value: _preserveStreakStatus,
          onChanged: (val) => setState(() => _preserveStreakStatus = val ?? false),
        ),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  // SHARED UI HELPERS
  // ══════════════════════════════════════════════════════════

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
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _buildPreserveStreakToggle({
    required bool value,
    required bool disabled,
    required ValueChanged<bool> onChanged,
  }) {
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
            color: disabled ? Colors.grey : null,
          ),
        ),
      ]),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: Colors.grey, letterSpacing: 0.3,
        ));
  }

  Widget _buildTextField({required String hint, required ValueChanged<String> onChanged}) {
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
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
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
      hint: hint != null ? Text(hint, style: const TextStyle(color: Colors.grey)) : null,
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
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
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
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
      onChanged: (v) {
        final parsed = int.tryParse(v);
        if (parsed != null) onChanged(parsed.clamp(min, max));
      },
    );
  }
}
