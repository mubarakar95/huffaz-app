import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/app_provider.dart';
import '../models/student.dart';
import '../models/sabaq_log.dart';
import '../utils/student_utils.dart';
import '../utils/quran_data.dart';

class _PersonItem {
  final String name;
  final String group;
  _PersonItem({required this.name, required this.group});
}

class SabqiBottomSheet extends StatefulWidget {
  final String studentId;
  final Student student;
  final String? initialDate;

  const SabqiBottomSheet({
    Key? key,
    required this.studentId,
    required this.student,
    this.initialDate,
  }) : super(key: key);

  @override
  _SabqiBottomSheetState createState() => _SabqiBottomSheetState();
}

class _SabqiBottomSheetState extends State<SabqiBottomSheet> {
  bool _isLoading = false;
  late String _date = widget.initialDate ?? getLocalToday();

  bool _isSabqiSkipped = false;
  String _skipReason = 'Khatam Juz';
  String _skipSickDetail = '';
  String _skipOtherDetail = '';
  bool _preserveStreak = true;

  final Map<int, String> _assignments = {};
  final Set<int> _selectedPages = {};
  String? _batchHeardBy;
  List<Map<String, dynamic>> _pages = [];
  int? _activeJuzId;

  List<Map<String, dynamic>> get _availablePages {
    final existingLog = _getExistingLog();
    if (existingLog == null) {
      return _pages;
    }
    final sabaqPages = existingLog.sabaq.isNotEmpty
        ? getPagesFromSabaqString(existingLog.sabaq)
        : <int>[];

    final existingSabqi = (existingLog.parsedManzil?['sabqi'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        <Map<String, dynamic>>[];

    final sabqiPages = <int>[];
    for (final item in existingSabqi) {
      final text = item['sabaq'] as String? ?? '';
      if (text.startsWith('[SKIPPED')) continue;
      final m = RegExp(r'Page (\d+)').firstMatch(text);
      if (m != null) {
        final p = int.tryParse(m.group(1) ?? '');
        if (p != null) sabqiPages.add(p);
      }
    }

    return _pages.where((p) {
      final pageNum = p['page'] as int;
      return !sabaqPages.contains(pageNum) && !sabqiPages.contains(pageNum);
    }).toList();
  }

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
    final pages = provider.getSabqiPagesForStudent(widget.studentId);
    final teachers = provider.institutionPeople['teachers'] ?? [];
    final profileName = provider.profile?.fullName;
    final teacherNames = teachers.map<String>((t) => t['full_name'] as String).toList();

    String? defaultTeacher;
    if (profileName != null && teacherNames.contains(profileName)) {
      defaultTeacher = profileName;
    } else if (teachers.isNotEmpty) {
      defaultTeacher = teachers.first['full_name'];
    }

    final existingLog = _getExistingLog();
    final sabaqPages = (existingLog != null && existingLog.sabaq.isNotEmpty)
        ? getPagesFromSabaqString(existingLog.sabaq)
        : <int>[];

    final existingSabqi = existingLog != null
        ? (existingLog.parsedManzil?['sabqi'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[];

    final sabqiPages = <int>[];
    for (final item in existingSabqi) {
      final text = item['sabaq'] as String? ?? '';
      if (text.startsWith('[SKIPPED')) continue;
      final m = RegExp(r'Page (\d+)').firstMatch(text);
      if (m != null) {
        final p = int.tryParse(m.group(1) ?? '');
        if (p != null) sabqiPages.add(p);
      }
    }

    int? activeJuz;
    if (pages.isNotEmpty) {
      activeJuz = pages.first['juz'] as int?;
    }

    final milestone = provider.getJuzMilestoneForStudent(widget.studentId);
    final activeJuzFromMilestone = milestone?['id'] as int?;
    final targetJuz = activeJuzFromMilestone ?? activeJuz;

    final selected = <int>{};
    for (final p in pages) {
      final pageNum = p['page'] as int;
      final juz = p['juz'] as int?;
      if (!sabaqPages.contains(pageNum) && !sabqiPages.contains(pageNum)) {
        if (juz == targetJuz) {
          selected.add(pageNum);
        }
      }
    }

    if (mounted) {
      setState(() {
        _pages = pages;
        _batchHeardBy = _batchHeardBy ?? defaultTeacher;
        _activeJuzId = _activeJuzId ?? targetJuz;
        if (_selectedPages.isEmpty) {
          _selectedPages.addAll(selected);
        }
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

  void _handleHeardByChange(String newHeardBy) {
    setState(() => _batchHeardBy = newHeardBy);
  }

  void _togglePage(int pageNum) {
    setState(() {
      if (_selectedPages.contains(pageNum)) {
        _selectedPages.remove(pageNum);
      } else {
        _selectedPages.add(pageNum);
      }
    });
  }

  void _addAllToSelection() {
    setState(() {
      for (final p in _availablePages) {
        _selectedPages.add(p['page'] as int);
      }
    });
  }

  void _addFirstHalfToSelection() {
    final available = _availablePages;
    final mid = (available.length / 2).ceil();
    setState(() {
      for (int i = 0; i < mid && i < available.length; i++) {
        _selectedPages.add(available[i]['page'] as int);
      }
    });
  }

  void _addLastHalfToSelection() {
    final available = _availablePages;
    final mid = (available.length / 2).ceil();
    setState(() {
      for (int i = mid; i < available.length; i++) {
        _selectedPages.add(available[i]['page'] as int);
      }
    });
  }

  void _addActiveJuzToSelection() {
    if (_activeJuzId == null) return;
    setState(() {
      for (final p in _availablePages) {
        if (p['juz'] == _activeJuzId) {
          _selectedPages.add(p['page'] as int);
        }
      }
    });
  }

  void _assignSelected() {
    setState(() {
      for (final pageNum in _selectedPages) {
        _assignments[pageNum] = _batchHeardBy ?? '';
      }
      _selectedPages.clear();
    });
  }

  void _clearAll() {
    setState(() {
      _assignments.clear();
      _selectedPages.clear();
    });
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<AppProvider>();

      List<Map<String, dynamic>> sabqiItems;

      if (_isSabqiSkipped) {
        String reasonText = _skipReason;
        if (_skipReason == 'Sick' && _skipSickDetail.isNotEmpty) {
          reasonText = 'Sick - $_skipSickDetail';
        } else if (_skipReason == 'Other' && _skipOtherDetail.isNotEmpty) {
          reasonText = _skipOtherDetail;
        }
        final preserveStr = (_preserveStreak || _skipReason == 'Khatam Juz') ? ' [PRESERVE_STREAK]' : '';
        sabqiItems = [
          {'sabaq': '[SKIPPED: $reasonText]$preserveStr', 'heardBy': _batchHeardBy ?? ''}
        ];
      } else {
        final pageInfo = {for (final p in _availablePages) p['page'] as int: p['surahName'] as String? ?? ''};
        sabqiItems = _assignments.entries.map((entry) {
          final pageNum = entry.key;
          return {
            'sabaq': 'Page $pageNum (${pageInfo[pageNum] ?? ''})',
            'heardBy': entry.value,
          };
        }).toList();
      }

      final existingLog = _getExistingLog();
      final existingManzil = existingLog?.parsedManzil ?? <String, dynamic>{};
      final existingManzilPages = (existingManzil['manzilPages'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];

      List<Map<String, dynamic>> finalSabqiItems;
      if (_isSabqiSkipped) {
        finalSabqiItems = sabqiItems;
      } else {
        final merged = <int, Map<String, dynamic>>{};
        final existingSabqi = (existingManzil['sabqi'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? <Map<String, dynamic>>[];
        for (final item in existingSabqi) {
          final text = item['sabaq'] as String? ?? '';
          if (text.startsWith('[SKIPPED')) continue;
          final m = RegExp(r'Page (\d+)').firstMatch(text);
          if (m != null) {
            final p = int.tryParse(m.group(1) ?? '');
            if (p != null) {
              merged[p] = item;
            }
          }
        }
        for (final item in sabqiItems) {
          final text = item['sabaq'] as String? ?? '';
          if (text.startsWith('[SKIPPED')) continue;
          final m = RegExp(r'Page (\d+)').firstMatch(text);
          if (m != null) {
            final p = int.tryParse(m.group(1) ?? '');
            if (p != null) {
              merged[p] = item;
            }
          }
        }
        finalSabqiItems = merged.values.toList();
      }

      final result = await provider.mergeLog(
        studentId: widget.studentId,
        date: _date,
        manzil: {
          'sabqi': finalSabqiItems,
          'manzilPages': existingManzilPages,
        },
      );

      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sabqi logged successfully')),
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
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.15) : AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Log Sabaq Para',
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
                            final newDate = picked.toIso8601String().substring(0, 10);
                            _onDateChanged(newDate);
                          }
                        },
                        icon: Icon(Icons.calendar_today_rounded, size: 14, color: theme.colorScheme.primary),
                        label: Text(_date, style: theme.textTheme.bodyMedium),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildForm()),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isLoading || (!_isSabqiSkipped && (_assignments.isEmpty || _selectedPages.isNotEmpty))) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Submit Sabaq Para',
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

  void _onDateChanged(String newDate) {
    final provider = context.read<AppProvider>();
    final pages = provider.getSabqiPagesForStudent(widget.studentId, beforeDate: newDate);
    
    final existingLog = _getExistingLogForDate(newDate);
    final sabaqPages = (existingLog != null && existingLog.sabaq.isNotEmpty)
        ? getPagesFromSabaqString(existingLog.sabaq)
        : <int>[];

    final existingSabqi = existingLog != null
        ? (existingLog.parsedManzil?['sabqi'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[];

    final sabqiPages = <int>[];
    for (final item in existingSabqi) {
      final text = item['sabaq'] as String? ?? '';
      if (text.startsWith('[SKIPPED')) continue;
      final m = RegExp(r'Page (\d+)').firstMatch(text);
      if (m != null) {
        final p = int.tryParse(m.group(1) ?? '');
        if (p != null) sabqiPages.add(p);
      }
    }

    int? activeJuz;
    if (pages.isNotEmpty) {
      activeJuz = pages.first['juz'] as int?;
    }

    final selected = <int>{};
    for (final p in pages) {
      final pageNum = p['page'] as int;
      final juz = p['juz'] as int?;
      if (!sabaqPages.contains(pageNum) && !sabqiPages.contains(pageNum)) {
        if (juz == activeJuz) {
          selected.add(pageNum);
        }
      }
    }

    setState(() {
      _date = newDate;
      _pages = pages;
      _assignments.clear();
      _selectedPages.clear();
      _selectedPages.addAll(selected);
      _activeJuzId = activeJuz;
    });
  }

  SabaqLog? _getExistingLog() {
    return _getExistingLogForDate(_date);
  }

  SabaqLog? _getExistingLogForDate(String date) {
    final provider = context.read<AppProvider>();
    final logs = provider.getLogsForStudent(widget.studentId);
    try {
      return logs.firstWhere((l) => l.date == date);
    } catch (_) {
      return null;
    }
  }

  Widget _buildExistingSabqiCard(SabaqLog log) {
    final theme = Theme.of(context);
    final sabqiItems = log.parsedManzil?['sabqi'] as List? ?? [];
    final skipped = sabqiItems.any((item) =>
      item is Map && (item['sabaq']?.toString().contains('[SKIPPED]') ?? false));
    final nonSkipped = sabqiItems.where((item) =>
      item is Map && !(item['sabaq']?.toString().contains('[SKIPPED]') ?? false)).toList();

    if (!skipped && nonSkipped.isEmpty) return const SizedBox.shrink();

    String summary;
    if (skipped) {
      summary = log.cleanSabaqText;
    } else {
      final pages = <int>[];
      for (final item in nonSkipped) {
        final text = item is Map ? (item['sabaq'] as String? ?? '') : '';
        final m = RegExp(r'Page (\d+)').firstMatch(text);
        if (m != null) {
          final p = int.tryParse(m.group(1) ?? '');
          if (p != null) pages.add(p);
        }
      }
      if (pages.isNotEmpty) {
        pages.sort();
        summary = '${pages.length}Pgs (Pg ${pages.first}-${pages.last})';
      } else {
        summary = '${nonSkipped.length}Pgs';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              summary,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _deleteExistingSabqi(log),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExistingSabqi(SabaqLog log) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear Sabaq Para?'),
        content: const Text('This will clear the Sabaq Para log entry for today. Other logged fields (like Sabaq/Muraja) on this date will be preserved.'),
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
      final existingManzil = log.parsedManzil ?? {};
      final modified = Map<String, dynamic>.from(existingManzil);
      modified['sabqi'] = <Map<String, dynamic>>[];
      
      final result = await provider.mergeLog(studentId: log.studentId, date: log.date, manzil: modified);
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sabaq Para cleared successfully')),
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

  Widget _buildForm() {
    final existingLog = _getExistingLog();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      children: [
        if (existingLog != null) _buildExistingSabqiCard(existingLog),
        _buildSkipToggle(
          label: "Skip today's Sabaq Para",
          value: _isSabqiSkipped,
          onChanged: (v) => setState(() => _isSabqiSkipped = v),
        ),

        if (_isSabqiSkipped) ...[
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
                if (v == 'Khatam Juz') _preserveStreak = true;
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
            value: _preserveStreak,
            disabled: _skipReason == 'Khatam Juz',
            onChanged: (v) => setState(() => _preserveStreak = v),
          ),
        ] else ...[
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSectionLabel('Active Sabaq Para Pages (Last ${_availablePages.length} Pages)'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Select pages, choose who heard it, then tap Assign. Repeat for different people.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 16),
        ],

        const SizedBox(height: 8),
        _buildSectionLabel(
          _isSabqiSkipped ? 'Exemption Approved By (Heard By):' : 'Assigning To (Heard By):',
        ),
        const SizedBox(height: 6),
        _buildHeardByDropdown(),

        if (!_isSabqiSkipped) ...[
          const SizedBox(height: 12),
          _buildQuickToggles(),
          const SizedBox(height: 16),
          if (_availablePages.isEmpty)
            _buildEmptyState()
          else
            _buildPagesGrid(),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHeardByDropdown() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final provider = context.read<AppProvider>();
    final teachers = (provider.institutionPeople['teachers'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final profileName = provider.profile?.fullName ?? '';
    final split = _splitStudents(provider);
    final myStudents = split['my']!;
    final otherStudents = split['other']!;

    final nameCounts = <String, int>{};
    for (final s in [...myStudents, ...otherStudents]) {
      final name = (s['full_name'] as String? ?? '').trim();
      nameCounts[name] = (nameCounts[name] ?? 0) + 1;
    }

    final otherTeachers = teachers.where((t) => t['full_name'] != profileName).toList();

    final orderedItems = <_PersonItem>[];
    if (profileName.isNotEmpty) {
      orderedItems.add(_PersonItem(name: profileName, group: 'Me'));
    }
    for (final s in myStudents) {
      orderedItems.add(_PersonItem(
        name: _getStudentOptionValue(s, nameCounts),
        group: 'My Students',
      ));
    }
    for (final s in otherStudents) {
      orderedItems.add(_PersonItem(
        name: _getStudentOptionValue(s, nameCounts),
        group: 'Other Students',
      ));
    }
    for (final t in otherTeachers) {
      orderedItems.add(_PersonItem(
        name: t['full_name'] as String? ?? '',
        group: 'Other Teachers',
      ));
    }

    return SearchAnchor(
      builder: (context, searchCtrl) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return InkWell(
          onTap: () => searchCtrl.openView(),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.person_search_rounded, size: 20,
                    color: theme.textTheme.bodySmall?.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _batchHeardBy ?? 'Search...',
                    style: TextStyle(
                      fontSize: 14,
                      color: _batchHeardBy != null
                          ? theme.textTheme.bodyLarge?.color
                          : theme.textTheme.bodySmall?.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_drop_down_rounded,
                    color: theme.textTheme.bodySmall?.color),
              ],
            ),
          ),
        );
      },
      suggestionsBuilder: (context, searchCtrl) {
        final query = searchCtrl.text.toLowerCase();
        final filtered = query.isEmpty
            ? orderedItems
            : orderedItems.where((item) =>
                item.name.toLowerCase().contains(query)).toList();

        if (filtered.isEmpty) {
          return [const ListTile(title: Text('No results'))];
        }

        final tiles = <Widget>[];
        String? lastGroup;
        for (final item in filtered) {
          if (item.group != lastGroup) {
            tiles.add(Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                item.group,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ));
            lastGroup = item.group;
          }
          tiles.add(ListTile(
            dense: true,
            selected: item.name == _batchHeardBy,
            title: Text(item.name),
            onTap: () {
              _handleHeardByChange(item.name);
              Navigator.pop(context);
            },
          ));
        }
        return tiles;
      },
    );
  }

  Map<String, List<Map<String, dynamic>>> _splitStudents(AppProvider provider) {
    final students = (provider.institutionPeople['students'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final currentTeacherId = provider.profile?.id;
    final my = <Map<String, dynamic>>[];
    final other = <Map<String, dynamic>>[];
    for (final s in students) {
      if (currentTeacherId != null && s['teacher_id'] == currentTeacherId) {
        my.add(s);
      } else {
        other.add(s);
      }
    }
    return {'my': my, 'other': other};
  }

  String _getStudentOptionValue(Map<String, dynamic> student, Map<String, int> nameCounts) {
    final trimmedName = (student['full_name'] as String? ?? '').trim();
    final isDuplicate = (nameCounts[trimmedName] ?? 0) > 1;
    if (isDuplicate && student['parent_name'] != null && (student['parent_name'] as String).isNotEmpty) {
      return '$trimmedName (${student['parent_name']})';
    }
    return trimmedName;
  }

  Widget _buildQuickToggles() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _buildPillBtn('All', _addAllToSelection),
                  const SizedBox(width: 6),
                  _buildPillBtn('1st Half', _addFirstHalfToSelection),
                  const SizedBox(width: 6),
                  _buildPillBtn('2nd Half', _addLastHalfToSelection),
                  const SizedBox(width: 6),
                  _buildPillBtn('Active', _addActiveJuzToSelection, enabled: _activeJuzId != null),
                  const SizedBox(width: 6),
                  _buildPillBtn('Clear', _clearAll),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _selectedPages.isEmpty ? null : _assignSelected,
                  icon: const Icon(Icons.checklist_rounded, size: 18),
                  label: Text('Assign ${_selectedPages.length}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPillBtn(String label, VoidCallback onTap, {bool enabled = true}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textColor = enabled ? null : Theme.of(context).textTheme.bodySmall?.color;

    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            color: enabled ? null : Colors.transparent,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPagesGrid() {
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final p in _availablePages) {
      final juz = p['juz'] as int? ?? 0;
      grouped.putIfAbsent(juz, () => []);
      grouped[juz]!.add(p);
    }

    final sortedJuzs = grouped.keys.toList()
      ..sort((a, b) {
        if (a == _activeJuzId && b != _activeJuzId) return -1;
        if (b == _activeJuzId && a != _activeJuzId) return 1;
        return a.compareTo(b);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedJuzs.map((juz) {
        final pages = grouped[juz]!;
        return _buildJuzSection(juz, pages);
      }).toList(),
    );
  }

  Widget _buildJuzSection(int juz, List<Map<String, dynamic>> pages) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
            ),
            child: Text(
              'Juz $juz',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodySmall?.color,
                letterSpacing: 0.5,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.3,
            ),
            itemCount: pages.length,
            itemBuilder: (context, index) => _buildPageCard(pages[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildPageCard(Map<String, dynamic> pageData) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pageNum = pageData['page'] as int;
    final surahName = pageData['surahName'] as String? ?? '';
    final isSelected = _selectedPages.contains(pageNum);
    final isAssigned = _assignments.containsKey(pageNum);
    final assignedTo = _assignments[pageNum];

    Color cardColor;
    Border cardBorder;
    IconData icon;
    Color iconColor;

    if (isSelected) {
      cardColor = AppColors.warning.withValues(alpha: 0.1);
      cardBorder = Border.all(color: AppColors.warning, width: 2);
      icon = Icons.check_circle_outline_rounded;
      iconColor = AppColors.warning;
    } else if (isAssigned) {
      cardColor = AppColors.success.withValues(alpha: 0.08);
      cardBorder = Border.all(color: AppColors.success, width: 2);
      icon = Icons.check_circle_rounded;
      iconColor = AppColors.success;
    } else {
      cardColor = theme.cardColor;
      cardBorder = Border.all(
        color: isDark ? AppColors.borderDark : AppColors.borderLight,
      );
      icon = Icons.circle_rounded;
      iconColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    }

    return GestureDetector(
      onTap: () => _togglePage(pageNum),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: cardBorder,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'P. $pageNum',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                Icon(icon, size: 14, color: iconColor),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              surahName,
              style: TextStyle(
                fontSize: 10,
                color: theme.textTheme.bodySmall?.color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (isAssigned && assignedTo != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected ? AppColors.warning : AppColors.success,
                  ),
                  color: theme.cardColor,
                ),
                child: Text(
                  assignedTo,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.warning : AppColors.success,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          'No active Sabaq Para pages. Log a Sabaq first.',
          style: TextStyle(color: theme.textTheme.bodySmall?.color),
        ),
      ),
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
}
