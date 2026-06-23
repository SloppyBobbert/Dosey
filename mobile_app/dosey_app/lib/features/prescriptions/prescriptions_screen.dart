import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/prescriptions/local_prescription_repository.dart';
import 'package:dosey_app/core/prescriptions/prescription.dart';
import 'package:dosey_app/core/reminders/local_reminder_repository.dart';
import 'package:dosey_app/features/reminders/reminders_screen.dart';
import 'package:flutter/material.dart';

class PrescriptionsScreen extends StatelessWidget {
  const PrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dependencies = DoseyAppScope.of(context);
    final prescriptions = dependencies.prescriptions;

    return StreamBuilder<List<Prescription>>(
      stream: prescriptions.watchPrescriptions(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Prescription>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Prescriptions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () =>
                      _showPrescriptionSheet(context, prescriptions),
                  icon: const Icon(Icons.add),
                  label: const Text('Add prescription'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Enter what is on your prescription label.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Dosey does not verify prescriptions or identify pills.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No prescriptions yet.'),
                      SizedBox(height: 6),
                      Text('Add your first prescription.'),
                    ],
                  ),
                ),
              )
            else
              for (final prescription in items)
                _PrescriptionTile(
                  prescription: prescription,
                  allPrescriptions: items,
                  prescriptions: prescriptions,
                  reminders: dependencies.reminders,
                ),
          ],
        );
      },
    );
  }

  static Future<void> _showPrescriptionSheet(
    BuildContext context,
    PrescriptionRepository prescriptions, {
    Prescription? prescription,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PrescriptionSheet(
        prescriptions: prescriptions,
        prescription: prescription,
      ),
    );
  }
}

class _PrescriptionTile extends StatelessWidget {
  const _PrescriptionTile({
    required this.prescription,
    required this.allPrescriptions,
    required this.prescriptions,
    required this.reminders,
  });

  final Prescription prescription;
  final List<Prescription> allPrescriptions;
  final PrescriptionRepository prescriptions;
  final ReminderRepository reminders;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: _PillTypeBadge(pillType: prescription.pillType),
        title: Text(prescription.name),
        subtitle: Text(prescription.pillType.label),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Schedule prescription',
              onPressed: () => _schedule(context),
              icon: const Icon(Icons.event_available_outlined),
            ),
            IconButton(
              tooltip: 'Edit prescription',
              onPressed: () => PrescriptionsScreen._showPrescriptionSheet(
                context,
                prescriptions,
                prescription: prescription,
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete prescription',
              onPressed: () => _delete(context),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the schedule builder with this prescription already selected so
  /// users can move from medication entry to routine setup without retyping.
  Future<void> _schedule(BuildContext context) {
    return RemindersScreen.showScheduleSheet(
      context,
      reminders,
      allPrescriptions,
      initialPrescriptionId: prescription.id,
    );
  }

  Future<void> _delete(BuildContext context) async {
    try {
      await prescriptions.deletePrescription(prescription.id);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prescription delete failed: $error')),
      );
    }
  }
}

class _PrescriptionSheet extends StatefulWidget {
  const _PrescriptionSheet({required this.prescriptions, this.prescription});

  final PrescriptionRepository prescriptions;
  final Prescription? prescription;

  @override
  State<_PrescriptionSheet> createState() => _PrescriptionSheetState();
}

class _PrescriptionSheetState extends State<_PrescriptionSheet> {
  late final TextEditingController _nameController;
  late PillType _pillType;
  var _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final prescription = widget.prescription;
    _nameController = TextEditingController(text: prescription?.name ?? '');
    _pillType = prescription?.pillType ?? PillType.pill;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.prescription == null
                  ? 'Add prescription'
                  : 'Edit prescription',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Medication name',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            Text(
              'What does it look like?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pillType in PillType.values)
                  ChoiceChip(
                    avatar: Icon(_iconFor(pillType), size: 18),
                    label: Text(pillType.label),
                    selected: _pillType == pillType,
                    onSelected: (_) => setState(() => _pillType = pillType),
                  ),
              ],
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: const Text('Save prescription'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Validates the label copy, then persists the local prescription entry.
  Future<void> _save() async {
    if (_isSaving) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Enter a medication name.');
      return;
    }

    setState(() {
      _errorText = null;
      _isSaving = true;
    });

    final now = DateTime.now().toUtc();
    final existing = widget.prescription;
    final prescription = Prescription(
      id: existing?.id ?? 'prescription-${now.microsecondsSinceEpoch}',
      name: name,
      pillType: _pillType,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await widget.prescriptions.upsertPrescription(prescription);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Prescription save failed: $error';
        _isSaving = false;
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

class _PillTypeBadge extends StatelessWidget {
  const _PillTypeBadge({required this.pillType});

  final PillType pillType;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      child: Icon(_iconFor(pillType)),
    );
  }
}

IconData _iconFor(PillType pillType) {
  return switch (pillType) {
    PillType.pill => Icons.circle_outlined,
    PillType.capsule => Icons.medication_outlined,
    PillType.tablet => Icons.crop_square_outlined,
  };
}
