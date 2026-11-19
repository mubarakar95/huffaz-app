import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/shell/app_shell.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/students/students_list_screen.dart';
import '../screens/students/student_detail_screen.dart';
import '../screens/students/add_student_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/teacher_management_screen.dart';
import '../screens/reports/reports_screen.dart';


final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AppProvider provider) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: provider,
    redirect: (context, state) {
      final isLoggedIn = provider.isLoggedIn;
      final hasInstitution = provider.hasInstitution;
      final loc = state.matchedLocation;

      if (loc == '/splash') return null;

      if (!isLoggedIn) {
        return loc == '/login' ? null : '/login';
      }

      if (provider.isLoading) {
        return null;
      }

      if (!hasInstitution) {
        return loc == '/onboarding' ? null : '/onboarding';
      }

      if (loc == '/login' || loc == '/onboarding' || loc == '/splash') {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
           GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const DashboardScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
            ),
          ),
          GoRoute(
            path: '/students',
            pageBuilder: (context, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const StudentsListScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
            ),
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const AddStudentScreen(),
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final studentId = state.pathParameters['id']!;
                  return StudentDetailScreen(studentId: studentId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (context, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const ReportsScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const SettingsScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
            ),
            routes: [
              GoRoute(
                path: 'teachers',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const TeacherManagementScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

