import 'package:dosey_app/app/web/web_auth_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes an allowed origin and derives both callbacks', () {
    final config = WebAuthConfiguration.fromValues(
      enabled: true,
      appOrigin: ' https://app.dosey.example/ ',
      endpoint: 'https://cloud.example/v1/',
      projectId: ' project ',
    );

    expect(config.appOrigin, 'https://app.dosey.example');
    expect(config.isStaging, isFalse);
    expect(config.oauthSuccess.path, '/auth.html');
    expect(config.oauthFailure.path, '/auth.html');
    expect(
      config.oauthSuccess.toString(),
      contains('/auth.html?result=success'),
    );
    expect(
      config.oauthFailure.toString(),
      contains('/auth.html?result=failure'),
    );
    expect(config.oauthSuccess.queryParameters, {'result': 'success'});
    expect(config.oauthFailure.queryParameters, {'result': 'failure'});
  });

  test('disabled preview does not require public auth configuration', () {
    expect(WebAuthConfiguration.fromValues(enabled: false).enabled, isFalse);
  });

  test('parses the auth flag without treating typos as disabled', () {
    expect(WebAuthConfiguration.parseAuthEnabled(''), isFalse);
    expect(WebAuthConfiguration.parseAuthEnabled('false'), isFalse);
    expect(WebAuthConfiguration.parseAuthEnabled('true'), isTrue);
    for (final value in ['ture', ' true ', ' false ', 'TRUE', 'False']) {
      expect(
        () => WebAuthConfiguration.parseAuthEnabled(value),
        throwsA(isA<ArgumentError>()),
      );
    }
  });

  test('recognizes the immutable staging origin', () {
    final config = WebAuthConfiguration.fromValues(
      enabled: true,
      appOrigin: 'https://staging.dosey.dev/',
      endpoint: 'https://cloud.example/v1',
      projectId: 'project',
    );
    expect(config.isStaging, isTrue);
  });

  test('enabled auth requires each public setting', () {
    for (final values in [
      {
        'appOrigin': null,
        'endpoint': 'https://cloud.example/v1',
        'projectId': 'p',
      },
      {'appOrigin': 'https://app.example', 'endpoint': null, 'projectId': 'p'},
      {
        'appOrigin': 'https://app.example',
        'endpoint': 'https://cloud.example/v1',
        'projectId': null,
      },
    ]) {
      expect(
        () => WebAuthConfiguration.fromValues(
          enabled: true,
          appOrigin: values['appOrigin'],
          endpoint: values['endpoint'],
          projectId: values['projectId'],
        ),
        throwsArgumentError,
      );
    }
  });

  test('rejects unsafe origins when enabled', () {
    for (final origin in [
      'http://dosey.example',
      'https://user:secret@dosey.example',
      'https://dosey.example/path',
      'https://dosey.example?code=secret',
      'https://dosey.example#fragment',
    ]) {
      expect(
        () => WebAuthConfiguration.fromValues(
          enabled: true,
          appOrigin: origin,
          endpoint: 'https://cloud.example/v1',
          projectId: 'project',
        ),
        throwsArgumentError,
      );
    }
  });

  test('accepts localhost over HTTP and handles IPv6 formatting', () {
    final config = WebAuthConfiguration.fromValues(
      enabled: true,
      appOrigin: 'http://[::1]:8080',
      endpoint: 'http://localhost:9000/v1',
      projectId: 'project',
    );
    expect(config.appOrigin, 'http://[::1]:8080');
    expect(config.oauthSuccess.path, '/auth.html');
  });

  test('rejects unsafe endpoints', () {
    for (final endpoint in [
      'http://cloud.example/v1',
      'https://user:secret@cloud.example/v1',
      'https://cloud.example/v1?token=secret',
      'https://cloud.example/v1#fragment',
    ]) {
      expect(
        () => WebAuthConfiguration.fromValues(
          enabled: true,
          appOrigin: 'https://app.example',
          endpoint: endpoint,
          projectId: 'project',
        ),
        throwsArgumentError,
      );
    }
  });
}
