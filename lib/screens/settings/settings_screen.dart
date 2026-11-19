import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../utils/student_utils.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _sabaqGoalCtrl;
  late TextEditingController _sabqiGoalCtrl;
  late TextEditingController _manzilGoalCtrl;
  bool _saving = false;

  final _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    final p = context.read<AppProvider>();
    _sabaqGoalCtrl = TextEditingController(text: p.defaultSabaqGoal.toString());
    _sabqiGoalCtrl = TextEditingController(text: p.defaultSabqiGoal.toString());
    _manzilGoalCtrl = TextEditingController(text: p.defaultManzilGoal.toString());
  }

  @override
  void dispose() {
    _sabaqGoalCtrl.dispose();
    _sabqiGoalCtrl.dispose();
    _manzilGoalCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveGoals() async {
    setState(() => _saving = true);
    final provider = context.read<AppProvider>();
    final err = await provider.updateSettings(
      sabaqGoal: double.tryParse(_sabaqGoalCtrl.text),
      sabqiGoal: double.tryParse(_sabqiGoalCtrl.text),
      manzilGoal: double.tryParse(_manzilGoalCtrl.text),
    );
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? 'Settings saved!'),
        backgroundColor: err != null ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Future<void> _toggleWeeklyOffDay(int day, AppProvider provider) async {
    final current = List<int>.from(provider.weeklyOffDays);
    if (current.contains(day)) {
      current.remove(day);
    } else {
      current.add(day);
    }
    await provider.updateSettings(weeklyOffDays: current);
  }

  Future<void> _addHoliday(AppProvider provider) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    final dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    if (!mounted) return;
    final err = await provider.addHoliday(dateStr);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _addAbsence(AppProvider provider) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    final dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    if (!mounted) return;
    setState(() => _saving = true);
    final err = await provider.addAbsence(dateStr);
    setState(() => _saving = false);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _removeAbsence(String date, AppProvider provider) async {
    final todayStr = getLocalToday();
    if (date.compareTo(todayStr) < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot remove past absences'), backgroundColor: AppColors.danger),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Absence'),
        content: Text('Are you sure you want to remove the scheduled absence for $date?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    setState(() => _saving = true);
    final err = await provider.removeAbsence(date);
    setState(() => _saving = false);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isAdmin = provider.isAdmin;
    final isDark = provider.isDarkMode;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          _SectionCard(
            title: 'Profile',
            isDark: isDark,
            children: [
              _InfoRow(
                icon: Icons.person_rounded,
                label: 'Name',
                value: provider.profile?.fullName ?? '—',
                isDark: isDark,
              ),
              Divider(color: border, height: 1),
              _InfoRow(
                icon: Icons.badge_rounded,
                label: 'Role',
                value: _formatRole(provider.profile?.role),
                isDark: isDark,
              ),
              Divider(color: border, height: 1),
              _InfoRow(
                icon: Icons.account_balance_rounded,
                label: 'Institution',
                value: provider.profile?.institutionName ?? '—',
                isDark: isDark,
              ),
            ],
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),

          const SizedBox(height: 16),

          // Appearance
          _SectionCard(
            title: 'Appearance',
            isDark: isDark,
            children: [
              Row(
                children: [
                  Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Dark Mode',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textMain)),
                  ),
                  CupertinoSwitch(
                    value: isDark,
                    activeColor: AppColors.primary,
                    onChanged: (_) => provider.toggleTheme(),
                  ),
                ],
              ),
            ],
          ).animate(delay: 100.ms).fadeIn(duration: 300.ms).slideY(begin: 0.1),

          if (isAdmin) ...[
            const SizedBox(height: 16),

            // Daily Goals Section
            _SectionCard(
              title: 'Default Daily Goals',
              subtitle: 'Applied to all students without individual goals',
              isDark: isDark,
              children: [
                _GoalField(
                  label: 'Sabaq (pages)',
                  controller: _sabaqGoalCtrl,
                  icon: Icons.book_rounded,
                  color: AppColors.info,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _GoalField(
                  label: 'Sabqi Para (pages)',
                  controller: _sabqiGoalCtrl,
                  icon: Icons.history_rounded,
                  color: AppColors.warning,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _GoalField(
                  label: 'Manzil (pages)',
                  controller: _manzilGoalCtrl,
                  icon: Icons.auto_stories_rounded,
                  color: AppColors.success,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveGoals,
                    child: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save Goals'),
                  ),
                ),
              ],
            ).animate(delay: 200.ms).fadeIn(duration: 300.ms).slideY(begin: 0.1),

            const SizedBox(height: 16),

            // Weekly Off Days
            _SectionCard(
              title: 'Weekly Off Days',
              subtitle: 'Students are not expected to log on these days',
              isDark: isDark,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (day) {
                    final isSelected = provider.weeklyOffDays.contains(day);
                    return FilterChip(
                      label: Text(_dayNames[day]),
                      selected: isSelected,
                      onSelected: (_) => _toggleWeeklyOffDay(day, provider),
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : textMuted,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    );
                  }),
                ),
              ],
            ).animate(delay: 300.ms).fadeIn(duration: 300.ms).slideY(begin: 0.1),

            const SizedBox(height: 16),

            // Holidays
            _SectionCard(
              title: 'Institution Holidays',
              subtitle: 'Holidays are excluded from streak calculations',
              isDark: isDark,
              action: TextButton.icon(
                onPressed: () => _addHoliday(provider),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
              children: [
                if (provider.holidays.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No holidays added',
                        style: TextStyle(color: textMuted, fontSize: 14)),
                  )
                else
                  ...provider.holidays.map((date) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.event_rounded, color: AppColors.primary, size: 20),
                        title: Text(date,
                            style: TextStyle(fontSize: 14, color: textMain, fontWeight: FontWeight.w500)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          color: AppColors.danger,
                          onPressed: () => provider.removeHoliday(date),
                        ),
                      )),
              ],
            ).animate(delay: 400.ms).fadeIn(duration: 300.ms).slideY(begin: 0.1),

            const SizedBox(height: 16),

            // Manage Teachers entry point (admin-only)
            _ManageTeachersCard(
              isDark: isDark,
              teacherCount: provider.teachers.where((t) => t.isActive).length,
            ).animate(delay: 450.ms).fadeIn(duration: 300.ms).slideY(begin: 0.1),
          ],

          const SizedBox(height: 16),

          // Absence Scheduler
          _SectionCard(
            title: 'My Absence Scheduler',
            subtitle: 'Mark dates you will be absent. Your assigned students will be shared with other teachers on these dates.',
            isDark: isDark,
            action: TextButton.icon(
              onPressed: () => _addAbsence(provider),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
            children: [
              if (provider.scheduledAbsences.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No scheduled absences',
                      style: TextStyle(color: textMuted, fontSize: 14)),
                )
              else
                ...provider.scheduledAbsences.map((absence) {
                  final date = absence['absence_date'] as String;
                  final hasPassed = date.compareTo(getLocalToday()) < 0;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.calendar_today_rounded, 
                      color: hasPassed ? textMuted : AppColors.danger, 
                      size: 20
                    ),
                    title: Row(
                      children: [
                        Text(date,
                            style: TextStyle(
                              fontSize: 14, 
                              color: hasPassed ? textMuted : textMain, 
                              fontWeight: FontWeight.w500,
                            )),
                        if (hasPassed) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Passed',
                              style: TextStyle(
                                fontSize: 10,
                                color: textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: hasPassed
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            color: AppColors.danger,
                            onPressed: () => _removeAbsence(date, provider),
                          ),
                  );
                }),
            ],
          ).animate(delay: 450.ms).fadeIn(duration: 300.ms).slideY(begin: 0.1),

          const SizedBox(height: 16),

          // Reminders (Only for teachers/admins since students do not log progress)
          if (provider.profile?.role == 'teacher' || provider.isAdmin) ...[
            _SectionCard(
              title: 'Reminders',
              subtitle: 'Configure daily progress logging alerts',
              isDark: isDark,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Logging Reminder',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textMainDark : AppColors.textMainLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Receive a daily reminder alert to log lessons',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: provider.reminderEnabled,
                      activeColor: AppColors.primary,
                      onChanged: (val) async {
                        final err = await provider.updateReminderSettings(enabled: val);
                        if (err != null && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(err),
                              backgroundColor: AppColors.danger,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                if (provider.reminderEnabled) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  InkWell(
                    onTap: () async {
                      final initialTime = TimeOfDay(
                        hour: provider.reminderHour,
                        minute: provider.reminderMinute,
                      );
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: initialTime,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: Theme.of(context).colorScheme.copyWith(
                                primary: AppColors.primary,
                                onPrimary: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        await provider.updateReminderSettings(
                          hour: picked.hour,
                          minute: picked.minute,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_filled_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reminder Time',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? AppColors.textMainDark : AppColors.textMainLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Set when to receive the daily alert',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            TimeOfDay(
                              hour: provider.reminderHour,
                              minute: provider.reminderMinute,
                            ).format(context),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ).animate(delay: 480.ms).fadeIn(duration: 300.ms).slideY(begin: 0.1),
            const SizedBox(height: 16),
          ],

          // Sign Out
          _SectionCard(
            title: 'Account',
            isDark: isDark,
            children: [
              InkWell(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('Sign Out', style: TextStyle(color: AppColors.danger)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    context.read<AppProvider>().signOut();
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: AppColors.danger, size: 22),
                      const SizedBox(width: 12),
                      Text('Sign Out',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.danger)),
                    ],
                  ),
                ),
              ),
            ],
          ).animate(delay: 500.ms).fadeIn(duration: 300.ms).slideY(begin: 0.1),

          const SizedBox(height: 32),

          Center(
            child: Text(
              'Huffaz v1.0.4 · Mubarak Technologies',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _formatRole(String? role) {
    if (role == null) return 'User';
    return role.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;
  final bool isDark;

  const _SectionCard({
    required this.title,
    required this.children,
    required this.isDark,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700, color: textMain)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            style: TextStyle(fontSize: 12, color: textMuted)),
                      ],
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          Divider(color: border, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 14, color: textMuted)),
          const Spacer(),
          Text(value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textMain)),
        ],
      ),
    );
  }
}

class _GoalField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _GoalField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textMainDark : AppColors.textMainLight,
              )),
        ),
        SizedBox(
          width: 80,
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textMainDark : AppColors.textMainLight),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------
// Manage Teachers entry card (admin-only)
// -----------------------------------------------------------------------

class _ManageTeachersCard extends StatelessWidget {
  final bool isDark;
  final int teacherCount;

  const _ManageTeachersCard({
    required this.isDark,
    required this.teacherCount,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return InkWell(
      onTap: () => context.push('/settings/teachers'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.group_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage Teachers',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    teacherCount == 0 ? 'No teachers yet' : '$teacherCount teacher${teacherCount == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
