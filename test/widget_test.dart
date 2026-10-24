import 'package:flutter_test/flutter_test.dart';
import 'package:roku_remote/ecp2/ecp2_auth.dart';

void main() {
  group('Ecp2Auth', () {
    test('computes the known challenge/response vector', () {
      // Captured from the official app: challenge -> response.
      const challenge = 'AyCBTDxA6o3v+UjUSYRb1g==';
      const expected = 'SaCJPcD5cKOGN7LAbeht+IjxkXs=';
      expect(Ecp2Auth.response(challenge), expected);
    });

    test('is deterministic', () {
      const challenge = 'MEmKpXyTLcGmGpAYUUguYw==';
      expect(Ecp2Auth.response(challenge), Ecp2Auth.response(challenge));
    });
  });
}
