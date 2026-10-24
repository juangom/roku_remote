# Roku Remote (Flutter)

A Flutter remote control for Roku TV/players that works **even when the TV is
set to "Limited" network mode** — the mode where the classic HTTP ECP API
returns `403 Forbidden`.

It talks the **ECP-2 WebSocket protocol**, the same one the official Roku
mobile app uses, on `ws://<ip>:8060/ecp-session`.

This is a working skeleton: discovery + connection/auth + the core remote
buttons are implemented and functional. See [Status](#status).

---

## Why this protocol?

Older Roku remote tools use Roku's **ECP** REST API:

```
POST http://<ip>:8060/keypress/Home      →  403 Forbidden in limited mode
```

Newer Roku firmware (OS 14+) defaults many devices to a privacy setting that
blocks these requests. The official app switched to **ECP-2**: a WebSocket
that authenticates with a SHA-1 challenge/response and is **not** blocked.

```
ws://<ip>:8060/ecp-session          (subprotocol: ecp-2)
{"request":"key-press","param-key":"Home"}   →  {"status":"200","status-msg":"OK"}
```

Full details — handshake, auth, message format, button map — are in
[`docs/ECP2_PROTOCOL.md`](docs/ECP2_PROTOCOL.md). You do **not** need any other
context to understand or reimplement it.

## Features

- **SSDP discovery** of Roku devices on the LAN (`roku:ecp`).
- **Device info** over plain HTTP (`/query/device-info`) for name/model.
- **ECP-2 session**: WebSocket connect + automatic SHA-1 authentication.
- **Remote buttons**: power, home, back, select, D-pad, volume, mute,
  play/replay/rewind/fast-forward, options/info, search.
- Library-level support for **text entry**, **installed apps** and
  **launch app** (`Ecp2Client.sendText`, `.installedApps`, `.launchApp`).

## Requirements

- Flutter (tested with Flutter 3.47 / Dart 3.13).
- The phone/computer and the Roku on the **same LAN**.
- Dependencies: `web_socket_channel`, `crypto`, `http` (already in `pubspec.yaml`).

## Run

```bash
flutter pub get
flutter run          # pick a connected device/emulator
```

## Project structure

```
lib/
  main.dart                     App entry (MaterialApp, dark theme)
  models/
    roku_device.dart            Discovered-device model
  ecp2/
    ecp2_auth.dart              SHA-1 challenge/response (the auth constant)
    ecp2_client.dart            WebSocket client: connect, auth, key-press, queries
    roku_keys.dart              Button -> param-key names
    discovery.dart              SSDP scan + /query/device-info
  ui/
    device_picker_page.dart     Scan list + add-by-IP
    remote_page.dart            D-pad and button pad
test/
  widget_test.dart              Auth vector test (known challenge/response)
docs/
  ECP2_PROTOCOL.md              Self-contained protocol reference
  DISCOVERY.md                  How discovery works, requirements, roadmap
  NETWORKING.md                 Discovery and the Android-emulator NAT limitation
```

## How it works (short version)

1. **Discover**: SSDP `M-SEARCH` for `roku:ecp` → list of IPs. Fetch each
   device's name/model via `GET http://<ip>:8060/query/device-info`.
2. **Connect**: open `ws://<ip>:8060/ecp-session` with subprotocol `ecp-2`.
3. **Authenticate**: the Roku sends a `param-challenge`; respond with
   `base64(SHA1(challenge + "F3A278B8-1C6F-44A9-9D89-F1979CA4C6F1"))`.
   Without this, requests return `401 Unauthorized`.
4. **Control**: send `{"request":"key-press","param-key":"<Key>",...}`; read the
   `{"response":"key-press","status":"200",...}` back, matched by `request-id`.

## Status

Implemented:
- Discovery, device-info, ECP-2 connect + auth, all core buttons.
- Reconnect-and-resume: the session is re-established automatically after the
  app is backgrounded/locked or the connection drops.

Not yet implemented (library hooks exist):
- Text entry UI, app list / launch UI, settings.

## Known limitations

- **Discovery (SSDP) does not work in the Android emulator.** The emulator runs
  behind user-mode NAT, which forwards unicast TCP but not multicast. Use
  **Add by IP** there; auto-scan works on a real phone/computer on the same
  WiFi. Details and options: [`docs/NETWORKING.md`](docs/NETWORKING.md).

## Legal

Use this only on Roku devices you own or are authorized to control, on networks
you are allowed to use.
