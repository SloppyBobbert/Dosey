import 'package:dosey_app/core/audit/admin_audit_event.dart';
import 'package:dosey_app/core/auth/local_auth_repository.dart';
import 'package:dosey_app/core/settings/action_pin_gate.dart';

typedef ProtectedAdminPinRequest = Future<String?> Function();
typedef ProtectedAdminAction<T> =
    Future<T> Function(AdminAuditActorIdentity actor);

enum ProtectedAdminActionStatus { success, cancelled, denied }

class ProtectedAdminActionResult<T> {
  const ProtectedAdminActionResult._({
    required this.status,
    this.value,
    this.actor,
  });

  const ProtectedAdminActionResult.success({
    required T value,
    required AdminAuditActorIdentity actor,
  }) : this._(
         status: ProtectedAdminActionStatus.success,
         value: value,
         actor: actor,
       );

  const ProtectedAdminActionResult.cancelled()
    : this._(status: ProtectedAdminActionStatus.cancelled);

  const ProtectedAdminActionResult.denied()
    : this._(status: ProtectedAdminActionStatus.denied);

  final ProtectedAdminActionStatus status;
  final T? value;
  final AdminAuditActorIdentity? actor;

  bool get isSuccess => status == ProtectedAdminActionStatus.success;
}

class ProtectedAdminActionRunner {
  const ProtectedAdminActionRunner({
    required this.pinGate,
    required this.localAuth,
  });

  final ActionPinGate pinGate;
  final LocalAuthRepository localAuth;

  Future<ProtectedAdminActionResult<T>> run<T>({
    required ProtectedAdminPinRequest requestPin,
    required ProtectedAdminAction<T> action,
  }) async {
    final pinEnabled = await pinGate.isPinEnabled();
    if (pinEnabled) {
      final pin = await requestPin();
      if (pin == null) {
        return const ProtectedAdminActionResult.cancelled();
      }

      final verified = await pinGate.verifyPin(pin);
      if (!verified) {
        return const ProtectedAdminActionResult.denied();
      }
    }

    final actor = await resolveActor();
    final value = await action(actor);
    return ProtectedAdminActionResult.success(value: value, actor: actor);
  }

  Future<AdminAuditActorIdentity> resolveActor() async {
    final user = await localAuth.readCurrentUser();
    if (user == null) {
      return const AdminAuditActorIdentity(
        actorType: AdminAuditActorType.localAdmin,
        actorLabel: 'local admin',
        actorProviderLabel: null,
      );
    }

    final fallbackLabel = _normalizeActorLabel(user.displayName) ?? user.email;
    final providerLabel = user.provider.name;
    return AdminAuditActorIdentity(
      actorType: AdminAuditActorType.signedInUser,
      actorUserId: '$providerLabel:${user.id}',
      actorLabel: '$fallbackLabel ($providerLabel)',
      actorProviderLabel: providerLabel,
    );
  }

  static String? _normalizeActorLabel(String? value) {
    if (value == null) {
      return null;
    }
    final normalizedValue = value.trim();
    return normalizedValue.isEmpty ? null : normalizedValue;
  }
}
