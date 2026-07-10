import 'dart:async';

import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/notifications/reminder_notification_tap_controller.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/features/carousel/carousel_screen.dart';
import 'package:dosey_app/features/controller/controller_screen.dart';
import 'package:dosey_app/features/log/dose_log_screen.dart';
import 'package:dosey_app/features/prescriptions/prescriptions_screen.dart';
import 'package:dosey_app/features/reminders/reminders_screen.dart';
import 'package:dosey_app/features/robot_face/robot_face_screen.dart';
import 'package:dosey_app/features/settings/settings_screen.dart';
import 'package:dosey_app/features/today/today_screen.dart';
import 'package:flutter/material.dart';

class DoseyShell extends StatefulWidget {
  const DoseyShell({super.key});

  @override
  State<DoseyShell> createState() => _DoseyShellState();
}

class _DoseyShellState extends State<DoseyShell> {
  int _selectedIndex = 0;
  SettingsSection? _settingsSectionTarget;
  int _settingsNavigationRequest = 0;
  ReminderNotificationTapController? _notificationTaps;
  StreamSubscription<ReminderNotificationTap>? _notificationTapSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notificationTaps = DoseyAppScope.of(context).notificationTaps;
    if (identical(notificationTaps, _notificationTaps)) {
      return;
    }
    _notificationTapSubscription?.cancel();
    _notificationTaps = notificationTaps;
    _notificationTapSubscription = notificationTaps.taps.listen(
      _handleNotificationTap,
    );
  }

  @override
  void dispose() {
    unawaited(_notificationTapSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);
    final platform = currentAppDevicePlatform();
    final roleStream = dependencies.settings.watchDeviceRole();

    return StreamBuilder<AppDeviceRole>(
      stream: roleStream,
      builder: (context, roleSnapshot) {
        final role = _resolvedRole(roleSnapshot.data, platform);
        final tabs = _buildTabs(role);
        // Role changes can remove Robot Face; clamp before rebuilding the stack.
        final selectedIndex = _selectedIndex.clamp(0, tabs.length - 1);
        if (selectedIndex != _selectedIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedIndex = selectedIndex;
            });
          });
        }

        final activeTab = tabs[selectedIndex];
        final settingsTabIndex = tabs.indexWhere(
          (tab) => tab.id == _ShellTabId.settings,
        );

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dosey',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(activeTab.title),
              ],
            ),
            actions: [
              StreamBuilder<AuthSession>(
                stream: dependencies.auth.watchSession(),
                builder: (context, authSnapshot) {
                  final session =
                      authSnapshot.data ?? const AuthSession.signedOut();

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: PopupMenuButton<_SettingsMenuAction>(
                      tooltip: 'Open settings menu',
                      icon: const Icon(Icons.settings_outlined),
                      onSelected: (action) => _handleSettingsMenuAction(
                        action,
                        settingsTabIndex: settingsTabIndex,
                      ),
                      itemBuilder: (context) =>
                          _settingsMenuItems(session: session, role: role),
                    ),
                  );
                },
              ),
            ],
          ),
          body: IndexedStack(
            index: selectedIndex,
            children: [
              for (var index = 0; index < tabs.length; index += 1)
                tabs[index].buildScreen(selectedIndex, index),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: tabs.map((tab) => tab.destination).toList(),
          ),
        );
      },
    );
  }

  List<_ShellTab> _buildTabs(AppDeviceRole role) {
    return [
      const _ShellTab(
        id: _ShellTabId.today,
        title: 'Today',
        destination: NavigationDestination(
          icon: Icon(Icons.today_outlined),
          selectedIcon: Icon(Icons.today),
          label: 'Today',
        ),
        screenBuilder: _buildTodayScreen,
      ),
      const _ShellTab(
        id: _ShellTabId.prescriptions,
        title: 'Prescriptions',
        destination: NavigationDestination(
          icon: Icon(Icons.medication_outlined),
          selectedIcon: Icon(Icons.medication),
          label: 'Prescriptions',
        ),
        screenBuilder: _buildPrescriptionsScreen,
      ),
      const _ShellTab(
        id: _ShellTabId.schedule,
        title: 'Schedule',
        destination: NavigationDestination(
          icon: Icon(Icons.alarm_outlined),
          selectedIcon: Icon(Icons.alarm),
          label: 'Schedule',
        ),
        screenBuilder: _buildRemindersScreen,
      ),
      // iOS and Personal Mode never expose the mounted robot face tab.
      if (role.canHostRobot)
        const _ShellTab(
          id: _ShellTabId.robotFace,
          title: 'Robot Face',
          destination: NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'Robot Face',
          ),
          screenBuilder: _buildRobotFaceScreen,
        ),
      const _ShellTab(
        id: _ShellTabId.carousel,
        title: 'Carousel',
        destination: NavigationDestination(
          icon: Icon(Icons.view_carousel_outlined),
          selectedIcon: Icon(Icons.view_carousel),
          label: 'Carousel',
        ),
        screenBuilder: _buildCarouselScreen,
      ),
      const _ShellTab(
        id: _ShellTabId.controller,
        title: 'Controller',
        destination: NavigationDestination(
          icon: Icon(Icons.memory_outlined),
          selectedIcon: Icon(Icons.memory),
          label: 'Controller',
        ),
        screenBuilder: _buildControllerScreen,
      ),
      const _ShellTab(
        id: _ShellTabId.log,
        title: 'Log',
        destination: NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Log',
        ),
        screenBuilder: _buildDoseLogScreen,
      ),
      _ShellTab(
        id: _ShellTabId.settings,
        title: 'Settings',
        destination: const NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
        screenBuilder: (selectedIndex, tabIndex) => SettingsScreen(
          key: ValueKey(
            'settings-$_settingsNavigationRequest-$_settingsSectionTarget',
          ),
          sectionTarget: _settingsSectionTarget,
        ),
      ),
    ];
  }

  List<PopupMenuEntry<_SettingsMenuAction>> _settingsMenuItems({
    required AuthSession session,
    required AppDeviceRole role,
  }) {
    return [
      PopupMenuItem(
        value: const _SettingsMenuAction.openSection(SettingsSection.account),
        child: ListTile(
          leading: Icon(
            session.isSignedIn ? Icons.account_circle : Icons.login,
          ),
          title: const Text('Account'),
          subtitle: Text(session.isSignedIn ? 'Sign out' : 'Sign in'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem(
        value: _SettingsMenuAction.openSection(SettingsSection.deviceMode),
        child: ListTile(
          leading: Icon(Icons.phone_android_outlined),
          title: Text('Device mode'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      if (role.canHostRobot)
        const PopupMenuItem(
          value: _SettingsMenuAction.openSection(SettingsSection.robotFace),
          child: ListTile(
            leading: Icon(Icons.face_retouching_natural_outlined),
            title: Text('Robot Face'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      const PopupMenuItem(
        value: _SettingsMenuAction.openSection(SettingsSection.notifications),
        child: ListTile(
          leading: Icon(Icons.notifications_active_outlined),
          title: Text('Reminder notifications'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem(
        value: _SettingsMenuAction.openSection(SettingsSection.safety),
        child: ListTile(
          leading: Icon(Icons.health_and_safety_outlined),
          title: Text('Prototype safety'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem(
        value: _SettingsMenuAction.openSection(SettingsSection.helpAbout),
        child: ListTile(
          leading: Icon(Icons.help_outline),
          title: Text('Help & About'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem(
        value: _SettingsMenuAction.openSection(SettingsSection.setup),
        child: ListTile(
          leading: Icon(Icons.restart_alt),
          title: Text('Start over setup'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: _SettingsMenuAction.openSettingsHome(),
        child: ListTile(
          leading: Icon(Icons.settings_outlined),
          title: Text('All settings'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ];
  }

  static AppDeviceRole _resolvedRole(
    AppDeviceRole? storedRole,
    AppDevicePlatform platform,
  ) {
    final allowedRoles = AppDeviceRole.allowedFor(platform);
    if (storedRole != null && allowedRoles.contains(storedRole)) {
      return storedRole;
    }
    return AppDeviceRole.defaultFor(platform);
  }

  void _handleSettingsMenuAction(
    _SettingsMenuAction action, {
    required int settingsTabIndex,
  }) {
    _openSettings(settingsTabIndex, section: action.section);
  }

  void _openSettings(int settingsTabIndex, {SettingsSection? section}) {
    if (settingsTabIndex < 0) return;
    setState(() {
      // Bump the key so repeated settings deep links scroll again.
      _settingsSectionTarget = section;
      _settingsNavigationRequest += 1;
      _selectedIndex = settingsTabIndex;
    });
  }

  void _selectTab(int index) {
    if (_selectedIndex == index) {
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleNotificationTap(ReminderNotificationTap tap) {
    if (!mounted) {
      return;
    }
    _selectTab(_todayTabIndex);
  }
}

class _SettingsMenuAction {
  const _SettingsMenuAction.openSection(this.section);
  const _SettingsMenuAction.openSettingsHome() : section = null;

  final SettingsSection? section;
}

const _todayTabIndex = 0;

enum _ShellTabId {
  today,
  prescriptions,
  schedule,
  robotFace,
  carousel,
  controller,
  log,
  settings,
}

typedef _ShellScreenBuilder = Widget Function(int selectedIndex, int tabIndex);

class _ShellTab {
  const _ShellTab({
    required this.id,
    required this.title,
    required this.destination,
    required this.screenBuilder,
  });

  final _ShellTabId id;
  final String title;
  final NavigationDestination destination;
  final _ShellScreenBuilder screenBuilder;

  Widget buildScreen(int selectedIndex, int tabIndex) {
    return screenBuilder(selectedIndex, tabIndex);
  }
}

Widget _buildTodayScreen(int selectedIndex, int tabIndex) =>
    const TodayScreen();
Widget _buildPrescriptionsScreen(int selectedIndex, int tabIndex) =>
    const PrescriptionsScreen();
Widget _buildRemindersScreen(int selectedIndex, int tabIndex) =>
    const RemindersScreen();
Widget _buildRobotFaceScreen(int selectedIndex, int tabIndex) =>
    RobotFaceScreen(isActive: selectedIndex == tabIndex);
Widget _buildCarouselScreen(int selectedIndex, int tabIndex) =>
    const CarouselScreen();
Widget _buildControllerScreen(int selectedIndex, int tabIndex) =>
    const ControllerScreen();
Widget _buildDoseLogScreen(int selectedIndex, int tabIndex) =>
    const DoseLogScreen();
