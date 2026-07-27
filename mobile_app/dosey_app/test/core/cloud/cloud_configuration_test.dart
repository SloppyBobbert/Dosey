import 'package:dosey_app/core/cloud/cloud_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cloud configuration stays disabled when values are absent', () {
    final configuration = CloudConfiguration.fromValues();

    expect(configuration.isEnabled, isFalse);
    expect(configuration.endpoint, isNull);
    expect(configuration.projectId, isNull);
  });

  test('cloud configuration enables a complete Appwrite setup', () {
    final configuration = CloudConfiguration.fromValues(
      endpoint: 'https://nyc.cloud.appwrite.io/v1',
      projectId: 'dosey-development',
    );

    expect(configuration.isEnabled, isTrue);
    expect(configuration.endpoint, 'https://nyc.cloud.appwrite.io/v1');
    expect(configuration.projectId, 'dosey-development');
  });

  test('cloud configuration rejects a partial Appwrite setup', () {
    expect(
      () => CloudConfiguration.fromValues(
        endpoint: 'https://nyc.cloud.appwrite.io/v1',
      ),
      throwsArgumentError,
    );
    expect(
      () => CloudConfiguration.fromValues(projectId: 'dosey-development'),
      throwsArgumentError,
    );
  });
}
