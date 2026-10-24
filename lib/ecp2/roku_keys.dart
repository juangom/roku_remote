/// Roku ECP-2 key names (the `param-key` value in a `key-press` request).
///
/// These are the same names the legacy HTTP ECP API uses, but sent as JSON
/// over the ECP-2 WebSocket instead of a URL path.
///
/// Reference: docs/ECP2_PROTOCOL.md
class RokuKeys {
  RokuKeys._();

  // Power
  static const power = 'PowerOff';
  static const powerOn = 'PowerOn';

  // Navigation
  static const home = 'Home';
  static const back = 'Back';
  static const select = 'Select';
  static const up = 'Up';
  static const down = 'Down';
  static const left = 'Left';
  static const right = 'Right';
  static const info = 'Info';
  static const enter = 'Enter';
  static const backspace = 'Backspace';

  // Volume
  static const volumeUp = 'VolumeUp';
  static const volumeDown = 'VolumeDown';
  static const mute = 'VolumeMute';

  // Playback
  static const play = 'Play';
  static const replay = 'InstantReplay';
  static const rewind = 'Rev';
  static const fastForward = 'Fwd';

  // Channels / inputs
  static const channelUp = 'ChannelUp';
  static const channelDown = 'ChannelDown';
  static const inputTuner = 'InputTuner';
  static const inputHdmi1 = 'InputHDMI1';
  static const inputHdmi2 = 'InputHDMI2';
  static const inputHdmi3 = 'InputHDMI3';
  static const inputHdmi4 = 'InputHDMI4';

  // Other
  static const search = 'Search';
  static const findRemote = 'FindRemote';

  /// A literal text character, e.g. `Lit_a`, `Lit_7`, `Lit_.`.
  /// Do NOT URL-encode the character (unlike the legacy HTTP ECP API).
  static String lit(String char) => 'Lit_$char';
}
