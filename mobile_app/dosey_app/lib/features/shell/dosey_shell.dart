import 'dart:async';

import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/controller/controller_gateway.dart';
import 'package:dosey_app/core/display/screen_awake_gateway.dart';
import 'package:dosey_app/core/demo/demo_scenario.dart';
import 'package:dosey_app/core/demo/demo_scenario_service.dart';
import 'package:dosey_app/core/notifications/reminder_notification_tap_controller.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/features/carousel/carousel_hub_screen.dart';
import 'package:dosey_app/features/dashboard/dashboard_screen.dart';
import 'package:dosey_app/features/robot_face/robot_face_screen.dart';
import 'package:dosey_app/features/robot_face/robot_face_settings.dart';
import 'package:dosey_app/features/robot_face/robot_face_state.dart';
import 'package:dosey_app/features/settings/settings_screen.dart';
import 'package:dosey_app/features/schedule/schedule_hub_screen.dart';
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
  CarouselHubSegment _carouselSegment = CarouselHubSegment.carousel;
  int _carouselNavigationRequest = 0;
  DoseyAppDependencies? _dependencies;
  ReminderNotificationTapController? _notificationTaps;
  StreamSubscription<ReminderNotificationTap>? _notificationTapSubscription;
  Object? _settingsSource;
  StreamSubscription<AppDeviceRole>? _deviceRoleSubscription;
  Object? _robotFaceSettingsSource;
  StreamSubscription<RobotFaceSettings>? _robotFaceSettingsSubscription;
  Object? _controllerEventSource;
  StreamSubscription<ControllerEvent>? _controllerEventSubscription;
  Object? _robotFaceStateSource;
  StreamSubscription<RobotFaceState>? _robotFaceStateSubscription;
  DemoScenarioService? _demoScenarios;
  StreamSubscription<DemoScenarioState>? _demoScenarioSubscription;
  bool _wasPresenting = false;
  AppLifecycleState? _lifecycleState;
  bool _handledNotificationWhileBackgrounded = false;
  AppDeviceRole? _currentRole;
  int _returnToFaceAfterInactivityMinutes =
      RobotFaceSettings.defaultReturnToFaceAfterInactivityMinutes;
  Timer? _inactivityTimer;
  int _pirWakeDurationSeconds = RobotFaceSettings.defaultPirWakeDurationSeconds;
  Timer? _faceAwakeTimer;
  bool _faceAwakeWindowActive = false;
  bool _scheduledDoseAwake = false;
  ScreenAwakeGateway? _screenAwake;
  bool? _screenAwakeRequested;
  Future<void> _screenAwakeUpdate = Future<void>.value();

  @override
  void initState() {
    super.initState();
    if (widget.startOnController) {
      _carouselSegment = CarouselHubSegment.controller;
    }
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
    if (!identical(dependencies.controller, _controllerEventSource)) {
      unawaited(_controllerEventSubscription?.cancel());
      _controllerEventSource = dependencies.controller;
      _controllerEventSubscription = switch (dependencies.controller) {
        final ControllerEventGateway eventGateway =>
          eventGateway.watchControllerEvents().listen(_handleControllerEvent),
        _ => null,
      };
    }
    if (!identical(dependencies.robotFaceController, _robotFaceStateSource)) {
      unawaited(_robotFaceStateSubscription?.cancel());
      _robotFaceStateSource = dependencies.robotFaceController;
      _robotFaceStateSubscription = dependencies.robotFaceController
          .watchState()
          .listen(_handleRobotFaceStateChanged);
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
    _faceAwakeTimer?.cancel();
    _requestScreenAwake(false);
    unawaited(_deviceRoleSubscription?.cancel());
    unawaited(_robotFaceSettingsSubscription?.cancel());
    unawaited(_controllerEventSubscription?.cancel());
    unawaited(_robotFaceStateSubscription?.cancel());
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
      _stopFaceAwakeWindow();
      _syncScreenAwake();
      return;
    }

    final preserveNotificationDestination =
        _handledNotificationWhileBackgrounded;
    _handledNotificationWhileBackgrounded = false;
    _restartFaceAwakeWindow();
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
        final navigationTabs = tabs
            .where((tab) => tab.destination != null)
            .toList();

        final activeTab = tabs[selectedIndex];
        final selectedNavigationIndex = navigationTabs.indexWhere(
          (tab) => tab.id == activeTab.id,
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
                      labelBehavior:
                          MediaQuery.textScalerOf(context).scale(1) > 1.3
                          ? NavigationDestinationLabelBehavior.alwaysHide
                          : NavigationDestinationLabelBehavior.alwaysShow,
                      selectedIndex: selectedNavigationIndex < 0
                          ? 0
                          : selectedNavigationIndex,
                      onDestinationSelected: (index) =>
                          _selectTab(navigationTabs[index].id),
                      destinations: navigationTabs
                          .map((tab) => tab.destination!)
                          .toList(),
                    ),
            ),
          ),
        );
      },
    );
  }

  List<_ShellTab> _buildTabs(AppDeviceRole role) {
    return [
      _ShellTab(
        id: _ShellTabId.dashboard,
        title: 'Dashboard',
        destination: NavigationDestination(
          icon: Tooltip(
            message: 'Dashboard',
            child: Icon(Icons.dashboard_outlined),
          ),
          selectedIcon: Tooltip(
            message: 'Dashboard',
            child: Icon(Icons.dashboard),
          ),
          label: 'Dashboard',
        ),
        screenBuilder: (selectedIndex, tabIndex) => DashboardScreen(
          showRobotFaceShortcut: role.canHostRobot,
          onOpenSchedule: () => _selectTab(_ShellTabId.schedule),
          onOpenCarousel: () => _openCarousel(CarouselHubSegment.carousel),
          onOpenSettings: () => _openSettings(),
          onOpenRobotFace: role.canHostRobot
              ? () => _selectTab(_ShellTabId.robotFace)
              : null,
        ),
      ),
      _ShellTab(
        id: _ShellTabId.schedule,
        title: 'Schedule',
        destination: NavigationDestination(
          icon: Tooltip(message: 'Schedule', child: Icon(Icons.alarm_outlined)),
          selectedIcon: Tooltip(message: 'Schedule', child: Icon(Icons.alarm)),
          label: 'Schedule',
        ),
        screenBuilder: (selectedIndex, tabIndex) => const ScheduleHubScreen(),
      ),
      // iOS and Personal Mode never expose the mounted robot face tab.
      if (role.canHostRobot)
        const _ShellTab(
          id: _ShellTabId.robotFace,
          title: 'Robot Face',
          destination: null,
          screenBuilder: _buildRobotFaceScreen,
        ),
      _ShellTab(
        id: _ShellTabId.carousel,
        title: 'Carousel',
        destination: NavigationDestination(
          icon: Tooltip(
            message: 'Carousel',
            child: Icon(Icons.view_carousel_outlined),
          ),
          selectedIcon: Tooltip(
            message: 'Carousel',
            child: Icon(Icons.view_carousel),
          ),
          label: 'Carousel',
        ),
        screenBuilder: (selectedIndex, tabIndex) => CarouselHubScreen(
          key: ValueKey('carousel-$_carouselNavigationRequest'),
          initialSegment: _carouselSegment,
        ),
      ),
      _ShellTab(
        id: _ShellTabId.settings,
        title: 'Settings',
        destination: NavigationDestination(
          icon: Tooltip(
            message: 'Settings',
            child: Icon(Icons.settings_outlined),
          ),
          selectedIcon: Tooltip(
            message: 'Settings',
            child: Icon(Icons.settings),
          ),
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

  void _openSettings({SettingsSection? section}) {
    setState(() {
      // Bump the key so repeated settings deep links scroll again.
      _settingsSectionTarget = section;
      _settingsNavigationRequest += 1;
      _selectedTabId = _ShellTabId.settings;
    });
    _restartInactivityTimer();
    _syncScreenAwake();
  }

  void _openCarousel(CarouselHubSegment segment) {
    setState(() {
      _carouselSegment = segment;
      _carouselNavigationRequest += 1;
      _selectedTabId = _ShellTabId.carousel;
    });
    _stopFaceAwakeWindow();
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
    if (nextTabId == _ShellTabId.robotFace) {
      _restartFaceAwakeWindow();
    } else {
      _stopFaceAwakeWindow();
    }
    _restartInactivityTimer();
    _syncScreenAwake();
  }

  void _handleDeviceRoleChanged(AppDeviceRole storedRole) {
    final wasRobot = _currentRole?.canHostRobot == true;
    _currentRole = _resolvedRole(storedRole, currentAppDevicePlatform());
    if (_currentRole?.canHostRobot == true && !wasRobot) {
      _restartFaceAwakeWindow();
    } else if (_currentRole?.canHostRobot != true) {
      _stopFaceAwakeWindow();
    }
    _restartInactivityTimer();
    _syncScreenAwake();
  }

  void _handleRobotFaceSettingsChanged(RobotFaceSettings settings) {
    _returnToFaceAfterInactivityMinutes =
        settings.returnToFaceAfterInactivityMinutes;
    _pirWakeDurationSeconds = settings.pirWakeDurationSeconds;
    if (_faceAwakeWindowActive) {
      _restartFaceAwakeWindow();
    }
    _restartInactivityTimer();
    _syncScreenAwake();
  }

  void _handleControllerEvent(ControllerEvent event) {
    if (event != ControllerEvent.wakeFace ||
        _currentRole?.canHostRobot != true ||
        (_lifecycleState != null &&
            _lifecycleState != AppLifecycleState.resumed)) {
      return;
    }
    _selectTab(_ShellTabId.robotFace);
    _restartFaceAwakeWindow();
    final gateway = _screenAwake;
    if (gateway != null) {
      unawaited(_wakeScreen(gateway));
    }
  }

  void _handleRobotFaceStateChanged(RobotFaceState state) {
    if (_scheduledDoseAwake == state.isInAwakeWindow) {
      return;
    }
    _scheduledDoseAwake = state.isInAwakeWindow;
    _syncScreenAwake();
  }

  Future<void> _wakeScreen(ScreenAwakeGateway gateway) async {
    try {
      await gateway.wakeScreen();
    } on Object {
      // Waking the mounted display is best-effort and must not block routing.
    }
  }

  void _handleDemoScenarioChanged(DemoScenarioState state) {
    if (!mounted || state.isPresenting == _wasPresenting) {
      return;
    }
    _wasPresenting = state.isPresenting;
    if (state.isPresenting) {
      _selectTab(_ShellTabId.robotFace);
    } else {
      _openCarousel(CarouselHubSegment.controller);
    }
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
          isResumed &&
          (_faceAwakeWindowActive || _scheduledDoseAwake),
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
    final role = _currentRole;
    final selectedTabId = role == null
        ? _selectedTabId
        : _selectedTabId ?? _defaultTabIdFor(role);
    if (role?.canHostRobot == true && selectedTabId == _ShellTabId.robotFace) {
      _restartFaceAwakeWindow();
      return;
    }
    if (_shouldRunInactivityTimer) {
      _restartInactivityTimer();
    }
  }

  void _restartFaceAwakeWindow() {
    _faceAwakeTimer?.cancel();
    _faceAwakeTimer = null;
    final role = _currentRole;
    final selectedTabId = role == null
        ? _selectedTabId
        : _selectedTabId ?? _defaultTabIdFor(role);
    final isResumed =
        _lifecycleState == null || _lifecycleState == AppLifecycleState.resumed;
    if (role?.canHostRobot != true ||
        selectedTabId != _ShellTabId.robotFace ||
        !isResumed) {
      _faceAwakeWindowActive = false;
      _syncScreenAwake();
      return;
    }
    _faceAwakeWindowActive = true;
    _faceAwakeTimer = Timer(
      Duration(seconds: _pirWakeDurationSeconds),
      _handleFaceAwakeTimeout,
    );
    _syncScreenAwake();
  }

  void _stopFaceAwakeWindow() {
    _faceAwakeTimer?.cancel();
    _faceAwakeTimer = null;
    _faceAwakeWindowActive = false;
  }

  void _handleFaceAwakeTimeout() {
    _faceAwakeTimer = null;
    _faceAwakeWindowActive = false;
    _syncScreenAwake();
  }

  bool get _shouldRunInactivityTimer {
    final role = _currentRole;
    if (_dependencies?.isDemo == true || role == null || !role.canHostRobot) {
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
    if (tap.kind == ReminderNotificationTapKind.shortage) {
      _openCarousel(CarouselHubSegment.carousel);
    } else {
      _selectTab(
        role.canHostRobot ? _ShellTabId.robotFace : _ShellTabId.dashboard,
      );
    }
  }

  Future<void> _handleResume(bool preserveNotificationDestination) async {
    final dependencies = _dependencies;
    if (dependencies == null) {
      return;
    }

    unawaited(dependencies.runMissedDoseReconciliation());
    if (preserveNotificationDestination || dependencies.isDemo) {
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
      return _ShellTabId.dashboard;
    }
    if (widget.startOnController) {
      return _ShellTabId.carousel;
    }
    return role.canHostRobot ? _ShellTabId.robotFace : _ShellTabId.dashboard;
  }
}

enum _ShellTabId { dashboard, schedule, robotFace, carousel, settings }

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
  final NavigationDestination? destination;
  final _ShellScreenBuilder screenBuilder;

  Widget buildScreen(int selectedIndex, int tabIndex) {
    return screenBuilder(selectedIndex, tabIndex);
  }
}

Widget _buildRobotFaceScreen(int selectedIndex, int tabIndex) =>
    RobotFaceScreen(isActive: selectedIndex == tabIndex);
