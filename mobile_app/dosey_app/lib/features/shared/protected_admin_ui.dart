import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/admin/protected_admin_action.dart';
import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/settings/action_pin_dialog.dart';
import 'package:flutter/material.dart';

Future<ProtectedAdminActionResult<T>> runProtectedAdminAction<T>(
  BuildContext context, {
  required Future<T> Function(AdminAuditActorIdentity actor) action,
}) async {
  final dependencies = DoseyAppScope.of(context);
  final runner = ProtectedAdminActionRunner(
    pinGate: dependencies.actionPinGate,
    localAuth: dependencies.localAuth,
  );
  final result = await runner.run<T>(
    requestPin: () => showActionPinPromptDialog(context),
    action: action,
  );
  if (!context.mounted) {
    return result;
  }
  if (result.status == ProtectedAdminActionStatus.denied) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Wrong PIN.')));
  }
  return result;
}

Future<String> currentAdminSourceDeviceRole(BuildContext context) async {
  final dependencies = DoseyAppScope.of(context);
  final role = await dependencies.settings.getDeviceRole();
  return role.storageValue;
}
