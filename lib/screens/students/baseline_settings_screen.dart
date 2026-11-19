import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../models/student.dart';
import '../../../providers/app_provider.dart';
import '../../../utils/quran_data.dart';
import '../../../utils/student_utils.dart';

class BaselineSettingsScreen extends StatefulWidget {
  final String studentId;

  const BaselineSettingsScreen({Key? key, required this.studentId}) : super(key: key);

  @override
  State<BaselineSettingsScreen> createState() => _BaselineSettingsScreenState();
}

class _BaselineSettingsScreenState extends State<BaselineSettingsScreen> {
  bool _isLoading = false;
  bool _isSaving = false;

  // Selected Muraja Juz list
  final List<int> _selectedMurajaJuz = [];
  
  // Sabaq progress selection
  int _sabaqParaJuz = 1;
  int _sabaqParaPageInJuz = 1;
  int _sabaqParaPrevJuz = 0;

  @override
  void initState() {
    super.initState();
    _loadBaselineData();
  }

  void _loadBaselineData() {
    final provider = context.read<AppProvider>();
    final existingLogs = provider.getLogsForStudent(widget.studentId);
    debugPrint('BASELINE_SETTINGS_SCREEN: Loaded ${existingLogs.length} logs for studentId: ${widget.studentId}');
    
    // 1. Get current Muraja Juz from baseline logs
    final murajaBasePages = existingLogs
        .where((l) => l.status == 'baseline')
        .map((l) => getPagesFromSabaqString(l.sabaq))
        .expand((x) => x)
        .toList();
    
    final Set<int> existingSabaqJuzs = murajaBasePages.map((p) => getJuzForPage(p)).toSet();
    _selectedMurajaJuz.addAll(existingSabaqJuzs);
    debugPrint('BASELINE_SETTINGS_SCREEN: parsed Muraja baseline Juzs: $_selectedMurajaJuz');

    // Get current Sabqi pages (remains baseline_sabqi logs)
    final sabqiBasePages = existingLogs
        .where((l) => l.status == 'baseline_sabqi')
        .map((l) => getPagesFromSabaqString(l.sabaq))
        .expand((x) => x)
        .toList()..sort();

    if (sabqiBasePages.isNotEmpty) {
      final lastPageAbs = sabqiBasePages.last;
      _sabaqParaJuz = getJuzForPage(lastPageAbs);
      final otherJuzs = sabqiBasePages
          .map((p) => getJuzForPage(p))
          .where((j) => j != _sabaqParaJuz)
          .toList();
      if (otherJuzs.isNotEmpty) {
        _sabaqParaPrevJuz = otherJuzs.first;
      } else {
        _sabaqParaPrevJuz = _sabaqParaJuz > 1 ? _sabaqParaJuz - 1 : 30;
      }

      final juzPages = _getPagesInJuz(_sabaqParaJuz);
      final idx = juzPages.indexOf(lastPageAbs);
      _sabaqParaPageInJuz = idx != -1 ? idx + 1 : 1;
    } else {
      final firstAvailable = List.generate(30, (i) => i + 1).firstWhere(
        (j) => !_selectedMurajaJuz.contains(j),
        orElse: () => 1,
      );
      _sabaqParaJuz = firstAvailable;
      _sabaqParaPrevJuz = 0;
      _sabaqParaPageInJuz = 1;
    }
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

  Future<void> _saveBaseline() async {
    setState(() => _isSaving = true);
    try {
      final provider = context.read<AppProvider>();

      // 1. Calculate Muraja pages from selected Juz
      final List<int> computedMurajaPages = [];
      for (int p = 1; p <= 604; p++) {
        if (_selectedMurajaJuz.contains(getJuzForPage(p))) {
          computedMurajaPages.add(p);
        }
      }

      // 2. Calculate Sabaq Para Pages
      final List<int> currentJuzPages = _getPagesInJuz(_sabaqParaJuz);
      final List<int> computedSabaqParaPages = [];
      
      final limit = _sabaqParaPageInJuz <= currentJuzPages.length
          ? _sabaqParaPageInJuz
          : currentJuzPages.length;
      for (int i = 0; i < limit; i++) {
        computedSabaqParaPages.add(currentJuzPages[i]);
      }

      if (computedSabaqParaPages.length < 20 && _sabaqParaPrevJuz > 0) {
        final prevJuzPages = _getPagesInJuz(_sabaqParaPrevJuz);
        final needed = 20 - computedSabaqParaPages.length;
        final startIdx = (prevJuzPages.length - needed).clamp(0, prevJuzPages.length);
        final extra = prevJuzPages.sublist(startIdx);
        computedSabaqParaPages.insertAll(0, extra);
      }

      if (computedSabaqParaPages.length > 20) {
        computedSabaqParaPages.removeRange(0, computedSabaqParaPages.length - 20);
      }

      final baselineErr = await provider.saveBaseline(
        studentId: widget.studentId,
        sabaqPages: computedMurajaPages,
        sabqiPages: _selectedMurajaJuz.length == 30 ? [] : computedSabaqParaPages,
      );

      if (mounted) {
        if (baselineErr != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save baseline: $baselineErr'), backgroundColor: AppColors.danger),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Baseline saved successfully'), backgroundColor: AppColors.success),
          );
          Navigator.pop(context, true);
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resetBaseline() async {
    setState(() => _isSaving = true);
    try {
      final provider = context.read<AppProvider>();
      final baselineErr = await provider.saveBaseline(
        studentId: widget.studentId,
        sabaqPages: [],
        sabqiPages: [],
      );

      if (mounted) {
        if (baselineErr != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reset baseline: $baselineErr'), backgroundColor: AppColors.danger),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Baseline reset successfully'), backgroundColor: AppColors.success),
          );
          Navigator.pop(context, true);
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final student = provider.students.firstWhere(
      (s) => s.id == widget.studentId,
      orElse: () => Student(id: widget.studentId, fullName: 'Student', institutionId: '', isPersonal: false),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Recalculate Muraja Pages
    final List<int> computedMurajaPages = [];
    for (int p = 1; p <= 604; p++) {
      if (_selectedMurajaJuz.contains(getJuzForPage(p))) {
        computedMurajaPages.add(p);
      }
    }

    // Recalculate Sabaq Para Pages
    final List<int> currentJuzPages = _getPagesInJuz(_sabaqParaJuz);
    final List<int> computedSabaqParaPages = [];
    
    final limit = _sabaqParaPageInJuz <= currentJuzPages.length
        ? _sabaqParaPageInJuz
        : currentJuzPages.length;
    for (int i = 0; i < limit; i++) {
      computedSabaqParaPages.add(currentJuzPages[i]);
    }

    if (computedSabaqParaPages.length < 20 && _sabaqParaPrevJuz > 0) {
      final prevJuzPages = _getPagesInJuz(_sabaqParaPrevJuz);
      final needed = 20 - computedSabaqParaPages.length;
      final startIdx = (prevJuzPages.length - needed).clamp(0, prevJuzPages.length);
      final extra = prevJuzPages.sublist(startIdx);
      computedSabaqParaPages.insertAll(0, extra);
    }

    if (computedSabaqParaPages.length > 20) {
      computedSabaqParaPages.removeRange(0, computedSabaqParaPages.length - 20);
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Baseline - ${student.fullName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : AppColors.textMainLight,
      ),
      body: SafeArea(
        bottom: true,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Theme(
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section 1: Completed Juz
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
                            const Text(
                              '1. Completed Juz (Muraja / Manzil)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select completed Juz to add them to the Muraja pool.',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 6,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1.1,
                              ),
                              itemCount: 30,
                              itemBuilder: (context, idx) {
                                final juzNum = idx + 1;
                                final isSelected = _selectedMurajaJuz.contains(juzNum);
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedMurajaJuz.remove(juzNum);
                                      } else {
                                        _selectedMurajaJuz.add(juzNum);
                                        if (_sabaqParaJuz == juzNum) {
                                          final nextAvailable = List.generate(30, (i) => i + 1).firstWhere(
                                            (j) => !_selectedMurajaJuz.contains(j),
                                            orElse: () => 1,
                                          );
                                          _sabaqParaJuz = nextAvailable;
                                        }
                                      }
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark ? const Color(0xFF2C2F34) : const Color(0xFFF4F4F5)),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : (isDark ? AppColors.borderDark : AppColors.borderLight),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$juzNum',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark ? Colors.white : AppColors.textMainLight),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 2: Current Sabaq Progress
                    if (_selectedMurajaJuz.length < 30) ...[
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
                              const Text(
                                '2. Current Sabaq Progress',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Tell the system where you were yesterday. We'll seed the last 20 pages as Sabaq Para.",
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                              const SizedBox(height: 16),
                              (() {
                                final availableSabaqJuzs = List.generate(30, (i) => i + 1)
                                    .where((j) => !_selectedMurajaJuz.contains(j))
                                    .toList();
                                
                                if (!availableSabaqJuzs.contains(_sabaqParaJuz)) {
                                  _sabaqParaJuz = availableSabaqJuzs.isNotEmpty ? availableSabaqJuzs.first : 1;
                                }

                                if (_sabaqParaPageInJuz > currentJuzPages.length || _sabaqParaPageInJuz < 1) {
                                  _sabaqParaPageInJuz = 1;
                                }

                                 return DropdownButtonFormField<int>(
                                  value: _sabaqParaJuz,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Active Juz'),
                                  items: availableSabaqJuzs
                                      .map((j) => DropdownMenuItem(value: j, child: Text('Juz $j')))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _sabaqParaJuz = val;
                                        _sabaqParaPageInJuz = 1;
                                      });
                                    }
                                  },
                                );
                              })(),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<int>(
                                value: _sabaqParaPageInJuz,
                                isExpanded: true,
                                decoration: InputDecoration(labelText: 'Last Page Memorized in Juz $_sabaqParaJuz'),
                                items: List.generate(currentJuzPages.length, (i) => i + 1)
                                    .map((pIdx) => DropdownMenuItem(
                                          value: pIdx,
                                          child: Text('Page $pIdx (Mushaf P. ${currentJuzPages[pIdx - 1]})'),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _sabaqParaPageInJuz = val;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<int>(
                                value: _sabaqParaPrevJuz,
                                isExpanded: true,
                                decoration: const InputDecoration(labelText: 'Last Finished Juz (for Revision)'),
                                items: [
                                  const DropdownMenuItem(value: 0, child: Text('None (Beginner / < 20 pages)')),
                                  ...List.generate(30, (i) => i + 1)
                                      .map((j) => DropdownMenuItem(value: j, child: Text('Juz $j'))),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _sabaqParaPrevJuz = val;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Live Preview box
                    Card(
                      elevation: 0,
                      color: isDark ? const Color(0xFF2C2F34) : const Color(0xFFF8FAF9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
                              'Live Preview Summary',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.textMainLight,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Muraja pool size:'),
                                Text(
                                  '${computedMurajaPages.length} pages (${_selectedMurajaJuz.length} Juz)',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (_selectedMurajaJuz.length < 30) ...[
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Sabaq Para pool size:'),
                                  Text(
                                    '${computedSabaqParaPages.length} pages',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              if (computedSabaqParaPages.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'Mushaf range: P. ${computedSabaqParaPages.first} - P. ${computedSabaqParaPages.last}',
                                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _isSaving ? null : _saveBaseline,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Save Baseline Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isSaving ? null : _resetBaseline,
                      child: const Text('Reset Profile Baseline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isSaving ? null : () => _showClearJuzLogsDialog(context),
                      icon: const Icon(Icons.cleaning_services_rounded, size: 20),
                      label: const Text('Reset Daily Sabaq by Juz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  void _showClearJuzLogsDialog(BuildContext context) {
    int selectedJuz = 1;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setState) {
          return AlertDialog(
            title: const Text('Reset Daily Sabaq by Juz'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select the Juz to remove daily Sabaq records for. This will not affect baseline records or other metrics.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedJuz,
                  decoration: const InputDecoration(
                    labelText: 'Select Juz',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: List.generate(30, (i) => i + 1)
                      .map((j) => DropdownMenuItem(
                            value: j,
                            child: Text('Juz $j'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedJuz = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  BuildContext? loadingDialogCtx;
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (loadingCtx) {
                      loadingDialogCtx = loadingCtx;
                      return const Center(child: CircularProgressIndicator());
                    },
                  );
                  
                  final provider = context.read<AppProvider>();
                  final err = await provider.clearSabaqLogsForJuz(widget.studentId, selectedJuz);
                  if (loadingDialogCtx != null && loadingDialogCtx!.mounted) {
                    Navigator.pop(loadingDialogCtx!); // Close spinner specifically
                  }
                  if (context.mounted) {
                    if (err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $err'), backgroundColor: AppColors.danger),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sabaq logs for Juz $selectedJuz cleared successfully!')),
                      );
                    }
                  }
                },
                child: const Text('Clear Logs'),
              ),
            ],
          );
        },
      ),
    );
  }
}
