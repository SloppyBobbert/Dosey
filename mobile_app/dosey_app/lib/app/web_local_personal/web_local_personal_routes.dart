import 'package:flutter/material.dart';

enum WebLocalPersonalDestination {
  today('/today', 'Today', Icons.today_outlined),
  prescriptions('/prescriptions', 'Prescriptions', Icons.medication_outlined),
  schedule('/schedule', 'Schedule', Icons.calendar_month_outlined),
  log('/log', 'Log', Icons.receipt_long_outlined),
  settings('/settings', 'Settings', Icons.tune_outlined);

  const WebLocalPersonalDestination(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;

  static WebLocalPersonalDestination fromPath(String path) {
    final normalizedPath = normalizePath(path);
    return values.firstWhere(
      (destination) => destination.path == normalizedPath,
      orElse: () => WebLocalPersonalDestination.today,
    );
  }

  static bool containsPath(String path) {
    final normalizedPath = normalizePath(path);
    return values.any((destination) => destination.path == normalizedPath);
  }

  static String normalizePath(String path) {
    if (path.isEmpty) return '/today';
    var normalizedPath = path;
    while (normalizedPath.length > 1 && normalizedPath.endsWith('/')) {
      normalizedPath = normalizedPath.substring(0, normalizedPath.length - 1);
    }
    return normalizedPath == '/' ? '/today' : normalizedPath;
  }
}

class WebLocalPersonalRouteController extends ChangeNotifier {
  WebLocalPersonalRouteController({String initialPath = '/today'})
    : _history = [WebLocalPersonalDestination.fromPath(initialPath)],
      _unknownPath = WebLocalPersonalDestination.containsPath(initialPath)
          ? null
          : WebLocalPersonalDestination.normalizePath(initialPath);

  final List<WebLocalPersonalDestination> _history;
  int _index = 0;
  String? _unknownPath;

  WebLocalPersonalDestination get current => _history[_index];
  String get currentPath => _unknownPath ?? current.path;
  bool get hasUnknownPath => _unknownPath != null;
  bool get canGoBack => _index > 0;
  bool get canGoForward => _index < _history.length - 1;

  void goTo(WebLocalPersonalDestination destination) {
    final wasUnknown = _unknownPath != null;
    _unknownPath = null;
    if (destination == current) {
      if (wasUnknown) notifyListeners();
      return;
    }
    _history.removeRange(_index + 1, _history.length);
    _history.add(destination);
    _index = _history.length - 1;
    notifyListeners();
  }

  void setPath(String path) {
    final normalizedPath = WebLocalPersonalDestination.normalizePath(path);
    if (!WebLocalPersonalDestination.containsPath(normalizedPath)) {
      if (_unknownPath == normalizedPath) return;
      _unknownPath = normalizedPath;
      notifyListeners();
      return;
    }
    goTo(WebLocalPersonalDestination.fromPath(normalizedPath));
  }

  bool goBack() {
    if (_unknownPath != null) {
      _unknownPath = null;
      notifyListeners();
      return true;
    }
    if (!canGoBack) return false;
    _index -= 1;
    notifyListeners();
    return true;
  }

  bool goForward() {
    if (!canGoForward) return false;
    _index += 1;
    notifyListeners();
    return true;
  }
}

typedef WebLocalPersonalRouterBuilder =
    Widget Function(
      BuildContext context,
      WebLocalPersonalRouteController controller,
    );

class WebLocalPersonalRouteDelegate extends RouterDelegate<RouteInformation>
    with ChangeNotifier {
  WebLocalPersonalRouteDelegate({
    required this.controller,
    required this.builder,
  }) {
    controller.addListener(notifyListeners);
  }

  final WebLocalPersonalRouteController controller;
  final WebLocalPersonalRouterBuilder builder;

  @override
  RouteInformation? get currentConfiguration =>
      RouteInformation(uri: Uri(path: controller.currentPath));

  @override
  Future<void> setNewRoutePath(RouteInformation configuration) {
    controller.setPath(configuration.uri.path);
    return Future.value();
  }

  @override
  Widget build(BuildContext context) => builder(context, controller);

  @override
  Future<bool> popRoute() => Future.value(controller.goBack());

  @override
  void dispose() {
    controller.removeListener(notifyListeners);
    super.dispose();
  }
}

class WebLocalPersonalRouteInformationParser
    extends RouteInformationParser<RouteInformation> {
  const WebLocalPersonalRouteInformationParser();

  @override
  Future<RouteInformation> parseRouteInformation(
    RouteInformation routeInformation,
  ) => Future.value(routeInformation);

  @override
  RouteInformation restoreRouteInformation(RouteInformation configuration) =>
      configuration;
}
