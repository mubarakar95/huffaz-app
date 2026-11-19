import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:huffaz_app/utils/quran_data.dart';
import 'package:huffaz_app/utils/student_utils.dart';

void main() async {
  final currentDir = Directory.current.path;
  final tempDir = Directory('$currentDir/test_hive_temp_adil_diag');
  if (!tempDir.existsSync()) tempDir.createSync();
  
  final logsFile = File('$currentDir/test/logs.hive');
  final studentsFile = File('$currentDir/test/students.hive');
  final settingsFile = File('$currentDir/test/settings.hive');
  
  if (logsFile.existsSync()) logsFile.copySync('${tempDir.path}/logs.hive');
  if (studentsFile.existsSync()) studentsFile.copySync('${tempDir.path}/students.hive');
  if (settingsFile.existsSync()) settingsFile.copySync('${tempDir.path}/settings.hive');
  
  Hive.init(tempDir.path);
  final logsBox = await Hive.openBox('logs');
  final studentsBox = await Hive.openBox('students');
  final settingsBox = await Hive.openBox('settings');
  
  List<dynamic> allLogsList = jsonDecode(logsBox.get('logs') ?? '[]');
  List<dynamic> studentsList = jsonDecode(studentsBox.get('students') ?? '[]');
  String settingsJsonStr = settingsBox.get('settings') ?? '{}';
  Map<String, dynamic> settings = jsonDecode(settingsJsonStr);

  Set<String> holidaysSet = Set<String>.from(settings['holidays'] ?? []);
  List<int> weeklyOffDays = List<int>.from(settings['weekly_off_days'] ?? settings['weeklyOffDays'] ?? [5, 7]);

  print('=== SETTINGS ===');
  print('holidays: $holidaysSet');
  print('weeklyOffDays: $weeklyOffDays');

  for (var s in studentsList) {
    String name = s['fullName']?.toString() ?? s['full_name']?.toString() ?? '';
    if (name.toLowerCase().contains('adil')) {
      print('\n========================================');
      print('STUDENT: $name');
      print('ID: ${s['id']}');
      print('Raw Profile: $s');
      
      double sabaqGoal = (s['sabaq_goal'] ?? s['sabaqGoal'] ?? settings['sabaqGoal'] ?? 1.0).toDouble();
      double sabqiGoal = (s['sabqi_goal'] ?? s['sabqiGoal'] ?? settings['sabqiGoal'] ?? 1.0).toDouble();
      double manzilGoal = (s['manzil_goal'] ?? s['manzilGoal'] ?? settings['manzilGoal'] ?? 20.0).toDouble();
      bool isHafiz = s['is_hafiz'] ?? s['isHafiz'] ?? false;

      print('Effective Goals: Sabaq=$sabaqGoal, Sabqi=$sabqiGoal, Manzil=$manzilGoal, isHafiz=$isHafiz');

      String sId = s['id'].toString();
      var adilLogs = allLogsList.where((l) => l['student_id'] == sId || l['studentId'] == sId).toList();
      List<Map<String, dynamic>> castedLogs = adilLogs.map((e) => Map<String, dynamic>.from(e)).toList();

      print('\nTotal logs count: ${castedLogs.length}');

      int streak = computeStreak(
        castedLogs,
        holidaysSet,
        weeklyOffDays,
        sabaqGoal,
        sabqiGoal,
        manzilGoal,
        isHafiz: isHafiz,
      );
      print('>>> Calculated Streak: $streak <<<');

      // Let's print day by day evaluation for the last 30 days
      print('\n--- Day by Day Evaluation ---');
      Map<String, Map<String, dynamic>> dateMap = {};
      for (var log in castedLogs) {
        String status = log['status']?.toString() ?? '';
        if (status == 'baseline' || status == 'baseline_sabqi') continue;
        String date = (log['date']?.toString() ?? '').split('T')[0];
        if (date.isEmpty) continue;
        
        String sabaqStr = log['sabaq']?.toString() ?? '';
        String manzilStr = log['manzil']?.toString() ?? '';
        
        bool isSabaqSkipped = sabaqStr.contains('[SKIPPED:');
        bool isSabaqPreserved = isSabaqSkipped && (sabaqStr.contains('[PRESERVE_STREAK]') || sabaqStr.contains('Khatam'));
        
        double sabaq = 0;
        bool isSickOrAbsent = false;
        bool isWholeDayPreserved = false;
        
        bool isWholeDayStatus = ['sick', 'absent', 'other', 'no_lesson'].contains(status);
        
        if (isWholeDayStatus) {
          if (sabaqStr.contains('[PRESERVE_STREAK]') || sabaqStr.contains('Khatam') || manzilStr.contains('[PRESERVE_STREAK]')) {
            isWholeDayPreserved = true;
          } else {
            isSickOrAbsent = true;
          }
        } else if (!isSickOrAbsent && !isSabaqSkipped) {
          sabaq = getPagesFromSabaqString(sabaqStr).length.toDouble();
        }
        
        double sabqiPara = 0;
        double muraja = 0;
        bool isSabqiPreserved = manzilStr.contains('[PRESERVE_STREAK]') || manzilStr.contains('Khatam');
        bool isManzilPreserved = manzilStr.contains('[PRESERVE_STREAK]') || manzilStr.contains('Khatam');

        var manzil = log['manzil'];
        Map<String, dynamic>? parsedManzil;
        if (manzil is Map<String, dynamic>) {
          parsedManzil = manzil;
        } else if (manzil is String && manzil.isNotEmpty) {
          try {
            parsedManzil = json.decode(manzil);
          } catch (_) {}
        }
        
        if (parsedManzil != null) {
          if (parsedManzil['sabqi'] is List) {
            for (var item in parsedManzil['sabqi']) {
              if (item is Map) {
                String itemSabaq = item['sabaq']?.toString() ?? '';
                if (itemSabaq.contains('[PRESERVE_STREAK]') || itemSabaq.contains('Khatam')) {
                  isSabqiPreserved = true;
                } else if (!itemSabaq.contains('[SKIPPED]')) {
                  sabqiPara += 1.0;
                }
              }
            }
          }
          if (parsedManzil['manzilPages'] is List) {
            for (var item in parsedManzil['manzilPages']) {
              if (item is Map) {
                String itemSurah = item['surahName']?.toString() ?? '';
                String itemSabaq = item['sabaq']?.toString() ?? '';
                if (itemSurah.contains('[PRESERVE_STREAK]') || itemSurah.contains('Khatam') ||
                    itemSabaq.contains('[PRESERVE_STREAK]') || itemSabaq.contains('Khatam')) {
                  isManzilPreserved = true;
                } else if (item['page'] != -1 && !itemSabaq.contains('[SKIPPED]')) {
                  muraja += 1.0;
                }
              }
            }
          }
        }
        
        bool sabaqSatisfied = (sabaq >= sabaqGoal) || isSabaqPreserved;
        bool sabqiSatisfied = (sabqiPara >= sabqiGoal) || isSabqiPreserved;
        bool manzilSatisfied = (muraja >= manzilGoal) || isManzilPreserved;
        
        bool honored = false;
        if (!isSickOrAbsent && !isWholeDayStatus) {
          if (isHafiz) {
            honored = (muraja >= manzilGoal) || isManzilPreserved;
          } else {
            honored = sabaqSatisfied && sabqiSatisfied && manzilSatisfied;
          }
        }

        dateMap[date] = {
          'sabaq': sabaq,
          'sabqiPara': sabqiPara,
          'muraja': muraja,
          'sabaqSatisfied': sabaqSatisfied,
          'sabqiSatisfied': sabqiSatisfied,
          'manzilSatisfied': manzilSatisfied,
          'isSickOrAbsent': isSickOrAbsent,
          'isPreserved': isWholeDayPreserved,
          'isHonored': honored,
        };
      }

      DateTime start = DateTime(2026, 9, 2);
      for (int i = 0; i < 35; i++) {
        DateTime dt = start.subtract(Duration(days: i));
        String dStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        String wName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dt.weekday - 1];
        bool isOff = weeklyOffDays.contains(dt.weekday) || holidaysSet.contains(dStr);
        var data = dateMap[dStr];
        if (data == null) {
          print('  $dStr ($wName): NO LOG | isOff=$isOff');
        } else {
          print('  $dStr ($wName): sabaqSatisfied=${data['sabaqSatisfied']} (sabaq=${data['sabaq']}), sabqiSatisfied=${data['sabqiSatisfied']} (sabqi=${data['sabqiPara']}), manzilSatisfied=${data['manzilSatisfied']} (muraja=${data['muraja']}), isOff=$isOff | HONORED=${data['isHonored']}');
        }
      }
    }
  }

  try { tempDir.deleteSync(recursive: true); } catch (_) {}
}
