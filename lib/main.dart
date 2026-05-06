import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/group_screen.dart';
import 'screens/items_screen.dart';
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
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      locale: const Locale('ko', 'KR'),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => MainNavigationState();
}

/// 하단 탭 셸. 자식 화면이 `findAncestorStateOfType<MainNavigationState>()`로
/// 찾아서 `switchTab(...)`을 호출할 수 있도록 의도적으로 public 이다.
class MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  /// 자식 화면이 탭 전환 시 참조할 수 있도록 노출하는 인덱스 상수.
  static const int kItemsTabIndex = 2;

  static const _tabs = <_TabSpec>[
    _TabSpec('홈', Icons.home_outlined, Icons.home),
    _TabSpec('그룹', Icons.group_outlined, Icons.group),
    _TabSpec('모든 제품', Icons.list_alt_outlined, Icons.list_alt),
    _TabSpec('리포트', Icons.bar_chart_outlined, Icons.bar_chart),
    _TabSpec('설정', Icons.settings_outlined, Icons.settings),
  ];

  /// 자식 화면이 탭 인덱스를 강제 전환할 때 사용한다 (예: 홈의 "모두 보기").
  void switchTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    setState(() => _currentIndex = index);
  }

  Widget _screenAt(int index) => switch (index) {
    0 => const HomeScreen(),
    1 => const GroupScreen(),
    2 => const ItemsScreen(),
    3 => const ReportsScreen(),
    4 => const SettingsScreen(),
    _ => throw StateError('No screen registered for tab $index'),
  };

  Future<void> _openAddSheet() async {
    final choice = await showModalBottomSheet<_AddChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const _AddActionSheet(),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _AddChoice.scan:
        // ScanScreen 코드는 변경하지 않음. 자체 헤더가 있으니 AppBar 없이
        // 그대로 push하고 floating close 버튼만 얹는다.
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => Scaffold(
              backgroundColor: AppColors.background,
              body: Stack(
                children: [
                  const ScanScreen(),
                  Positioned(
                    top: MediaQuery.of(ctx).padding.top + 8,
                    right: 12,
                    child: Material(
                      color: AppColors.surface,
                      shape: const CircleBorder(),
                      elevation: 1,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: AppColors.text,
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case _AddChoice.manual:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddItemScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final showFab = _currentIndex == 0 || _currentIndex == 2;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [for (var i = 0; i < _tabs.length; i++) _screenAt(i)],
      ),
      floatingActionButton: showFab
          ? FloatingActionButton(
              onPressed: _openAddSheet,
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              elevation: 6,
              tooltip: '제품 추가',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.add, size: 26),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: switchTab,
          items: [
            for (final t in _tabs)
              BottomNavigationBarItem(
                icon: Icon(t.icon),
                activeIcon: Icon(t.activeIcon),
                label: t.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

enum _AddChoice { scan, manual }

class _AddActionSheet extends StatelessWidget {
  const _AddActionSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const _SheetAction(
              choice: _AddChoice.scan,
              icon: Icons.photo_camera_outlined,
              accent: AppColors.primary,
              title: '카메라 스캔',
              sub: '영수증·라벨을 찍으면 자동 인식',
            ),
            const SizedBox(height: 10),
            const _SheetAction(
              choice: _AddChoice.manual,
              icon: Icons.edit_outlined,
              accent: AppColors.textSecondary,
              title: '직접 등록',
              sub: '이름·주기를 직접 입력',
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.choice,
    required this.icon,
    required this.accent,
    required this.title,
    required this.sub,
  });

  final _AddChoice choice;
  final IconData icon;
  final Color accent;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).pop(choice),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
