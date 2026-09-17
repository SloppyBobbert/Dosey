import 'package:dosey_app/features/shared/personal_setup_scope.dart';
import 'package:dosey_app/core/admin/protected_admin_action.dart';
import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/settings/action_pin_dialog.dart';
import 'package:flutter/material.dart';

Future<ProtectedAdminActionResult<T>> runProtectedAdminAction<T>(
  BuildContext context, {
  required Future<T> Function(AdminAuditActorIdentity actor) action,
}) async {
  final dependencies = PersonalSetupScope.of(context);
  final result = await dependencies.run<T>(
    requestPin: () {
      if (!context.mounted) return Future<String?>.value();
      return showActionPinPromptDialog(context);
    },
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

Widget protectSetupForm(BuildContext context, bool pending, Widget child) {
  if (!PersonalSetupScope.of(context).localWeb) return child;
  return PopScope(
    canPop: !pending,
    child: AbsorbPointer(absorbing: pending, child: child),
  );
}

Future<bool> confirmSetupDelete(BuildContext context, String item) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete $item?'),
          content: const Text(
            'This cannot be undone. Existing dose history is retained.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<String> currentAdminSourceDeviceRole(BuildContext context) async {
  return PersonalSetupScope.of(context).sourceRole();
}
