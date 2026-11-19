# RK84 (USB 258A:00C8) configuration protocol

These notes come from static analysis of the vendor's Windows app,
`RK_Keyboard_Software_Setup_V4.6 20250617.exe`, Inno Setup 5.3.3. The installer
was unpacked with `innoextract`. The main program is `app/DeviceDriver.exe`
(32-bit MFC, SHA-256 of the installer `d0640f29…aefa6`). Addresses below are
virtual addresses in `DeviceDriver.exe`.

Each claim is labelled:

- **observed**: read directly from the disassembly or config files.
- **inferred**: a reasonable reading that hardware has not yet confirmed.
- **verified**: confirmed on a real RK84.

## Hardware verification (RK84, USB, macOS)

| Feature | Result |
|---|---|
| Lighting effect packet (`02 29 …`, offset 3 = `01`) | **verified**: modes and colour apply |
| Per-key colour packet (`03 7E 01 …`), LED index = KB.ini index | **verified**: Esc red and WASD blue landed on the right keys |
| Key matrix packet (`01 F8 …`, length 505), Pause → Z | **verified**: remap works; other keys, modifiers and Fn unaffected |
| Default matrix (modifiers as usages `E0–E7`, Fn `00 00 B0 00`) | **verified**: "Restore defaults" brings back the stock layout |
| Sleep values 1–5 = 5/10/20/30 min / off | **verified**: the backlight turns off after the selected idle time |

## Device

| Item | Value | Status |
|---|---|---|
| USB vendor / product | `0x258A` / `0x00C8`, "RK Bluetooth Keyboard" (SinoWealth) | observed (macOS ioreg) |
| Listed in vendor app | `Cfg.ini` `PID=` list contains `00c8`; layout in `Dev/00C8/KB.ini` | observed |
| Interfaces | #0 keyboard (usage 1:6); #1 has usage 1:0x80 with a 65-byte feature report | observed (ioreg) |
| Driver class used | `CDevRKKB` (write function `0x413230`) | inferred from report size 65 |

## Transport: `CDevRKKB::WriteDevice` (`0x413230`)

The app splits a logical payload into 62-byte chunks. It sends each chunk with
`HidD_SetFeature` as a 65-byte feature report and waits 8 ms between chunks.
(observed)

```
byte 0     0x0A                 report ID
byte 1     N                    total packet count = ceil(len / 62)
byte 2     i                    packet index, 1-based
byte 3..64 payload[(i-1)*62 ...] up to 62 bytes, zero padded
```

The RKKB path never calls `HidD_GetFeature`, so the protocol is **write-only**
and the app cannot read back the keyboard's current settings. (observed: all
six `GetFeature` call sites are in other device classes, `0x40f000`–`0x4106xx`)

## Commands (built in `CDevRKKB::ApplySetting`, `0x413c00`)

### Lighting effect: flag bit `0x02`, payload length 60 (1 packet)

| Offset | Value | Source | Status |
|---|---|---|---|
| 0 | `0x02` | constant | observed |
| 1 | `0x29` | constant | observed |
| 2 | mode index + 1 | `[dev+0x213c]` | observed |
| 3 | `0x01` | constant | observed |
| 4 | speed | mode entry `+0x00` | observed (field); range inferred 1–5 |
| 5 | brightness | `LightHW` table indexed by entry `+0x04`; defaults to 0..5 (`0x451b00`) | observed |
| 6,7,8 | R, G, B | entry `+0x10..+0x12`, order from `RGBIndex=0,1,2` | observed |
| 9 | colourful / random-colour flag | entry `+0x2c` | observed (field), meaning inferred |
| 10 | sleep setting | `[dev+0x3e14]` | observed (field); values verified |
| 11..59 | 0 | | observed |

Mode numbers follow `tc_led_mode1..21` in `Text/en/text.xml` (inferred):

1 Neon Stream, 2 Ripples Shining, 3 Rotating Windmill, 4 Sine Wave,
5 Rainbow Roulette, 6 Stars Twinkle, 7 Layer Upon Layer, 8 Rich And Honored,
9 Marquee Effect, 10 Rotating Storm, 11 Serpentine Horse Race, 12 Retro Snake,
13 Diagonal Transformation, 14 Customize (per-key), 15 Ambilight, 16 Streamer,
17 Steady, 18 Breathing, 19 Neon, 20 Shadow Disappear, 21 Flash Away.

`KB.ini` `LedOpt1..21` says which controls each mode exposes, in the order
"animation, speed, light, direct, random, colornum". (observed)

### Per-key colour (custom mode): flag bit `0x04`, payload length 381 (7 packets)

This is sent only when the selected mode is the custom mode. (observed)

| Offset | Value | Status |
|---|---|---|
| 0 | `0x03` | observed |
| 1 | `0x7E` | observed |
| 2 | custom slot + 1 (10 wraps to 0) | observed |
| 3 + 3·L + {0,1,2} | R, G, B for LED index L (0..125) | observed |

The LED index is field `+5` of each key entry, which is the 2nd number after the
key code in `KB.ini` lines. If only one number is given, the matrix index is
assumed to be reused. (inferred)

### Key matrix: flag bit `0x01`

- Base layer: payload `01 F8` + 504 bytes (126 slots × 4). The app sends a
  length of **505**, so the last byte is never sent. (observed)
- Fn layer: payload `10 F8` + 504 bytes, also sent with length 505. This is
  only sent when the config enables it. (observed)
- Macros: payload `04 00` + 1920 bytes, length 1922. (observed)

Slot code (`keyinfo_to_hardware_code`, `0x413420`), little-endian bytes:

| Kind | Bytes | Status |
|---|---|---|
| Normal key / combo | `00 MM K1 K2` (MM = HID modifier bits, K1/K2 = HID usages) | observed |
| Fn | `00 00 B0 00` | observed |
| Consumer (media) | `01 00 HI LO` (e.g. volume up `01 00 00 E9`) | observed |
| Macro | `02 00 MODE ID` style | observed (not implemented) |

VK→HID conversion uses the app's own table at `0x5d2fc0` (114 pairs), exported
in `rk84-layout.json`.

**Safety:** a matrix write replaces the whole table. Every key, including Fn,
has to be filled from the defaults or keys stop working.

## Cross-check with Rangoli

[Rangoli](https://github.com/rnayabed/rangoli), a GPL-3.0 project, lists PID
`00c8` ("RK84N RGB") as working. Its packets independently agree on:

- the framing;
- the lighting layout: mode numbering 1..21 in the same order, speed 1–5,
  brightness 0–5, RGB, rainbow flag, sleep 1–5;
- the per-key colour header `03 7E 01`;
- the key-map header `01 F8`;
- matrix index = LED index for this board.

Rangoli labels sleep values 1–5 as 5, 10, 20 and 30 minutes, then "off".
Hardware confirms these values.

Modifier keys are encoded differently:

- Rangoli writes the 7 default modifiers as modifier bits, e.g. LShift = `00 02 00 00`.
- The vendor app sends VKs 0xA0–0xA5 through the generic path and its VK→HID
  table, which gives `00 00 E1 00` (observed: dispatch table `0x413778` sends
  0xA0–0xA5 to `0x41353f`).

This project follows the vendor app. If modifiers misbehave after a remap,
switch to the bit form.

The other difference: Rangoli sends `00` at lighting payload offset 3, where the vendor
app sends `01`. This project follows the vendor app. No code was copied; only
the byte facts were compared.

## Not implemented

- Music/"Ambilight" streaming (`SendMusicData`, payload `06 00 …`): real-time
  only.
- Firmware update.
- Bluetooth / 2.4 GHz configuration (the app sets `DisableBT=1`).
