import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/admin/admin_audit_event_factory.dart';
import 'package:dosey_app/core/admin/protected_admin_action.dart';
import 'package:dosey_app/core/auth/auth_service.dart';
import 'package:dosey_app/core/settings/current_device_platform.dart';
import 'package:dosey_app/core/settings/device_role.dart';
import 'package:dosey_app/features/onboarding/onboarding_flow.dart';
import 'package:dosey_app/features/onboarding/household_membership_gate.dart';
import 'package:dosey_app/features/shell/dosey_shell.dart';
import 'package:flutter/material.dart';

class OnboardingGate extends StatelessWidget {
  const OnboardingGate({
    super.key,
    this.onboardingCompletedStream,
    this.shellForceTodayTab = false,
    this.demoMode = false,
  });

  final Stream<bool>? onboardingCompletedStream;
  final bool shellForceTodayTab;
  final bool demoMode;

  @override
  Widget build(BuildContext context) {
    final dependencies = onboardingCompletedStream == null
        ? DoseyAppScope.of(context)
        : null;
    final onboardingCompleted =
        onboardingCompletedStream ??
        dependencies!.settings.watchOnboardingCompleted();

    return StreamBuilder<bool>(
      stream: onboardingCompleted,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _SetupLoadError();
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data!) {
          return _CompletedOnboardingGate(
            dependencies: dependencies!,
            shellForceTodayTab: shellForceTodayTab,
            demoMode: demoMode,
          );
        }

        return const OnboardingFlow();
      },
    );
  }
}

class _CompletedOnboardingGate extends StatelessWidget {
  const _CompletedOnboardingGate({
    required this.dependencies,
    required this.shellForceTodayTab,
    required this.demoMode,
  });

  final DoseyAppDependencies dependencies;
  final bool shellForceTodayTab;
  final bool demoMode;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppDeviceRole>(
      stream: dependencies.settings.watchDeviceRole(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _SetupLoadError();
        }

        if (!snapshot.hasData) {
          return const _SetupLoading();
        }

        final platform = currentAppDevicePlatform();
        final role = snapshot.data!.isAllowedOn(platform)
            ? snapshot.data!
            : AppDeviceRole.defaultFor(platform);
        // Robot Mode is local-only; personal phones must pass through sign-in.
        if (role.canHostRobot) {
          return DoseyShell(
            forceTodayTab: shellForceTodayTab,
            startOnController: demoMode,
          );
        }

        if (demoMode) {
          return const DoseyShell(startOnController: true);
        }

        return StreamBuilder<AuthSession>(
          stream: dependencies.auth.watchSession(),
          builder: (context, authSnapshot) {
            if (authSnapshot.hasError) {
              return const _SetupLoadError();
            }

            if (!authSnapshot.hasData) {
              return const _SetupLoading();
            }

            if (authSnapshot.data!.isSignedIn) {
              final user = authSnapshot.data!.user!;
              return HouseholdMembershipGate(
                accountId: user.id,
                sync: dependencies.householdSync,
                management: dependencies.householdManagement,
                cache: dependencies.householdCache,
                now: dependencies.appClock.now,
                onHouseholdCreated: (robot) async {
                  final actor = await ProtectedAdminActionRunner(
                    pinGate: dependencies.actionPinGate,
                    localAuth: dependencies.localAuth,
                  ).resolveActor();
                  await dependencies.adminAudit.addEvent(
                    const AdminAuditEventFactory().householdCreated(
                      actor: actor,
                      sourceDeviceRole: role.storageValue,
                      targetId: robot.id,
                      summary: 'Created a robot household.',
                      robotDisplayName: robot.displayName,
                      occurredAt: dependencies.appClock.now(),
                    ),
                  );
                },
                child: DoseyShell(forceTodayTab: shellForceTodayTab),
              );
            }

            return OnboardingFlow(signInRole: role);
          },
        );
      },
    );
  }
}

class _SetupLoading extends StatelessWidget {
  const _SetupLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _SetupLoadError extends StatelessWidget {
  const _SetupLoadError();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40),
              SizedBox(height: 12),
              Text(
                'Setup could not load',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                'Close and reopen Dosey, then try again.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
