import 'dart:convert';

import 'package:crypto/crypto.dart';

/// ECP-2 authentication.
///
/// On connect the Roku sends a challenge:
///
///   {"notify":"authenticate","param-challenge":"AyCBTDxA6o3v+UjUSYRb1g==", ...}
///
/// The client answers with base64(SHA1(challengeString + magicKey)). The
/// challenge is used **as text** (do not base64-decode it).
///
/// The magic key is a constant baked into the official Roku app; it is not a
/// per-device secret, so any client can compute the response.
class Ecp2Auth {
  Ecp2Auth._();

  static const magicKey = 'F3A278B8-1C6F-44A9-9D89-F1979CA4C6F1';

  static String response(String challenge) {
    final digest = sha1.convert(utf8.encode(challenge + magicKey));
    return base64.encode(digest.bytes);
  }
}
