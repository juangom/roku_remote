# Networking & Discovery

Notes on how device discovery works and why it behaves differently on the
Android emulator versus a real phone.

## How discovery works

`RokuDiscovery.discover()` sends an **SSDP `M-SEARCH`** for `roku:ecp` to the
multicast group `239.255.255.250:1900`, collects responder IPs, then fetches
each device's name/model with `GET http://<ip>:8060/query/device-info`
(plain HTTP, answered even in ECP "limited" mode).

Because it relies on **multicast**, discovery only works when the client is a
full member of the local network (a real phone/computer on the same WiFi).

## Android emulator limitation

The Android emulator (Android Studio / QEMU) runs behind **user-mode NAT**:

- The guest lives on `10.0.2.0/24`; `10.0.2.2` is the host, `10.0.2.15` the guest.
- **Unicast TCP is NATed through the host**, so the emulator *can* reach a LAN
  device by IP (the host opens the socket for it).
- **Multicast is NOT forwarded**, so the SSDP `M-SEARCH` never reaches the LAN
  and **discovery returns nothing**.

Observed behavior:

| Method | Real phone on WiFi | Android emulator |
|--------|--------------------|------------------|
| SSDP discovery (`Scan`) | works | **does not work** |
| Add device by IP | works | **works** (unicast TCP via NAT) |
| Send keys (ECP-2 WebSocket) | works | works once a device is added by IP |

So in the emulator: **use "Add by IP"** (`192.168.x.x`). The auto-scan will
stay empty.

## Options to get discovery in the emulator

Listed for future work; **none of these is implemented yet**.

- **A — Unicast subnet scan (recommended, no root).** Probe `TCP :8060` for
  `.1`–`.254` under a given prefix (e.g. `192.168.100.`) in parallel, then
  `/query/device-info` on the hits. Works through the NAT and also covers
  networks where multicast is blocked. Requires the user to supply/remember the
  subnet prefix (the emulator does not know it).
- **B — Bridged/TAP networking (root, fragile).** Give the AVD a real LAN IP via
  a `tap0` + bridge so SSDP works. Touches host networking/kernel settings
  (`ip tuntap`, bridge, possibly `ip_forward`).
- **C — Manual add-by-IP (current).** Simplest; no discovery in the emulator,
  SSDP still works on real devices.
- **D — Detect the emulator** and, when SSDP comes back empty, show a hint that
  discovery is unavailable and to use Add by IP / subnet scan.

## Testing notes

- Real phone: same WiFi as the Roku → `Scan` should list the device.
- Emulator: `Add by IP` → enter the TV's IP → connect and send keys.
- No changes to the TV settings are required (ECP-2 works in limited mode).
