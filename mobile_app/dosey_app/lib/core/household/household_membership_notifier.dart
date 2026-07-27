import 'package:dosey_app/core/household/robot_installation.dart';
import 'package:flutter/foundation.dart';

class HouseholdMembershipNotifier extends ChangeNotifier {
  RobotInstallation? _robot;

  RobotInstallation? get robot => _robot;

  void update(RobotInstallation? robot) {
    _robot = robot;
    notifyListeners();
  }
}
