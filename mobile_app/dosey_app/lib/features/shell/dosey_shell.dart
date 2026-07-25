import 'dart:async';

import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/display/screen_awake_gateway.dart';
import 'package:dosey_app/core/demo/demo_scenario.dart';
import 'package:dosey_app/core/demo/demo_scenario_service.dart';
import 'package:dosey_app/core/notifications/reminder_notification_tap_controller.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/features/carousel/carousel_screen.dart';
import 'package:dosey_app/features/controller/controller_screen.dart';
import 'package:dosey_app/features/log/dose_log_screen.dart';
import 'package:dosey_app/features/prescriptions/prescriptions_screen.dart';
import 'package:dosey_app/features/reminders/reminders_screen.dart';
import 'package:dosey_app/features/robot_face/robot_face_screen.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
import 'package:dosey_app/features/settings/settings_screen.dart';
import 'package:dosey_app/features/today/today_screen.dart';
import 'package:flutter/material.dart';

class DoseyShell extends StatefulWidget {
  const DoseyShell({
    super.key,
    this.forceTodayTab = false,
    this.startOnController = false,
  });

  final bool forceTodayTab;
  final bool startOnController;

  @override
  State<DoseyShell> createState() => _DoseyShellState();
}

class _DoseyShellState extends State<DoseyShell> with WidgetsBindingObserver {
  _ShellTabId? _selectedTabId;
  SettingsSection? _settingsSectionTarget;
  int _settingsNavigationRequest = 0;
  DoseyAppDependencies? _dependencies;
  ReminderNotificationTapController? _notificationTaps;
  StreamSubscription<ReminderNotificationTap>? _notificationTapSubscription;
  Object? _settingsSource;
  StreamSubscription<AppDeviceRole>? _deviceRoleSubscription;
  Object? _robotFaceSettingsSource;
  StreamSubscription<RobotFaceSettings>? _robotFaceSettingsSubscription;
  DemoScenarioService? _demoScenarios;
  StreamSubscription<DemoScenarioState>? _demoScenarioSubscription;
  bool _wasPresenting = false;
  AppLifecycleState? _lifecycleState;
  bool _handledNotificationWhileBackgrounded = false;
  AppDeviceRole? _currentRole;
  int _returnToFaceAfterInactivityMinutes =
      RobotFaceSettings.defaultReturnToFaceAfterInactivityMinutes;
  Timer? _inactivityTimer;
  ScreenAwakeGateway? _screenAwake;
  bool? _screenAwakeRequested;
  Future<void> _screenAwakeUpdate = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _lifecycleState = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dependencies = DoseyAppScope.of(context);
    _dependencies = dependencies;
    if (!identical(dependencies.screenAwake, _screenAwake)) {
      _screenAwake = dependencies.screenAwake;
      _screenAwakeRequested = null;
      _syncScreenAwake();
    }
    if (!identical(dependencies.settings, _settingsSource)) {
      unawaited(_deviceRoleSubscription?.cancel());
      _settingsSource = dependencies.settings;
      _deviceRoleSubscription = dependencies.settings.watchDeviceRole().listen(
        _handleDeviceRoleChanged,
      );
    }
    if (!identical(dependencies.robotFaceSettings, _robotFaceSettingsSource)) {
      unawaited(_robotFaceSettingsSubscription?.cancel());
      _robotFaceSettingsSource = dependencies.robotFaceSettings;
      _robotFaceSettingsSubscription = dependencies.robotFaceSettings
          .watchSettings()
          .listen(_handleRobotFaceSettingsChanged);
    }
    if (!identical(dependencies.demoScenarios, _demoScenarios)) {
      unawaited(_demoScenarioSubscription?.cancel());
      _demoScenarios = dependencies.demoScenarios;
      _wasPresenting = dependencies.demoScenarios?.state.isPresenting ?? false;
      _demoScenarioSubscription = dependencies.demoScenarios?.states.listen(
        _handleDemoScenarioChanged,
      );
    }
    final notificationTaps = dependencies.notificationTaps;
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
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    _requestScreenAwake(false);
    unawaited(_deviceRoleSubscription?.cancel());
    unawaited(_robotFaceSettingsSubscription?.cancel());
    unawaited(_demoScenarioSubscription?.cancel());
    unawaited(_notificationTapSubscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state != AppLifecycleState.resumed) {
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
      _syncScreenAwake();
      return;
    }

    final preserveNotificationDestination =
        _handledNotificationWhileBackgrounded;
    _handledNotificationWhileBackgrounded = false;
    _syncScreenAwake();
    unawaited(_handleResume(preserveNotificationDestination));
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
        final selectedIndex = _selectedIndexForTabs(tabs, role);

        final activeTab = tabs[selectedIndex];
        final settingsTabIndex = tabs.indexWhere(
          (tab) => tab.id == _ShellTabId.settings,
        );

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _recordInteraction(),
          child: PopScope<Object?>(
            canPop: !role.canHostRobot,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop &&
                  role.canHostRobot &&
                  activeTab.id != _ShellTabId.robotFace) {
                _selectTab(_ShellTabId.robotFace);
              }
            },
            child: Scaffold(
              appBar: _wasPresenting
                  ? null
                  : AppBar(
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dosey',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
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
                                authSnapshot.data ??
                                const AuthSession.signedOut();

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: PopupMenuButton<_SettingsMenuAction>(
                                tooltip: 'Open settings menu',
                                icon: const Icon(Icons.settings_outlined),
                                onSelected: (action) =>
                                    _handleSettingsMenuAction(
                                      action,
                                      settingsTabIndex: settingsTabIndex,
                                    ),
                                itemBuilder: (context) => _settingsMenuItems(
                                  session: session,
                                  role: role,
                                ),
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
              bottomNavigationBar: _wasPresenting
                  ? null
                  : NavigationBar(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: (index) =>
                          _selectTab(tabs[index].id),
                      destinations: tabs.map((tab) => tab.destination).toList(),
                    ),
            ),
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
      if (!role.canHostRobot)
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
      const PopupMenuItem(
        value: _SettingsMenuAction.openSection(
          SettingsSection.householdAccount,
        ),
        child: ListTile(
          leading: Icon(Icons.home_outlined),
          title: Text('Household & robot profile'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem(
        value: _SettingsMenuAction.openSection(SettingsSection.adminHistory),
        child: ListTile(
          leading: Icon(Icons.history_outlined),
          title: Text('Admin history'),
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
      _selectedTabId = _ShellTabId.settings;
    });
    _restartInactivityTimer();
    _syncScreenAwake();
  }

  void _selectTab(_ShellTabId nextTabId) {
    if (_selectedTabId == nextTabId) {
      return;
    }
    setState(() {
      _selectedTabId = nextTabId;
    });
    _restartInactivityTimer();
    _syncScreenAwake();
  }

  void _handleDeviceRoleChanged(AppDeviceRole storedRole) {
    _currentRole = _resolvedRole(storedRole, currentAppDevicePlatform());
    _restartInactivityTimer();
    _syncScreenAwake();
  }

  void _handleRobotFaceSettingsChanged(RobotFaceSettings settings) {
    _returnToFaceAfterInactivityMinutes =
        settings.returnToFaceAfterInactivityMinutes;
    _restartInactivityTimer();
    _syncScreenAwake();
  }

  void _handleDemoScenarioChanged(DemoScenarioState state) {
    if (!mounted || state.isPresenting == _wasPresenting) {
      return;
    }
    _wasPresenting = state.isPresenting;
    _selectTab(
      state.isPresenting ? _ShellTabId.robotFace : _ShellTabId.controller,
    );
  }

  void _syncScreenAwake() {
    final role = _currentRole;
    final selectedTabId = role == null
        ? _selectedTabId
        : _selectedTabId ?? _defaultTabIdFor(role);
    final isResumed =
        _lifecycleState == null || _lifecycleState == AppLifecycleState.resumed;
    _requestScreenAwake(
      role?.canHostRobot == true &&
          selectedTabId == _ShellTabId.robotFace &&
          isResumed,
    );
  }

  void _requestScreenAwake(bool enabled) {
    final gateway = _screenAwake;
    if (gateway == null || _screenAwakeRequested == enabled) {
      return;
    }
    _screenAwakeRequested = enabled;
    _screenAwakeUpdate = _screenAwakeUpdate.then((_) async {
      try {
        await gateway.setKeepScreenAwake(enabled);
      } on Object {
        // Screen wake is a mounted-display convenience, not a startup blocker.
      }
    });
  }

  void _recordInteraction() {
    if (_shouldRunInactivityTimer) {
      _restartInactivityTimer();
    }
  }

  bool get _shouldRunInactivityTimer {
    final role = _currentRole;
    if (role == null || !role.canHostRobot) {
      return false;
    }
    if (_lifecycleState != null &&
        _lifecycleState != AppLifecycleState.resumed) {
      return false;
    }
    final selectedTabId = _selectedTabId ?? _defaultTabIdFor(role);
    return selectedTabId != _ShellTabId.robotFace;
  }

  void _restartInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    if (!_shouldRunInactivityTimer) {
      return;
    }
    _inactivityTimer = Timer(
      Duration(minutes: _returnToFaceAfterInactivityMinutes),
      _handleInactivityTimeout,
    );
  }

  void _handleInactivityTimeout() {
    _inactivityTimer = null;
    if (!mounted || !_shouldRunInactivityTimer) {
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != true) {
      _inactivityTimer = Timer(
        const Duration(seconds: 1),
        _handleInactivityTimeout,
      );
      return;
    }
    _selectTab(_ShellTabId.robotFace);
  }

  void _handleNotificationTap(ReminderNotificationTap tap) {
    if (_lifecycleState != null &&
        _lifecycleState != AppLifecycleState.resumed) {
      _handledNotificationWhileBackgrounded = true;
    }

    unawaited(_routeNotificationTap(tap));
  }

  Future<void> _routeNotificationTap(ReminderNotificationTap tap) async {
    final dependencies = _dependencies;
    if (dependencies == null) {
      return;
    }

    final storedRole = await dependencies.settings.getDeviceRole();
    if (!mounted) {
      return;
    }
    final role = _resolvedRole(storedRole, currentAppDevicePlatform());
    final destination = switch (tap.kind) {
      ReminderNotificationTapKind.shortage => _ShellTabId.carousel,
      ReminderNotificationTapKind.doseReminder =>
        role.canHostRobot ? _ShellTabId.robotFace : _ShellTabId.today,
    };
    _selectTab(destination);
  }

  Future<void> _handleResume(bool preserveNotificationDestination) async {
    final dependencies = _dependencies;
    if (dependencies == null) {
      return;
    }

    unawaited(dependencies.runMissedDoseReconciliation());
    if (preserveNotificationDestination) {
      return;
    }

    final storedRole = await dependencies.settings.getDeviceRole();
    if (!mounted) {
      return;
    }
    final role = _resolvedRole(storedRole, currentAppDevicePlatform());
    if (role.canHostRobot) {
      _selectTab(_ShellTabId.robotFace);
    }
  }

  int _selectedIndexForTabs(List<_ShellTab> tabs, AppDeviceRole role) {
    final selectedTabId = _selectedTabId ?? _defaultTabIdFor(role);
    final selectedIndex = tabs.indexWhere((tab) => tab.id == selectedTabId);
    return selectedIndex >= 0 ? selectedIndex : 0;
  }

  _ShellTabId _defaultTabIdFor(AppDeviceRole role) {
    if (widget.forceTodayTab) {
      return _ShellTabId.today;
    }
    if (widget.startOnController) {
      return _ShellTabId.controller;
    }
    return role.canHostRobot ? _ShellTabId.robotFace : _ShellTabId.today;
  }
}

class _SettingsMenuAction {
  const _SettingsMenuAction.openSection(this.section);
  const _SettingsMenuAction.openSettingsHome() : section = null;

  final SettingsSection? section;
}

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
