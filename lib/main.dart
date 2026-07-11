// App 進入點：初始化時區與本地資料庫後，啟動儀表板 UI。

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'database/app_database.dart';
import 'database/database_connection.dart';
import 'logic/portfolio_repository.dart';
import 'services/market_session_resolver.dart';
import 'ui/dashboard_controller.dart';
import 'ui/dashboard_page.dart';
import 'ui/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MarketSessionResolver.InitializeTimeZoneDatabase();
  final AppDatabase database = AppDatabase(OpenConnection());
  final PortfolioRepository repository =
      PortfolioRepository(database: database);
  runApp(StockPortfolioApp(repository: repository));
}

/// App 根 widget：注入 DashboardController 並套用整體主題。
class StockPortfolioApp extends StatelessWidget {
  final PortfolioRepository repository;

  const StockPortfolioApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DashboardController>(
      create: (BuildContext context) =>
          DashboardController(repository: repository)..InitializeDashboard(),
      child: Consumer<DashboardController>(
        builder: (BuildContext context, DashboardController controller,
            Widget? child) {
          return MaterialApp(
            title: '股票庫存管理',
            debugShowCheckedModeBanner: false,
            locale: const Locale('zh', 'TW'),
            supportedLocales: const <Locale>[Locale('zh', 'TW'), Locale('en')],
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: BuildAppTheme(Brightness.light),
            darkTheme: BuildAppTheme(Brightness.dark),
            themeMode: ConvertToMaterialThemeMode(controller.theme_mode),
            home: const DashboardPage(),
          );
        },
      ),
    );
  }
}
