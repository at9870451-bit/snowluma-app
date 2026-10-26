import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import 'core/app_state.dart';
import 'core/bridge.dart';
import 'pages/actions_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/logs_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  await appState.init(dataDir: dir.path);
  runApp(const SnowLumaApp());
}

/// SnowLuma 前端 — Flutter UI + Rust Core（FFI JSON 总线）
class SnowLumaApp extends StatelessWidget {
  const SnowLumaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => appState,
      child: MaterialApp(
        title: 'SnowLuma',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3949AB)),
          scaffoldBackgroundColor: const Color(0xFFF5F5F7),
          appBarTheme: const AppBarTheme(backgroundColor: Colors.white, elevation: 0),
          inputDecorationTheme: const InputDecorationTheme(
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        routes: {
          '/': (context) => const RootView(),
          '/actions': (context) => const ActionsPage(),
          '/logs': (context) => const LogsPage(),
        },
      ),
    );
  }
}

/// 根视图：有会话 → 主页；无会话 → 登录页
class RootView extends StatelessWidget {
  const RootView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return state.connected ? const HomePage() : const LoginPage(onConnected: _noop);
  }

  static void _noop() {}
}
