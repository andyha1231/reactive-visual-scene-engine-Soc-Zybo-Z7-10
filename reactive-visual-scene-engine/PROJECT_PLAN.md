# Reactive Visual Scene Engine

**ECE 520 — Final Project**
**Team:** Macy Varga & Andy Ha
**Target:** Digilent Zybo Z7-10 (Xilinx Zynq-7010, `xc7z010clg400-1`)
**Toolchain:** Vivado 2023.1 + Vitis 2023.1 (unified IDE)
**Last updated:** 2026-05-04

---

## Abstract

We built a real-time **audio-driven visual engine** on the Zybo Z7-10. A pre-decoded song of any length is embedded in the Vitis ELF; the ARM PS continuously streams 32K-sample chunks (~3 seconds at 11.025 kHz) into BRAM as the PL audio reader wraps. The PL extracts amplitude + 3-band energy features in pure RTL (envelope detector + shift-IIR filter bank with EMA smoothing) and drives one of **4 selectable visual scenes** to HDMI at 640×480 / 60 Hz, plus a **2×2 quad-view** that shows all 4 simultaneously. Display modes are hardware switches (PL-direct, instant); the PS exposes runtime sensitivity tuning + streamer control through a 115200-baud UART menu. A PowerShell helper script synchronizes FPGA visuals with PC-played MP3 audio at sub-100 ms accuracy.

**Highlights:**
- ✅ Full-song playback via PS-driven BRAM streaming (no length limit beyond ELF size)
- ✅ Single-buffer streaming with PL-side wrap detection — glitch-free by design (PS write 1000× faster than reader)
- ✅ 4 visually distinct reactive scenes + quad-view + freeze
- ✅ All sim coverage green: **49 / 49 tests pass** across 5 testbenches
- ✅ Fits in **33% LUT / 17% FF / 48% BRAM / 3% DSP** on the smallest Zynq part
- ✅ Routed timing met on all clock domains (after explicit pipeline + CDC fixes)
- ✅ Single-window PowerShell demo: visuals on HDMI, audio on PC speakers, UART menu inline

---

## Table of Contents

1. [Motivation & Goals](#1-motivation--goals)
2. [System Architecture](#2-system-architecture)
3. [Audio Pipeline (Build-Time & Runtime)](#3-audio-pipeline-build-time--runtime)
4. [Hardware Modules (RTL)](#4-hardware-modules-rtl)
5. [Software Application (PS / Vitis)](#5-software-application-ps--vitis)
6. [Visual Scene Designs](#6-visual-scene-designs)
7. [Verification Strategy & Results](#7-verification-strategy--results)
8. [Hardware Bring-Up Results](#8-hardware-bring-up-results)
9. [Engineering Challenges](#9-engineering-challenges)
10. [Resource Utilization](#10-resource-utilization)
11. [Key Design Decisions](#11-key-design-decisions)
12. [Lessons Learned](#12-lessons-learned)
13. [Future Work](#13-future-work)
14. [Project File Structure](#14-project-file-structure)
15. [Build & Run Cheat Sheet](#15-build--run-cheat-sheet)
16. [Change Log](#16-change-log)
17. [Course Connections](#17-course-connections)

---

## 1. Motivation & Goals

### 1.1 Why this project

Audio visualizers — VU meters, spectrum displays, music-reactive light shows — are everywhere from car stereos to concert lighting. Most run on general-purpose CPUs/GPUs with software DSP. We wanted to demonstrate that the **same effects can be done in pure FPGA hardware** with deterministic latency and minimal resource usage, while exercising the full Zynq SoC stack: PS↔PL communication via AXI, custom AXI-Lite IP, BRAM with COE init + runtime streaming, MMCM clock generation, HDMI TMDS output, and a Vitis software application.

### 1.2 Concrete goals — all met

| Goal | Met? |
|------|------|
| Stream 16-bit PCM audio from BRAM at 11.025 kHz | ✅ |
| Extract amplitude + 3-band energy in PL (no software DSP) | ✅ |
| Render at least 4 distinct reactive scenes to HDMI | ✅ |
| Switch scenes via board controls in real time | ✅ |
| Allow runtime parameter tuning via UART/PS | ✅ (sensitivity + streamer control) |
| **Play full-length songs** (not a 3-second loop) | ✅ (PS streams chunks into BRAM) |
| Sync FPGA visuals with audio playback on PC | ✅ (UART 'G' gate + PowerShell helper) |
| Fit in xc7z010 (smallest Zynq part) | ✅ (33% LUT, 48% BRAM peak) |
| Meet timing on all clock domains | ✅ (after pipeline + CDC fixes) |
| Provide debug aids: freeze, quad-view, status | ✅ |

### 1.3 Non-goals (explicit scope limits)

- **No FPGA-side audio output.** Audio plays on PC speakers via a media player; the FPGA only handles visualization. Adding I2S to the on-board SSM2603 codec is documented as future work.
- **No microphone / live audio input.** BRAM-based playback is intentional (deterministic for demos, predictable for verification).
- **No FFT.** Shift-based 1st-order IIR + EMA suffices for low / mid / high band separation and saves DSP slices.
- **No graphics acceleration / frame buffer.** Every pixel is computed combinationally each frame from current pixel coords + audio features (with small animation counters in two scenes).

---

## 2. System Architecture

### 2.1 Top-level block diagram

```
                    +----------------------+
                    | sw[3:0] PL DIRECT    |
                    |   sw[1:0] = scene_select
                    |   sw[2]   = quad_view_en
                    |   sw[3]   = freeze
                    +----------+-----------+
                               |
+-----------+   AXI-Lite       |     +-------------+    +-------------------+    +-----------------+
|  Zynq PS  |<--+ via          |---->| scene       |--->| scene_engine_top  |--->| rgb2dvi_0  HDMI |
| Cortex-A9 |   | SmartConnect |     | _ctrl_v1_0  |    |  - quad-view mux  |    | (Digilent v1.4) |
| + UART    |   |              |     | (AXI slave) |    |  - crosshair      |    +-----------------+
| + AXI GPIO|   |              |     | sensitivity |    |  - freeze gate    |
+-+---------+   |              |     | wrap_flag   |    +-------------------+
  |             |              |     +-------------+              ^
  |             |              |          ^                       |
  |             |              |          |                       |
  |             |              |    +-------------+      +-----------------+    +-------------------+
  |             |              |    | feature_    |<-----|  audio_sample_  |<---| BRAM Standalone   |
  |             |              |    | extraction  |      |  reader         |    | 32b x 32768       |
  |             |              |    | _top        |      |  + wrap_pulse   |    | Port A <- AXI     |
  |             |              |    +-------------+      +-----------------+    +-------------------+
  |             |              |                                                          ^
  |             +--- 2-FF sync + edge detect on wrap_pulse (sys_clk -> clk_fpga_0)        |
  |             |                                                                         |
  +--> AXI BRAM ctrl  @ 0x4000_0000 ---- PS streams next song chunk on each WRAP_FLAG ----+
  +--> AXI GPIO       @ 0x4120_0000 ---- ch1 = sw[1:0] readback for status display
  +--> scene_ctrl     @ 0x43C0_0000 ---- 7 registers: SENSITIVITY, WRAP_FLAG, etc.
```

### 2.2 Clock domains

| Net | Frequency | Source | Drives |
|-----|-----------|--------|--------|
| `sys_clk_pin` | 125 MHz | K17 (board crystal) | audio reader, feature extraction, BRAM Port B, freeze register, wrap_pulse generation |
| `clk_fpga_0` | 100 MHz | PS FCLK_CLK0 | AXI interconnect, `scene_ctrl_v1_0`, WRAP_FLAG register + synchronizer |
| `clkout0` | 25 MHz | MMCM (`pixel_clk_gen.v`) | `vga_sync`, `scene_engine_top` (pixel rendering + animation counters) |
| `clkout1` | 125 MHz | MMCM | `rgb2dvi_0` SerialClk (TMDS encoder) |

**CDC false paths** (in `constraints/timing_cdc.xdc`, implementation-only):
- `sys_clk_pin → clkout0` — audio features → pixel renderer (data changes at 11 kHz max)
- `clk_fpga_0 → clkout0` — AXI sensitivity → pixel renderer (changes on PS write)
- `sys_clk_pin → clk_fpga_0` — wrap_pulse → WRAP_FLAG sync (pulse-stretched 15 cycles in source)

---

## 3. Audio Pipeline (Build-Time & Runtime)

The audio pipeline is split across two phases: **build-time** (offline on the developer's PC) and **runtime** (on the Zybo board).

### 3.1 Build-time: MP3 → C array + COE

```
        mysong.mp3
            │
            │  Audacity / VLC / ffmpeg  (manual)
            ▼
        data/song.wav     (16-bit signed PCM, mono, 11.025 kHz preferred)
            │
            │  python tools/gen_song_data.py
            ▼
   ┌────────────────────────────────┐  ┌─────────────────────────────────┐
   │  sw/src/song_data.c            │  │  data/audio_samples.coe          │
   │  const int16_t song_data[N]    │  │  First 32K samples of the song   │
   │  song_total_samples = N        │  │  for synth-time BRAM init        │
   │  song_chunk_samples = 32768    │  │  (so audio plays from boot       │
   │  song_sample_rate  = 11025     │  │   even before PS code runs)      │
   └────────────────────────────────┘  └─────────────────────────────────┘
            │                                       │
            │  ARM cross-compile               BRAM IP loads at synth
            ▼                                       │
        scene_engine_app.elf                        ▼
        (5–6 MB; embedded song)               BRAM init contents
            │                                       │
            ▼                                       ▼
        JTAG to Zynq DDR                       Zynq PL BRAM
```

`tools/gen_song_data.py` reads any WAV (mono / stereo, 8 / 16 / 24 / 32-bit), mixes to mono, resamples to 11.025 kHz, and emits both:
- A fully-formed C source file containing the entire song as `const int16_t song_data[N]`
- A 32K-sample COE file for the BRAM IP's synth-time initialization

### 3.2 Runtime: PS-streamed BRAM playback

The PL audio reader plays whatever is in BRAM. The PS continuously **rewrites** BRAM with the next chunk of the song every time the reader wraps to address 0:

```
T = 0.000 s   FPGA boots. BRAM is initialized from data/audio_samples.coe
              (the first 32K samples). Audio reader starts at addr 0.

T = 0.300 s   Vitis app reaches the [READY] gate, prints to UART, blocks.

T = ~0.5 s    User runs play_demo.ps1, presses ENTER. PS sends 'G' AND
              starts MP3 playback simultaneously.

T = post-G    audio_streamer_init() writes song chunk 0 to BRAM, clears
              WRAP_FLAG, starts main loop.

T = +2.97 s   Audio reader's BRAM addr wraps from 32767 → 0. wrap_pulse
              fires on sys_clk side; pulse-stretched 15 cycles for CDC.
              2-FF synchronizer + edge detect in scene_ctrl latches
              WRAP_FLAG = 1 in clk_fpga_0 domain.

T = +2.98 s   Main loop polls WRAP_FLAG (every 10 ms), sees it set:
                - clears WRAP_FLAG
                - increments chunk_idx (0 → 1)
                - writes samples [32768 .. 65535] from song_data[] into
                  BRAM via Xil_Out32 to BRAM_CTRL_BASE_ADDR + (i << 2)
              Audio reader picks up the new chunk on its next sample tick.

T = +5.94 s   Wrap event 2. chunk_idx 1 → 2. Writes samples [65536..98303].

...

T = ~251 s    Wrap event 84 (last chunk). chunk_idx wraps 0 if loop_mode=ON.
              Song restarts from chunk 0. Otherwise streamer pauses,
              visuals freeze on last chunk's content.
```

### 3.3 Race-condition analysis (why single-buffer is glitch-free)

When WRAP_FLAG fires, the audio reader is at BRAM address 0. The PS starts writing samples 0..32767 of the new chunk. The two are racing:
- **Audio reader:** 1 sample per 11337 cycles of sys_clk → 1 sample per ~91 µs
- **PS:** writes via AXI BRAM ctrl at ~100 MB/s → 32K × 4 bytes = 128 KB in ~1.3 ms

PS finishes the entire 32K-sample write in 1.3 ms; in that same window, the audio reader has only advanced ~14 samples. PS *easily* outruns the reader, so single-buffered streaming has zero audible glitches.

### 3.4 The wrap-detection register (WRAP_FLAG @ 0x18)

A new sticky bit in the `scene_ctrl_v1_0` AXI slave:
- **Set** by a 2-FF synchronizer when a `wrap_pulse` rising edge is detected on `sys_clk → clk_fpga_0`
- **Read** by PS via `Xil_In32(SCENE_CTRL_BASE + 0x18)` returns `1` if a wrap is pending
- **Cleared** by writing `1` to bit 0 (W1C semantics)

The source pulse from `audio_sample_reader` is stretched to 15 cycles (~120 ns at 125 MHz) so the synchronizer at 100 MHz can capture it without missing.

---

## 4. Hardware Modules (RTL)

### 4.1 Audio sample reader (`rtl/audio/audio_sample_reader.v`)

- Counter-based 11.025 kHz tick from 125 MHz (configurable via `SAMPLE_RATE` parameter).
- 15-bit BRAM address increments per sample, wraps at 32768 → ~2.97 s loop *per BRAM contents* (the streamer keeps replacing those contents).
- Outputs: `sample_out[15:0]`, `sample_valid` (one cycle high per sample), `wrap_pulse` (pulse-stretched 15 cycles each address wrap).

### 4.2 Amplitude detector (`rtl/feature_extraction/amplitude_detector.v`)

Envelope follower:
```
amp ← amp − (amp >> DECAY) + (|sample| >> ATTACK)    (ATTACK=2, DECAY=6)
```
Fast attack, slow decay — typical envelope for visualizers.

### 4.3 Band energy estimator (`rtl/feature_extraction/band_energy.v`) — timing-critical

Single-pole IIR low-pass filters with shift-based coefficients (`LOW_SHIFT=4, MID_SHIFT=1`, `EMA_SHIFT=5`). No multipliers needed; band separation uses subtraction:
- `energy_low`  ← EMA(|low-pass output|)
- `energy_mid`  ← EMA(|mid-pass = low-pass(broad) − low-pass(narrow)|)
- `energy_high` ← EMA(|sample − low-pass|)

**Critical: 2-stage pipeline.** Stage 1 runs the IIR filter and registers `abs_low/mid/high`. Stage 2 reads those registers and updates the EMA. Without this split, a 14-level CARRY4 chain failed silicon timing (sim worked; on-chip energies clamped to zero, black screen). See [§9 Engineering Challenges](#9-engineering-challenges).

### 4.4 Scene engine top (`rtl/scene_engine/scene_engine_top.v`)

Centralized pixel renderer. Single set of 4 scene instances drives both single-mode and quad-mode via virtualized pixel coordinates:

```verilog
qx = in_left ? (pixel_x << 1) : ((pixel_x - 320) << 1);
qy = in_top  ? (pixel_y << 1) : ((pixel_y - 240) << 1);
vx = quad_view_en ? qx : pixel_x;
vy = quad_view_en ? qy : pixel_y;
```

- **Single mode** (`quad_view_en=0`): mux output by `scene_select`, scenes render full 640×480.
- **Quad mode** (`quad_view_en=1`): mux output by quadrant index (TL=0, TR=1, BL=2, BR=3); each scene renders downscaled 320×240 in its quadrant. White 1-pixel crosshair at `x ∈ {319, 320}` and `y ∈ {239, 240}`.
- **Freeze** (`freeze=1`): passed through to scenes 0 and 2 (the two with internal animation counters); scenes 1 and 3 are pure combinational on features and are frozen by latching features in the top module.

### 4.5 Video pipeline

- **`pixel_clk_gen.v`** — MMCM with `CLKFBOUT_MULT=8, CLKOUT0_DIVIDE_F=40, CLKOUT1_DIVIDE=8` → 25 MHz pixel + 125 MHz serial. Lock signal on LED0.
- **`vga_sync.v`** — 640×480 @ 60 Hz on 25 MHz pixel clock. `H_TOTAL=800, V_TOTAL=525`, hsync/vsync active-low. Outputs `pixel_x/y[9:0]`, `active_video`.
- **`rgb2dvi_0` (Digilent v1.4)** — TMDS encoder. Settings (do not change):
  - `kGenerateSerialClk = false` → SerialClk is INPUT, driven by MMCM clkout1
  - `kRstActiveHigh = true` → matches `aRst <= btn0`
  - `vid_data` byte order: `[23:16]=R, [15:8]=B, [7:0]=G` (Digilent non-standard)
  - Top stitches: `vid_data = {{r,r}, {b,b}, {g,g}}` — duplicating each 4-bit channel to 8-bit

### 4.6 AXI-Lite control IP (`rtl/axi_ip/scene_ctrl_v1_0.v`)

7 × 32-bit registers, hand-written in the Lab 3/4 pattern:

| Offset | Register | RTL-consumed? | Notes |
|--------|----------|---------------|-------|
| 0x00 | SCENE_SEL   | ❌ ignored | Scene comes from `sw[1:0]` (PL direct) |
| 0x04 | PRESET_SEL  | ❌ reserved | |
| 0x08 | **SENSITIVITY** | ✅ active | Drives `scene_engine_top.sensitivity`; default 0xF0 (240); UART tunes |
| 0x0C | THRESHOLD   | ❌ reserved | |
| 0x10 | MODE_CTRL   | ❌ reserved | |
| 0x14 | DEBUG_EN    | ❌ reserved | |
| 0x18 | **WRAP_FLAG** | ✅ active | Sticky bit, set by wrap_pulse → 2-FF sync; W1C semantics |

### 4.7 Top-level (`rtl/top/reactive_scene_top_ps.v`)

Stitches:
- `pixel_clk_gen` (MMCM) → 25 MHz pixel + 125 MHz serial + `mmcm_locked`
- `design_1_wrapper` (Block Design: PS7 + SmartConnect + AXI BRAM ctrl + Standalone BRAM + AXI GPIO + ProcSysReset)
- `scene_ctrl_v1_0` AXI slave on M02 (with `wrap_pulse_async` input)
- `audio_sample_reader` reads BRAM Port B; emits `wrap_pulse`
- `feature_extraction_top` consumes audio
- Freeze register block (latches features when `sw[3]==1`)
- `vga_sync` produces pixel coords + active_video
- `scene_engine_top` produces RGB (scene from `sw[1:0]`, quad from `sw[2]`, freeze from `sw[3]`)
- `rgb2dvi_0` encodes to HDMI TMDS

LED layout: `[0]=mmcm_locked, [1]=active_video, [2]=sw[2] (quad), [3]=sw[3] (freeze)`.

### 4.8 Hardware switch & button contract

| Pin | Wire | Function |
|-----|------|----------|
| `sw[1:0]` | `scene_select` (PL direct) | `00` = Scene 1, `01` = Scene 2, `10` = Scene 3, `11` = Scene 4 |
| `sw[2]` | `quad_view_en` (PL direct) | `1` = render all 4 in 2×2 grid; ignores `sw[1:0]` |
| `sw[3]` | `freeze` (PL direct) | `1` = latch features + halt animation counters |
| `btn[0]` | PL reset (active-high) | Also wired to AXI GPIO ch2; reading not useful (also resets) |
| `btn[3:1]` | unused | Not pin-constrained (future expansion) |

---

## 5. Software Application (PS / Vitis)

The Vitis app handles audio chunk streaming, the UART menu, and status reporting. Display modes are HW switches — the PS does not touch them.

### 5.1 Source files

| File | Role | LOC |
|------|------|-----|
| `sw/src/main.c` | Boot, UART [READY] gate, main poll loop | ~80 |
| `sw/src/audio_streamer.c` | Streams song chunks to BRAM on each WRAP_FLAG | ~115 |
| `sw/src/song_data.c` | **Auto-generated** by `tools/gen_song_data.py` — full song as `const int16_t` array | varies (~50 MB source for ~4 min of audio) |
| `sw/src/uart_menu.c` | Single-character menu: 1-6, s, G, h | ~165 |
| `sw/src/scene_ctrl.c` | AXI write/read helpers (`Xil_Out32 / Xil_In32`) | ~55 |
| `sw/src/button_handler.c` | `init()` + `read_scene_switches()` for status | ~25 |

**Total binary** with ~4-minute song embedded: `scene_engine_app.elf` ≈ 5.6 MB text / 1.2 KB data / 22.7 KB BSS.

### 5.2 Boot sequence (UART output)

```
=============================================
  Reactive Visual Scene Engine
  ECE 520 Final Project
  Macy Varga & Andy Ha
=============================================
[INIT] Sensitivity = 240
[INIT] GPIO ready.
[INIT] Song: 2768303 samples (251.099 s, 85 chunks of 32768)
[READY] Press 'G' to start.
                       ← gate blocks here, waiting for UART 'G'
```

The `[READY]` line is a sentinel for `play_demo.ps1` to know the FPGA is fully booted and prompt the user to press ENTER.

### 5.3 Streaming algorithm

```c
void audio_streamer_process(void) {
    if (paused || finished) return;
    if (!wrap_flag_read())  return;

    wrap_flag_clear();
    chunk_idx++;
    if (chunk_idx >= num_chunks) {
        if (loop_mode) chunk_idx = 0;
        else { finished = 1; chunk_idx = num_chunks - 1; return; }
    }
    write_chunk_to_bram(chunk_idx * song_chunk_samples);
}
```

Called every 10 ms in the main poll loop. PS finishes a chunk write in ~1–2 ms; reader takes ~3 s to traverse the buffer. PS easily wins the race.

### 5.4 UART menu (115200 8N1)

```
========================================
  Reactive Visual Scene Engine
========================================
  1 - Set sensitivity (0-9 -> 0-252)
  2 - Show current status
  3 - Reset sensitivity to default (240)
  4 - Restart song from chunk 0
  5 - Toggle loop mode (loop forever vs. play once)
  6 - Toggle pause (freeze BRAM contents)
  s - Silence (zero BRAM + pause)
  G - Restart streamer (also re-runs init after silence)
  h - Show this menu
========================================
```

`2` (status) reads `sw[1:0]` via AXI GPIO ch1 to report which scene is currently rendering, plus AXI sensitivity, plus `chunk X of Y` from the streamer.

### 5.5 The synchronization gate

`main()` calls `wait_for_go()` after init, which **blocks indefinitely** waiting for a 'G' / 'g' byte on UART. This is how FPGA visuals stay in sync with PC-played MP3 audio:
- `tools/play_demo.ps1` opens the FTDI COM port, watches for `[READY]`, prompts the user to press ENTER, then fires the `'G'` byte AND starts MP3 playback in the same script tick. Sync ~10–50 ms.
- 'G' is also handled by `uart_menu_process()` to **re-init the streamer** at any time (so re-running the script after Ctrl-C resumes audio cleanly without a board reset).

### 5.6 PowerShell helper (`tools/play_demo.ps1`)

A single PowerShell window that replaces the Vitis Serial Terminal entirely:
- Auto-detects Zybo's FTDI USB serial port (filters by VID `0403`, excludes Bluetooth ports)
- Streams FPGA UART output to the console in real time
- **Waits for `[READY]` marker before letting the user press ENTER** (or 1.5 s of UART silence as a fallback for "already past gate" case)
- Fires `'G'` + MP3 playback simultaneously on ENTER
- Forwards keystrokes to FPGA so the menu is usable inline (`1`-`6`, `h`, `s`, `G`)
- On Ctrl-C, sends `'s'` (silence) to leave the FPGA at zero — visuals collapse to baseline — then closes the port

### 5.7 Vitis workspace

- `vitis_application/zybo_z7_10_plat/` — platform component built from the XSA
- `vitis_application/scene_engine_app/` — application component
- Vitis 2023.1 unified IDE COPIES sources into `Debug/src/` (no "Link to files" option). **Source of truth = repo `sw/`.** Vitis copy is a build artifact.
- Adding new `.c` files requires `Debug/src/subdir.mk` to be regenerated by Vitis (build platform after adding files), or manually edited.

---

## 6. Visual Scene Designs

All scenes share the same RTL interface and are clocked from the 25 MHz pixel clock. Each scene receives the four audio features (`amplitude`, `energy_low/mid/high`), `sensitivity`, and a `freeze` input.

### 6.1 Scene 1 — Concentric Circles

- **Center:** solid yellow disc, radius 25 px (always visible).
- **Around the core:** orange rings at fixed radii every 32 px outward.
- **Music response:** the **number of visible rings** = `amplitude[15:11]` (0..31).
  - Silence → just the core, no rings
  - Quiet music → 1–3 rings near the core
  - Loud music → many rings cascading outward across the screen

When the music gets louder, new rings appear progressively further from the core. When it goes quiet, the rings collapse back. Direct visual translation of "how loud is this".

### 6.2 Scene 2 — Bass Bars

- Bottom-anchored green band; height = `(energy_low * sensitivity) >> 13`, clamped to 480 px.
- 2-pixel vertical gaps every 80 px (visually segments the bar into 8 sub-bars).
- Pure combinational on features — no internal animation.

### 6.3 Scene 3 — Multicolor Particle Storm

- Grid of 4×4 px dots, one per 16×16-pixel cell (40 cols × 30 rows = up to 1200 particles).
- 4-color palette (red / green / cyan / magenta) cycling across cells with a slow time drift, so the screen is a colored checkerboard that rotates colors over a few seconds.
- Each particle's brightness = `(tri_b/2) + energy_high[15:12]` clamped — treble drives intensity.
- Background magenta-tinted by `energy_mid` (subtle).

### 6.4 Scene 4 — Tri-Band EQ

- Three horizontal stacked bars (160 px tall each).
- **Top bar (red):** `energy_low` width
- **Middle bar (green):** `energy_mid` width
- **Bottom bar (blue):** `energy_high` width
- Each fills L→R by `(energy_band * sensitivity) >> 13`. White separator rows at y=160 / y=320.
- The only scene that visualizes `energy_mid`. Acts as a built-in spectrum analyzer.

### 6.5 Quad-view (sw[2] = 1)

All four scenes rendered simultaneously in a 2×2 grid (320×240 each), with a 1-pixel white crosshair at `x ∈ {319, 320}` and `y ∈ {239, 240}`. Quadrant assignment: `TL = Scene 1, TR = Scene 2, BL = Scene 3, BR = Scene 4`.

### 6.6 Freeze (sw[3] = 1)

Latches the audio features at the top level (so combinational scenes 2 + 4 freeze immediately) AND passes through to scenes 1 and 3 to halt their internal animation counters. With freeze on, the entire HDMI display becomes a still image — useful for screenshots and presentations.

---

## 7. Verification Strategy & Results

We tested in three layers: per-module simulation, integrated simulation, and on-board hardware verification.

### 7.1 Phase 1 — Audio pipeline simulation

Run via `xvlog/xelab/xsim` directly (Vivado batch mode breaks pipe on Windows).

| Testbench | Coverage | Result |
|-----------|----------|--------|
| `tb_amplitude_detector` | Reset, positive burst, negative burst (abs value), silence decay | ✅ 3/3 PASS |
| `tb_band_energy` | Reset; band energies for low-frequency vs high-frequency input | ✅ 1/1 PASS |
| `tb_feature_extraction_top` | Reset, silence, DC, 100 Hz bass, 4 kHz treble, 1 kHz mid, decay, valid-gating, alternating bass/treble | ✅ 9/9 PASS |

### 7.2 Phase 2 — Scene simulation (current designs)

| Testbench | Coverage | Result |
|-----------|----------|--------|
| `tb_scene_loudness_pulse` (Concentric Circles) | Reset, blanking, sun core, off-pattern bg, silent → no rings, loud amp → ring lit, far ring lit at high amp / dark at low amp | ✅ 7/7 PASS |
| `tb_scene_bass_bars` | Reset, blanking, silent bg, full energy bottom/top, gap pixels, medium energy boundaries | ✅ 8/8 PASS |
| `tb_scene_treble_flash` (Multicolor Particles) | Reset, blanking, particles in each of 4 colors at known cells, loud-treble brightening, magenta bg, silent bg | ✅ 9/9 PASS |
| `tb_scene_tri_band_eq` | Reset, blanking, separators, full + silent for each band, sensitivity scaling, in/out of bar boundaries | ✅ 11/11 PASS |
| `tb_scene_engine_top` | Single mode all 4 scenes, NOT crosshair in single, quad TL/TR/BL/BR, crosshair at x=319 / y=240, scene_select ignored in quad, blanking | ✅ 14/14 PASS |

**Total: 49 / 49 sim tests PASS.**

### 7.3 Phase 3 — Hardware verification (PL)

| Phase | Scope | Result |
|-------|-------|--------|
| 3A — PL-only HW | `reactive_scene_top.v` (no PS), oscillating triangle wave audio | ✅ All 4 scenes rendered on HDMI; sw[1:0] selects scene; LED0+1 lit |
| 3B — Full PS integration | `reactive_scene_top_ps.v` + BD + Standalone BRAM + AXI streaming | ✅ Bitstream + XSA generated, **routed timing MET**, BRAM COE init confirmed (`_init`-suffix wrappers in OOC synth log), all 4 scenes + quad + freeze rendering with COE-driven and PS-streamed audio |

### 7.4 Phase 4 — Vitis software

CLI build via `arm-none-eabi-gcc` produces `scene_engine_app.elf` with **0 errors, 0 warnings**. With ~4-minute song embedded: text section ~5.6 MB. UART [READY] gate + chunk streaming + UART menu verified on hardware.

---

## 8. Hardware Bring-Up Results

### 8.1 What works on the board (verified)

- ✅ MMCM locks (LED0)
- ✅ Active video signal (LED1)
- ✅ HDMI signal at 640×480 @ 60 Hz on a standard monitor
- ✅ COE-loaded BRAM driving audio reader (first chunk plays from boot)
- ✅ PS-streamed song chunks (chunk counter advances every ~3 s; UART status reports progression)
- ✅ Feature extraction producing non-zero amplitude / band energies (after the 2-stage pipeline fix)
- ✅ All 4 scenes rendering with music response
- ✅ Quad view — all 4 scenes simultaneously with white crosshair
- ✅ Freeze — all 4 scenes pause cleanly on `sw[3]=1`
- ✅ PC-FPGA sync via `play_demo.ps1`: visuals follow PC-played MP3 audio
- ✅ Ctrl-C silence: visuals collapse to baseline state
- ✅ UART menu: sensitivity tuning, status, restart, loop toggle, pause, silence

### 8.2 Suggested demo script (for presentation)

1. **Power on + program FPGA.** LED0 + LED1 light immediately. UART terminal shows the boot banner ending with `[READY] Press 'G' to start.`
2. **Run `play_demo.ps1`** in PowerShell on the laptop. The script prints `"Waiting for FPGA to be ready..."`, streams the boot output, then prompts `[FPGA READY -- press ENTER]`.
3. **Press ENTER.** Audio starts on PC speakers; FPGA `[GATE] Got GO` message appears, streamer kicks off.
4. **Cycle through scenes** with `sw[1:0]`:
   - `00` → Scene 1 (Concentric Circles): rings appear / disappear with loudness
   - `01` → Scene 2 (Bass Bars): green bar grows on every bass hit
   - `10` → Scene 3 (Multicolor Particles): colored dot field, brightness pulses on cymbals
   - `11` → Scene 4 (Tri-Band EQ): R/G/B horizontal bars showing per-band energy
5. **Quad view** (`sw[2]=1`): all 4 scenes simultaneously. LED2 lights.
6. **Freeze** (`sw[3]=1`): pause on a beat. LED3 lights. Useful for screenshots.
7. **Inline UART**: type `2` for status, `1` then `9` to crank sensitivity, `5` to toggle loop, etc. — all in the same PowerShell window.
8. **Ctrl-C** to stop. PowerShell sends `s`; visuals collapse to silence.

---

## 9. Engineering Challenges

The four most "presentable" engineering moments — bugs we hit and how we diagnosed and fixed them.

### 9.1 Black screen in silicon despite passing simulation

- **Symptom:** First Phase 3B program — LED0 + LED1 lit (MMCM + active video OK), but HDMI was completely black. Sim passed.
- **Diagnosis:** Inspected the timing report — found a 14-level CARRY4 chain in `band_energy.v` with negative slack. The chain spanned IIR filter → abs → multiply-accumulate for the EMA in a single combinational path. Sim worked because behavioral models ignore propagation delay; on silicon at 125 MHz the chain didn't settle in time, energy registers latched zeros every cycle.
- **Fix:** Split `band_energy.v` into a 2-stage pipeline. Stage 1 updates the IIR state and registers `abs_low/mid/high`. Stage 2 reads those registers and updates the EMA. Adds 1 cycle latency (irrelevant at 11 kHz audio) but cuts worst-case chain depth in half. Timing closed; HDMI immediately came alive.
- **Lesson:** Sim ≠ silicon. Always check post-route timing on Zynq, especially anything with multi-level CARRY4 chains.

### 9.2 BRAM all-zeros despite COE file present

- **Symptom:** Audio reader output stuck at zero even with the COE file selected in the IP's UI.
- **Diagnosis:** The BRAM IP defaults to **BRAM_Controller mode** when added via the AXI BRAM ctrl wizard, and in that mode the `Load_Init_File` checkbox is **disabled**. The COE setting was silently ignored at synth time.
- **Fix:** Switched BRAM to **Standalone mode** in the BD. This re-enabled `Load_Init_File`, and the OOC synth log started showing `_init`-suffix BRAM primitives confirming initialization. Standalone mode also changes the Port B interface (15-bit word addr, no rst pin, 1-bit we), so the top module had to follow.
- **Lesson:** When a Vivado IP option is grayed out, look for the parent mode setting that re-enables it.

### 9.3 Cross-clock-domain wrap pulse for streaming

- **Symptom:** Initial streaming attempt — chunks not advancing reliably; sometimes WRAP_FLAG never sets despite the audio reader visibly wrapping.
- **Diagnosis:** The `wrap_pulse` signal lives in the 125 MHz `sys_clk_pin` domain. WRAP_FLAG lives in the 100 MHz `clk_fpga_0` domain (alongside the rest of the AXI slave). A naive 1-cycle pulse at 125 MHz is just barely catchable by a 100 MHz synchronizer — a single missed sample means a missed wrap event, which means a missed chunk write.
- **Fix:** Pulse-stretch the source signal to **15 cycles** (~120 ns) in `audio_sample_reader.v` before crossing. Receive side is a standard 2-FF synchronizer plus rising-edge detector. False-pathed in `timing_cdc.xdc` (`set_false_path -from sys_clk_pin -to clk_fpga_0`).
- **Lesson:** Pulse-stretch + 2-FF synchronize is simpler than a full async-FIFO when you only need an event handshake. Always pulse-stretch wider than the destination clock period.

### 9.4 Treble flash kept animating during freeze

- **Symptom:** In quad+freeze mode (`sw[3:2]=11`), three quadrants properly froze, but Scene 3 (Particle Storm) kept twinkling.
- **Diagnosis:** The freeze logic latched the audio FEATURES at the top level. But Scene 3 has its own internal `flash_counter` that ticks on every pixel clock, independent of features.
- **Fix:** Added a `freeze` input to `scene_treble_flash.v` (and later `scene_loudness_pulse.v`). Plumbed `freeze` through `scene_engine_top.v` from `sw[3]`.
- **Lesson:** "Freeze the inputs" doesn't equal "freeze the output" if a module has internal state. Audit every scene module for independent counters before claiming freeze done.

---

## 10. Resource Utilization

Numbers from `phase3_integration.runs/impl_1/reactive_scene_top_ps_utilization_placed.rpt` for `xc7z010clg400-1`:

| Resource | Used | Available | % |
|----------|------|-----------|---|
| Slice LUTs | 5,885 | 17,600 | **33.4%** |
| LUT as Logic | 5,148 | 17,600 | 29.3% |
| Slice Registers (FFs) | 5,808 | 35,200 | **16.5%** |
| Block RAM (RAMB36/FIFO) | 29 | 60 | **48.3%** |
| DSP48E1 | 2 | 80 | **2.5%** |

**Power** (post-route estimate): Total on-chip 1.87 W (static 0.13 W, dynamic ~1.74 W).

**Vitis ELF footprint** with ~4-minute song embedded:
- `text` ≈ 5.57 MB (almost entirely the `song_data` const array)
- `data` ≈ 1.2 KB
- `bss` ≈ 22.7 KB
- JTAG upload: ~10–15 seconds

**Why these numbers matter:**
- BRAM dominates because of the audio sample store (16 of 29 tiles for the audio buffer; the rest for AXI infrastructure).
- DSP usage is intentionally low — the only multipliers used are for `(energy * sensitivity)` in `scene_bass_bars` and `scene_tri_band_eq`. All band filtering uses shift-based IIR.
- The full design fits in **the smallest Zynq part** with significant headroom.
- LUT count includes the entire AXI infrastructure (SmartConnect, BRAM ctrl, GPIO ctrl, scene_ctrl_v1_0).

**Timing** (post-route): All clocks MET. Worst negative slack positive on every constraint group after band_energy pipeline + 3 CDC false paths.

---

## 11. Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Video output | HDMI via Digilent `rgb2dvi_0` | Native Zybo HDMI port; handles TMDS encoding |
| Pixel clock | MMCM (×8 / ÷40 = 25 MHz) | Locks reliably; counter divider gives wrong frequency |
| Audio format | 16-bit signed PCM, mono, 11.025 kHz | 32768 samples / 11025 Hz = ~2.97 s per chunk; drums + bass + vocals + cymbals all fully resolved; only freq > 5.5 kHz lost |
| BRAM organization | 32-bit × 32768 (audio in low 16 bits) | Matches AXI 32-bit width without packing logic |
| BRAM mode | **Standalone** (not BRAM_Controller) | Only Standalone exposes `Load_Init_File` for COE init |
| Band filtering | Shift-based 1st-order IIR | No multipliers in pixel path; sufficient resolution |
| Band energy timing | 2-stage pipeline | Required for timing closure on silicon |
| AXI IP | Hand-written `scene_ctrl_v1_0.v` (7 registers) | Matches Lab 3/4 patterns; full control over register semantics |
| Color depth | 4-bit per channel duplicated to 8-bit | Cheap; sufficient visual fidelity |
| Display mode control | **HW switches (PL direct)** | Display works without Vitis loaded; instant response |
| Sensitivity control | **AXI register (UART-tuned, default 240)** | Continuous range; default near max so music looks responsive without tuning |
| Quad-view | Single set of 4 scene instances + virtualized coords | Cheaper than 8 instances; same hardware path for both modes |
| Freeze | Latch features at sys_clk + `freeze` input on scenes with internal counters | Three of four scenes are pure combinational; only treble + sun need explicit freeze |
| CDC | False-paths in `timing_cdc.xdc` (impl-only) | `clk_fpga_0` not visible at synth time |
| **Audio streaming buffer** | **Single-buffer** (32K samples) + **polled WRAP_FLAG** | PS easily outruns reader; double-buffer would waste 16 BRAM tiles for no benefit |
| **Song storage** | **Embedded in ELF** (`const int16_t song_data[]`) | Simplest distribution; ELF gets uploaded via JTAG once; no SD card or filesystem |
| **Sync gate** | Wait indefinitely for UART 'G' | Explicit synchronization; user controls when audio starts |
| **Audio playback** | PC speakers (not FPGA I2S) | Adds zero hardware complexity; sub-100 ms sync via PowerShell helper |
| **Demo interface** | Single PowerShell window | Vitis Serial Terminal not needed — bidirectional UART in `play_demo.ps1` |
| Vitis app scope | UART menu + audio streamer | Minimal but functional |

---

## 12. Lessons Learned

1. **Sim ≠ silicon.** Behavioral simulation cannot detect combinational depth issues. Always check post-route timing on Zynq.
2. **Vivado IP options can be silently disabled.** When something *should* be configurable but the checkbox is grayed out, look at the parent IP's mode setting.
3. **The BD is part of the source code.** Multi-instance vs. multi-channel GPIO is a contract decision worth documenting; renaming/restructuring takes seconds in Vivado but saves hours of debugging in software.
4. **Freeze the right things.** Latching audio features doesn't freeze a scene that has its own animation timer. Audit every module for independent counters/state.
5. **Hardware-driven controls are simpler than software-driven for demos.** Switches → PL wires → scene change is more responsive and demoable than switches → C → AXI register → scene change.
6. **Build the UART-only Vitis app early.** Even a minimal ELF that just shows a menu confirms the platform component, BSP, UART pinning, and PS-PL handshake all work.
7. **Single-rendering-path designs scale better.** Virtualized pixel coords let one set of scene instances drive both single AND quad modes — half the resource cost of duplicating.
8. **xvlog/xelab/xsim from PowerShell beats `vivado -mode batch`** for testbench iteration on Windows.
9. **PS-driven BRAM streaming is a tiny amount of code for a huge feature gain.** The wrap-detection RTL was ~30 lines, the streamer ~80 lines, and we went from a 3-second loop to a full 4-minute song with no BD changes.
10. **Pulse-stretch your CDC signals.** A 1-cycle pulse at 125 MHz is just barely catchable by a 100 MHz synchronizer; widening to 15 cycles eliminates the race and costs ~5 FFs.
11. **Auto-detection by sort order fails the moment the user has an unexpected device.** Prefer VID/PID filtering for USB serial enumeration (FTDI VID `0403` for Zybo).
12. **Visual designs need iteration with real music.** "Mathematically distinct" doesn't always feel "visually distinct" with real audio. We went through several scene-1 and scene-3 redesigns based on hardware feedback.
13. **Embedded `const` arrays bloat ELF size.** A 4-minute song at 11 kHz = 5.6 MB just in `song_data`. JTAG upload takes ~10 seconds. Acceptable for demos; would matter for production firmware.
14. **Sentinel markers in UART output enable PowerShell automation.** A simple `[READY]` string lets the helper script wait until the FPGA is ready before prompting the user.

---

## 13. Future Work

| Item | Effort | Value |
|------|--------|-------|
| Wire `btn[3:1]` (3 new pin constraints) for sensitivity step ± and audio reset | 30 min | Adds tactile control without UART |
| Wire `sw[3:2]` into AXI GPIO (BD update + re-impl) | 30 min | Software can read full HW state for richer UART status |
| FPGA-driven I2S audio out via Zybo SSM2603 codec | 4 hours | Audio + visuals from same chip; perfect sync without PC |
| Real-time MP3 decode in PS (replace pre-decoded array) | 6 hours | Smaller ELF; load songs at runtime |
| Live audio input via PMOD I2S microphone | 4 hours | Removes embedded loop, true reactive demo |
| FFT-based band split (replace IIR) | 8+ hours | True spectrum analyzer; more DSP usage |
| On-screen text overlay (scene names + values) | 3–4 hours | Self-documenting display; needs font ROM |
| Add 5th+ scene (e.g., circular waveform, plasma field) | 2 hours | More variety |
| Add `tb_scene_treble_flash` freeze test | 20 min | Closes a sim gap |

---

## 14. Project File Structure

```
final_project/
  reactive-visual-scene-engine/                <-- This repo
    rtl/
      audio/
        audio_sample_reader.v                  Counter+reader, wrap_pulse output
      feature_extraction/
        amplitude_detector.v                   Envelope follower
        band_energy.v                          2-stage pipeline (timing critical)
        feature_extraction_top.v               Wrapper
      scene_engine/
        scene_loudness_pulse.v                 Scene 1: Concentric Circles
        scene_bass_bars.v                      Scene 2: Bass bars
        scene_treble_flash.v                   Scene 3: Multicolor particles
        scene_tri_band_eq.v                    Scene 4: Horizontal R/G/B EQ
        scene_engine_top.v                     4-scene mux + quad view + crosshair + freeze
        scene_split_screen.v                   DEPRECATED (kept for reference)
      video/
        vga_sync.v                             640x480 @ 60Hz timing
        pixel_clk_gen.v                        MMCM 25 MHz + 125 MHz
        vga_controller.v                       (legacy, not used)
      axi_ip/
        scene_ctrl_v1_0.v                      AXI-Lite top wrapper
        scene_ctrl_v1_0_S00_AXI.v              7-register slave (incl. WRAP_FLAG)
      top/
        reactive_scene_top.v                   Phase 3A (PL-only)
        reactive_scene_top_ps.v                Phase 3B/4 production top
        reactive_scene_top_ps_test.v           Same as ps.v (kept for flexibility)
        hdmi_test_pattern_top.v                Phase 0 HDMI bring-up
    tb/
      tb_amplitude_detector.v                  3 tests
      tb_band_energy.v                         1 test
      tb_feature_extraction_top.v              9 tests
      tb_scene_loudness_pulse.v                7 tests (Concentric Circles)
      tb_scene_bass_bars.v                     8 tests
      tb_scene_treble_flash.v                  9 tests (Multicolor Particles)
      tb_scene_tri_band_eq.v                   11 tests
      tb_scene_engine_top.v                    14 tests (quad mux + integration)
      tb_scene_split_screen.v                  7 tests (legacy, module not instantiated)
      tb_audio_sample_reader.v
      tb_vga_sync.v
    sw/
      src/
        main.c                                 Boot, [READY] gate, poll loop
        audio_streamer.c                       Streams song chunks to BRAM
        song_data.c                            AUTO-GENERATED full-song array
        uart_menu.c                            One-char menu (1-6, s, G, h)
        scene_ctrl.c                           AXI helpers
        button_handler.c                       Switch readback for status
      include/
        scene_ctrl.h
        scene_ctrl_regs.h                      BRAM_CTRL_BASE_ADDR, WRAP_FLAG_OFFSET
        audio_streamer.h
        song_data.h
        button_handler.h
        uart_menu.h
    constraints/
      zybo_z7_hdmi.xdc                         HDMI TMDS, sw[3:0], btn0, LEDs
      timing_cdc.xdc                           3 CDC false paths (impl-only)
    data/
      audio_samples.coe                        32-bit COE (auto-overwritten by gen_song_data.py)
      song.mp3                                 (Optional) input MP3
      song.wav                                 (Optional) intermediate WAV
    scripts/                                   TCL helpers (BD setup, sim)
    tools/
      gen_audio_coe.py                         WAV -> COE (single chunk)
      gen_song_data.py                         WAV -> song_data.c + audio_samples.coe
      play_demo.ps1                            Single-window PowerShell demo helper
    PROJECT_PLAN.md                            this file
    PC_SETUP_GUIDE.md                          Vivado/Vitis install notes

  phase1_sim/                                   Vivado sim project
  phase2_scene_sim_xsim/                        xvlog flow for scene sims
  phase3_integration/                           Vivado project (BD + bitstream + XSA)
  vitis_application/                            Vitis 2023.1 unified workspace
    zybo_z7_10_plat/                           Platform component
    scene_engine_app/                          Application component (-> scene_engine_app.elf)
```

---

## 15. Build & Run Cheat Sheet

### 15.1 Run any simulation

```powershell
cd phase2_scene_sim_xsim
xvlog -prj tb_<NAME>_vlog.prj
xelab --debug typical --relax --mt 8 -L xil_defaultlib --snapshot tb_<NAME>_behav xil_defaultlib.tb_<NAME> xil_defaultlib.glbl
xsim tb_<NAME>_behav -t run_all.tcl -onerror quit
```

### 15.2 Convert MP3 → song_data.c + COE

```powershell
# Step 1 (manual): MP3 -> WAV using Audacity / VLC / ffmpeg
# Save as data\song.wav (mono 16-bit PCM preferred; script resamples regardless)

# Step 2: WAV -> C array + COE in one command
cd C:\Users\khuon\ECE520\final_project\reactive-visual-scene-engine
python tools\gen_song_data.py data\song.wav
# Outputs:
#   sw\src\song_data.c       (full song)
#   data\audio_samples.coe   (first 32K samples for boot-time playback)
```

### 15.3 Re-synth + impl + bitstream

In Vivado TCL Console (project `phase3_integration` open):
```tcl
reset_run design_1_axi_bram_ctrl_0_bram_0_1_synth_1   # if COE changed
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
puts "WNS: [get_property STATS.WNS [get_runs impl_1]]"
write_hw_platform -fixed -include_bit -force C:/Users/khuon/ECE520/final_project/phase3_integration/reactive_scene_top_ps.xsa
```

### 15.4 Re-build Vitis app from CLI

```powershell
# Sync C source from repo to Vitis copy (after editing)
copy /Y reactive-visual-scene-engine\sw\src\*.c vitis_application\scene_engine_app\src\
copy /Y reactive-visual-scene-engine\sw\include\*.h vitis_application\scene_engine_app\src\

# Build
cd vitis_application\scene_engine_app\Debug
$env:PATH = "C:\Xilinx\Vitis\2023.1\gnu\aarch32\nt\gcc-arm-none-eabi\bin;C:\Xilinx\Vitis\2023.1\gnuwin\bin;$env:PATH"
make all
```

### 15.5 Demo workflow (single PowerShell window)

```powershell
# 1. In Vivado Hardware Manager: Auto Connect -> Program Device with reactive_scene_top_ps.bit
# 2. In Vitis: right-click scene_engine_app -> Run As -> Launch Hardware (loads ELF)
# 3. In PowerShell:
cd C:\Users\khuon\ECE520\final_project\reactive-visual-scene-engine
.\tools\play_demo.ps1

#    The script:
#    - Waits for [READY] from FPGA
#    - Prompts: "[FPGA READY -- press ENTER to fire GO + audio]"
#    - On ENTER: sends 'G' + starts MP3 simultaneously
#    - Forwards your keystrokes to FPGA UART (1-6, h, s, G work inline)
#    - On Ctrl-C: sends 's' to silence FPGA, then closes
```

While the script is running, control the demo with:
- `sw[3:0]` on the board: choose scene / quad / freeze
- Type `2` in PowerShell: status (HW scene, sensitivity, song chunk progress)
- Type `1` then `9` in PowerShell: max sensitivity
- Type `5` in PowerShell: toggle loop mode
- Type `6` in PowerShell: pause/resume
- Type `s` in PowerShell: silence (BRAM zeroed)
- Type `G` in PowerShell: restart streamer from chunk 0

---

## 16. Change Log

### 16.1 RTL changes (vs. original design)

| File | Change | Reason |
|------|--------|--------|
| `rtl/feature_extraction/band_energy.v` | Added 2-stage pipeline | 14-level CARRY4 chain failed silicon timing |
| `rtl/scene_engine/scene_tri_band_eq.v` | NEW module — 3 horizontal R/G/B bars | Need `energy_mid` visualization; replaces split_screen |
| `rtl/scene_engine/scene_loudness_pulse.v` | REWRITTEN: Concentric Circles (rings count = amplitude) | Original square design was too static |
| `rtl/scene_engine/scene_treble_flash.v` | REWRITTEN: Multicolor Particle Storm | Original edge-flash design was too simple |
| `rtl/scene_engine/scene_bass_bars.v` | Shift `>>14 → >>13` (2× amplification) | Music has lower peak energy than synthetic test tones |
| `rtl/scene_engine/scene_tri_band_eq.v` | Same shift change | Same |
| `rtl/scene_engine/scene_engine_top.v` | Replaced split_screen with tri_band_eq; added quad_view_en + virtualized coords + crosshair; added freeze input | Scene 4 redesign + quad view + freeze plumbing |
| `rtl/scene_engine/scene_loudness_pulse.v` | Added `freeze` input (dead reg, gates animation if added) | Future-proof |
| `rtl/scene_engine/scene_treble_flash.v` | Added `freeze` input | Hardware test showed cyan kept flashing in freeze; counter is internal to scene |
| `rtl/audio/audio_sample_reader.v` | Added `wrap_pulse` output (pulse-stretched 15 cycles) | PS needs to know when audio reader wraps |
| `rtl/axi_ip/scene_ctrl_v1_0_S00_AXI.v` | Added 7th register WRAP_FLAG @ 0x18 (sticky bit, W1C, with 2-FF synchronizer + edge detect) | Streaming handshake |
| `rtl/axi_ip/scene_ctrl_v1_0.v` | Added `wrap_pulse_async` input port; default SENSITIVITY changed 128 → 240 | Plumb-through; bigger bars by default |
| `rtl/top/reactive_scene_top_ps.v` | GPIO ports `*_tri_i`. BRAM Port B Standalone interface. Wired sw[1:0]→scene, sw[2]→quad, sw[3]→freeze. Freeze register block. AXI scene_select disconnected (HW direct). SAMPLE_RATE = 11_025. wrap_pulse wiring | New HW switch contract; longer audio loop; streaming |
| `rtl/top/reactive_scene_top_ps_test.v` | NEW — same wiring as ps.v (functionally identical) | Originally for HW test without Vitis; now redundant |
| `constraints/timing_cdc.xdc` | NEW — 3 implementation-only false paths | CDC isolation |

### 16.2 Software changes

| File | Change | Reason |
|------|--------|--------|
| `sw/src/button_handler.c` | First fix: ONE `XGpio` with channels 1 + 2. Then: stripped to `init()` + `read_scene_switches()` only | BSP only generates GPIO_0; HW-driven design eliminated need for processing |
| `sw/src/uart_menu.c` | Removed scene-select / preset / threshold / reset-defaults. Added: 4=restart, 5=loop toggle, 6=pause, s=silence, G=restart streamer | RTL only consumes SENSITIVITY register; new commands for streamer + sync |
| `sw/src/main.c` | Added `wait_for_go()` UART gate. Added `audio_streamer_init/process` calls. Added `[READY]` sentinel. Default sensitivity = 240 | Sync gate for PC audio + streaming |
| `sw/src/audio_streamer.c` | NEW — chunk-by-chunk BRAM streaming via WRAP_FLAG polling | Full-song playback |
| `sw/src/song_data.c` | NEW — auto-generated full-song embedded array | Song storage |
| `sw/include/scene_ctrl_regs.h` | Added `WRAP_FLAG_OFFSET=0x18`, `BRAM_CTRL_BASE_ADDR=0x40000000`, `BRAM_SAMPLE_ADDR(n)` macro. `DEFAULT_SENSITIVITY` 128 → 240 | New register, BRAM access, more responsive default |
| `sw/include/audio_streamer.h` + `song_data.h` | NEW headers | API for streamer + song |

### 16.3 Tooling additions

| File | Purpose |
|------|---------|
| `tools/gen_audio_coe.py` | (Existing, fixed) WAV → COE single chunk; output now 8-char hex (32-bit BRAM width) |
| `tools/gen_song_data.py` | NEW — WAV → `sw/src/song_data.c` (full song) + `data/audio_samples.coe` (first chunk) |
| `tools/play_demo.ps1` | NEW — single-window PowerShell helper. Auto-detects FTDI COM port, streams UART output, waits for `[READY]`, fires UART 'G' + WPF MediaPlayer simultaneously, forwards keystrokes, sends 's' on Ctrl-C |

### 16.4 Sim coverage additions / updates

| Testbench | Tests | Status |
|-----------|-------|--------|
| `tb_scene_loudness_pulse.v` | 7 | UPDATED for Concentric Circles design |
| `tb_scene_treble_flash.v` | 9 | UPDATED for Multicolor Particle Storm design |
| `tb_scene_tri_band_eq.v` | 11 | NEW |
| `tb_scene_engine_top.v` | 14 | NEW; updated assertions for current scene 1+3 outputs |

### 16.5 Verification log (chronological)

- 2026-05-03 (early): First Phase 3B program — LED0+1 lit, scene 0 renders correctly with COE-driven audio.
- 2026-05-03 (mid): Switch contract redesign + tri-band EQ + quad view + freeze deployed.
- 2026-05-03 (mid): HW test in quad+freeze: BL (treble) bug found → freeze input added.
- 2026-05-03 (late): C code aligned with HW-driven design.
- 2026-05-03: Audio streaming pipeline implemented end-to-end.
- 2026-05-03: SAMPLE_RATE 22050 → 11025 for ~3 s chunk loops.
- 2026-05-03: UART 'G' gate + play_demo.ps1 for PC-FPGA sync; FTDI VID-based port detection.
- 2026-05-04: Iterated scene 1 + 3 visual designs based on hardware feedback (final: Concentric Circles + Multicolor Particle Storm).
- 2026-05-04: Default sensitivity bumped 128 → 240 + scene shift `>>14 → >>13` for 3.75× responsiveness.
- 2026-05-04: PowerShell helper went bidirectional (single window for visuals + audio + UART menu).
- 2026-05-04: Added `[READY]` sentinel + Ctrl-C silence handling.
- 2026-05-04: All 49 / 49 sim tests pass with current designs.

---

## 17. Course Connections

| Lab / Lecture | Concept reused |
|---------------|----------------|
| **Lab 1** | Counter-based clock dividers → `audio_sample_reader.v` 11.025 kHz tick |
| **Lab 1, 5** | Counter / FSM patterns → `vga_sync.v` HV timing |
| **Lab 2** | Memory-mapped IO basics → `Xil_Out32 / Xil_In32` in `scene_ctrl.c`, `audio_streamer.c` |
| **Lab 3** | Custom AXI-Lite IP → `scene_ctrl_v1_0.v` (7 registers, hand-written) |
| **Lab 4** | UART terminal menu pattern → `uart_menu.c` (115200 8N1 polling) |
| **Lab 4** | AXI GPIO peripheral driver → `button_handler.c` (`XGpio_Initialize` + `XGpio_DiscreteRead`) |
| **Lecture 002** | BRAM primitive + DSP48E1 inference → 32-bit × 32768 audio store + multipliers in scene 2 / 4 |
| **Lecture (clocking)** | MMCM clock generation → `pixel_clk_gen.v` |
| **Lecture (CDC)** | Multi-clock-domain handoff → 2-FF synchronizer + edge detect for `wrap_pulse` |

---

*End of document.*
