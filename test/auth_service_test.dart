import 'package:flutter_test/flutter_test.dart';
import 'package:poost_media_buying_os/auth_service.dart';

void main() {
  group('emailForUsername', () {
    test('lowercases and appends the synthetic domain', () {
      expect(emailForUsername('Yosef Aped'), 'yosef-aped@auth.poost.app');
    });

    test('collapses invalid characters into single hyphens', () {
      expect(emailForUsername('  ali!!fahmy__2024  '), 'ali-fahmy-2024@auth.poost.app');
    });

    test('trims leading/trailing hyphens produced by normalization', () {
      expect(emailForUsername('!!ali!!'), 'ali@auth.poost.app');
    });

    test('throws on empty username instead of producing a bare domain', () {
      expect(() => emailForUsername(''), throwsArgumentError);
      expect(() => emailForUsername('   '), throwsArgumentError);
      expect(() => emailForUsername('!!!'), throwsArgumentError);
    });

    test('is deterministic (same username always maps to same email)', () {
      expect(emailForUsername('Owner'), emailForUsername('owner'));
      expect(emailForUsername('Owner'), emailForUsername('  Owner  '));
    });
  });

  group('describeAuthError', () {
    test('never leaks a raw ArgumentError message to the UI', () {
      final msg = describeAuthError(ArgumentError('internal detail'));
      expect(msg, isNot(contains('internal detail')));
    });

    test('falls back to a generic message for unrecognized errors', () {
      final msg = describeAuthError(Exception('some low-level socket error'));
      expect(msg, isNot(contains('socket')));
    });
  });
}
