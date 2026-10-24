# Discovery

How the app finds Roku devices on the local network, what it needs to work,
and what is still missing.

Related: [ECP2_PROTOCOL.md](ECP2_PROTOCOL.md) (control protocol),
[NETWORKING.md](NETWORKING.md) (emulator/NAT limitation).

## How it works

`RokuDiscovery.discover(timeout: 4s)` (see `lib/ecp2/discovery.dart`):

1. Bind a UDP socket (`RawDatagramSocket.bind(0.0.0.0, 0)`), enable broadcast.
2. Send an **SSDP `M-SEARCH`** to multicast `239.255.255.250:1900`:
   ```
   M-SEARCH * HTTP/1.1
   HOST: 239.255.255.250:1900
   MAN: "ssdp:discover"
   MX: 3
   ST: roku:ecp
   ```
3. Listen for UDP replies; keep the source IP of responses containing `ROKU`.
4. Wait `timeout`, close the socket.
5. For each IP, fetch `GET http://<ip>:8060/query/device-info` and parse the
   XML (`user-device-name`/`friendly-device-name`, `model-name`,
   `serial-number`, `software-version`).
6. Return the list, sorted by IP.

This is **phase 1** of the app. It only uses plain HTTP/UDP, which Roku
answers even in ECP "limited" mode. Control afterwards goes over the ECP-2
WebSocket (see ECP2_PROTOCOL.md).

## Requirements

| Requirement | Status |
|-------------|--------|
| Client and Roku on the **same LAN** | Required. |
| **Multicast allowed** by the AP | Guest WiFi often blocks it. |
| Not running on the **Android emulator** | Its NAT drops multicast (see NETWORKING.md). |
| Android **`INTERNET` permission** | **Present** in the manifest. |
| Android **`WifiManager.MulticastLock`** | **Not implemented** — many devices filter multicast in power-save; holding a lock while scanning improves reliability. |
| iOS **local network permission** | **Not implemented** — needs `NSLocalNetworkUsageDescription` (and `NSBonjourServices` if you discover Bonjour services) in `Info.plist`; without it iOS blocks LAN access. |
| Socket bound to the **WiFi interface** | With mobile data + WiFi on, the search should egress via WiFi; otherwise bind explicitly. |
| Port **8060 reachable** | For the `device-info` step. |

## Limitations

- **Android emulator**: SSDP never reaches the LAN (NAT), so `Scan` returns
  nothing. Use **Add by IP** there.
- **Guest/IoT networks**: may block multicast; the scan will be empty even on a
  real device.
- SSDP is best-effort: short timeouts can miss slow devices; re-scan.

## Roadmap (not implemented)

1. **Android MulticastLock** while scanning (`WifiManager.MulticastLock`).
2. **iOS local-network permission** (`NSLocalNetworkUsageDescription`).
3. **Subnet unicast scan fallback** — probe `TCP :8060` across a /24 in
   parallel, then `/query/device-info` on hits. Works through the emulator's
   NAT and on multicast-blocked networks.
4. **Bind to the WiFi interface** explicitly when both WiFi and mobile data are
   up.

## Testing

- **Real phone on the same WiFi**: `Scan` should list the Roku (name + model).
- **Emulator**: `Scan` stays empty; use **Add by IP** and then control works.
- No TV settings change is needed for discovery or control.
