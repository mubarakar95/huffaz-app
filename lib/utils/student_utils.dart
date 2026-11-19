import 'dart:math';
import 'dart:convert';
import 'quran_data.dart'; // To use getPagesFromSabaqString

int getJuzForPage(int page) {
  if (page <= 21) return 1;
  return min(30, ((page - 2) / 20).floor() + 1);
}

List<int> getPagesForJuz(int juz) {
  int startPage = juz == 1 ? 1 : (juz - 1) * 20 + 2;
  int endPage = juz == 30 ? 604 : juz * 20 + 1;
  return [for (int i = startPage; i <= endPage; i++) i];
}

String getLocalToday() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String shiftDate(DateTime base, int deltaDays) {
  final shifted = base.add(Duration(days: deltaDays));
  return '${shifted.year}-${shifted.month.toString().padLeft(2, '0')}-${shifted.day.toString().padLeft(2, '0')}';
}

int computeStreak(
  List<Map<String, dynamic>> logs,
  Set<String> holidaysSet,
  List<int> weeklyOffDays,
  double sabaqGoal,
  double sabqiGoal,
  double manzilGoal, {
  bool isHafiz = false,
}) {
  Map<String, Map<String, dynamic>> dateMap = {};

  for (var log in logs) {
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
    
    if (manzil is String && manzil.contains(RegExp(r'Juz \d+'))) {
      var matches = RegExp(r'Juz \d+').allMatches(manzil);
      muraja += matches.length * 20;
    }
    
    bool isSabaqNatural = !isSabaqSkipped && (sabaq >= sabaqGoal);
    bool isSabqiNatural = (sabqiPara >= sabqiGoal);
    bool isManzilNatural = (muraja >= manzilGoal);

    bool sabaqSatisfied = isSabaqNatural || isSabaqPreserved;
    bool sabqiSatisfied = isSabqiNatural || isSabqiPreserved;
    bool manzilSatisfied = isManzilNatural || isManzilPreserved;

    bool allSatisfied = sabaqSatisfied && sabqiSatisfied && manzilSatisfied;
    bool allNatural = isSabaqNatural && isSabqiNatural && isManzilNatural;

    bool honored = false;
    bool dayPreserved = isWholeDayPreserved;

    if (!isSickOrAbsent && !isWholeDayStatus) {
      if (isHafiz) {
        if (isManzilNatural) {
          honored = true;
        } else if (isManzilPreserved) {
          dayPreserved = true;
        }
      } else {
        if (allNatural) {
          honored = true;
        } else if (allSatisfied) {
          dayPreserved = true;
        }
      }
    }

    dateMap[date] = {
      'sabaq': sabaq,
      'sabqiPara': sabqiPara,
      'muraja': muraja,
      'isSickOrAbsent': isSickOrAbsent,
      'isPreserved': dayPreserved,
      'isHonored': honored,
    };
  }

  bool isHonored(String date) {
    var data = dateMap[date];
    if (data == null) return false;
    return data['isHonored'] == true;
  }

  String today = getLocalToday();
  DateTime current = DateTime.now();
  if (!isHonored(today) && !(dateMap[today]?['isPreserved'] == true)) {
    current = current.subtract(const Duration(days: 1));
  }

  int streak = 0;
  for (int i = 0; i < 365; i++) {
    String d = '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
    
    if (holidaysSet.contains(d) || weeklyOffDays.contains(current.weekday)) {
      current = current.subtract(const Duration(days: 1));
      continue;
    }
    
    var data = dateMap[d];
    if (data != null && data['isPreserved'] == true && data['isHonored'] != true) {
      current = current.subtract(const Duration(days: 1));
      continue;
    }
    
    if (isHonored(d)) {
      streak++;
      current = current.subtract(const Duration(days: 1));
    } else {
      break;
    }
  }

  return streak;
}

Map<String, String> getStreakTier(int streak) {
  if (streak >= 14) return {'tier': 'legend', 'label': 'Legendary Streak', 'short': 'Legend'};
  if (streak >= 7) return {'tier': 'hot', 'label': 'Hot Streak', 'short': 'Hot'};
  if (streak >= 3) return {'tier': 'warm', 'label': 'Warm Streak', 'short': 'Warm'};
  if (streak >= 1) return {'tier': 'ember', 'label': 'Starting Streak', 'short': 'Ember'};
  return {'tier': 'none', 'label': 'No Streak', 'short': 'None'};
}

double computeWeeklyVelocity(List<Map<String, dynamic>> logs) {
  double velocity = 0;
  String today = getLocalToday();
  DateTime now = DateTime.now();
  String sevenDaysAgo = shiftDate(now, -7);
  
  for (var log in logs) {
    String date = (log['date']?.toString() ?? '').split('T')[0];
    if (date.isEmpty || date.compareTo(sevenDaysAgo) < 0 || date.compareTo(today) > 0) continue;
    
    String sabaqStr = log['sabaq']?.toString() ?? '';
    List<int> pages = getPagesFromSabaqString(sabaqStr);
    velocity += pages.length;
  }
  
  return velocity;
}

String getStudentStatus(double weeklyVelocity, String? lastLogDate) {
  if (lastLogDate == null) return 'Inactive';
  DateTime? lastLog = DateTime.tryParse(lastLogDate);
  if (lastLog == null) return 'Inactive';
  
  if (DateTime.now().difference(lastLog).inDays > 14) {
    return 'Inactive';
  }
  
  if (weeklyVelocity >= 5.0) {
    return 'Active';
  }
  return 'Needs Attention';
}
