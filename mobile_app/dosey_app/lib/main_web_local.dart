import 'package:dosey_app/app/web_local_personal/web_local_personal_startup.dart';
import 'package:dosey_app/core/storage/web_storage_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    WebLocalPersonalStartupApp(
      startup: WebLocalPersonalStartup(
        bootstrap: () async {
          // Static local assets are assembled with this entry, never a CDN.
          final fonts = FontLoader('DoseyLocalRoboto')
            ..addFont(rootBundle.load('local_fonts/Roboto-Regular.ttf'))
            ..addFont(rootBundle.load('local_fonts/Roboto-Bold.ttf'));
          await fonts.load();
          return bootstrapWebDoseyDatabase(
            databaseName: WebLocalPersonalStartup.databaseName,
          );
        },
        onShutdownFailure: (failure) => FlutterError.reportError(
          FlutterErrorDetails(
            exception: failure.error,
            stack: failure.stackTrace,
            library: 'Dosey local storage shutdown',
          ),
        ),
      ),
    ),
  );
}
