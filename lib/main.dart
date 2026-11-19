import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_client.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'providers/app_provider.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Notification Service
  await NotificationService.init();

  // Set preferred orientations and enable edge-to-edge layout
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Initialize Hive
  await Hive.initFlutter();

  // Create and initialize provider (loads cached data from Hive instantly)
  final appProvider = AppProvider();
  try {
    await appProvider.initialize();
  } catch (e) {
    debugPrint("App initialization failed: $e");
  }

  runApp(HuffazApp(appProvider: appProvider));
}

class HuffazApp extends StatefulWidget {
  final AppProvider appProvider;
  const HuffazApp({super.key, required this.appProvider});

  @override
  State<HuffazApp> createState() => _HuffazAppState();
}

class _HuffazAppState extends State<HuffazApp> {
  late final GoRouterWrapper _routerWrapper;

  @override
  void initState() {
    super.initState();
    _routerWrapper = GoRouterWrapper(widget.appProvider);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppProvider>.value(
      value: widget.appProvider,
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return MaterialApp.router(
            title: 'Huffaz',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            routerConfig: _routerWrapper.router,
            builder: (context, child) {
              return Container(
                color: provider.isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
                child: child,
              );
            },
          );
        },
      ),
    );
  }
}

/// Wrapper to lazily create the router so it can access the provider
class GoRouterWrapper {
  final AppProvider _provider;
  late final dynamic router;

  GoRouterWrapper(this._provider) {
    router = createRouter(_provider);
  }
}
