import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import '../../providers/app_provider.dart';
import '../../core/theme.dart';
import '../../utils/student_utils.dart';

class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  Timer? _resumeDebounce;
  double _scrollOffset = 0.0;
  int _lastSelectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumeDebounce?.cancel();
    super.dispose();
  }

  /// Called by Flutter whenever the app lifecycle changes.
  /// We only care about [AppLifecycleState.resumed] — when the app
  /// comes back from background (home button, notifications, alt-tab, etc).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Debounce: ignore rapid focus switches (e.g. permission dialogs)
      _resumeDebounce?.cancel();
      _resumeDebounce = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        final provider = context.read<AppProvider>();
        if (provider.isLoggedIn && provider.hasInstitution) {
          provider.refresh();
        }
      });
    }
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/students')) {
      return 1;
    }
    if (location.startsWith('/reports')) {
      return 2;
    }
    if (location.startsWith('/settings')) {
      return 3;
    }
    return 0; // Default to Dashboard
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/students');
        break;
      case 2:
        context.go('/reports');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }

  void _showProfileMenu(BuildContext context) {
    final provider = context.read<AppProvider>();
    final profile = provider.profile;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final infoColor = isDark ? theme.colorScheme.secondary : AppColors.info;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: (isDark ? theme.colorScheme.secondary : AppColors.primary).withOpacity(0.15),
                child: Text(
                  (profile?.fullName != null && profile!.fullName.isNotEmpty)
                       ? profile.fullName[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    fontSize: 24,
                    color: isDark ? theme.colorScheme.secondary : AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                profile?.fullName ?? 'User',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: infoColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  profile?.role.toUpperCase() ?? 'USER',
                  style: TextStyle(
                    fontSize: 12,
                    color: infoColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ListTile(
                leading: Icon(Icons.brightness_6_outlined, color: theme.colorScheme.onSurface),
                title: Text('Toggle Theme', style: TextStyle(color: theme.colorScheme.onSurface)),
                onTap: () {
                  provider.toggleTheme();
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () {
                  provider.signOut();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (selectedIndex != _lastSelectedIndex) {
      _lastSelectedIndex = selectedIndex;
      _scrollOffset = 0.0;
    }

    final double scrolledPercent = (_scrollOffset / 80.0).clamp(0.0, 1.0);

    final Color appBarBg = selectedIndex == 0
        ? Color.lerp(Colors.transparent, theme.scaffoldBackgroundColor, scrolledPercent)!
        : theme.scaffoldBackgroundColor;

    final Color appBarContentColor = selectedIndex == 0
        ? Color.lerp(Colors.white, theme.colorScheme.onBackground, scrolledPercent)!
        : theme.colorScheme.onBackground;

    final Color bookIconColor = selectedIndex == 0
        ? Color.lerp(Colors.white, AppColors.primary, scrolledPercent)!
        : AppColors.primary;

    final Color syncBgColor = selectedIndex == 0
        ? Color.lerp(Colors.white.withOpacity(0.15), AppColors.warning.withOpacity(0.1), scrolledPercent)!
        : AppColors.warning.withOpacity(0.1);

    final Color syncContentColor = selectedIndex == 0
        ? Color.lerp(Colors.white, AppColors.warning, scrolledPercent)!
        : AppColors.warning;

    final Color avatarBorderColor = selectedIndex == 0
        ? Color.lerp(Colors.white.withOpacity(0.8), Colors.transparent, scrolledPercent)!
        : Colors.transparent;

    final Color avatarBgColor = selectedIndex == 0
        ? Color.lerp(Colors.white, AppColors.primary, scrolledPercent)!
        : AppColors.primary;

    final Color avatarTextColor = selectedIndex == 0
        ? Color.lerp(AppColors.primary, Colors.white, scrolledPercent)!
        : Colors.white;

    final double elevation = selectedIndex == 0 ? (3.0 * scrolledPercent) : 0.0;
    final Color shadowColor = selectedIndex == 0
        ? AppColors.primary.withOpacity(0.12 * scrolledPercent)
        : Colors.transparent;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: selectedIndex == 0,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: appBarBg,
            boxShadow: selectedIndex == 0 && scrolledPercent > 0.0
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.18 * scrolledPercent),
                      blurRadius: 10.0 * scrolledPercent,
                      offset: Offset(0, 4.0 * scrolledPercent),
                    ),
                  ]
                : null,
          ),
          child: TweenAnimationBuilder<Color?>(
            duration: const Duration(milliseconds: 200),
            tween: ColorTween(end: appBarContentColor),
            builder: (context, contentColor, child) {
              return TweenAnimationBuilder<Color?>(
                duration: const Duration(milliseconds: 200),
                tween: ColorTween(end: bookIconColor),
                builder: (context, iconColor, child) {
                  return AppBar(
                    title: Row(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          color: iconColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Huffaz',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: contentColor,
                          ),
                        ),
                      ],
                    ),
                    elevation: 0.0,
                    scrolledUnderElevation: 0.0,
                    backgroundColor: Colors.transparent,
                    systemOverlayStyle: selectedIndex == 0
                        ? SystemUiOverlayStyle(
                            statusBarColor: Colors.transparent,
                            statusBarIconBrightness: scrolledPercent > 0.5
                                ? (isDark ? Brightness.light : Brightness.dark)
                                : Brightness.light,
                            statusBarBrightness: scrolledPercent > 0.5
                                ? (isDark ? Brightness.dark : Brightness.light)
                                : Brightness.dark,
                            systemNavigationBarColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                          )
                        : SystemUiOverlayStyle(
                            statusBarColor: Colors.transparent,
                            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
                            systemNavigationBarColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                          ),
                    actions: [
                      // Sync Indicator
                      Consumer<AppProvider>(
                        builder: (context, provider, _) {
                          if (provider.isSyncing) {
                            return Center(
                              child: Container(
                                margin: const EdgeInsets.only(right: 16),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: syncBgColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: syncContentColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Syncing...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: syncContentColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),

                      // Date Selector (only on Students screen, hidden during sync)
                      if (selectedIndex == 1)
                        Consumer<AppProvider>(
                          builder: (context, provider, _) {
                            if (provider.isSyncing) return const SizedBox.shrink();
                            final isDifferentDate = provider.selectedDateStr != getLocalToday();
                            return IconButton(
                              icon: Badge(
                                isLabelVisible: isDifferentDate,
                                label: const Text('!', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.orange,
                                child: Icon(
                                  Icons.calendar_month_rounded,
                                  color: isDifferentDate ? Colors.orange : null,
                                ),
                              ),
                              tooltip: 'Change date',
                              onPressed: () async {
                                final parsed = DateTime.tryParse(provider.selectedDateStr) ?? DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: parsed,
                                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                  lastDate: DateTime.now().add(const Duration(days: 30)),
                                );
                                if (picked != null) {
                                  final formatted = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                  provider.setSelectedDateStr(formatted);
                                }
                              },
                            );
                          },
                        ),

                      // Search (only on Students screen, hidden during sync)
                      if (selectedIndex == 1)
                        Consumer<AppProvider>(
                          builder: (context, provider, _) {
                            if (provider.isSyncing) return const SizedBox.shrink();
                            return IconButton(
                              icon: Icon(provider.isSearchVisible ? Icons.search_off : Icons.search),
                              tooltip: 'Search students',
                              onPressed: () => provider.toggleSearch(),
                            );
                          },
                        ),

                      // Profile Avatar
                      Consumer<AppProvider>(
                        builder: (context, provider, _) {
                          final String name = provider.profile?.fullName ?? '';
                          final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: IconButton(
                              onPressed: () => _showProfileMenu(context),
                              icon: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: avatarBorderColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: avatarBgColor,
                                  child: Text(
                                    initial,
                                    style: TextStyle(
                                      color: avatarTextColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (selectedIndex == 0) {
            setState(() {
              _scrollOffset = notification.metrics.pixels;
            });
          }
          return false;
        },
        child: widget.child,
      ),
      floatingActionButton: selectedIndex == 1
          ? Consumer<AppProvider>(
              builder: (context, provider, _) {
                return AnimatedScale(
                  scale: provider.isFabVisible ? 1.0 : 0.0,
                  duration: provider.isFabVisible
                      ? const Duration(milliseconds: 280)
                      : const Duration(milliseconds: 180),
                  curve: provider.isFabVisible ? Curves.easeOutBack : Curves.easeIn,
                  child: FloatingActionButton(
                    onPressed: provider.isFabVisible
                        ? () => context.push('/students/add')
                        : null,
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                );
              },
            )
          : null,
      bottomNavigationBar: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final isDifferentDate = selectedIndex == 1 && provider.selectedDateStr != getLocalToday();
          
          final navBar = NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _onItemTapped(index, context),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people_rounded),
                label: 'Students',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_rounded),
                selectedIcon: Icon(Icons.bar_chart_rounded),
                label: 'Reports',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          );
          
          if (!isDifferentDate) {
            return navBar;
          }

          return Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF281C10)
                : const Color(0xFFFFF7ED),
            child: SafeArea(
              top: false,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.orange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_calendar_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Retroactive Log Mode",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                              letterSpacing: 0.1,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Logging students for ${provider.selectedDateStr}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white70
                                  : Colors.black54,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => provider.setSelectedDateStr(getLocalToday()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.today_rounded, size: 16),
                      label: const Text(
                        "Reset",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
