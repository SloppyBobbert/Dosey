import 'package:dosey_app/core/storage/dosey_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native in-memory constructor preserves the demo flag', () async {
    final production = DoseyDatabase.inMemory();

    expect(production.isDemo, isFalse);
    expect(await production.customSelect('SELECT 1').get(), isNotEmpty);
    await production.close();

    final demo = DoseyDatabase.inMemory(isDemo: true);
    addTearDown(demo.close);

    expect(demo.isDemo, isTrue);
    expect(await demo.customSelect('SELECT 1').get(), isNotEmpty);
  });
}
