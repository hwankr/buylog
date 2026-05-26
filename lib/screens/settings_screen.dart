import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationEnabled = true;
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationEnabled = _prefs.getBool('notification_enabled') ?? true;
    });
  }

  Future<void> _toggleNotification(bool value) async {
    setState(() {
      _notificationEnabled = value;
    });

    await _prefs.setBool('notification_enabled', value);

    if (value) {
      await NotificationService().scheduleAll();
    } else {
      await NotificationService().cancelAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('설정', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),

            // Profile card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary,
                    child: const Text(
                      '사',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '사용자',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '계정 정보 없음',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // General settings
            _sectionTitle('일반'),
            _settingsCard([
              _settingsTile(
                Icons.notifications_outlined,
                '알림 설정',
                subtitle: 'D-day 알림, 가격 변동 알림',
                trailing: Switch(
                  value: _notificationEnabled,
                  onChanged: _toggleNotification,
                  activeThumbColor: AppColors.primary,
                ),
              ),
              _settingsTile(Icons.palette_outlined, '테마', subtitle: '라이트 모드'),
              _settingsTile(Icons.language_outlined, '언어', subtitle: '한국어'),
            ]),
            const SizedBox(height: 20),

            // Data settings
            _sectionTitle('데이터'),
            _settingsCard([
              _settingsTile(
                Icons.cloud_sync_outlined,
                '데이터 동기화',
                subtitle: '마지막 동기화: 오늘 09:30',
              ),
              _settingsTile(Icons.download_outlined, '데이터 내보내기'),
              _settingsTile(Icons.upload_outlined, '데이터 가져오기'),
            ]),
            const SizedBox(height: 20),

            // AI settings
            _sectionTitle('AI 기능'),
            _settingsCard([
              _settingsTile(
                Icons.auto_awesome_outlined,
                'AI 교체 예측',
                subtitle: '구매 패턴 기반 자동 예측',
                trailing: Switch(
                  value: true,
                  onChanged: (_) {},
                  activeThumbColor: AppColors.primary,
                ),
              ),
              _settingsTile(
                Icons.price_change_outlined,
                'AI 가격 비교',
                subtitle: '실시간 최저가 비교',
                trailing: Switch(
                  value: true,
                  onChanged: (_) {},
                  activeThumbColor: AppColors.primary,
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // Info
            _sectionTitle('정보'),
            _settingsCard([
              _settingsTile(Icons.info_outlined, '앱 버전', subtitle: '1.0.0'),
              _settingsTile(Icons.description_outlined, '이용약관'),
              _settingsTile(Icons.shield_outlined, '개인정보 처리방침'),
              _settingsTile(Icons.help_outline, '도움말'),
            ]),
            const SizedBox(height: 32),

            // Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('로그아웃', style: TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 0.5, indent: 52, color: AppColors.border),
          ],
        ],
      ),
    );
  }

  Widget _settingsTile(
    IconData icon,
    String title, {
    String? subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.text,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          trailing ??
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textMuted,
              ),
        ],
      ),
    );
  }
}
