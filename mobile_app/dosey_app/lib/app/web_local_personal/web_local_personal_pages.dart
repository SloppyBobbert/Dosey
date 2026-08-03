import 'package:dosey_app/app/web_local_personal/web_local_personal_routes.dart';
import 'package:dosey_app/core/storage/web_storage_types.dart';
import 'package:flutter/material.dart';

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
  final copy = switch (destination) {
    WebLocalPersonalDestination.today => (
      title: 'Today',
      message: 'Local schedule details will appear here.',
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
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
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
  WebStorageReady() => 'Local storage is ready for this browser.',
  WebStorageDemoOnly() =>
    'Demo only — non-persistent. Nothing entered here is saved.',
  WebStorageStartupRecovery() =>
    'Local storage needs attention before information can be opened.',
};

String _localOnlyMessage(WebStorageBootstrapResult storage) =>
    switch (storage) {
      WebStorageReady() => 'Information stays in this browser.',
      WebStorageDemoOnly() => 'This is a fictional, non-persistent preview.',
      WebStorageStartupRecovery() => 'Information has not been opened.',
    };
