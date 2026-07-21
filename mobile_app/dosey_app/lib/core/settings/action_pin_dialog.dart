import 'package:dosey_app/app/dosey_app_scope.dart';
import 'package:dosey_app/core/settings/action_pin_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<bool> authorizeActionPin(BuildContext context) async {
  final gate = ActionPinGate(DoseyAppScope.of(context).settings);
  final authorized = await gate.authorize(
    requestPin: () => showActionPinPromptDialog(context),
  );
  if (!authorized && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Action PIN not accepted.')));
  }
  return authorized;
}

Future<String?> showActionPinPromptDialog(BuildContext context) {
  final controller = TextEditingController();
  String? errorText;

  return showDialog<String>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Enter Action PIN'),
            content: TextField(
              key: const Key('action-pin-field'),
              controller: controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'PIN',
                errorText: errorText,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final pin = controller.text.trim();
                  if (pin.isEmpty) {
                    setState(() => errorText = 'Enter your PIN.');
                    return;
                  }
                  Navigator.of(context).pop(pin);
                },
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(() {
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  });
}

Future<String?> showActionPinSetupDialog(
  BuildContext context, {
  String title = 'Enable PIN',
}) {
  final pinController = TextEditingController();
  final confirmController = TextEditingController();
  String? errorText;

  return showDialog<String>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('new-action-pin-field'),
                  controller: pinController,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'New PIN',
                    errorText: errorText,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('confirm-action-pin-field'),
                  controller: confirmController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Confirm PIN'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final pin = pinController.text.trim();
                  final confirmation = confirmController.text.trim();
                  if (!_isDigitsOnly(pin) || !_isDigitsOnly(confirmation)) {
                    setState(() => errorText = 'Use digits only.');
                    return;
                  }
                  if (pin.length < 4) {
                    setState(() => errorText = 'Use at least 4 digits.');
                    return;
                  }
                  if (pin != confirmation) {
                    setState(() => errorText = 'PIN entries do not match.');
                    return;
                  }
                  Navigator.of(context).pop(pin);
                },
                child: const Text('Save PIN'),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pinController.dispose();
      confirmController.dispose();
    });
  });
}

bool _isDigitsOnly(String pin) {
  return RegExp(r'^\d+$').hasMatch(pin);
}
