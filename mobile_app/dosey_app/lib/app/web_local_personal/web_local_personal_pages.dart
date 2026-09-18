import 'package:dosey_app/app/web_local_personal/web_local_personal_routes.dart';
import 'package:dosey_app/core/storage/web_storage_types.dart';
import 'package:flutter/material.dart';
import 'package:dosey_app/features/prescriptions/prescriptions_screen.dart';
import 'package:dosey_app/features/reminders/reminders_screen.dart';
import 'package:dosey_app/features/shared/personal_setup_scope.dart';

const localPersonalStorageNotice =
    'Information stays only in this browser profile on this device. It is not '
    'shared with an account or household. Clearing site data, private browsing '
    'or browser eviction can lose it. There is no server recovery and no OS or '
    'background reminder guarantee.';

typedef WebLocalPersonalPageBuilder =
    Widget Function(
      BuildContext context,
      WebLocalPersonalDestination destination,
      WebStorageBootstrapResult storage, {
      VoidCallback? onAddPrescription,
      VoidCallback? onAddSchedule,
    });

Widget buildWebLocalPersonalFoundationPage(
  BuildContext context,
  WebLocalPersonalDestination destination,
  WebStorageBootstrapResult storage, {
  VoidCallback? onAddPrescription,
  VoidCallback? onAddSchedule,
}) {
  final isReady = storage is WebStorageReady;
  if (isReady && PersonalSetupScope.maybeOf(context) != null) {
    if (destination == WebLocalPersonalDestination.prescriptions) {
      return const PrescriptionsScreen();
    }
    if (destination == WebLocalPersonalDestination.schedule) {
      return const RemindersScreen();
    }
  }
  final copy = switch (destination) {
    WebLocalPersonalDestination.today => (
      title: 'Today',
      message: 'Your next local dose details will appear here.',
      action: null,
      actionLabel: null,
    ),
    WebLocalPersonalDestination.prescriptions => (
      title: 'Prescriptions',
      message: 'Local prescription details will appear here.',
      action: isReady ? onAddPrescription : null,
      actionLabel: isReady && onAddPrescription != null
          ? 'Add prescription'
          : null,
    ),
    WebLocalPersonalDestination.schedule => (
      title: 'Schedule',
      message: 'Local schedule details will appear here.',
      action: isReady ? onAddSchedule : null,
      actionLabel: isReady && onAddSchedule != null ? 'Add schedule' : null,
    ),
    WebLocalPersonalDestination.log => (
      title: 'Log',
      message: 'This read-only space will show local dose history.',
      action: null,
      actionLabel: null,
    ),
    WebLocalPersonalDestination.settings => (
      title: 'Settings',
      message: _storageMessage(storage),
      action: null,
      actionLabel: null,
    ),
  };

  return Semantics(
    container: true,
    label: '${copy.title} page',
    child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          // Match the horizontal inset the prescriptions and schedule pages use
          // so switching tabs no longer shifts the content column sideways.
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  copy.title,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                copy.message,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(_localOnlyMessage(storage)),
              const SizedBox(height: 12),
              const Text('Today actions and history are not available yet.'),
              if (copy.action != null) ...[
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: copy.action,
                  icon: const Icon(Icons.add),
                  label: Text(copy.actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

String _storageMessage(WebStorageBootstrapResult storage) => switch (storage) {
  WebStorageReady(:final classification) =>
    'Local storage is ready for this browser (${classification.implementation.name}).',
  WebStorageDemoOnly() =>
    'Demo only — non-persistent. Nothing entered here is saved.',
  WebStorageStartupRecovery() =>
    'Local storage needs attention before information can be opened.',
};

String _localOnlyMessage(WebStorageBootstrapResult storage) =>
    switch (storage) {
      WebStorageReady() => localPersonalStorageNotice,
      WebStorageDemoOnly() => 'This is a fictional, non-persistent preview.',
      WebStorageStartupRecovery() => 'Information has not been opened.',
    };
