import 'package:dosey_app/app/web_local_personal/web_local_personal_pages.dart';
import 'package:dosey_app/app/web_local_personal/web_local_personal_routes.dart';
import 'package:dosey_app/core/storage/web_storage_types.dart';
import 'package:flutter/material.dart';

class WebLocalPersonalApp extends StatefulWidget {
  const WebLocalPersonalApp({
    super.key,
    required this.storage,
    this.routeController,
    this.pageBuilder = buildWebLocalPersonalFoundationPage,
    this.onAddPrescription,
    this.onAddSchedule,
    this.onRetryStorage,
    this.routeInformationProvider,
  });

  final WebStorageBootstrapResult storage;

  /// Fixed for the lifetime of this root app widget.
  final WebLocalPersonalRouteController? routeController;
  final WebLocalPersonalPageBuilder pageBuilder;
  final VoidCallback? onAddPrescription;
  final VoidCallback? onAddSchedule;
  final VoidCallback? onRetryStorage;
  final RouteInformationProvider? routeInformationProvider;

  @override
  State<WebLocalPersonalApp> createState() => _WebLocalPersonalAppState();
}

class _WebLocalPersonalAppState extends State<WebLocalPersonalApp> {
  late final WebLocalPersonalRouteController _controller =
      widget.routeController ?? WebLocalPersonalRouteController();
  late final bool _ownsController = widget.routeController == null;
  late final WebLocalPersonalRouteDelegate _routeDelegate =
      WebLocalPersonalRouteDelegate(
        controller: _controller,
        builder: _buildRoute,
      );

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    _routeDelegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    title: 'Dosey Local Personal',
    theme: _theme(),
    routeInformationParser: const WebLocalPersonalRouteInformationParser(),
    routerDelegate: _routeDelegate,
    routeInformationProvider: widget.routeInformationProvider,
  );

  Widget _buildRoute(
    BuildContext context,
    WebLocalPersonalRouteController controller,
  ) {
    if (widget.storage is WebStorageStartupRecovery) {
      return _RecoveryGate(onRetry: widget.onRetryStorage);
    }
    if (controller.hasUnknownPath) {
      return _UnknownRouteGate(
        onReturn: () => controller.goTo(WebLocalPersonalDestination.today),
      );
    }
    return _PersonalShell(
      storage: widget.storage,
      controller: controller,
      pageBuilder: widget.pageBuilder,
      onAddPrescription: widget.onAddPrescription,
      onAddSchedule: widget.onAddSchedule,
    );
  }
}

ThemeData _theme() {
  const ink = Color(0xFF103E46);
  const cream = Color(0xFFF6F0E5);
  const paper = Color(0xFFFFFCF6);
  const coral = Color(0xFFC65F50);
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Georgia',
    colorScheme: const ColorScheme.light(
      primary: ink,
      onPrimary: paper,
      secondary: Color(0xFF1B9AAA),
      surface: paper,
      onSurface: Color(0xFF1D2929),
      error: coral,
    ),
    scaffoldBackgroundColor: cream,
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 42,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: TextStyle(fontSize: 20, height: 1.4, color: ink),
      bodyLarge: TextStyle(fontSize: 17, height: 1.55),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(44, 48)),
    ),
  );
}

class _PersonalShell extends StatefulWidget {
  const _PersonalShell({
    required this.storage,
    required this.controller,
    required this.pageBuilder,
    this.onAddPrescription,
    this.onAddSchedule,
  });

  final WebStorageBootstrapResult storage;
  final WebLocalPersonalRouteController controller;
  final WebLocalPersonalPageBuilder pageBuilder;
  final VoidCallback? onAddPrescription;
  final VoidCallback? onAddSchedule;

  @override
  State<_PersonalShell> createState() => _PersonalShellState();
}

class _PersonalShellState extends State<_PersonalShell> {
  final FocusNode _pageFocusNode = FocusNode(debugLabel: 'Local Personal page');

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_moveFocusToPage);
  }

  @override
  void didUpdateWidget(covariant _PersonalShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_moveFocusToPage);
    widget.controller.addListener(_moveFocusToPage);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_moveFocusToPage);
    _pageFocusNode.dispose();
    super.dispose();
  }

  void _moveFocusToPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pageFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compactRail = width >= 700 && width < 1024;
    final desktopRail = width >= 1024;
    final allowsDataActions = widget.storage is WebStorageReady;
    final page = widget.pageBuilder(
      context,
      widget.controller.current,
      widget.storage,
      onAddPrescription: allowsDataActions ? widget.onAddPrescription : null,
      onAddSchedule: allowsDataActions ? widget.onAddSchedule : null,
    );
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (desktopRail || compactRail)
              _NavigationRail(
                controller: widget.controller,
                expanded: desktopRail,
              ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: width < 700 ? 20 : 48,
                      ),
                      child: Focus(
                        key: const ValueKey('web-local-personal-page-focus'),
                        focusNode: _pageFocusNode,
                        child: page,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: width < 700
          ? _BottomNavigation(controller: widget.controller)
          : null,
    );
  }
}

class _NavigationRail extends StatelessWidget {
  const _NavigationRail({required this.controller, required this.expanded});

  final WebLocalPersonalRouteController controller;
  final bool expanded;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Primary navigation',
    child: Container(
      width: expanded ? 232 : 80,
      color: const Color(0xFF103E46),
      child: NavigationRail(
        backgroundColor: Colors.transparent,
        extended: expanded,
        minExtendedWidth: 232,
        useIndicator: true,
        indicatorColor: const Color(0xFFBFEAF0),
        selectedIconTheme: const IconThemeData(color: Color(0xFF103E46)),
        unselectedIconTheme: const IconThemeData(color: Color(0xFFFFFCF6)),
        selectedLabelTextStyle: const TextStyle(
          color: Color(0xFF103E46),
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: Color(0xFFFFFCF6),
          fontWeight: FontWeight.w600,
        ),
        selectedIndex: controller.current.index,
        labelType: expanded
            ? NavigationRailLabelType.none
            : NavigationRailLabelType.all,
        onDestinationSelected: (index) =>
            controller.goTo(WebLocalPersonalDestination.values[index]),
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 24),
          child: Text(
            expanded ? 'Dosey\nPersonal' : 'D',
            style: const TextStyle(
              color: Color(0xFFFFFCF6),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        destinations: [
          for (final destination in WebLocalPersonalDestination.values)
            NavigationRailDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.icon),
              label: Text(destination.label),
            ),
        ],
      ),
    ),
  );
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({required this.controller});

  final WebLocalPersonalRouteController controller;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final roomyLabels = textScale > 1.25;
    return Semantics(
      label: 'Primary navigation',
      child: Container(
        key: const ValueKey('web-local-personal-bottom-navigation'),
        padding: EdgeInsets.only(bottom: bottom),
        color: const Color(0xFF103E46),
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: roomyLabels
              ? Column(
                  children: [
                    for (final destination
                        in WebLocalPersonalDestination.values)
                      FocusTraversalOrder(
                        order: NumericFocusOrder(destination.index.toDouble()),
                        child: SizedBox(
                          height: 52,
                          width: double.infinity,
                          child: _BottomDestination(
                            destination: destination,
                            selected: destination == controller.current,
                            expanded: true,
                            onSelect: () => controller.goTo(destination),
                          ),
                        ),
                      ),
                  ],
                )
              : SizedBox(
                  height: 72,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final destination
                            in WebLocalPersonalDestination.values)
                          FocusTraversalOrder(
                            order: NumericFocusOrder(
                              destination.index.toDouble(),
                            ),
                            child: SizedBox(
                              width: 64,
                              child: _BottomDestination(
                                destination: destination,
                                selected: destination == controller.current,
                                onSelect: () => controller.goTo(destination),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _BottomDestination extends StatelessWidget {
  const _BottomDestination({
    required this.destination,
    required this.selected,
    required this.onSelect,
    this.expanded = false,
  });

  final WebLocalPersonalDestination destination;
  final bool selected;
  final VoidCallback onSelect;
  final bool expanded;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: destination.label,
    child: TextButton(
      key: ValueKey('web-local-personal-nav-${destination.name}'),
      autofocus: selected,
      onPressed: onSelect,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        foregroundColor: selected
            ? const Color(0xFF7DDAE5)
            : const Color(0xFFFFFCF6),
      ),
      child: expanded
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(destination.icon, size: 22),
                const SizedBox(width: 12),
                Text(
                  destination.label,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(destination.icon, size: 22),
                const SizedBox(height: 3),
                Expanded(
                  child: Text(
                    destination.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
    ),
  );
}

class _RecoveryGate extends StatelessWidget {
  const _RecoveryGate({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Semantics(
                container: true,
                liveRegion: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Local storage needs attention',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Dosey has not opened your information. Reload this page or try a supported browser.',
                    ),
                    if (onRetry != null) ...[
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: onRetry,
                        child: const Text('Try again'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _UnknownRouteGate extends StatelessWidget {
  const _UnknownRouteGate({required this.onReturn});

  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Semantics(
              container: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Page not found',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('This local Personal page is not available.'),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: onReturn,
                    child: const Text('Go to Today'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
