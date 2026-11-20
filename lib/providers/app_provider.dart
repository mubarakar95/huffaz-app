import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../models/student.dart';
import '../models/sabaq_log.dart';
import '../models/teacher.dart';
import '../services/auth_service.dart';
import '../services/student_service.dart';
import '../services/settings_service.dart';
import '../services/dashboard_service.dart';
import '../services/report_service.dart';
import '../services/acknowledgement_service.dart';
import '../utils/student_utils.dart';
import '../utils/quran_data.dart';
import '../services/notification_service.dart';


/// Central state management — mirrors the DataContext from the Next.js web app.
/// Uses Hive for offline persistence so data is instantly available on app launch.
class AppProvider extends ChangeNotifier {
  /// [authService] is injectable so auth flows can be tested without a backend.
  AppProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  // --- Services ---
  final AuthService _authService;
  final StudentService _studentService = StudentService();
  final SettingsService _settingsService = SettingsService();
  final DashboardService _dashboardService = DashboardService();
  final ReportService _reportService = ReportService();
  final AcknowledgementService _acknowledgementService = AcknowledgementService();

  // --- Hive Box Names ---
  static const _boxProfile = 'profile';
  static const _boxStudents = 'students';
  static const _boxLogs = 'logs';
  static const _boxDashboard = 'dashboard';
  static const _boxSettings = 'settings';
  static const _boxHolidays = 'holidays';

  // --- Auth State ---
  User? _user;
  AppProfile? _profile;

  User? get user => _user;
  AppProfile? get profile => _profile;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _profile?.role == 'admin' || _profile?.role == 'super_admin';
  bool get hasInstitution => _profile?.institutionId != null;

  // --- Loading State ---
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _hasFetchedStudents = false;
  bool _hasFetchedDashboard = false;

  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get hasFetchedStudents => _hasFetchedStudents;
  bool get hasFetchedDashboard => _hasFetchedDashboard;

  // --- Theme ---
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  // --- Notifications / Reminders ---
  bool _reminderEnabled = false;
  bool get reminderEnabled => _reminderEnabled;

  int _reminderHour = 15; // Default: 3:00 PM
  int get reminderHour => _reminderHour;

  int _reminderMinute = 0;
  int get reminderMinute => _reminderMinute;

  Future<String?> updateReminderSettings({bool? enabled, int? hour, int? minute}) async {
    if (enabled != null) {
      if (enabled) {
        final granted = await NotificationService.requestPermissions();
        if (!granted) {
          return 'Notification permission denied by system.';
        }
      }
      _reminderEnabled = enabled;
      await _settingsBox.put('reminderEnabled', enabled);
    }
    if (hour != null) {
      _reminderHour = hour;
      await _settingsBox.put('reminderHour', hour);
    }
    if (minute != null) {
      _reminderMinute = minute;
      await _settingsBox.put('reminderMinute', minute);
    }

    await refreshScheduledReminder();

    notifyListeners();
    return null;
  }

  int getPendingLogsCountForToday() {
    final todayStr = getLocalToday();
    final currentUserId = _profile?.id;
    if (currentUserId == null) return 0;

    // Filter students assigned to this teacher (excluding personal/private students)
    final personalStudents = _students
        .where((s) => s.teacherId == currentUserId && s.isPersonal != true)
        .toList();

    int pendingCount = 0;
    for (final student in personalStudents) {
      final isHafiz = student.progressPercent >= 100;
      final sGoal = student.sabaqGoal ?? _defaultSabaqGoal;
      final sqGoal = student.sabqiGoal ?? _defaultSabqiGoal;
      final mGoal = student.manzilGoal ?? _defaultManzilGoal;

      final logs = getLogsForStudent(student.id);
      final log = logs.where((l) => l.date.split('T')[0] == todayStr).firstOrNull;

      if (log == null) {
        pendingCount++;
        continue;
      }

      final status = log.status;
      if (status == 'absent' || status == 'sick' || status == 'other') {
        // Exempt today, not pending!
        continue;
      }

      // Compute page counts from the log
      final sabaqStr = log.sabaq;
      final sabaqPages = sabaqStr.isNotEmpty ? getPagesCountFromSabaqString(sabaqStr) : 0.0;
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

      bool isComplete;
      if (isHafiz) {
        isComplete = manzilDone;
      } else {
        isComplete = sabaqDone && sabqiDone && manzilDone;
      }

      if (!isComplete) {
        pendingCount++;
      }
    }

    return pendingCount;
  }

  Future<void> refreshScheduledReminder() async {
    if (!_reminderEnabled) {
      await NotificationService.cancelDailyReminder();
      return;
    }
    final pendingCount = getPendingLogsCountForToday();
    await NotificationService.scheduleDailyReminder(_reminderHour, _reminderMinute, pendingCount: pendingCount);
  }

  // --- Teacher Absences State ---
  List<Map<String, dynamic>> _scheduledAbsences = [];
  List<Map<String, dynamic>> get scheduledAbsences => _scheduledAbsences;

  List<Map<String, dynamic>> _absentTeachersToday = [];
  List<Map<String, dynamic>> get absentTeachersToday => _absentTeachersToday;

  // --- Teacher Management State (admin-only) ---
  List<Teacher> _teachers = [];
  List<Teacher> get teachers => _teachers;

  bool _isLoadingTeachers = false;
  bool get isLoadingTeachers => _isLoadingTeachers;

  bool _hasFetchedTeachers = false;
  bool get hasFetchedTeachers => _hasFetchedTeachers;

  int _leaveReportYear = DateTime.now().year;
  int _leaveReportMonth = DateTime.now().month;
  int get leaveReportYear => _leaveReportYear;
  int get leaveReportMonth => _leaveReportMonth;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _settingsBox.put('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  // --- Search ---
  bool _isSearchVisible = false;
  bool get isSearchVisible => _isSearchVisible;
  void toggleSearch() {
    _isSearchVisible = !_isSearchVisible;
    notifyListeners();
  }
  void hideSearch() {
    _isSearchVisible = false;
    notifyListeners();
  }

  // --- FAB visibility (driven by list scroll position) ---
  bool _isFabVisible = true;
  bool get isFabVisible => _isFabVisible;
  void setFabVisible(bool visible) {
    if (_isFabVisible == visible) return;
    _isFabVisible = visible;
    notifyListeners();
  }

  // --- Selected Date for Students List ---
  String _selectedDateStr = getLocalToday();
  String get selectedDateStr => _selectedDateStr;
  void setSelectedDateStr(String date) {
    if (_selectedDateStr == date) return;
    _selectedDateStr = date;
    fetchDailyReport(date);
    loadAcknowledgements(date);
    notifyListeners();
  }

  bool _filterPending = false;
  bool get filterPending => _filterPending;
  void setFilterPending(bool val) {
    if (_filterPending == val) return;
    _filterPending = val;
    notifyListeners();
  }

  // --- Lesson Acknowledgements ---
  // Keyed by date string ('YYYY-MM-DD') → Set of acknowledged student IDs.
  // Supports both today and any past date (e.g. yesterday's pending banner).
  final Map<String, Set<String>> _acknowledgedByDate = {};

  /// Returns the Set of student IDs acknowledged for the given [date].
  Set<String> getAcknowledgedIds(String date) =>
      _acknowledgedByDate[date] ?? {};

  /// Persists an acknowledgement for [studentId] on [date] and updates local state.
  Future<void> acknowledgeStudent(String studentId, String date) async {
    final teacherId = _user?.id;
    if (teacherId == null) return;

    // Optimistic local update first for immediate UI response
    _acknowledgedByDate.putIfAbsent(date, () => {}).add(studentId);
    notifyListeners();

    // Persist to Supabase in background
    try {
      await _acknowledgementService.acknowledge(
        teacherId: teacherId,
        studentId: studentId,
        date: date,
        institutionId: _profile?.institutionId,
      );
    } catch (e) {
      debugPrint('[AppProvider] acknowledgeStudent error: $e');
      // Roll back on failure
      _acknowledgedByDate[date]?.remove(studentId);
      notifyListeners();
    }
  }

  /// Removes an acknowledgement for [studentId] on [date] and updates local state.
  Future<void> unacknowledgeStudent(String studentId, String date) async {
    final teacherId = _user?.id;
    if (teacherId == null) return;

    // Optimistic local update
    _acknowledgedByDate[date]?.remove(studentId);
    notifyListeners();

    try {
      await _acknowledgementService.removeAcknowledgement(
        teacherId: teacherId,
        studentId: studentId,
        date: date,
      );
    } catch (e) {
      debugPrint('[AppProvider] unacknowledgeStudent error: $e');
      _acknowledgedByDate.putIfAbsent(date, () => {}).add(studentId);
      notifyListeners();
    }
  }

  /// Loads acknowledgements from Supabase for the given [date].
  /// Call this during dashboard or student list init for today (and any selected date).
  Future<void> loadAcknowledgements(String date) async {
    final teacherId = _user?.id;
    final institutionId = _profile?.institutionId;
    try {
      final ids = await _acknowledgementService.fetchAcknowledgedStudentIds(
          teacherId, date, institutionId: institutionId);
      _acknowledgedByDate[date] = ids;
      notifyListeners();
    } catch (e) {
      debugPrint('[AppProvider] loadAcknowledgements error: $e');
    }
  }

  String _getLastClassDayStr() {
    final holidaysSet = _holidays.toSet();
    var d = DateTime.now().subtract(const Duration(days: 1));
    for (int i = 0; i < 10; i++) {
      final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final isWeekend = weeklyOffDays.contains(d.weekday);
      final isHoliday = holidaysSet.contains(dateStr);
      if (!isWeekend && !isHoliday) {
        return dateStr;
      }
      d = d.subtract(const Duration(days: 1));
    }
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // --- Reports Data ---
  List<Student> _reportStudents = [];
  List<Student> get reportStudents => _reportStudents;

  bool _isLoadingReport = false;
  bool get isLoadingReport => _isLoadingReport;

  Future<void> fetchDailyReport(String date) async {
    _isLoadingReport = true;
    notifyListeners();
    try {
      _reportStudents = await _reportService.fetchDailyReport(
        date: date,
        cachedStudents: _students,
        cachedLogs: _allLogs,
      );
    } catch (e) {
      debugPrint('Error loading daily report: $e');
    } finally {
      _isLoadingReport = false;
      notifyListeners();
    }
  }

  // --- Weekly Reports Data ---
  Map<String, dynamic> _weeklyReportData = {};
  Map<String, dynamic> get weeklyReportData => _weeklyReportData;

  bool _isLoadingWeekly = false;
  bool get isLoadingWeekly => _isLoadingWeekly;

  Future<void> fetchWeeklyReport(String endDate) async {
    _isLoadingWeekly = true;
    notifyListeners();
    try {
      _weeklyReportData = await _reportService.fetchWeeklyReport(
        endDateStr: endDate,
        cachedStudents: _students,
        cachedLogs: _allLogs,
        holidaysSet: holidaysSet,
        weeklyOffDays: _weeklyOffDays,
        defaultSabaqGoal: _defaultSabaqGoal,
        defaultSabqiGoal: _defaultSabqiGoal,
        defaultManzilGoal: _defaultManzilGoal,
      );
    } catch (e) {
      debugPrint('Error loading weekly report: $e');
    } finally {
      _isLoadingWeekly = false;
      notifyListeners();
    }
  }

  // --- Monthly Reports Data ---
  Map<String, dynamic> _monthlyReportData = {};
  Map<String, dynamic> get monthlyReportData => _monthlyReportData;

  bool _isLoadingMonthly = false;
  bool get isLoadingMonthly => _isLoadingMonthly;

  Future<void> fetchMonthlyReport(int year, int month) async {
    _isLoadingMonthly = true;
    notifyListeners();
    try {
      _monthlyReportData = await _reportService.fetchMonthlyReport(
        year: year,
        month: month,
        cachedStudents: _students,
        cachedLogs: _allLogs,
        holidaysSet: holidaysSet,
        weeklyOffDays: _weeklyOffDays,
        defaultSabaqGoal: _defaultSabaqGoal,
        defaultSabqiGoal: _defaultSabqiGoal,
        defaultManzilGoal: _defaultManzilGoal,
      );
    } catch (e) {
      debugPrint('Error loading monthly report: $e');
    } finally {
      _isLoadingMonthly = false;
      notifyListeners();
    }
  }

  // --- Dashboard Data ---
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? get dashboardData => _dashboardData;

  // --- Students ---
  List<Student> _students = [];
  List<Student> get students => _students;

  // --- Logs ---
  List<SabaqLog> _allLogs = [];
  List<SabaqLog> get allLogs => _allLogs;

  // --- Student Details Cache ---
  final Map<String, Map<String, dynamic>> _studentDetails = {};
  Map<String, dynamic>? getStudentDetail(String id) => _studentDetails[id];

  // --- Settings ---
  List<String> _holidays = [];
  Set<String> get holidaysSet => _holidays.toSet();
  List<String> get holidays => _holidays;

  double _defaultSabaqGoal = 1.0;
  double _defaultSabqiGoal = 10.0;
  double _defaultManzilGoal = 20.0;
  List<int> _weeklyOffDays = [];

  double get defaultSabaqGoal => _defaultSabaqGoal;
  double get defaultSabqiGoal => _defaultSabqiGoal;
  double get defaultManzilGoal => _defaultManzilGoal;
  List<int> get weeklyOffDays => _weeklyOffDays;

  // --- Institution People (for Heard By picker) ---
  Map<String, dynamic> _institutionPeople = {'teachers': [], 'students': []};
  Map<String, dynamic> get institutionPeople => _institutionPeople;

  // --- Hive boxes ---
  late Box _profileBox;
  late Box _studentsBox;
  late Box _logsBox;
  late Box _dashboardBox;
  late Box _settingsBox;
  late Box _holidaysBox;

  // -----------------------------------------------------------------------
  // Initialization
  // -----------------------------------------------------------------------

  Future<void> initialize() async {
    await _openBoxes();
    _loadFromHive();
    _isDarkMode = _settingsBox.get('isDarkMode', defaultValue: false);

    // Listen to Auth state changes to persist and bootstrap the session as soon as it's available
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null && !session.isExpired) {
        if (_user?.id != session.user.id) {
          _user = session.user;
          _isLoading = true;
          notifyListeners();
          await _bootstrapAfterLogin(session.user);
          _isLoading = false;
          notifyListeners();
        }
      } else {
        if (_user != null) {
          _user = null;
          _clearAllState();
          notifyListeners();
        }
      }
    });

    // Check for existing session immediately just in case it is already populated
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && !session.isExpired) {
      _isLoading = true;
      _user = session.user;
      notifyListeners();
      await _bootstrapAfterLogin(session.user);
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _openBoxes() async {
    _profileBox   = await Hive.openBox(_boxProfile);
    _studentsBox  = await Hive.openBox(_boxStudents);
    _logsBox      = await Hive.openBox(_boxLogs);
    _dashboardBox = await Hive.openBox(_boxDashboard);
    _settingsBox  = await Hive.openBox(_boxSettings);
    _holidaysBox  = await Hive.openBox(_boxHolidays);
  }

  /// Load persisted data from Hive — instant, no network needed
  void _loadFromHive() {
    // Profile
    final profileJson = _profileBox.get('profile');
    if (profileJson != null) {
      _profile = AppProfile.fromMap(Map<String, dynamic>.from(jsonDecode(profileJson)));
      _defaultSabaqGoal = _profile?.defaultSabaqGoal ?? 1.0;
      _defaultSabqiGoal = _profile?.defaultSabqiGoal ?? 10.0;
      _defaultManzilGoal = _profile?.defaultManzilGoal ?? 20.0;
      _weeklyOffDays = _profile?.weeklyOffDays ?? [];
    }

    // Holidays
    final holidaysList = _holidaysBox.get('holidays');
    if (holidaysList != null) {
      _holidays = List<String>.from(jsonDecode(holidaysList));
    }

    // Students
    final studentsJson = _studentsBox.get('students');
    if (studentsJson != null) {
      final list = jsonDecode(studentsJson) as List;
      _students = list.map((m) => Student.fromMap(Map<String, dynamic>.from(m))).toList();
      _hasFetchedStudents = _students.isNotEmpty;
    }

    // Logs
    final logsJson = _logsBox.get('logs');
    if (logsJson != null) {
      final list = jsonDecode(logsJson) as List;
      _allLogs = list.map((m) => SabaqLog.fromMap(Map<String, dynamic>.from(m))).toList();
    }

    // Student details cache
    final detailsJson = _studentsBox.get('details');
    if (detailsJson != null) {
      final map = jsonDecode(detailsJson) as Map;
      for (final entry in map.entries) {
        _studentDetails[entry.key] = Map<String, dynamic>.from(entry.value);
      }
    }

    // Dashboard
    final dashJson = _dashboardBox.get('data');
    if (dashJson != null) {
      _dashboardData = Map<String, dynamic>.from(jsonDecode(dashJson));
      _hasFetchedDashboard = true;
    }

    // Institution People
    final peopleJson = _settingsBox.get('institutionPeople');
    if (peopleJson != null) {
      _institutionPeople = Map<String, dynamic>.from(jsonDecode(peopleJson));
    }

    // Reminders (On by default from this update)
    _reminderEnabled = _settingsBox.get('reminderEnabled', defaultValue: true);
    _reminderHour = _settingsBox.get('reminderHour', defaultValue: 15);
    _reminderMinute = _settingsBox.get('reminderMinute', defaultValue: 0);

    final hasPrompted = _settingsBox.get('hasPromptedReminderPermission', defaultValue: false);
    if (!hasPrompted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final granted = await NotificationService.requestPermissions();
        if (granted) {
          await refreshScheduledReminder();
        } else {
          _reminderEnabled = false;
          await _settingsBox.put('reminderEnabled', false);
          notifyListeners();
        }
        await _settingsBox.put('hasPromptedReminderPermission', true);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        refreshScheduledReminder();
      });
    }

    // Load initial daily report
    fetchDailyReport(_selectedDateStr);

    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // Auth
  // -----------------------------------------------------------------------

  Future<String?> signIn({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _authService.signIn(email: email, password: password);
      if (res.user != null) {
        _user = res.user;
        notifyListeners();
        // Start background prefetch
        await _bootstrapAfterLogin(res.user!);
        return null; // success
      }
      return 'Sign in failed';
    } on AuthException catch (e) {
      // Check sign-in specific messages first: the generic mapper would
      // otherwise turn "Invalid login credentials" into a session-expired hint.
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials') || msg.contains('invalid credentials')) {
        return 'Invalid email or password. Please try again.';
      }
      if (msg.contains('email not confirmed')) {
        return 'Your email address is not verified. Please check your inbox.';
      }
      final friendly = _getFriendlyError(e.message);
      if (friendly != e.message) {
        return friendly;
      }
      return e.message;
    } catch (e) {
      return _getFriendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _clearAllState();
    notifyListeners();
  }

  void _clearAllState() {
    _user = null;
    _profile = null;
    _students = [];
    _allLogs = [];
    _studentDetails.clear();
    _acknowledgedByDate.clear();
    _dashboardData = null;
    _holidays = [];
    _institutionPeople = {'teachers': [], 'students': []};
    _absentTeachersToday = [];
    _teachers = [];
    _hasFetchedTeachers = false;
    _hasFetchedStudents = false;
    _hasFetchedDashboard = false;
    _profileBox.clear();
    _studentsBox.clear();
    _logsBox.clear();
    _dashboardBox.clear();
    _holidaysBox.clear();
    _settingsBox.delete('institutionPeople');
  }


  // -----------------------------------------------------------------------
  // Bootstrap after login
  // -----------------------------------------------------------------------

  Future<void> _bootstrapAfterLogin(User user) async {
    // 1. Fetch full profile with institution settings
    final profile = await _settingsService.fetchFullProfile(user.id);
    if (profile == null) {
      // No profile yet — check for teacher invitation
      final email = user.email ?? '';
      final accepted = await _settingsService.checkAndAcceptInvitation(email);
      if (accepted) {
        final newProfile = await _settingsService.fetchFullProfile(user.id);
        if (newProfile != null) {
          _profile = newProfile;
          _persistProfile(newProfile);
        }
      }
    } else {
      _profile = profile;
      _persistProfile(profile);
      _defaultSabaqGoal = profile.defaultSabaqGoal;
      _defaultSabqiGoal = profile.defaultSabqiGoal;
      _defaultManzilGoal = profile.defaultManzilGoal;
      _weeklyOffDays = profile.weeklyOffDays;
    }
    notifyListeners();

    // 2. Trigger background prefetch of all data
    if (_profile?.institutionId != null && _profile!.institutionId!.isNotEmpty) {
      await _prefetchAll();
    }
  }

  Future<void> _prefetchAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    final instId = _profile?.institutionId;
    if (instId == null || instId.trim().isEmpty) {
      _isSyncing = false;
      notifyListeners();
      return;
    }

    try {
      final institutionId = instId;
      final userId = _user!.id;
      final role = _profile!.role;

      // Parallel: dashboard + holidays + institution people + absences + acknowledgements
      await Future.wait([
        _fetchDashboard(),
        _fetchHolidays(institutionId),
        _fetchInstitutionPeople(institutionId),
        fetchAbsences(),
        fetchAbsentTeachersToday(),
        loadAcknowledgements(getLocalToday()),
        loadAcknowledgements(_getLastClassDayStr()),
      ]);

      // Students + logs (heavy — needs holidays first)
      await _fetchStudentsAndLogs(
        institutionId: institutionId,
        userId: userId,
        role: role,
      );
    } catch (e) {
      debugPrint('Prefetch error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Public refresh (e.g. pull-to-refresh)
  Future<void> refresh() async {
    if (_user != null && (_profile == null || _profile!.institutionId.isEmpty)) {
      final p = await _settingsService.fetchFullProfile(_user!.id);
      if (p != null) {
        _profile = p;
        _persistProfile(p);
      }
    }
    final instId = _profile?.institutionId;
    if (instId == null || instId.trim().isEmpty) {
      _hasFetchedStudents = true;
      notifyListeners();
      return;
    }
    await _prefetchAll();
  }

  Future<void> _fetchDashboard() async {
    try {
      final data = await _dashboardService.getDashboardData();
      _dashboardData = data;
      _hasFetchedDashboard = true;
      _dashboardBox.put('data', jsonEncode(data));
      notifyListeners();
    } catch (e) {
      debugPrint('Dashboard fetch error: $e');
    }
  }

  Future<void> _fetchHolidays(String institutionId) async {
    try {
      final holidays = await _settingsService.fetchHolidays(institutionId);
      _holidays = holidays;
      _holidaysBox.put('holidays', jsonEncode(holidays));
      notifyListeners();
    } catch (e) {
      debugPrint('Holidays fetch error: $e');
    }
  }

  Future<void> _fetchInstitutionPeople(String institutionId) async {
    try {
      final people = await _studentService.getInstitutionPeople(institutionId, _user!.id);
      _institutionPeople = people;
      _settingsBox.put('institutionPeople', jsonEncode(people));
      notifyListeners();
    } catch (e) {
      debugPrint('Institution people fetch error: $e');
    }
  }

  Future<void> _fetchStudentsAndLogs({
    required String institutionId,
    required String userId,
    required String role,
  }) async {
    try {
      final result = await _studentService.fetchStudentsAndLogs(
        institutionId: institutionId,
        userId: userId,
        role: role,
        holidaysSet: holidaysSet,
        weeklyOffDays: _weeklyOffDays,
        defaultSabaqGoal: _defaultSabaqGoal,
        defaultSabqiGoal: _defaultSabqiGoal,
        defaultManzilGoal: _defaultManzilGoal,
      );

      final fetchedStudents = result['students'] as List<Student>;
      for (int i = 0; i < fetchedStudents.length; i++) {
        final fs = fetchedStudents[i];
        Student? cached;
        for (final s in _students) {
          if (s.id == fs.id) {
            cached = s;
            break;
          }
        }
        if (cached != null) {
          final progress = fs.progressPercent > cached.progressPercent ? fs.progressPercent : cached.progressPercent;
          final unique = fs.uniqueCount > cached.uniqueCount ? fs.uniqueCount : cached.uniqueCount;
          final currentJuz = (fs.currentJuz != null && (cached.currentJuz == null || fs.currentJuz! > cached.currentJuz!))
              ? fs.currentJuz
              : cached.currentJuz;
          final streak = fs.streak > cached.streak ? fs.streak : cached.streak;

          fetchedStudents[i] = fs.copyWith(
            progressPercent: progress,
            uniqueCount: unique,
            currentJuz: currentJuz,
            streak: streak,
          );
        }
      }
      _students = fetchedStudents;
      _allLogs = result['logs'] as List<SabaqLog>;
      final details = result['studentDetails'] as Map<String, Map<String, dynamic>>;
      _studentDetails.addAll(details);
      _hasFetchedStudents = true;

      // Load initial daily report
      await fetchDailyReport(_selectedDateStr);

      // Persist to Hive
      _studentsBox.put('students', jsonEncode(_students.map((s) => s.toMap()).toList()));
      _logsBox.put('logs', jsonEncode(_allLogs.map((l) => l.toMap()).toList()));
      _studentsBox.put('details', jsonEncode(_studentDetails));

      refreshScheduledReminder(); // Refresh reminder notification with updated count
      notifyListeners();
    } catch (e) {
      debugPrint('Students fetch error: $e');
    } finally {
      _hasFetchedStudents = true;
      notifyListeners();
    }
  }

  // -----------------------------------------------------------------------
  // Onboarding
  // -----------------------------------------------------------------------

  Future<String?> createInstitutionAndProfile({
    required String institutionName,
    required String fullName,
  }) async {
    try {
      final userId = _user!.id;
      final institutionId = await _settingsService.createInstitution(institutionName);
      await _settingsService.linkProfileToInstitution(
        userId: userId,
        institutionId: institutionId,
        fullName: fullName,
        role: 'admin',
      );
      final profile = await _settingsService.fetchFullProfile(userId);
      if (profile != null) {
        _profile = profile;
        _persistProfile(profile);
        notifyListeners();
        _prefetchAll();
      }
      return null;
    } catch (e) {
      return _getFriendlyError(e);
    }
  }

  // -----------------------------------------------------------------------
  // Log Lesson — Optimistic UI
  // -----------------------------------------------------------------------
  //
  // All three operations (submit / merge / delete) follow the same pattern:
  //   1. Snapshot current state for rollback.
  //   2. Apply change locally to _allLogs immediately.
  //   3. Recompute the affected Student from local logs (pure, no network).
  //   4. Persist optimistic state to Hive.
  //   5. notifyListeners() → UI refreshes in < 100 ms.
  //   6. Fire Supabase call in background.
  //   7. On success → kick off a silent background re-fetch for full consistency.
  //   8. On failure  → roll back to snapshot, notifyListeners(), return error.

  Future<String?> submitLog({
    required String studentId,
    required String date,
    required String sabaq,
    required dynamic manzil,
    required String status,
  }) async {
    // --- 1. Snapshot ---
    final prevLogs = List<SabaqLog>.from(_allLogs);
    final prevStudents = List<Student>.from(_students);

    // --- 2. Build optimistic log (temp id, will be replaced on re-fetch) ---
    final tempId = 'optimistic_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticLog = SabaqLog(
      id: tempId,
      studentId: studentId,
      teacherId: _user?.id ?? '',
      teacherName: _profile?.fullName ?? '',
      studentName: '',
      date: date,
      sabaq: sabaq,
      manzil: manzil,
      status: status,
      createdAt: DateTime.now(),
    );

    // Remove any existing log for this student+date (submit replaces)
    _allLogs.removeWhere((l) =>
        l.studentId == studentId &&
        l.date == date &&
        l.status != 'baseline' &&
        l.status != 'baseline_sabqi');
    _allLogs.add(optimisticLog);

    // --- 3. Recompute affected student ---
    _recomputeStudentFromLogs(studentId);

    // --- 4. Persist to Hive ---
    _persistLogsToHive();

    // --- 5. Notify UI ---
    notifyListeners();

    // --- 6 & 7. Background Supabase sync ---
    try {
      await _studentService.submitLog(
        studentId: studentId,
        date: date,
        sabaq: sabaq,
        manzil: manzil,
        status: status,
      );
      // Targeted sync: only pull this student's logs, not the whole institution
      syncSingleStudentLogs(studentId);
      _fetchDashboard();
      return null;
    } catch (e) {
      // --- 8. Rollback ---
      _allLogs
        ..clear()
        ..addAll(prevLogs);
      _students
        ..clear()
        ..addAll(prevStudents);
      _persistLogsToHive();
      notifyListeners();
      return _getFriendlyError(e);
    }
  }

  Future<String?> mergeLog({
    required String studentId,
    required String date,
    String? sabaq,
    dynamic manzil,
    String? status,
  }) async {
    // --- 1. Snapshot ---
    final prevLogs = List<SabaqLog>.from(_allLogs);
    final prevStudents = List<Student>.from(_students);

    // --- 2. Apply optimistic merge to local logs ---
    final existingIdx = _allLogs.indexWhere((l) =>
        l.studentId == studentId &&
        l.date == date &&
        l.status != 'baseline' &&
        l.status != 'baseline_sabqi');

    String finalSabaq = sabaq ?? '';
    bool shouldDelete = false;
    String? logIdToDelete;

    if (existingIdx >= 0) {
      final old = _allLogs[existingIdx];
      final existingSabaq = old.sabaq ?? '';
      if (sabaq != null && existingSabaq.isNotEmpty && !existingSabaq.startsWith('[SKIPPED') && !sabaq.startsWith('[SKIPPED')) {
        final start = _parseStartFromSabaq(existingSabaq);
        final end = _parseEndFromSabaq(sabaq);
        if (start != null && end != null) {
          final startSurah = findQuranSurah(start.surahName);
          final endSurah = findQuranSurah(end.surahName);
          if (startSurah != null && endSurah != null) {
            final pageSpan = calculatePageSpanFromAyahs(startSurah.number, start.ayahNum, endSurah.number, end.ayahNum);
            final lines = (pageSpan * 15.0).round().clamp(0, 9060);
            final startPage = getPageForAyah(startSurah.number, start.ayahNum);
            final endPage = getPageForAyah(endSurah.number, end.ayahNum);
            final pageRangeStr = startPage == endPage ? '$endPage' : '$startPage-$endPage';
            final fromSurahName = startSurah.name;
            final toSurahName = endSurah.name;
            final heardMatch = RegExp(r'Heard by:\s*(.+)').firstMatch(sabaq);
            final heardBy = heardMatch != null ? heardMatch.group(1) : null;

            if (startSurah.number == endSurah.number) {
              finalSabaq = 'Surah $fromSurahName (Ayah ${start.ayahNum}-${end.ayahNum}) [Page $pageRangeStr] - $lines Line(s) (${pageSpan.toStringAsFixed(2)} Page)';
            } else {
              finalSabaq = '$fromSurahName (${start.ayahNum}) to $toSurahName (${end.ayahNum}) [Page $pageRangeStr] - $lines Line(s) (${pageSpan.toStringAsFixed(2)} Page)';
            }
            if (heardBy != null && heardBy.trim().isNotEmpty) {
              finalSabaq += ' - Heard by: $heardBy';
            }
          }
        }
      } else {
        finalSabaq = sabaq ?? old.sabaq ?? '';
      }

      final mergedManzil = manzil ?? old.manzil;
      final mergedStatus = status ?? old.status;

      // Check if completely empty
      final parsed = mergedManzil is Map 
          ? mergedManzil 
          : (mergedManzil is String && (mergedManzil as String).isNotEmpty 
              ? json.decode(mergedManzil as String) 
              : {});
      final hasSabaq = finalSabaq.trim().isNotEmpty;
      final hasSabqi = parsed['sabqi'] != null && (parsed['sabqi'] as List).isNotEmpty;
      final hasManzilPages = parsed['manzilPages'] != null && (parsed['manzilPages'] as List).isNotEmpty;
      final hasManzilText = parsed['manzil'] != null && (parsed['manzil'] as String).trim().isNotEmpty;
      final hasStatus = mergedStatus != 'good' && mergedStatus != 'present' && mergedStatus.isNotEmpty;

      if (!hasSabaq && !hasSabqi && !hasManzilPages && !hasManzilText && !hasStatus) {
        shouldDelete = true;
        logIdToDelete = old.id;
        _allLogs.removeAt(existingIdx);
      } else {
        _allLogs[existingIdx] = SabaqLog(
          id: old.id,
          studentId: old.studentId,
          teacherId: old.teacherId,
          teacherName: old.teacherName,
          studentName: old.studentName,
          date: old.date,
          sabaq: finalSabaq,
          manzil: mergedManzil,
          status: mergedStatus,
          createdAt: old.createdAt,
        );
      }
    } else {
      final tempId = 'optimistic_${DateTime.now().millisecondsSinceEpoch}';
      _allLogs.add(SabaqLog(
        id: tempId,
        studentId: studentId,
        teacherId: _user?.id ?? '',
        teacherName: _profile?.fullName ?? '',
        studentName: '',
        date: date,
        sabaq: sabaq ?? '',
        manzil: manzil,
        status: status ?? 'good',
        createdAt: DateTime.now(),
      ));
    }

    // --- 3. Recompute affected student ---
    _recomputeStudentFromLogs(studentId);

    // --- 4. Persist to Hive ---
    _persistLogsToHive();
    refreshScheduledReminder(); // Refresh reminder notification with updated count

    // --- 5. Notify UI ---
    notifyListeners();

    // --- 6 & 7. Background sync ---
    try {
      if (shouldDelete && logIdToDelete != null) {
        await _studentService.deleteLog(logIdToDelete);
      } else {
        await _studentService.mergeLog(
          studentId: studentId,
          date: date,
          sabaq: sabaq,
          manzil: manzil,
          status: status,
          institutionId: _profile?.institutionId,
        );
      }
      // Targeted sync: only pull this student's logs, not the whole institution
      syncSingleStudentLogs(studentId);
      _fetchDashboard();
      return null;
    } catch (e) {
      // --- 8. Rollback ---
      _allLogs
        ..clear()
        ..addAll(prevLogs);
      _students
        ..clear()
        ..addAll(prevStudents);
      _persistLogsToHive();
      notifyListeners();
      return _getFriendlyError(e);
    }
  }

  Future<String?> deleteLog(String logId, String studentId) async {
    // --- 1. Snapshot ---
    final prevLogs = List<SabaqLog>.from(_allLogs);
    final prevStudents = List<Student>.from(_students);

    // --- 2. Remove optimistically ---
    _allLogs.removeWhere((l) => l.id == logId);

    // --- 3. Recompute affected student ---
    _recomputeStudentFromLogs(studentId);

    // --- 4. Persist to Hive ---
    _persistLogsToHive();
    refreshScheduledReminder(); // Refresh reminder notification with updated count

    // --- 5. Notify UI ---
    notifyListeners();

    // --- 6 & 7. Background sync ---
    try {
      await _studentService.deleteLog(logId);
      // Targeted sync: only pull this student's logs, not the whole institution
      syncSingleStudentLogs(studentId);
      _fetchDashboard();
      return null;
    } catch (e) {
      // --- 8. Rollback ---
      _allLogs
        ..clear()
        ..addAll(prevLogs);
      _students
        ..clear()
        ..addAll(prevStudents);
      _persistLogsToHive();
      notifyListeners();
      return _getFriendlyError(e);
    }
  }

  String _formatPagesString(List<int> pages) {
    if (pages.isEmpty) return '';
    pages.sort();
    List<String> segments = [];
    int start = pages[0];
    int prev = pages[0];
    
    for (int i = 1; i < pages.length; i++) {
      int current = pages[i];
      if (current == prev + 1) {
        prev = current;
      } else {
        if (start == prev) {
          segments.add('$start');
        } else {
          segments.add('$start-$prev');
        }
        start = current;
        prev = current;
      }
    }
    if (start == prev) {
      segments.add('$start');
    } else {
      segments.add('$start-$prev');
    }
    return 'Page ${segments.join(', ')}';
  }

  /// Remove daily logs for a specific student that contain sabaq, sabqi, or manzil entries within a target Juz
  Future<String?> clearSabaqLogsForJuz(String studentId, int juzNum) async {
    _isLoading = true;
    notifyListeners();
    try {
      final logs = getLogsForStudent(studentId);
      final logsNotBaseline = logs.where((l) => l.status != 'baseline' && l.status != 'baseline_sabqi').toList();
      print('clearSabaqLogsForJuz: starting for student $studentId, Juz $juzNum. Total daily logs: ${logsNotBaseline.length}');
      
      int processedCount = 0;
      for (final log in logsNotBaseline) {
        bool modified = false;
        String sabaqVal = log.sabaq ?? '';
        
        // 1. Check/Clear Sabaq
        if (sabaqVal.isNotEmpty) {
          final sabaqPages = getPagesFromSabaqString(sabaqVal);
          final remainingPages = sabaqPages.where((p) => getJuzForPage(p) != juzNum).toList();
          
          if (remainingPages.length != sabaqPages.length) {
            sabaqVal = _formatPagesString(remainingPages);
            modified = true;
          }
        }
        
        // 2. Check/Clear Sabqi and Manzil entries inside parsedManzil JSON
        var parsed = log.parsedManzil != null ? Map<String, dynamic>.from(log.parsedManzil!) : <String, dynamic>{};
        
        // Filter 'sabqi'
        if (parsed['sabqi'] is List) {
          final originalList = parsed['sabqi'] as List;
          final filteredList = originalList.where((item) {
            if (item is Map) {
              final text = item['sabaq']?.toString() ?? '';
              final match = RegExp(r'Page (\d+)').firstMatch(text);
              if (match != null) {
                final p = int.tryParse(match.group(1) ?? '');
                if (p != null && getJuzForPage(p) == juzNum) {
                  modified = true;
                  return false; // Exclude pages in target Juz
                }
              }
            }
            return true;
          }).toList();
          parsed['sabqi'] = filteredList;
        }
        
        // Filter 'manzilPages'
        if (parsed['manzilPages'] is List) {
          final originalList = parsed['manzilPages'] as List;
          final filteredList = originalList.where((item) {
            if (item is Map) {
              int? p;
              if (item['page'] is int) {
                p = item['page'] as int;
              } else {
                final text = item['sabaq']?.toString() ?? '';
                final match = RegExp(r'Page (\d+)').firstMatch(text);
                if (match != null) {
                  p = int.tryParse(match.group(1) ?? '');
                }
              }
              if (p != null && getJuzForPage(p) == juzNum) {
                modified = true;
                return false; // Exclude pages in target Juz
              }
            }
            return true;
          }).toList();
          parsed['manzilPages'] = filteredList;
        }
        
        // Filter 'manzil' text (e.g. "Juz 15")
        if (parsed['manzil'] is String) {
          final manzilStr = parsed['manzil'] as String;
          if (manzilStr.contains('Juz $juzNum')) {
            final pattern = RegExp('Juz $juzNum\\b');
            final cleaned = manzilStr.replaceAll(pattern, '').trim();
            final formatted = cleaned.replaceAll(RegExp(r',+'), ',').replaceAll(RegExp(r'^,|,+$'), '').trim();
            parsed['manzil'] = formatted;
            modified = true;
          }
        }
        
        if (modified) {
          final hasSabaq = sabaqVal.isNotEmpty;
          final hasSabqi = parsed['sabqi'] != null && (parsed['sabqi'] as List).isNotEmpty;
          final hasManzilPages = parsed['manzilPages'] != null && (parsed['manzilPages'] as List).isNotEmpty;
          final hasManzilText = parsed['manzil'] != null && (parsed['manzil'] as String).isNotEmpty;
          
          if (hasSabaq || hasSabqi || hasManzilPages || hasManzilText) {
            // Keep log but save only the filtered parts directly in service without list reloading
            await _studentService.mergeLog(
              studentId: studentId,
              date: log.date,
              sabaq: sabaqVal,
              manzil: parsed,
              institutionId: _profile?.institutionId,
            );
          } else {
            // Delete entire log if completely empty now directly in service
            await _studentService.deleteLog(log.id);
          }
          processedCount++;
        }
      }
      print('clearSabaqLogsForJuz: modified/deleted $processedCount daily logs. Refreshing...');
      
      // Refresh students
      if (_profile?.institutionId != null) {
        await _fetchStudentsAndLogs(
          institutionId: _profile!.institutionId!,
          userId: _user!.id,
          role: _profile!.role,
        );
        await _fetchDashboard();
      }
      print('clearSabaqLogsForJuz: completed successfully!');
      return null;
    } catch (e) {
      print('clearSabaqLogsForJuz: error occurred: $e');
      return _getFriendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // -----------------------------------------------------------------------
  // Students CRUD
  // -----------------------------------------------------------------------

  Future<String?> addStudent({
    required String fullName,
    String? parentName,
    String? contactNumber,
    String? teacherId,
    double? sabaqGoal,
    double? sabqiGoal,
    double? manzilGoal,
    bool isPersonal = false,
  }) async {
    try {
      await _studentService.addStudent(
        institutionId: _profile!.institutionId!,
        teacherId: teacherId,
        fullName: fullName,
        parentName: parentName,
        contactNumber: contactNumber,
        sabaqGoal: sabaqGoal,
        sabqiGoal: sabqiGoal,
        manzilGoal: manzilGoal,
        isPersonal: isPersonal,
      );
      // Refresh
      await _fetchStudentsAndLogs(
        institutionId: _profile!.institutionId!,
        userId: _user!.id,
        role: _profile!.role,
      );
      await _fetchDashboard();
      return null;
    } catch (e) {
      return _getFriendlyError(e);
    }
  }

  Future<String?> updateStudent({
    required String studentId,
    required String fullName,
    required String? parentName,
    required String? contactNumber,
    required String? teacherId,
    required double? sabaqGoal,
    required double? sabqiGoal,
    required double? manzilGoal,
    required bool isPersonal,
  }) async {
    try {
      await _studentService.updateStudent(
        studentId: studentId,
        fullName: fullName,
        parentName: parentName,
        contactNumber: contactNumber,
        teacherId: teacherId,
        sabaqGoal: sabaqGoal,
        sabqiGoal: sabqiGoal,
        manzilGoal: manzilGoal,
        isPersonal: isPersonal,
      );
      // Refresh
      await _fetchStudentsAndLogs(
        institutionId: _profile!.institutionId,
        userId: _user!.id,
        role: _profile!.role,
      );
      await _fetchDashboard();
      return null;
    } catch (e) {
      return _getFriendlyError(e);
    }
  }

  Future<String?> deleteStudent(String studentId) async {
    try {
      await _studentService.deleteStudent(studentId);
      // Refresh
      await _fetchStudentsAndLogs(
        institutionId: _profile!.institutionId,
        userId: _user!.id,
        role: _profile!.role,
      );
      await _fetchDashboard();
      return null;
    } catch (e) {
      return _getFriendlyError(e);
    }
  }

  Future<String?> saveBaseline({
    required String studentId,
    required List<int> sabaqPages,
    required List<int> sabqiPages,
  }) async {
    try {
      final teacherId = _profile?.id ?? '';
      final institutionId = _profile?.institutionId ?? '';
      await _studentService.saveBaseline(
        studentId: studentId,
        teacherId: teacherId,
        sabaqPages: sabaqPages,
        sabqiPages: sabqiPages,
        institutionId: institutionId,
      );
      // Targeted sync: only re-fetch this student's logs
      await syncSingleStudentLogs(studentId);
      return null;
    } catch (e) {
      return _getFriendlyError(e);
    }
  }

  // -----------------------------------------------------------------------
  // Settings
  // -----------------------------------------------------------------------

  Future<String?> updateSettings({
    List<int>? weeklyOffDays,
    double? sabaqGoal,
    double? sabqiGoal,
    double? manzilGoal,
  }) async {
    try {
      await _settingsService.updateInstitutionSettings(
        institutionId: _profile!.institutionId!,
        weeklyOffDays: weeklyOffDays,
        defaultSabaqGoal: sabaqGoal,
        defaultSabqiGoal: sabqiGoal,
        defaultManzilGoal: manzilGoal,
      );
      if (weeklyOffDays != null) _weeklyOffDays = weeklyOffDays;
      if (sabaqGoal != null) _defaultSabaqGoal = sabaqGoal;
      if (sabqiGoal != null) _defaultSabqiGoal = sabqiGoal;
      if (manzilGoal != null) _defaultManzilGoal = manzilGoal;
      notifyListeners();
      return null;
    } catch (e) {
      return _getFriendlyError(e);
    }
  }

  Future<String?> addHoliday(String date) async {
    try {
      await _settingsService.addHoliday(_profile!.institutionId!, date);
      _holidays.add(date);
      _holidaysBox.put('holidays', jsonEncode(_holidays));
      notifyListeners();
      return null;
    } catch (e) {
      return _getFriendlyError(e);
    }
  }

  Future<String?> removeHoliday(String date) async {
    try {
      await _settingsService.removeHoliday(_profile!.institutionId!, date);
      _holidays.remove(date);
      _holidaysBox.put('holidays', jsonEncode(_holidays));
      notifyListeners();
      return null;
    } catch (e) {
      return _getFriendlyError(e);
    }
  }

  Future<void> fetchAbsences() async {
    if (_profile == null) return;
    try {
      final res = await _studentService.fetchScheduledAbsences(_user!.id);
      _scheduledAbsences = res;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching scheduled absences: $e');
    }
  }

  Future<void> fetchAbsentTeachersToday() async {
    if (_profile == null || _profile!.institutionId == null) return;
    try {
      final todayStr = getLocalToday();
      final res = await _studentService.fetchAbsentTeachersToday(_profile!.institutionId!, todayStr);
      _absentTeachersToday = res;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching absent teachers today: $e');
    }
  }

  Future<String?> addAbsence(String date) async {
    if (_profile == null || _profile!.institutionId == null) return 'Profile or institution not found';
    try {
      await _studentService.markTeacherAbsence(
        teacherId: _user!.id,
        institutionId: _profile!.institutionId!,
        date: date,
        isAbsent: true,
      );
      await fetchAbsences();
      
      // Refresh students list because coverage students must show up or disappear
      final instId = _profile!.institutionId!;
      final userId = _user!.id;
      final role = _profile!.role;
      await _fetchStudentsAndLogs(
        institutionId: instId,
        userId: userId,
        role: role,
      );
      
      // Refresh dashboard data
      await _fetchDashboard();
      
      return null;
    } catch (e) {
      return _getFriendlyError(e);
    }
  }

  Future<String?> removeAbsence(String date) async {
    if (_profile == null || _profile!.institutionId == null) return 'Profile or institution not found';
    try {
      await _studentService.markTeacherAbsence(
        teacherId: _user!.id,
        institutionId: _profile!.institutionId!,
        date: date,
        isAbsent: false,
      );
      await fetchAbsences();

      // Refresh students list
      final instId = _profile!.institutionId!;
      final userId = _user!.id;
      final role = _profile!.role;
      await _fetchStudentsAndLogs(
        institutionId: instId,
        userId: userId,
        role: role,
      );

      // Refresh dashboard data
      await _fetchDashboard();

      return null;
    } catch (e) {
      return _getFriendlyError(e);
    }
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  void _persistProfile(AppProfile p) {
    _profileBox.put('profile', jsonEncode(p.toMap()));
  }

  /// Get logs for a specific student (from cache or re-derive)
  List<SabaqLog> getLogsForStudent(String studentId) {
    return _allLogs.where((l) => l.studentId == studentId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// After a successful Supabase log write, pulls fresh logs for only the affected
  /// student and recomputes their derived fields — 1 query instead of N+2.
  Future<void> syncSingleStudentLogs(String studentId) async {
    try {
      final freshLogs = await _studentService.fetchLogsForStudent(studentId);

      // Replace only this student's logs in the shared list
      _allLogs.removeWhere((l) => l.studentId == studentId);
      _allLogs.addAll(freshLogs);

      // Update the student details cache too
      if (_studentDetails.containsKey(studentId)) {
        _studentDetails[studentId]!['logs'] =
            freshLogs.map((l) => l.toMap()).toList();
        _studentsBox.put('details', jsonEncode(_studentDetails));
      }

      // Recompute derived Student fields from the now-fresh logs
      _recomputeStudentFromLogs(studentId);

      // Persist and notify
      _persistLogsToHive();
      refreshScheduledReminder(); // Refresh reminder notification with updated count
      notifyListeners();
    } catch (e) {
      // Non-fatal: optimistic state is already correct; next pull-to-refresh
      // will reconcile if needed.
      debugPrint('Single-student sync error for $studentId: $e');
    }
  }

  /// Persist Hive snapshot of logs + students (called after every optimistic write).
  void _persistLogsToHive() {
    _logsBox.put('logs', jsonEncode(_allLogs.map((l) => l.toMap()).toList()));
    _studentsBox.put('students', jsonEncode(_students.map((s) => s.toMap()).toList()));
  }

  /// Recompute a single Student's derived fields from the current in-memory
  /// _allLogs — no network call. Mirrors the logic in StudentService.
  void _recomputeStudentFromLogs(String studentId) {
    final idx = _students.indexWhere((s) => s.id == studentId);
    if (idx < 0) return;

    final student = _students[idx];
    final studentLogs = getLogsForStudent(studentId);
    final today = getLocalToday();

    // Goals
    final sGoal = student.sabaqGoal ?? _defaultSabaqGoal;
    final sqGoal = student.sabqiGoal ?? _defaultSabqiGoal;
    final mGoal = student.manzilGoal ?? _defaultManzilGoal;

    // Unique memorized pages
    final uniquePages = <int>{};
    final sabaqUniquePages = <int>{};
    for (final log in studentLogs) {
      final sabaqPages = getPagesFromSabaqString(log.sabaq);
      uniquePages.addAll(sabaqPages);
      sabaqUniquePages.addAll(sabaqPages);
      final parsed = log.parsedManzil;
      if (parsed != null) {
        if (parsed['manzilPages'] is List) {
          for (final item in parsed['manzilPages'] as List) {
            final p = item is Map ? (item['page'] as num?)?.toInt() : null;
            if (p != null && p >= 1 && p <= 604) uniquePages.add(p);
          }
        }
        if (parsed['manzil'] is String) {
          final juzRegex = RegExp(r'Juz\s+(\d+)');
          for (final m in juzRegex.allMatches(parsed['manzil'] as String)) {
            final num = int.tryParse(m.group(1) ?? '');
            if (num != null && num >= 1 && num <= 30) {
              uniquePages.addAll(getPagesForJuz(num));
            }
          }
        }
        if (parsed['sabqi'] is List) {
          for (final item in parsed['sabqi'] as List) {
            final text = item is String ? item : (item is Map ? (item['sabaq'] as String?) : null);
            if (text != null) {
              final m = RegExp(r'^Page (\d+)').firstMatch(text);
              if (m != null) {
                final p = int.tryParse(m.group(1) ?? '');
                if (p != null) uniquePages.add(p);
              }
            }
          }
        }
      }
    }

    // Juz progress
    double totalJuzCompleted = 0;
    for (int j = 1; j <= 30; j++) {
      final pages = getPagesForJuz(j);
      final memorized = pages.where((p) => uniquePages.contains(p)).length;
      totalJuzCompleted += memorized / pages.length;
    }
    final uniqueCount = totalJuzCompleted.floor().clamp(0, 30);
    final progressPercent = ((uniquePages.length / 604) * 100).round();

    // Current Juz
    int? maxJuz;
    if (sabaqUniquePages.isNotEmpty) {
      int highest = 0;
      for (final p in sabaqUniquePages) {
        final j = getJuzForPage(p);
        if (j > highest) highest = j;
      }
      maxJuz = highest > 0 ? highest : null;
    }

    // Today's log
    final logsNotBaseline = studentLogs
        .where((l) => l.status != 'baseline' && l.status != 'baseline_sabqi')
        .toList();
    final todayLog = logsNotBaseline.where((l) {
      final d = l.date.contains('T') ? l.date.split('T')[0] : l.date;
      return d == today;
    }).firstOrNull;

    final todayParsedManzil = todayLog?.parsedManzil;
    final isAbsentOrSick =
        todayLog?.status == 'absent' || todayLog?.status == 'sick' || todayLog?.status == 'other' || todayLog?.status == 'no_lesson';
    final todaySabaqPages = (!isAbsentOrSick && todayLog?.sabaq != null)
        ? getPagesCountFromSabaqString(todayLog!.sabaq!)
        : 0.0;
    final todaySabqiPages = (!isAbsentOrSick && todayParsedManzil != null)
        ? ((todayParsedManzil['sabqi'] as List?)?.length ?? 0).toDouble()
        : 0.0;
    double todayManzilPages = 0.0;
    if (!isAbsentOrSick && todayParsedManzil != null) {
      if (todayParsedManzil['manzilPages'] is List) {
        todayManzilPages +=
            (todayParsedManzil['manzilPages'] as List).length.toDouble();
      }
      if (todayParsedManzil['manzil'] is String) {
        final matches = RegExp(r'Juz\s+\d+')
            .allMatches(todayParsedManzil['manzil'] as String);
        todayManzilPages += matches.length * 20.0;
      }
    }

    // Streak
    final logMaps = studentLogs.map((l) => l.toMap()).toList();
    final streak = computeStreak(
        logMaps, holidaysSet, _weeklyOffDays, sGoal, sqGoal, mGoal,
        isHafiz: progressPercent >= 100);

    _students[idx] = student.copyWith(
      progressPercent: progressPercent,
      uniqueCount: uniqueCount,
      currentJuz: maxJuz,
      streak: streak,
      todayStatus: todayLog?.status,
      todayLogId: todayLog?.id,
      todaySabaqPages: todaySabaqPages,
      todaySabqiPages: todaySabqiPages,
      todayManzilPages: todayManzilPages,
    );
  }

  /// Get the Sabqi pages list (Sabaq Para pool) with repetition counts — exact match to web app sabqiRepetitionData
  List<Map<String, dynamic>> getSabqiPagesForStudent(String studentId, {int limit = 100, String? beforeDate}) {
    final logs = getLogsForStudent(studentId);
    final todayStr = beforeDate ?? getLocalToday();

    // 1. Filter sabaq logs on or before today
    final sabaqLogs = logs.where((l) =>
      l.sabaq != null &&
      l.sabaq!.isNotEmpty &&
      (l.date.compareTo(todayStr) <= 0 || l.status == 'baseline_sabqi' || l.status == 'baseline')
    ).toList();

    // Sort by date descending to preserve the correct calendar study sequence.
    // Use createdAt descending as a fallback when dates are equal (e.g. bulk baseline insertions).
    sabaqLogs.sort((a, b) {
      final cmp = b.date.compareTo(a.date);
      if (cmp != 0) return cmp;
      return b.createdAt.compareTo(a.createdAt);
    });

    final seen = <int>{};
    final uniqueSabaqPages = <int>[];

    for (final log in sabaqLogs) {
      final pages = getPagesFromSabaqString(log.sabaq ?? '');
      for (final p in pages) {
        if (!seen.contains(p)) {
          seen.add(p);
          uniqueSabaqPages.add(p);
        }
      }
    }

    if (uniqueSabaqPages.isEmpty) {
      // Fallback: search all logs for any Sabaq pages if date filter returned empty
      for (final log in logs) {
        if (log.status == 'baseline') continue;
        final pages = getPagesFromSabaqString(log.sabaq ?? '');
        for (final p in pages) {
          if (!seen.contains(p)) {
            seen.add(p);
            uniqueSabaqPages.add(p);
          }
        }
      }
    }

    // Determine current active Juz ID from student's latest sabaq log page
    int? activeJuzId;
    if (uniqueSabaqPages.isNotEmpty) {
      final latestPage = uniqueSabaqPages.first; // first in chronological order from sabaqLogs
      final info = getSabaqiPageInfo(latestPage);
      activeJuzId = info['juz'] as int?;
    }

    // Find today's sabaq pages and exclude them from the pool so that we have exactly 20 other pages
    final todayLog = logs.firstWhere(
      (l) => l.date == todayStr && l.sabaq.isNotEmpty,
      orElse: () => SabaqLog(
        id: '',
        studentId: '',
        teacherId: '',
        teacherName: '',
        studentName: '',
        date: '',
        sabaq: '',
        manzil: null,
        status: '',
        createdAt: DateTime.now(),
      ),
    );
    final todaySabaqPages = getPagesFromSabaqString(todayLog.sabaq);
    uniqueSabaqPages.removeWhere((p) => todaySabaqPages.contains(p));

    // Take the 20 most recently memorized pages (excluding today's sabaq)
    final sabaqParaPages = uniqueSabaqPages.take(20).toList();

    // Sort pages: pages from active Juz first (ordered by study sequence), and preceding/older Juzzes last (ascending)
    sabaqParaPages.sort((a, b) {
      final juzA = getSabaqiPageInfo(a)['juz'] as int?;
      final juzB = getSabaqiPageInfo(b)['juz'] as int?;
      if (juzA == activeJuzId && juzB != activeJuzId) return -1;
      if (juzB == activeJuzId && juzA != activeJuzId) return 1;
      return a.compareTo(b);
    });

    // Count repetition frequency for each page in sabqi log records
    final counts = <int, int>{};
    for (final p in sabaqParaPages) {
      counts[p] = 0;
    }

    for (final log in logs) {
      final parsed = log.parsedManzil;
      if (parsed != null && parsed['sabqi'] is List) {
        for (final item in parsed['sabqi'] as List) {
          final text = item is String ? item : (item is Map ? (item['sabaq'] as String?) : null);
          if (text != null) {
            final m = RegExp(r'Page (\d+)').firstMatch(text);
            if (m != null) {
              final p = int.tryParse(m.group(1) ?? '');
              if (p != null && counts.containsKey(p)) {
                counts[p] = (counts[p] ?? 0) + 1;
              }
            }
          }
        }
      }
    }

    return sabaqParaPages.map((page) {
      final info = getSabaqiPageInfo(page);
      final c = counts[page] ?? 0;
      final level = c == 0 ? 'critical' : c < 3 ? 'warning' : c < 5 ? 'good' : 'mastered';
      return {
        'page': page,
        'juz': info['juz'],
        'surahName': info['surahName'],
        'reps': c,
        'level': level,
      };
    }).toList();
  }

  List<Map<String, dynamic>> getManzilPagesForStudent(String studentId) {
    final logs = getLogsForStudent(studentId);
    final todayStr = getLocalToday();

    // Collect all pages memorized or logged by the student
    final memorizedPages = <int>{};

    // 1. Collect baseline pages
    for (final log in logs) {
      if ((log.status == 'baseline' || log.status == 'baseline_sabqi') && log.sabaq != null) {
        final pages = getPagesFromSabaqString(log.sabaq ?? '');
        memorizedPages.addAll(pages);
      }
    }

    // 2. Collect daily Sabaq pages (excluding today)
    for (final log in logs) {
      if (log.sabaq == null || log.sabaq!.isEmpty) continue;
      if (log.status == 'baseline' || log.status == 'baseline_sabqi') continue;
      if (log.date.compareTo(todayStr) >= 0) continue; // exclude today
      final pages = getPagesFromSabaqString(log.sabaq ?? '');
      memorizedPages.addAll(pages);
    }

    // 3. Collect pages from manzilPages logs to ensure manually edited/revised pages are included
    for (final log in logs) {
      final parsed = log.parsedManzil;
      if (parsed != null && parsed['manzilPages'] is List) {
        for (final item in parsed['manzilPages'] as List) {
          final p = item is Map ? (item['page'] as num?)?.toInt() : null;
          if (p != null && p >= 1 && p <= 604) {
            memorizedPages.add(p);
          }
        }
      }
    }

    // Determine which Juzs are fully completed (all pages of the Juz are in memorizedPages)
    final graduated = <int>[];
    for (int juz = 1; juz <= 30; juz++) {
      final juzPages = getPagesForJuz(juz);
      final isJuzCompleted = juzPages.every((p) => memorizedPages.contains(p));
      if (isJuzCompleted) {
        graduated.addAll(juzPages);
      }
    }

    // Sort final list by page number
    graduated.sort();

    return graduated.map((page) {
      final info = getSabaqiPageInfo(page);
      return {'page': page, 'juz': info['juz'], 'surahName': info['surahName']};
    }).toList();
  }

  /// Compute Memory Freshness status per Juz (1..30) matching web app algorithm
  List<Map<String, dynamic>> getJuzMemoryStatusForStudent(String studentId) {
    final logs = getLogsForStudent(studentId);
    final pageFreshness = <int, Map<String, dynamic>>{};

    for (int p = 1; p <= 604; p++) {
      pageFreshness[p] = {'level': 'never', 'daysAgo': null};
    }

    // Pass 1: baseline logs -> 'studied'
    for (final log in logs) {
      if ((log.status == 'baseline' || log.status == 'baseline_sabqi') && log.sabaq != null) {
        final pages = getPagesFromSabaqString(log.sabaq ?? '');
        for (final p in pages) {
          if (pageFreshness.containsKey(p)) {
            pageFreshness[p] = {'level': 'studied', 'daysAgo': 9999};
          }
        }
      }
    }

    final levelPriority = {
      'never': 0,
      'studied': 1,
      'neglected': 2,
      'weak': 3,
      'stale': 4,
      'fresh': 5,
    };

    final now = DateTime.now();

    // Pass 2: real logs (Sabaq, Sabqi, Manzil)
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
          if (pageFreshness.containsKey(p)) {
            pageFreshness[p] = {'level': level, 'daysAgo': diffDays};
          }
        }
      }

      final parsed = log.parsedManzil;
      if (parsed != null) {
        if (parsed['manzilPages'] is List) {
          for (final item in parsed['manzilPages'] as List) {
            final p = item is Map ? (item['page'] as num?)?.toInt() : null;
            if (p != null && pageFreshness.containsKey(p)) {
              pageFreshness[p] = {'level': level, 'daysAgo': diffDays};
            }
          }
        }
        if (parsed['sabqi'] is List) {
          for (final item in parsed['sabqi'] as List) {
            final text = item is String ? item : (item is Map ? (item['sabaq'] as String?) : null);
            if (text != null) {
              final m = RegExp(r'Page (\d+)').firstMatch(text);
              if (m != null) {
                final p = int.tryParse(m.group(1) ?? '');
                if (p != null && pageFreshness.containsKey(p)) {
                  pageFreshness[p] = {'level': level, 'daysAgo': diffDays};
                }
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
                if (pageFreshness.containsKey(p)) {
                  pageFreshness[p] = {'level': level, 'daysAgo': diffDays};
                }
              }
            }
          }
        }
      }
    }

    final result = <Map<String, dynamic>>[];

    for (int j = 1; j <= 30; j++) {
      final juzPages = getPagesForJuz(j);
      final memorizedPages = juzPages.where((p) => pageFreshness[p]?['level'] != 'never').toList();

      String level = 'never';
      int? daysAgo;

      if (memorizedPages.isNotEmpty) {
        String worstLevel = 'fresh';
        int? maxDays;

        for (final p in memorizedPages) {
          final pf = pageFreshness[p]!;
          final pLevel = pf['level'] as String;
          if ((levelPriority[pLevel] ?? 0) < (levelPriority[worstLevel] ?? 0)) {
            worstLevel = pLevel;
          }
          final dAgo = pf['daysAgo'] as int?;
          if (dAgo != null && (maxDays == null || dAgo > maxDays)) {
            maxDays = dAgo;
          }
        }

        level = worstLevel;
        daysAgo = maxDays;
      }

      // Calculate Juz repetition count as the minimum completed repetition count across all memorized pages of this Juz
      int minReps = 0;
      if (memorizedPages.isNotEmpty) {
        final allPageCounts = getAllPagesRepeatCountsForStudent(studentId);
        minReps = memorizedPages.map((p) => allPageCounts[p] ?? 0).reduce(math.min);
      }

      final milestone = getJuzMilestoneForStudent(studentId);
      final activeJuzId = milestone?['id'] as int?;
      if (j == activeJuzId) {
        level = 'active';
      }

      int freshPercent = 0;
      if (memorizedPages.isNotEmpty) {
        final firstHalfPages = j == 1
            ? [for (int i = 1; i <= 11; i++) i]
            : j == 30
                ? [for (int i = 582; i <= 593; i++) i]
                : [for (int i = (j - 1) * 20 + 2; i <= (j - 1) * 20 + 11; i++) i];

        final secondHalfPages = j == 1
            ? [for (int i = 12; i <= 21; i++) i]
            : j == 30
                ? [for (int i = 594; i <= 604; i++) i]
                : [for (int i = (j - 1) * 20 + 12; i <= j * 20 + 1; i++) i];

        final firstHalfHealthy = firstHalfPages.every((p) =>
            pageFreshness[p]?['level'] == 'fresh' || pageFreshness[p]?['level'] == 'stale');
        final secondHalfHealthy = secondHalfPages.every((p) =>
            pageFreshness[p]?['level'] == 'fresh' || pageFreshness[p]?['level'] == 'stale');

        if (firstHalfHealthy || secondHalfHealthy) {
          final healthyPagesCount = memorizedPages.where((p) =>
              pageFreshness[p]?['level'] == 'fresh' || pageFreshness[p]?['level'] == 'stale').length;
          freshPercent = ((healthyPagesCount / memorizedPages.length) * 100).round();
        }
      }

      result.add({
        'juz': j,
        'level': level,
        'daysAgo': daysAgo,
        'memorizedPagesCount': memorizedPages.length,
        'revisionCount': minReps,
        'freshPercent': freshPercent,
      });
    }

    return result;
  }

  /// Compute pagewise repeat counts for pages 1..604 matching web app allPagesRepeatCounts
  Map<int, int> getAllPagesRepeatCountsForStudent(String studentId) {
    final logs = getLogsForStudent(studentId);
    final counts = <int, int>{for (int p = 1; p <= 604; p++) p: 0};

    for (final log in logs) {
      if (log.status == 'baseline' || log.status == 'baseline_sabqi') continue;
      final parsed = log.parsedManzil;

      if (parsed != null) {
        if (parsed['sabqi'] is List) {
          for (final item in parsed['sabqi'] as List) {
            final text = item is String ? item : (item is Map ? (item['sabaq'] as String?) : null);
            if (text != null) {
              final m = RegExp(r'Page (\d+)').firstMatch(text);
              if (m != null) {
                final p = int.tryParse(m.group(1) ?? '');
                if (p != null && p >= 1 && p <= 604) counts[p] = (counts[p] ?? 0) + 1;
              }
            }
          }
        }

        if (parsed['manzilPages'] is List) {
          for (final item in parsed['manzilPages'] as List) {
            final p = item is Map ? (item['page'] as num?)?.toInt() : null;
            if (p != null && p >= 1 && p <= 604) counts[p] = (counts[p] ?? 0) + 1;
          }
        }

        if (parsed['manzil'] is String) {
          final matches = RegExp(r'Juz\s+(\d+)').allMatches(parsed['manzil'] as String);
          for (final m in matches) {
            final juz = int.tryParse(m.group(1) ?? '');
            if (juz != null) {
              final pages = getPagesForJuz(juz);
              for (final p in pages) {
                if (p >= 1 && p <= 604) counts[p] = (counts[p] ?? 0) + 1;
              }
            }
          }
        }
      }
    }

    return counts;
  }

  /// Compute current Juz Milestone Goal for a student matching exact web app activeJuzId & juzMilestone logic
  Map<String, dynamic>? getJuzMilestoneForStudent(String studentId) {
    final logs = getLogsForStudent(studentId);

    // 1. Filter sabaq logs (excluding baseline completed Juzs, keeping daily sabaq and baseline_sabqi)
    final sabaqLogsWithPage = <Map<String, dynamic>>[];
    for (final l in logs) {
      if (l.sabaq != null && l.sabaq!.isNotEmpty && l.status != 'baseline') {
        final pages = getPagesFromSabaqString(l.sabaq!);
        final maxP = pages.isNotEmpty ? pages.reduce((a, b) => a > b ? a : b) : 0;
        if (maxP > 0) {
          sabaqLogsWithPage.add({'log': l, 'date': l.date, 'pNum': maxP, 'status': l.status, 'createdAt': l.createdAt});
        }
      }
    }

    int? activeJuzId;

    if (sabaqLogsWithPage.isNotEmpty) {
      // Sort by date descending to prioritize the most recent calendar study log.
      // Use createdAt descending as a fallback.
      sabaqLogsWithPage.sort((a, b) {
        final dateA = a['date'] as String;
        final dateB = b['date'] as String;
        final cmp = dateB.compareTo(dateA);
        if (cmp != 0) return cmp;
        final createA = a['createdAt'] as DateTime;
        final createB = b['createdAt'] as DateTime;
        final cmpCreate = createB.compareTo(createA);
        if (cmpCreate != 0) return cmpCreate;
        return (b['pNum'] as int).compareTo(a['pNum'] as int);
      });
      final latestActivePage = sabaqLogsWithPage[0]['pNum'] as int;
      final info = getSabaqiPageInfo(latestActivePage);
      final rawJuz = info['juz'] as int? ?? 1;

      // Check if rawJuz is completed
      final endPageOfJuz = rawJuz == 30 ? 604 : (rawJuz * 20 + 1);
      final latestSabaqStr = (sabaqLogsWithPage[0]['log'] as SabaqLog).sabaq ?? '';

      bool isCompleted = latestActivePage >= endPageOfJuz;
      if (!isCompleted && (latestSabaqStr.contains('Surah An-Nas') || latestSabaqStr.contains('Khatam'))) {
        isCompleted = true;
      }

      if (isCompleted) {
        final memorizedPages = <int>{};
        for (final log in logs) {
          final sabaqPages = getPagesFromSabaqString(log.sabaq);
          memorizedPages.addAll(sabaqPages);
          final parsed = log.parsedManzil;
          if (parsed != null) {
            if (parsed['manzilPages'] is List) {
              for (final item in parsed['manzilPages'] as List) {
                final p = item is Map ? (item['page'] as num?)?.toInt() : null;
                if (p != null && p >= 1 && p <= 604) memorizedPages.add(p);
              }
            }
            if (parsed['manzil'] is String) {
              final juzRegex = RegExp(r'Juz\s+(\d+)');
              for (final m in juzRegex.allMatches(parsed['manzil'] as String)) {
                final num = int.tryParse(m.group(1) ?? '');
                if (num != null && num >= 1 && num <= 30) {
                  memorizedPages.addAll(getPagesForJuz(num));
                }
              }
            }
            if (parsed['sabqi'] is List) {
              for (final item in parsed['sabqi'] as List) {
                final text = item is String ? item : (item is Map ? (item['sabaq'] as String?) : null);
                if (text != null) {
                  final m = RegExp(r'^Page (\d+)').firstMatch(text);
                  if (m != null) {
                    final p = int.tryParse(m.group(1) ?? '');
                    if (p != null) memorizedPages.add(p);
                  }
                }
              }
            }
          }
        }

        bool isJuzCompleted(int juzNum) {
          final juzPages = getPagesForJuz(juzNum);
          if (juzPages.isEmpty) return false;
          final count = juzPages.where((p) => memorizedPages.contains(p)).length;
          return count >= (juzPages.length * 0.8);
        }

        int nextForwards = rawJuz + 1;
        while (nextForwards <= 30 && isJuzCompleted(nextForwards)) {
          nextForwards++;
        }

        int nextBackwards = rawJuz - 1;
        while (nextBackwards >= 1 && isJuzCompleted(nextBackwards)) {
          nextBackwards--;
        }

        if (nextForwards > 30 && nextBackwards < 1) {
          activeJuzId = rawJuz; // Entire Quran completed
        } else if (nextForwards > 30) {
          activeJuzId = nextBackwards;
        } else if (nextBackwards < 1) {
          activeJuzId = nextForwards;
        } else {
          // Suggest the closer one (nearest uncompleted Juz)
          final distForwards = nextForwards - rawJuz;
          final distBackwards = rawJuz - nextBackwards;
          if (distBackwards < distForwards) {
            activeJuzId = nextBackwards;
          } else {
            activeJuzId = nextForwards;
          }
        }
      } else {
        activeJuzId = rawJuz;
      }
    }

    final activeJuz = activeJuzId ?? 1;
    final juzPages = getPagesForJuz(activeJuz);
    if (juzPages.isEmpty) return null;

    final memorizedInJuz = <int>{};
    for (final log in logs) {
      if (log.sabaq != null && log.sabaq!.isNotEmpty) {
        final pages = getPagesFromSabaqString(log.sabaq!);
        for (final p in pages) {
          if (juzPages.contains(p)) {
            memorizedInJuz.add(p);
          }
        }
      }
    }

    final count = memorizedInJuz.length;
    final total = juzPages.length;
    final percent = total > 0 ? ((count / total) * 100).round().clamp(0, 100) : 0;
    final surahInfo = getSabaqiPageInfo(juzPages.first);
    final surahName = surahInfo['surahName'] as String? ?? '';

    return {
      'id': activeJuz,
      'name': surahName,
      'count': count,
      'total': total,
      'percent': percent,
    };
  }

  /// Get available YYYY-MM months for a student matching web app availableMonths
  List<String> getAvailableMonthsForStudent(String studentId) {
    final logs = getLogsForStudent(studentId);
    final months = <String>{};
    final now = DateTime.now();
    months.add('${now.year}-${now.month.toString().padLeft(2, '0')}');

    for (final l in logs) {
      if (l.status == 'baseline' || l.status == 'baseline_sabqi') continue;
      final parts = l.date.split('-');
      if (parts.length >= 2 && parts[0] != '2000') {
        months.add('${parts[0]}-${parts[1]}');
      }
    }

    final sorted = months.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  /// Generate complete daily book table rows matching web app tableRows for a specific YYYY-MM month
  List<Map<String, dynamic>> getTableRowsForStudent(String studentId, {String? targetMonth}) {
    final logs = getLogsForStudent(studentId);
    final logMap = <String, SabaqLog>{};
    for (final l in logs) {
      if (l.status == 'baseline' || l.status == 'baseline_sabqi') continue;
      logMap[l.date] = l;
    }

    final now = DateTime.now();
    final monthStr = targetMonth ?? '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final parts = monthStr.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    // Total days in this month
    final totalDays = DateTime(year, month + 1, 0).day;
    final isCurrentMonth = now.year == year && now.month == month;
    final maxDay = isCurrentMonth ? now.day : totalDays;

    final rows = <Map<String, dynamic>>[];

    for (int dayNum = maxDay; dayNum >= 1; dayNum--) {
      final d = DateTime(year, month, dayNum);
      final dateStr = '$year-${month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
      final isWeekend = _weeklyOffDays.contains(d.weekday);
      final isHoliday = holidaysSet.contains(dateStr);

      final log = logMap[dateStr];

      if (log != null) {
        rows.add({
          'date': dateStr,
          'dateObject': d,
          'dayNum': dayNum,
          'log': log,
          'isWeekend': isWeekend,
          'isHoliday': isHoliday,
          'type': 'log',
        });
      } else {
        rows.add({
          'date': dateStr,
          'dateObject': d,
          'dayNum': dayNum,
          'log': null,
          'isWeekend': isWeekend,
          'isHoliday': isHoliday,
          'type': isHoliday ? 'holiday' : (isWeekend ? 'weekend' : 'empty'),
        });
      }
    }

    return rows;
  }

  String _getFriendlyError(dynamic e) {
    final str = e.toString().toLowerCase();
    
    // 1. Network errors
    if (str.contains('socketexception') || 
        str.contains('network') || 
        str.contains('failed host lookup') || 
        str.contains('connection failed') || 
        str.contains('clientexception') ||
        str.contains('xmlhttprequest') ||
        str.contains('network_error') ||
        str.contains('network error') ||
        str.contains('handshakeexception') ||
        str.contains('unreachable')) {
      return 'No internet connection. Please check your network and try again.';
    }
    
    // 2. Timeout errors
    if (str.contains('time-out') || str.contains('timeout')) {
      return 'Connection timed out. Please try again later.';
    }
    
    // 3. Auth/Session/Token errors - Suggest Relogin
    if (str.contains('jwt') || 
        str.contains('token') || 
        str.contains('auth') || 
        str.contains('login') || 
        str.contains('session') || 
        str.contains('not authenticated') || 
        str.contains('row-level security') || 
        str.contains('violates row-level security') ||
        str.contains('rls policy')) {
      return 'Session expired or permission denied. Please log out and log back in to resolve this issue.';
    }
    
    // 4. Database errors
    if (str.contains('postgrestexception') || str.contains('database') || str.contains('postgresql')) {
      if (str.contains('violates not-null constraint')) {
        return 'Required data is missing. Please contact support.';
      }
      return 'A database error occurred. Please try again.';
    }
    
    return '$e';
  }

  ({String surahName, int ayahNum})? _parseStartFromSabaq(String sabaq) {
    final matchA = RegExp(r'Surah\s+(.*?)\s+\(Ayah\s+(\d+)-(\d+)\)').firstMatch(sabaq);
    if (matchA != null) {
      return (
        surahName: matchA.group(1) ?? '',
        ayahNum: int.tryParse(matchA.group(2) ?? '') ?? 1,
      );
    }
    final matchB = RegExp(r'^(.*?)\s+\((\d+)\)\s+to').firstMatch(sabaq);
    if (matchB != null) {
      return (
        surahName: matchB.group(1) ?? '',
        ayahNum: int.tryParse(matchB.group(2) ?? '') ?? 1,
      );
    }
    return null;
  }

  ({String surahName, int ayahNum})? _parseEndFromSabaq(String sabaq) {
    final matchA = RegExp(r'Surah\s+(.*?)\s+\(Ayah\s+(\d+)-(\d+)\)').firstMatch(sabaq);
    if (matchA != null) {
      return (
        surahName: matchA.group(1) ?? '',
        ayahNum: int.tryParse(matchA.group(3) ?? '') ?? 1,
      );
    }
    final matchB = RegExp(r'to\s+(.*?)\s+\((\d+)\)').firstMatch(sabaq);
    if (matchB != null) {
      return (
        surahName: matchB.group(1) ?? '',
        ayahNum: int.tryParse(matchB.group(2) ?? '') ?? 1,
      );
    }
    return null;
  }


  // -----------------------------------------------------------------------
  // Teacher Management
  // -----------------------------------------------------------------------

  /// Fetch the teacher list for the current institution and the currently
  /// selected leave-report month.
  Future<void> fetchTeachers({bool forceRefresh = false}) async {
    final instId = _profile?.institutionId;
    if (instId == null || instId.isEmpty) return;
    if (!isAdmin) return;
    if (_isLoadingTeachers) return;

    _isLoadingTeachers = true;
    notifyListeners();

    try {
      final result = await _settingsService.fetchTeachers(
        institutionId: instId,
        year: _leaveReportYear,
        month: _leaveReportMonth,
      );
      _teachers = result;
      _hasFetchedTeachers = true;
    } catch (e) {
      debugPrint('[AppProvider] fetchTeachers error: $e');
    } finally {
      _isLoadingTeachers = false;
      notifyListeners();
    }
  }

  /// Change the month shown in the leave report and re-fetch teacher data.
  Future<void> setLeaveReportMonth(int year, int month) async {
    if (_leaveReportYear == year && _leaveReportMonth == month) return;
    _leaveReportYear = year;
    _leaveReportMonth = month;
    _hasFetchedTeachers = false;
    notifyListeners();
    await fetchTeachers(forceRefresh: true);
  }

  /// Invite a teacher by email (creates a teacher_invitations row).
  Future<String?> inviteTeacher({
    required String email,
    String? name,
  }) async {
    final instId = _profile?.institutionId;
    if (instId == null) return 'No institution found';
    try {
      await _settingsService.inviteTeacher(
        institutionId: instId,
        email: email,
        fullName: name,
      );
      // Refresh the teachers list — newly invited aren't active yet but this
      // keeps the list current if they have already accepted a previous invite.
      fetchTeachers(forceRefresh: true);
      return null;
    } catch (e) {
      return _getFriendlyError(e);
    }
  }

  /// Schedule an absence for any teacher (admin action).
  Future<String?> scheduleAbsenceForTeacher({
    required String teacherId,
    required String date,
  }) async {
    final instId = _profile?.institutionId;
    if (instId == null) return 'No institution found';
    try {
      await _studentService.scheduleAbsenceForTeacher(
        teacherId: teacherId,
        institutionId: instId,
        date: date,
      );
      // Refresh teacher list so the leave badge updates.
      await fetchTeachers(forceRefresh: true);
      return null;
    } catch (e) {
      return _getFriendlyError(e);
    }
  }

  /// Disable a teacher — soft removal (sets is_active = false on their profile).
  /// Caller MUST handle student reassignment before calling this.
  Future<String?> disableTeacher(String teacherId) async {
    try {
      await _settingsService.setTeacherActive(teacherId, false);
      await fetchTeachers(forceRefresh: true);
      // Remove from institution people pickers.
      final instId = _profile?.institutionId;
      if (instId != null) {
        await _fetchInstitutionPeople(instId);
      }
      return null;
    } catch (e) {
      return _getFriendlyError(e);
    }
  }

  /// Re-enable a previously disabled teacher.
  Future<String?> enableTeacher(String teacherId) async {
    try {
      await _settingsService.setTeacherActive(teacherId, true);
      await fetchTeachers(forceRefresh: true);
      final instId = _profile?.institutionId;
      if (instId != null) {
        await _fetchInstitutionPeople(instId);
      }
      return null;
    } catch (e) {
      return _getFriendlyError(e);
    }
  }


  /// Fetch absence history for a specific teacher for a given year.
  Future<List<Map<String, dynamic>>> fetchTeacherAbsenceHistory(
    String teacherId, {
    int? year,
  }) async {
    try {
      return await _settingsService.fetchTeacherAbsenceHistory(
        teacherId,
        year: year,
      );
    } catch (e) {
      debugPrint('[AppProvider] fetchTeacherAbsenceHistory error: $e');
      return [];
    }
  }

  /// Bulk-reassign a list of students to a new teacher (or null = unassigned).
  /// Used in the disable-teacher flow.
  Future<String?> updateStudents(List<String> studentIds, {String? newTeacherId}) async {
    try {
      await _studentService.reassignStudents(
        studentIds: studentIds,
        newTeacherId: newTeacherId,
      );
      // Refresh students list so UI reflects the change.
      final instId = _profile?.institutionId;
      final userId = _user?.id;
      final role = _profile?.role;
      if (instId != null && userId != null && role != null) {
        await _fetchStudentsAndLogs(institutionId: instId, userId: userId, role: role);
      }
      return null;
    } catch (e) {
      return _getFriendlyError(e);
    }
  }
}
