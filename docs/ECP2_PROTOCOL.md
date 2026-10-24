# Roku ECP-2 Protocol Reference

A self-contained description of the Roku **ECP-2** protocol used by the official
Roku mobile app to control a Roku over the local network. This document is
enough to implement a client from scratch.

## 1. What it is

Roku devices expose two control surfaces on **TCP port 8060**:

| Surface | Transport | Behavior |
|---------|-----------|----------|
| **ECP (classic)** | HTTP REST | `POST /keypress/<Key>`. Returns `403 Forbidden` when the TV is in **limited** network mode. |
| **ECP-2** | WebSocket | `ws://<ip>:8060/ecp-session`. Authenticates, then sends JSON commands. **Works in limited mode.** |

ECP-2 is the protocol to use. It carries JSON messages, needs no pairing, and
authenticates with a public constant (not a per-device secret).

## 2. Transport & handshake

Open a WebSocket with:

- URL: `ws://<ip>:8060/ecp-session`
- Subprotocol: `ecp-2`
- Origin header: `Android` (the official app uses this; harmless for others)

The raw HTTP upgrade looks like:

```
GET /ecp-session HTTP/1.1
Host: <ip>:8060
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Protocol: ecp-2
Sec-WebSocket-Origin: Android
Sec-WebSocket-Key: <base64 random>
Sec-WebSocket-Version: 13
Sec-WebSocket-Extensions: permessage-deflate
User-Agent: okhttp/5.4.0
```

```
HTTP/1.1 101 Switching Protocols
Sec-WebSocket-Protocol: ecp-2
Upgrade: websocket
```

`permessage-deflate` is optional; a client that does not negotiate it still
works. WebSocket framing is standard: **client→server frames are masked,
server→client frames are not** (which is why server JSON is readable on the
wire while client JSON is obfuscated by the mask).

## 3. Authentication (required)

Immediately after the connection opens, the server sends:

```json
{
  "notify": "authenticate",
  "param-challenge": "AyCBTDxA6o3v+UjUSYRb1g==",
  "param-methods": ["client-id", "jwt"],
  "timestamp": "116824.968"
}
```

The client answers with:

```json
{ "request": "authenticate", "request-id": "1", "param-response": "<response>" }
```

where

```
response = base64( SHA1( challenge_string + MAGIC_KEY ) )
```

- `challenge_string` is the **raw** `param-challenge` text. **Do not**
  base64-decode it before hashing.
- `MAGIC_KEY` is a constant baked into the official app:

  ```
  F3A278B8-1C6F-44A9-9D89-F1979CA4C6F1
  ```

  It can also be derived from the base constant
  `95E610D0-7C29-44EF-FB0F-97F1FCE4C297` by replacing each hex digit `n` with
  `(15 - n + 9) mod 16` (non-hex characters pass through unchanged).

Success:

```json
{ "response": "authenticate", "response-id": "1", "status": "200", "status-msg": "OK" }
```

The client may include extra fields in the authenticate request, e.g.
`param-client-friendly-name`, `param-has-microphone`,
`param-microphone-sample-rates`; they are optional.

Any request sent **before** a successful authenticate returns:

```json
{ "status": "401", "status-msg": "Unauthorized" }
```

### Worked example

```
challenge = "AyCBTDxA6o3v+UjUSYRb1g=="
SHA1(challenge + MAGIC_KEY) → 49a0893dc0f970a38637b2c06de86df888f1917b
base64 → "SaCJPcD5cKOGN7LAbeht+IjxkXs="
```

This exact vector is covered by a unit test in this repository
(`test/widget_test.dart`).

## 4. Message format

Every client message is a JSON object with a `request` name, a unique
`request-id`, and request-specific parameters. The server replies with a
`response` object carrying the matching `response-id`:

```json
{ "response": "<request>", "response-id": "<id>", "status": "200", "status-msg": "OK" }
```

The server may also push asynchronous `notify` objects at any time. A client
should read messages until it finds the `response` with the expected id,
ignoring (or handling) `notify` messages in between.

| `request` | Parameters | Result |
|-----------|-----------|--------|
| `authenticate` | `param-response` | status |
| `query-device-info` | — | `content-data` = base64 of device-info XML |
| `query-active-app` | — | `content-data` = base64 XML |
| `query-apps` | — | `content-data` = base64 XML (installed apps) |
| `request-events` | `param-events` (e.g. `+tv-channel-changed`) | status |
| `key-press` | `param-key` | status |
| `launch` | `param-channel-id` | status |

### Query responses

Query payloads come back base64-encoded in `content-data`:

```json
{
  "content-data": "PD94bWwgdmVyc2lvbj0iMS4wIiA/Pgo8ZGV2aWNlLWluZm8+...",
  "content-type": "text/xml; charset=\"utf-8\"",
  "response": "query-device-info",
  "response-id": "1",
  "status": "200",
  "status-msg": "OK"
}
```

Decode `content-data` (base64) to get the XML string.

## 5. Key presses

```json
{ "request": "key-press", "param-key": "Home", "request-id": "3" }
→ { "response": "key-press", "response-id": "3", "status": "200", "status-msg": "OK" }
```

### Button → `param-key`

| Physical button | `param-key` |
|-----------------|-------------|
| Power (toggle) | `PowerOff` |
| Power on | `PowerOn` |
| Back | `Back` |
| Home | `Home` |
| OK / Select | `Select` |
| Up / Down / Left / Right | `Up` / `Down` / `Left` / `Right` |
| Volume up / down | `VolumeUp` / `VolumeDown` |
| Mute | `VolumeMute` |
| Play / Pause | `Play` |
| Instant replay | `InstantReplay` |
| Rewind | `Rev` |
| Fast forward | `Fwd` |
| Options `*` / Info | `Info` |
| Channel up / down | `ChannelUp` / `ChannelDown` |
| Input Tuner | `InputTuner` |
| Input HDMI 1-4 | `InputHDMI1` … `InputHDMI4` |
| Search | `Search` |
| Find remote | `FindRemote` |
| Enter | `Enter` |
| Backspace | `Backspace` |

## 6. Text entry

Send one key per character using `Lit_<char>`:

```json
{ "request": "key-press", "param-key": "Lit_H", "request-id": "5" }
```

**Do not URL-encode** the character (unlike the classic HTTP ECP API, which
required `%XX`). `Lit_&` is correct; `Lit_%26` returns `400 Bad Request`.

## 7. Launching apps

1. `query-apps` → decode `content-data` → XML with `<app id="...">Name</app>`.
2. Launch by id:

```json
{ "request": "launch", "param-channel-id": "12", "request-id": "7" }
```

## 8. Discovery (finding devices)

- **SSDP**: send `M-SEARCH` for `roku:ecp` to multicast
  `239.255.255.250:1900`; collect responder IPs.

  ```
  M-SEARCH * HTTP/1.1
  HOST: 239.255.255.250:1900
  MAN: "ssdp:discover"
  MX: 3
  ST: roku:ecp
  ```

- **Device info** (allowed even in limited mode):
  `GET http://<ip>:8060/query/device-info` → XML with `user-device-name`,
  `model-name`, `serial-number`, `software-version`, `ecp-setting-mode`, etc.

## 9. Minimal client flow

```
1. discover()                      → [192.168.1.42, ...]
2. GET /query/device-info          → name, model
3. ws://<ip>:8060/ecp-session  (subprotocol ecp-2, Origin Android)
4. recv notify(authenticate)       → challenge
5. send request(authenticate, response=SHA1(challenge+KEY))
6. send request(key-press, param-key=Home, request-id=N)
7. recv response(key-press, response-id=N, status=200)
```

## 10. Notes & caveats

- The auth key is a **constant**, not a per-device secret; no pairing or
  credential storage is required.
- Roku firmware occasionally drops the WebSocket; implement reconnect +
  re-authenticate.
- `request-id` values must be unique within a session; incrementing integers
  are fine.
- All of this works **without changing the TV settings**, unlike classic ECP
  (which requires "Control by mobile apps → Network access: Enabled").

## 11. Prior art

- `K1muraC1ph3r/roku` (Python) — same ECP-2 auth algorithm and message set.
- Stack Overflow Q77616691, "Private Listening session on Roku TV" — documents
  the magic-key constant.
