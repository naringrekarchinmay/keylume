# Keylume

An unofficial macOS app (and command-line tool) for configuring
**Royal Kludge** keyboards, starting with the **RK84 RGB**. The vendor only ships
a Windows app; Keylume gives Mac users the same lighting and key-remapping
features in a native app with a Liquid Glass design.

> Keylume is an independent, unofficial project and is not affiliated with,
> endorsed by, or sponsored by Royal Kludge. "Royal Kludge" and "RK84" are used
> only to describe compatibility. Use at your own risk.

## Features

- **Lighting effects**: all 19 built-in effects, with brightness, speed, colour
  or rainbow, and sleep setting, plus an animated preview. Changes apply
  instantly.
- **Per-key colours**: paint individual keys and write them to the keyboard's
  Custom mode.
- **Key remapping**: any key can send another key, a modifier, a media key, or
  nothing. "Restore defaults" writes back the stock layout.
- Settings are saved locally in `~/Library/Application Support/Keylume/profile.json`.
  The keyboard can't report its current settings, so the app remembers them.

## Supported hardware

| Model | USB ID | Status |
|---|---|---|
| RK84 RGB (wired, USB-C) | `258A:00C8` | verified on hardware: lighting, per-key colours, remap, restore defaults |

Other RK boards from the same family speak a similar protocol but use
different layouts. PRs that add layouts are welcome.

Configuration works over the **USB cable**. Bluetooth and 2.4 GHz are not
supported. The vendor app doesn't support them either.

## Install

Requires macOS 14+ and Xcode or the Swift toolchain.

```bash
git clone https://github.com/naringrekarchinmay/keylume && cd keylume
./scripts/make-app.sh
open dist/Keylume.app
```

On first launch, macOS asks for **Input Monitoring**. macOS requires this
before any app can talk to a keyboard. Keylume only sends settings and never
reads your keystrokes. After allowing it, quit and reopen the app.

If the app still says access is blocked, remove Keylume from System Settings →
Privacy & Security → Input Monitoring with **−**, then open the app again.

## Command line

```bash
dist/keylume doctor                                 # check permission and connection
dist/keylume modes                                  # list effects
dist/keylume light --mode steady --color ff0000     # solid red
dist/keylume light --mode breathing --rainbow --speed 4
dist/keylume light --mode steady --dry-run          # print the HID reports
```

The CLI uses the permission of the terminal app you run it from.

## How it works

The protocol was recovered by statically analysing the vendor's Windows app,
with [REA](https://github.com/morluto/rea) and rizin. Settings are sent as
65-byte HID feature reports (report ID `0x0A`). See
[docs/PROTOCOL.md](docs/PROTOCOL.md) for the byte-level details, including what
is verified and what is inferred.

Related projects: [Rangoli](https://github.com/rnayabed/rangoli) (Qt,
cross-platform) and [KludgeKnight](https://github.com/vinc3m1/kludgeknight)
(WebHID, remapping). Keylume shares no code with them.

## Development

```bash
swift test               # byte-exact packet tests
swift run keylume --help
swift run KeylumeApp
```

Layout: `KeylumeKit` builds the packets (pure, unit-tested) and handles IOKit.
`keylume` is the CLI. `KeylumeApp` is the SwiftUI app.

## License

MIT
