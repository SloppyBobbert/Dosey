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
import 'package:dosey_app/features/shell/robot_face_shell_controller.dart';
import 'package:dosey_app/features/today/today_screen.dart';
import 'package:flutter/material.dart';

final doseyRouteObserver = RouteObserver<ModalRoute<void>>();

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

class _DoseyShellState extends State<DoseyShell>
    with WidgetsBindingObserver, RouteAware {
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
  static const _robotFaceShellController = RobotFaceShellController();
  RobotFaceShellOrientation? _previousOrientation;
  RobotFaceShellOrientation? _currentOrientation;
  bool? _systemUiFaceRequested;
  ModalRoute<void>? _subscribedRoute;
  int _authoritativeNavigationGeneration = 0;
  bool _authoritativeNavigationPending = false;

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
      _deviceRoleSubscription = dependencies.effectiveRole
          .watchDeviceRole()
          .listen(_handleDeviceRoleChanged);
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
    final route = ModalRoute.of(context);
    if (route != null && !identical(route, _subscribedRoute)) {
      if (_subscribedRoute != null) doseyRouteObserver.unsubscribe(this);
      _subscribedRoute = route;
      doseyRouteObserver.subscribe(this, route);
    }
    final notificationTaps = dependencies.notificationTaps;
    if (identical(notificationTaps, _notificationTaps)) {
      return;
    }
    _notificationTapSubscription?.cancel();
    _notificationTaps = notificationTaps;
    final pendingTap = notificationTaps.takePendingTap();
    if (pendingTap != null) {
      _beginNotificationRouting(pendingTap);
    }
    _notificationTapSubscription = notificationTaps.taps.listen(
      _handleNotificationTap,
    );
  }

  @override
  void deactivate() {
    _syncSystemUi(false);
    _requestScreenAwake(false);
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    doseyRouteObserver.unsubscribe(this);
    _inactivityTimer?.cancel();
    _faceAwakeTimer?.cancel();
    _requestScreenAwake(false);
    unawaited(_dependencies?.systemUi.restoreAppUi());
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
    _dependencies?.externalActionResumeGuard.didChangeLifecycleState(state);
    if (state != AppLifecycleState.resumed) {
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
      _stopFaceAwakeWindow();
      _syncScreenAwake();
      _syncSystemUi(false);
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
    final roleStream = dependencies.effectiveRole.watchDeviceRole();

    return StreamBuilder<AppDeviceRole>(
      stream: roleStream,
      builder: (context, roleSnapshot) {
        final role = _resolvedRole(roleSnapshot.data, platform);
        final orientation = _shellOrientationOf(context);
        _currentOrientation = orientation;
        final previousOrientation = _previousOrientation;
        _previousOrientation = orientation;
        final tabs = _buildTabs(role);
        final selectedIndex = _selectedIndexForTabs(tabs, role, orientation);
        final navigationTabs = tabs
            .where((tab) => tab.destination != null)
            .toList();

        final activeTab = tabs[selectedIndex];
        final faceVisible = activeTab.id == _ShellTabId.robotFace;
        if (previousOrientation != null && previousOrientation != orientation) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleOrientationChanged(previousOrientation, orientation);
          });
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _syncSystemUi(faceVisible);
        });
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
              appBar: _wasPresenting || faceVisible
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
              bottomNavigationBar: _wasPresenting || faceVisible
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
                          _selectVisibleTab(navigationTabs[index].id),
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
          onOpenSchedule: () => _selectVisibleTab(_ShellTabId.schedule),
          onOpenCarousel: () => _openCarousel(CarouselHubSegment.carousel),
          onOpenSettings: () => _openSettings(),
          onOpenRobotFace: role.canHostRobot
              ? _openRobotFaceFromDashboard
              : null,
          onOpenToday: _openTodayDetails,
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
        _ShellTab(
          id: _ShellTabId.robotFace,
          title: 'Robot Face',
          destination: null,
          screenBuilder: (selectedIndex, tabIndex) => RobotFaceScreen(
            isActive: selectedIndex == tabIndex,
            onLongPress: _handleLongPressExit,
          ),
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
    _markAuthoritativeNavigationThroughNextFrame();
    setState(() {
      // Bump the key so repeated settings deep links scroll again.
      _settingsSectionTarget = section;
      _settingsNavigationRequest += 1;
      _selectedTabId = _ShellTabId.settings;
    });
    _stopFaceAwakeWindow();
    _restartInactivityTimer();
    _syncScreenAwake();
  }

  void _openCarousel(CarouselHubSegment segment, {bool authoritative = true}) {
    if (authoritative) _markAuthoritativeNavigationThroughNextFrame();
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

  void _selectVisibleTab(_ShellTabId nextTabId) {
    _markAuthoritativeNavigationThroughNextFrame();
    _selectTab(nextTabId);
  }

  void _markAuthoritativeNavigationThroughNextFrame() {
    final generation = ++_authoritativeNavigationGeneration;
    _authoritativeNavigationPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _authoritativeNavigationGeneration) return;
      _authoritativeNavigationPending = false;
    });
  }

  void _openTodayDetails() {
    _markAuthoritativeNavigationThroughNextFrame();
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Today')),
            body: const TodayScreen(),
          ),
        ),
      ),
    );
  }

  void _openRobotFaceFromDashboard() {
    if (_currentOrientation == RobotFaceShellOrientation.portrait) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rotate to landscape to open Robot Face.'),
        ),
      );
      return;
    }
    _selectTab(_ShellTabId.robotFace);
  }

  void _handleLongPressExit() {
    final role = _currentRole;
    final orientation = _currentOrientation;
    if (role == null || orientation == null) return;
    final decision = _robotFaceShellController.decide(
      RobotFaceShellInput(
        role: role,
        event: RobotFaceShellEvent.longPressExit,
        currentDestination: RobotFaceShellDestination.robotFace,
        orientation: orientation,
        shellRouteCurrent: ModalRoute.of(context)?.isCurrent == true,
        nestedRouteVisible: ModalRoute.of(context)?.isCurrent != true,
        lifecycleResumed: _isLifecycleResumed,
        authoritativeNavigationPending: _authoritativeNavigationPending,
        externalActionReturnPending: false,
      ),
    );
    final destination = decision.destination;
    if (destination != null) {
      _selectTab(_tabForControllerDestination(destination));
    }
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
          ModalRoute.of(context)?.isCurrent == true &&
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

    _beginNotificationRouting(tap);
  }

  void _beginNotificationRouting(ReminderNotificationTap tap) {
    final generation = ++_authoritativeNavigationGeneration;
    _authoritativeNavigationPending = true;
    if (tap.kind == ReminderNotificationTapKind.shortage && mounted) {
      _openCarousel(CarouselHubSegment.carousel, authoritative: false);
    }
    unawaited(_routeNotificationTap(tap, generation));
  }

  Future<void> _routeNotificationTap(
    ReminderNotificationTap tap,
    int generation,
  ) async {
    final dependencies = _dependencies;
    if (dependencies == null) {
      return;
    }

    final storedRole = await dependencies.effectiveRole.getDeviceRole();
    if (!mounted || generation != _authoritativeNavigationGeneration) {
      return;
    }
    final role = _resolvedRole(storedRole, currentAppDevicePlatform());
    if (tap.kind == ReminderNotificationTapKind.shortage) {
      _openCarousel(CarouselHubSegment.carousel, authoritative: false);
    } else {
      _selectTab(
        role.canHostRobot ? _ShellTabId.robotFace : _ShellTabId.dashboard,
      );
    }
    if (generation == _authoritativeNavigationGeneration) {
      _authoritativeNavigationPending = false;
    }
  }

  Future<void> _handleResume(bool preserveNotificationDestination) async {
    final dependencies = _dependencies;
    if (dependencies == null) {
      return;
    }

    unawaited(dependencies.runMissedDoseReconciliation());
    final externalTarget = dependencies.externalActionResumeGuard
        .consumeResumeTarget();
    if (externalTarget == 'settings') {
      _openSettings();
      return;
    }
    if (preserveNotificationDestination || dependencies.isDemo) {
      return;
    }

    final storedRole = await dependencies.effectiveRole.getDeviceRole();
    if (!mounted) {
      return;
    }
    final role = _resolvedRole(storedRole, currentAppDevicePlatform());
    final orientation = _currentOrientation;
    if (orientation == null) return;
    final currentTab = _selectedTabId ?? _defaultTabIdFor(role);
    final decision = _robotFaceShellController.decide(
      RobotFaceShellInput(
        role: role,
        event: RobotFaceShellEvent.resume,
        currentDestination: _controllerDestinationFor(currentTab),
        orientation: orientation,
        shellRouteCurrent: ModalRoute.of(context)?.isCurrent == true,
        nestedRouteVisible: ModalRoute.of(context)?.isCurrent != true,
        lifecycleResumed: _isLifecycleResumed,
        authoritativeNavigationPending: _authoritativeNavigationPending,
        externalActionReturnPending: false,
      ),
    );
    final destination = decision.destination;
    if (destination != null) {
      _selectTab(_tabForControllerDestination(destination));
    }
  }

  int _selectedIndexForTabs(
    List<_ShellTab> tabs,
    AppDeviceRole role,
    RobotFaceShellOrientation orientation,
  ) {
    final selectedTabId =
        _selectedTabId ?? _defaultTabIdFor(role, orientation: orientation);
    final selectedIndex = tabs.indexWhere((tab) => tab.id == selectedTabId);
    return selectedIndex >= 0 ? selectedIndex : 0;
  }

  _ShellTabId _defaultTabIdFor(
    AppDeviceRole role, {
    RobotFaceShellOrientation? orientation,
  }) {
    if (widget.forceTodayTab) {
      return _ShellTabId.dashboard;
    }
    if (widget.startOnController) {
      return _ShellTabId.carousel;
    }
    if (!role.canHostRobot) return _ShellTabId.dashboard;
    return orientation == RobotFaceShellOrientation.portrait
        ? _ShellTabId.dashboard
        : _ShellTabId.robotFace;
  }

  RobotFaceShellOrientation _shellOrientationOf(BuildContext context) {
    return MediaQuery.orientationOf(context) == Orientation.portrait
        ? RobotFaceShellOrientation.portrait
        : RobotFaceShellOrientation.landscape;
  }

  void _handleOrientationChanged(
    RobotFaceShellOrientation previous,
    RobotFaceShellOrientation current,
  ) {
    if (!mounted || _currentRole == null) return;
    final currentTab =
        _selectedTabId ?? _defaultTabIdFor(_currentRole!, orientation: current);
    final decision = _robotFaceShellController.decide(
      RobotFaceShellInput(
        role: _currentRole!,
        event: RobotFaceShellEvent.orientationChanged,
        currentDestination: _controllerDestinationFor(currentTab),
        orientation: current,
        previousOrientation: previous,
        shellRouteCurrent: ModalRoute.of(context)?.isCurrent == true,
        nestedRouteVisible: ModalRoute.of(context)?.isCurrent != true,
        lifecycleResumed:
            _lifecycleState == null ||
            _lifecycleState == AppLifecycleState.resumed,
        authoritativeNavigationPending: _authoritativeNavigationPending,
        externalActionReturnPending: false,
      ),
    );
    final destination = decision.destination;
    if (destination != null) {
      _selectTab(_tabForControllerDestination(destination));
    }
  }

  RobotFaceShellDestination _controllerDestinationFor(_ShellTabId tab) {
    return switch (tab) {
      _ShellTabId.dashboard => RobotFaceShellDestination.dashboard,
      _ShellTabId.schedule => RobotFaceShellDestination.schedule,
      _ShellTabId.carousel => RobotFaceShellDestination.carousel,
      _ShellTabId.settings => RobotFaceShellDestination.settings,
      _ShellTabId.robotFace => RobotFaceShellDestination.robotFace,
    };
  }

  _ShellTabId _tabForControllerDestination(
    RobotFaceShellDestination destination,
  ) {
    return switch (destination) {
      RobotFaceShellDestination.dashboard ||
      RobotFaceShellDestination.todayDetails => _ShellTabId.dashboard,
      RobotFaceShellDestination.schedule => _ShellTabId.schedule,
      RobotFaceShellDestination.carousel => _ShellTabId.carousel,
      RobotFaceShellDestination.settings => _ShellTabId.settings,
      RobotFaceShellDestination.robotFace => _ShellTabId.robotFace,
    };
  }

  void _syncSystemUi(bool faceVisible) {
    if (!mounted) return;
    final routeCurrent = ModalRoute.of(context)?.isCurrent == true;
    final resumed =
        _lifecycleState == null || _lifecycleState == AppLifecycleState.resumed;
    final shouldEnter = faceVisible && routeCurrent && resumed;
    if (_systemUiFaceRequested == shouldEnter) return;
    _systemUiFaceRequested = shouldEnter;
    unawaited(
      shouldEnter
          ? _dependencies?.systemUi.enterRobotFace()
          : _dependencies?.systemUi.restoreAppUi(),
    );
  }

  bool get _isLifecycleResumed =>
      _lifecycleState == null || _lifecycleState == AppLifecycleState.resumed;

  bool get _isFaceSelected {
    final role = _currentRole;
    if (role == null) return _selectedTabId == _ShellTabId.robotFace;
    return (_selectedTabId ?? _defaultTabIdFor(role)) == _ShellTabId.robotFace;
  }

  @override
  void didPushNext() {
    _syncSystemUi(false);
    _syncScreenAwake();
  }

  @override
  void didPopNext() {
    _syncSystemUi(_isFaceSelected);
    _syncScreenAwake();
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
