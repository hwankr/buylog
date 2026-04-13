import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/group_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/add_item_screen.dart';
import 'services/supabase_service.dart';
import 'services/item_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Supabase 초기화 (익명 로그인 포함)
  await SupabaseService.initialize();

  // 제품 목록 초기 로드
  await ItemStore.instance.initialize();

  runApp(const BuylogApp());
}

class BuylogApp extends StatelessWidget {
  const BuylogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buylog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // 한국어 Date Picker 및 기타 위젯 지원
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ko', 'KR'),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    GroupScreen(),
    ScanScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  void _openAddItem() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddItemScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      // 홈 탭에서만 FAB 표시
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _openAddItem,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              tooltip: '제품 직접 등록',
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '내 아이템',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group_outlined),
              activeIcon: Icon(Icons.group),
              label: '그룹',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.document_scanner_outlined),
              activeIcon: Icon(Icons.document_scanner),
              label: '스캔',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: '리포트',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }
}
