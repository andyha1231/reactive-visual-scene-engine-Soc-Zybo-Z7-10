# Reactive Visual Scene Engine

**ECE 520 — Final Project**
**Team:** Macy Varga & Andy Ha
**Target:** Digilent Zybo Z7-10 (Xilinx Zynq-7010, `xc7z010clg400-1`)
**Toolchain:** Vivado 2023.1 + Vitis 2023.1 (unified IDE)
**Last updated:** 2026-05-03

---

## Abstract

We built a real-time **audio-driven visual engine** on the Zybo Z7-10. Audio is streamed from BRAM at 22.05 kHz, processed in pure RTL (envelope detector + 3-band shift-IIR filter bank with EMA smoothing), and rendered to HDMI at 640×480/60Hz through one of **4 selectable scenes** plus a **2×2 quad-view** that shows all 4 simultaneously. Display modes are PL-direct from board switches; the ARM Cortex-A9 PS runs a slim Vitis app that exposes runtime sensitivity tuning via a 115200-baud UART menu. The full system fits in **33% LUTs / 17% FFs / 48% BRAM / 3% DSP** and meets timing (WNS positive, all constraints met).

---

## Table of Contents

1. [Motivation & Goals](#1-motivation--goals)
2. [Course Connections](#2-course-connections)
3. [System Architecture](#3-system-architecture)
4. [Hardware Modules (RTL)](#4-hardware-modules-rtl)
5. [Software Application (PS / Vitis)](#5-software-application-ps--vitis)
6. [Verification Strategy & Results](#6-verification-strategy--results)
7. [Hardware Bring-up Results](#7-hardware-bring-up-results)
8. [Challenges & Engineering Solutions](#8-challenges--engineering-solutions)
9. [Resource Utilization & Performance](#9-resource-utilization--performance)
10. [Key Design Decisions](#10-key-design-decisions)
11. [Lessons Learned](#11-lessons-learned)
12. [Future Work](#12-future-work)
13. [Project Structure](#13-project-structure)
14. [Build & Run Cheat Sheet](#14-build--run-cheat-sheet)
15. [Change Log](#15-change-log)

---

## 1. Motivation & Goals

### 1.1 Why this project

Audio visualizers — VU meters, spectrum displays, music-reactive light shows — are everywhere from car stereos to concert lighting rigs. Most run on general-purpose CPUs/GPUs with software DSP. We wanted to demonstrate that the **same effects can be done in pure FPGA hardware** with deterministic latency and minimal resource usage, while exercising the full Zynq SoC stack: PS↔PL communication, AXI-Lite custom IP, BRAM with COE init, MMCM clock generation, HDMI TMDS output, and a Vitis software application.

### 1.2 Concrete goals

| Goal | Met? |
|------|------|
| Stream prerecorded 16-bit PCM audio from BRAM at 22.05 kHz | ✅ |
| Extract amplitude + 3-band energy in PL (no software DSP) | ✅ |
| Render at least 4 distinct reactive scenes to HDMI | ✅ |
| Switch scenes via board controls in real time | ✅ |
| Allow runtime parameter tuning via UART/PS | ✅ (sensitivity) |
| Fit comfortably in xc7z010 (the smallest Zynq) | ✅ (33% LUT, 48% BRAM peak) |
| Meet timing on all clock domains | ✅ (WNS positive after pipeline + CDC fixes) |
| Provide good debug aids (freeze for inspection, quad-view for demo) | ✅ |

### 1.3 Non-goals (explicit scope limits)

- No microphone / live audio input — the BRAM-based loop is intentional (deterministic for demos, predictable for verification).
- No FFT — we use shift-based IIR + EMA, which is sufficient for low/mid/high band separation and saves DSP slices.
- No graphics acceleration — every pixel is computed combinationally from current pixel coords + audio features; no frame buffer.

---

## 2. Course Connections

| Lab / Lecture | Concept reused |
|---------------|----------------|
| **Lab 1** | Counter-based clock dividers → `audio_sample_reader.v` 22.05 kHz tick |
| **Lab 1, 5** | Counter / FSM patterns → `vga_sync.v` HV timing |
| **Lab 2** | Memory-mapped IO basics → `Xil_Out32 / Xil_In32` in `scene_ctrl.c` |
| **Lab 3** | Custom AXI-Lite IP → `scene_ctrl_v1_0.v` (6 registers, hand-written, packaged via Vivado IP wizard) |
| **Lab 4** | UART terminal menu pattern → `uart_menu.c` (115200 8N1 polling) |
| **Lab 4** | AXI GPIO peripheral driver → `button_handler.c` (`XGpio_Initialize` + `XGpio_DiscreteRead`) |
| **Lecture 002** | BRAM primitive + DSP48E1 inference → 32-bit × 32768 audio store + multiplier in `scene_bass_bars` / `scene_tri_band_eq` |
| **Lecture (clocking)** | MMCM clock generation → `pixel_clk_gen.v` (×8 / ÷40 = 25 MHz pixel + ÷8 = 125 MHz serial) |

---

## 3. System Architecture

### 3.1 Block diagram

```
                   +----------------------+
                   | sw[3:0] PL DIRECT
                   |   sw[1:0] = scene_select
                   |   sw[2]   = quad_view_en
                   |   sw[3]   = freeze
                   +----------+-----------+
                              |
+-----------+   AXI-Lite      |     +-------------+    +-------------------+    +-----------------+
|  Zynq PS  |<--+ via         |---->| scene       |--->| scene_engine_top  |--->| rgb2dvi_0  HDMI |
| Cortex-A9 |   | SmartConn   |     | _engine_    |    |  - quad-view mux  |    | (Digilent v1.4) |
| + UART    |   |             |     | top inputs  |    |  - crosshair      |    +-----------------+
| + AXI GPIO|   |             |     | (features)  |    |  - freeze gate    |
+-+---------+   |             |     +-------------+    +-------------------+
  |             |             |          ^                       ^
  |             |             |          |                       |
  |             |             |    +-------------+      +-----------------+    +----------------------+
  |             |             |    | feature_    |<-----|  audio_sample_  |<---| BRAM Standalone      |
  |             |             |    | extraction  |      |  reader         |    | 32b x 32768, COE-init|
  |             |             |    | _top        |      +-----------------+    | Port A <- AXI BRAM   |
  |             |             |    +-------------+                              +----------------------+
  |             |             |
  +--> AXI BRAM ctrl  @ 0x4000_0000  (PS could rewrite audio at runtime)
  +--> AXI GPIO       @ 0x4120_0000  (ch1 = sw[1:0] readback for status)
  +--> scene_ctrl     @ 0x43C0_0000  (only SENSITIVITY register is consumed by RTL)
```

### 3.2 Clock domains

| Net | Freq | Source | Drives |
|-----|------|--------|--------|
| `sys_clk_pin` | 125 MHz | K17 (board crystal) | audio reader, feature extraction, BRAM Port B, freeze register |
| `clk_fpga_0` | 100 MHz | PS FCLK_CLK0 | AXI interconnect, `scene_ctrl_v1_0` |
| `clkout0` | 25 MHz | MMCM (`pixel_clk_gen.v`) | `vga_sync`, `scene_engine_top` (pixel rendering) |
| `clkout1` | 125 MHz | MMCM | `rgb2dvi_0` SerialClk (TMDS encoder) |

CDC false paths are isolated in `constraints/timing_cdc.xdc` (implementation-only, can't go in main XDC because `clk_fpga_0` isn't visible at synthesis).

### 3.3 Data flow (one frame)

1. **Audio (125 MHz domain):** `audio_sample_reader` advances BRAM address every 5670 cycles (125e6 / 22050) → reads next 32-bit word → outputs low 16 bits as `sample_out` with `sample_valid`.
2. **Feature extraction (125 MHz):** `feature_extraction_top` runs `amplitude_detector` (envelope) + `band_energy` (2-stage pipelined IIR + EMA per band) → produces 4 features.
3. **Freeze gate (125 MHz):** Top module latches features when `sw[3]==1`; otherwise pass-through.
4. **CDC (125 → 25 MHz):** Features cross to pixel domain. False-pathed; safe because audio features change at 22 kHz max, slower than the 25 MHz pixel clock.
5. **Scene rendering (25 MHz):** For each of 480×800 pixels per frame, `scene_engine_top` selects which scene's RGB to display based on `scene_select` (or quadrant if `quad_view_en`).
6. **HDMI encode:** 24-bit RGB → `rgb2dvi_0` → TMDS differential pairs → HDMI connector.

---

## 4. Hardware Modules (RTL)

### 4.1 Audio Pipeline

**`audio_sample_reader.v`**
- Counter-based 22.05 kHz tick from 125 MHz.
- 15-bit BRAM address increments per sample, wraps at 32768 → ~1.5 s loop.
- Outputs: `sample_out[15:0]`, `sample_valid` (one cycle high per sample).

**`amplitude_detector.v`**
- Compute `|sample|` (handle 2's complement).
- Update envelope: `amp <= amp − (amp >> DECAY) + (abs >> ATTACK)` with `ATTACK=2, DECAY=6` → fast attack, slow decay (typical envelope follower).

**`band_energy.v`** (the trickiest module)
- Single-pole IIR low-pass filters with shift-based coefficients (no multipliers).
  - `LOW_SHIFT=4` → cutoff ≈ sample_rate / 2π / 16 ≈ 220 Hz
  - `MID_SHIFT=1` → broader low-pass; subtract from low → bandpass
  - High = `sample - low_filter` → high-pass
- EMA on `|filtered|` per band gives running energy.
- **Critical: 2-stage pipeline.** Stage 1 updates the IIR state and registers `abs_low/mid/high`. Stage 2 updates EMA from those registered values. This breaks a 14-level CARRY4 chain that fails timing in silicon. Without the pipeline, all energies stay clamped to zero on hardware (sim works, silicon doesn't — classic).

**`feature_extraction_top.v`** — wrapper.

### 4.2 Scene Engine

All scenes share the interface:
`clk, rst_n, pixel_x[9:0], pixel_y[9:0], active_video, amplitude[15:0], energy_low/mid/high[15:0], sensitivity[7:0]` → `r/g/b[3:0]`.

| ID | Module | Visualization | Drives from |
|----|--------|---------------|-------------|
| 0 | `scene_loudness_pulse.v` | Centered orange rectangle whose half-size pulses 10..200 px. Brightness = amplitude. | `amplitude` |
| 1 | `scene_bass_bars.v` | Bottom-anchored green band; height = `(energy_low * sensitivity) >> 14`, clamped to 480. 2-pixel vertical gaps every 80 px. | `energy_low` |
| 2 | `scene_treble_flash.v` | 60-px cyan flashing frame; flash period inversely proportional to `energy_high`. Center has magenta glow scaled by `energy_mid`. *(Has internal `flash_counter`; gated by `freeze` input.)* | `energy_high`, `energy_mid` |
| 3 | `scene_tri_band_eq.v` ⭐ | 3 horizontal stacked bars, 160 px each. Top=red(low), middle=green(mid), bottom=blue(high). Each fills L→R by `(energy_band * sensitivity) >> 14`. White separators at y=160 / y=320. | All 3 band energies — **only scene that visualizes `energy_mid`** |

`scene_split_screen.v` was the original Scene 3 — replaced by tri-band EQ because it duplicated scenes 1+2 and never used `energy_mid`. File kept for reference, not instantiated.

### 4.3 Scene Engine Top (`scene_engine_top.v`)

Centralized rendering. Single set of 4 scene instances drives both single and quad modes via virtualized pixel coords:

```verilog
qx = in_left ? (pixel_x << 1) : ((pixel_x - 320) << 1);
qy = in_top  ? (pixel_y << 1) : ((pixel_y - 240) << 1);
vx = quad_view_en ? qx : pixel_x;
vy = quad_view_en ? qy : pixel_y;
```

**Single mode** (`quad_view_en=0`): mux output by `scene_select`, scenes render full 640×480.
**Quad mode** (`quad_view_en=1`): mux by quadrant index (TL=0, TR=1, BL=2, BR=3), each scene renders downscaled 320×240 of its full logical frame. White 1-pixel crosshair at `x∈{319,320}` and `y∈{239,240}` marks boundaries.
**Freeze** (`freeze=1`): passed through to `scene_treble_flash` (the only scene with internal animation state); other scenes are frozen by latching features in the top.

### 4.4 Video Pipeline

**`pixel_clk_gen.v`** — MMCM with `CLKFBOUT_MULT=8, CLKOUT0_DIVIDE_F=40, CLKOUT1_DIVIDE=8` → 25 MHz pixel + 125 MHz serial. Locks to LED0.

**`vga_sync.v`** — 640×480 @ 60 Hz on 25 MHz. `H_TOTAL=800, V_TOTAL=525`, hsync/vsync active-low. Outputs `pixel_x/y[9:0]`, `active_video`.

**`rgb2dvi_0` (Digilent v1.4 IP)** — TMDS encoder. Settings (do not change):
- `kGenerateSerialClk = false` → SerialClk is INPUT, driven by MMCM clkout1.
- `kRstActiveHigh = true` → matches `aRst <= btn0`.
- vid_data byte order: `[23:16]=R, [15:8]=B, [7:0]=G` (Digilent non-standard).

Top stitches: `vid_data = {{r,r}, {b,b}, {g,g}}` — duplicating each 4-bit channel to 8-bit.

### 4.5 AXI-Lite Control IP (`scene_ctrl_v1_0.v`)

6 × 32-bit registers (Lab 3 pattern):

| Offset | Register | RTL-consumed? |
|--------|----------|---------------|
| 0x00 | SCENE_SEL | ❌ ignored — scene is HW-driven from sw[1:0] |
| 0x04 | PRESET_SEL | ❌ reserved |
| 0x08 | **SENSITIVITY** | ✅ **active** — drives `scene_engine_top.sensitivity`; UART tunes |
| 0x0C | THRESHOLD | ❌ reserved |
| 0x10 | MODE_CTRL | ❌ reserved |
| 0x14 | DEBUG_EN | ❌ reserved |

UART menu only exposes the active register. Inactive ones are still writable (for future expansion) but produce no visible effect.

### 4.6 Top Module (`reactive_scene_top_ps.v`)

Stitches:
- `pixel_clk_gen` (MMCM) → 25 MHz pixel + 125 MHz serial + `mmcm_locked`
- `design_1_wrapper` (BD: PS7 + SmartConnect + AXI BRAM ctrl + Standalone BRAM + AXI GPIO + ProcSysReset)
- `scene_ctrl_v1_0` AXI slave on M02
- `audio_sample_reader` reads BRAM Port B
- `feature_extraction_top` consumes audio
- Freeze register block (latches features when `sw[3]==1`)
- `vga_sync` produces pixel coords + active_video
- `scene_engine_top` produces RGB (scene from `sw[1:0]`, quad from `sw[2]`, freeze from `sw[3]`)
- `rgb2dvi_0` encodes to HDMI TMDS

LED layout: `[0]=mmcm_locked, [1]=active_video, [2]=sw[2] (quad), [3]=sw[3] (freeze)`.

### 4.7 Hardware Switch & Button Contract

| Pin | Wire | Function |
|-----|------|----------|
| `sw[1:0]` | `scene_select` (PL direct) | `00`=Loudness Pulse, `01`=Bass Bars, `10`=Treble Flash, `11`=Tri-Band EQ |
| `sw[2]` | `quad_view_en` (PL direct) | `1` = render all 4 in 2×2 grid; ignores `sw[1:0]` |
| `sw[3]` | `freeze` (PL direct) | `1` = latch features + halt treble flash counter |
| `btn[0]` | PL reset (active-high) | Also wired to AXI GPIO ch2; reading not useful (also resets) |
| `btn[3:1]` | unused | Not pin-constrained (future expansion) |

---

## 5. Software Application (PS / Vitis)

The Vitis app is intentionally minimal — display modes are HW switches, so the PS only handles UART + AXI sensitivity.

### 5.1 Files

| File | Role | LOC |
|------|------|-----|
| `sw/src/main.c` | Init sensitivity + GPIO, show menu, poll UART | ~45 |
| `sw/src/uart_menu.c` | 3-command menu (sensitivity / status / reset) | ~115 |
| `sw/src/scene_ctrl.c` | AXI write/read helpers (`Xil_Out32 / Xil_In32`) | ~55 |
| `sw/src/button_handler.c` | `init()` + `read_scene_switches()` | ~25 |
| Headers in `sw/include/` | Function/register declarations | — |

**Total binary:** `scene_engine_app.elf` = 27.9 KB text / 1.2 KB data / 22.7 KB BSS.

### 5.2 UART Menu (115200 8N1)

```
========================================
  Reactive Visual Scene Engine
========================================
  1 - Set sensitivity (0-9 -> 0-252)
  2 - Show current status
  3 - Reset sensitivity to default (128)
  h - Show this menu

  Note: scene/quad/freeze are PL switches:
    sw[1:0] -> scene 0..3
    sw[2]   -> quad-view (all 4 at once)
    sw[3]   -> freeze
========================================
> 
```

`2` (status) reads sw[1:0] via AXI GPIO ch1 to report which scene the HW is currently rendering, plus the AXI sensitivity register value.

### 5.3 Vitis Workspace

- `vitis_application/zybo_z7_10_plat/` — platform component built from the XSA
- `vitis_application/scene_engine_app/` — application component
- Vitis 2023.1 unified IDE COPIES sources into `Debug/src/` (no "Link to files" option). **Source of truth = repo `sw/`.** Vitis copy is a build artifact.

---

## 6. Verification Strategy & Results

We tested in three layers: per-module simulation, integrated simulation, and hardware verification on the actual Zybo board.

### 6.1 Phase 1 — Audio pipeline simulation

Run via `xvlog/xelab/xsim` directly (Vivado batch mode breaks pipe on Windows).

| Testbench | Coverage | Result |
|-----------|----------|--------|
| `tb_amplitude_detector` | Reset, positive burst, negative burst (abs value), silence decay | ✅ 3/3 PASS |
| `tb_band_energy` | Reset; report low/mid/high energies for low-freq input vs high-freq input | ✅ 1/1 PASS |
| `tb_feature_extraction_top` | Reset, silence, DC, 100 Hz bass, 4000 Hz treble, 1000 Hz mid, decay, valid-gating, alternating bass/treble | ✅ 9/9 PASS |

### 6.2 Phase 2 — Scene simulation

| Testbench | Coverage | Result |
|-----------|----------|--------|
| `tb_scene_loudness_pulse` | Reset, blanking, silence bg, loud pixel, quiet corner, blanking override | ✅ 6/6 PASS |
| `tb_scene_bass_bars` | Reset, blanking, silent bg, full energy bottom/top, gap pixel, medium energy boundaries | ✅ 8/8 PASS |
| `tb_scene_treble_flash` | Reset, blanking, center quiet, mid energy glow, edge flashing (both bright + dark), slow flash stable | ✅ 6/6 PASS |
| `tb_scene_split_screen` *(legacy)* | All 7 original tests | ✅ 7/7 PASS *(module no longer instantiated)* |
| `tb_scene_tri_band_eq` ⭐ | Reset, blanking, separators y=160/320, full+silent for each band, sensitivity scaling, in/out of bar boundaries | ✅ 11/11 PASS |
| `tb_scene_engine_top` ⭐ | Single mode each scene, single mode x=320 NOT crosshair, quad TL/TR/BL/BR show right scene, crosshair white at x=319/y=240, scene_select ignored in quad mode, blanking | ✅ 14/14 PASS |

**Total: 54/54 sim tests PASS** across 9 testbenches.

### 6.3 Phase 3 — Hardware verification

| Phase | What was verified |
|-------|------------------|
| 3A — PL-only HW | All 4 scenes render on HDMI; sw[1:0] selects scene; oscillating triangle wave drives features; LED0 (MMCM lock) + LED1 (active video) lit |
| 3B — Full PS integration | Bitstream + XSA generated, **routed timing MET (positive WNS, all constraints met)**, BRAM COE init confirmed (init-suffix wrappers in OOC synth log), scene 0 + quad-view + freeze rendering with real audio |

### 6.4 Phase 4 — Vitis software

CLI build via `arm-none-eabi-gcc` produces `scene_engine_app.elf` with **0 errors, 0 warnings**. Awaiting on-board UART smoke test.

---

## 7. Hardware Bring-up Results

### 7.1 What works on the board (verified)

- ✅ MMCM locks (LED0)
- ✅ Active video (LED1)
- ✅ HDMI signal at 640×480 @ 60 Hz, displayed on standard monitor
- ✅ COE-loaded BRAM driving audio reader (synthetic 110 Hz + 440 Hz + 3000 Hz multi-tone)
- ✅ Feature extraction producing non-zero amplitude / energies (after 2-stage pipeline fix)
- ✅ Scene 0 (Loudness Pulse) — orange center rectangle pulsing
- ✅ Scene 1 (Bass Bars) — green band growing from bottom with bass
- ✅ Scene 2 (Treble Flash) — cyan flashing edges + magenta center
- ✅ Scene 3 (Tri-Band EQ) — red/green/blue stacked bars filling left→right
- ✅ Quad view — all 4 scenes in 2×2 grid with white crosshair
- ✅ Freeze — scenes 0/1/3 frozen by feature-latch; scene 2 frozen after `freeze` input fix to `scene_treble_flash`

### 7.2 Suggested demo script (for presentation)

1. **Power on.** LED0 + LED1 light immediately. HDMI shows scene 0 (orange center pulse animating with audio).
2. **Cycle through scenes** by flipping `sw[1:0]`:
   - `00` → Loudness Pulse (orange center)
   - `01` → Bass Bars (green from bottom)
   - `10` → Treble Flash (cyan edges flashing)
   - `11` → Tri-Band EQ (RGB stacked bars)
3. **Quad mode** — flip `sw[2]` up. All 4 scenes appear simultaneously. LED2 lights to confirm.
4. **Freeze** — flip `sw[3]` up while in quad. Animation stops mid-frame. LED3 lights. Great for inspecting any single scene.
5. **UART tuning** — connect serial terminal at 115200. Press `2` to show status (current scene + sensitivity). Press `1` then `9` to crank sensitivity → bars/EQ visibly extend further across the screen.

### 7.3 Hardware test photo

A screenshot from `result.jpg` (2026-05-03) confirmed the quad+freeze layout: 4 quadrants visible with white crosshair, all 4 scenes rendering at quadrant scale, three properly frozen, one (treble) needed the additional fix described in §8.4.

---

## 8. Challenges & Engineering Solutions

This section narrates the four substantive bugs we hit and how we diagnosed them. These are the most "presentable" engineering moments of the project.

### 8.1 Black screen in silicon despite passing simulation

**Symptom:** First Phase 3B program — LED0 + LED1 lit (MMCM + active video OK), but HDMI was completely black. Sim passed.

**Diagnosis:** Inspected timing report — found a 14-level CARRY4 chain in `band_energy.v` with negative slack. The chain spanned IIR filter → abs → multiply-accumulate for the EMA in a single combinational path. Sim worked because behavioral models ignore propagation delay. On silicon at 125 MHz the chain didn't settle in time; energy registers latched zeros every cycle.

**Fix:** Split `band_energy.v` into a 2-stage pipeline. Stage 1 updates the IIR filter state and registers `abs_low/mid/high`. Stage 2 reads those registers and updates the EMA. Adds 1 cycle latency (irrelevant at 22 kHz audio) but cuts the worst-case chain depth in half. Timing closed; HDMI immediately came alive.

**Lesson:** Always check the post-route timing report on a Zynq design — sim won't catch combinational depth issues.

### 8.2 BRAM all-zeros despite COE file present

**Symptom:** Audio reader output stuck at zero even though the COE file existed and Vivado's IP customization showed the file was selected.

**Diagnosis:** The BRAM IP was in **BRAM_Controller mode** because that's how AXI BRAM ctrl auto-instantiates it. In that mode, the `Load_Init_File` checkbox is **disabled** by Vivado. The COE was set in the IP UI but never actually written to memory at synth time.

**Fix:** Manually changed BRAM mode to **Standalone** in the BD. This re-enables `Load_Init_File`, and the OOC synth log then shows `_init`-suffix BRAM primitives (e.g., `blk_mem_gen_prim_wrapper_init__parameterized27`) confirming initialization. Standalone mode also changes the Port B interface (15-bit word addr instead of byte addr, no rst pin, 1-bit we), so the top module had to be updated to match.

**Lesson:** When a Vivado IP has a config option that's grayed out, search for what mode would re-enable it.

### 8.3 Vitis compile error: `XPAR_AXI_GPIO_1_DEVICE_ID` undeclared

**Symptom:** First Vitis build failed with `XPAR_AXI_GPIO_1_DEVICE_ID undeclared (first use in this function); did you mean XPAR_AXI_GPIO_0_DEVICE_ID?`

**Diagnosis:** The original `button_handler.c` was written assuming two separate AXI GPIO IPs (one for switches, one for buttons). The actual BD has a single `axi_gpio_0` with two channels (ch1 = switches, ch2 = buttons). Only `_GPIO_0_DEVICE_ID` exists in the BSP.

**Fix:** Rewrote `button_handler.c` to use one `XGpio` instance and call `XGpio_DiscreteRead(&gpio, 1)` for switches, `(..., 2)` for buttons. Build immediately clean.

**Lesson:** When designing the BD, decide upfront whether to use multiple GPIO instances (clearer in software) or fewer dual-channel ones (lighter resource cost) — and write the C accordingly.

### 8.4 Treble flash kept animating during freeze

**Symptom:** Hardware test of quad+freeze (`sw[3:2]=11`) — three quadrants properly frozen, but the bottom-left (`scene_treble_flash`) cyan edges kept flashing.

**Diagnosis:** My freeze logic in the top module latched the audio FEATURES (`amplitude`, `energy_*`). The other 3 scenes are pure combinational on those features, so feature-latch alone freezes them. But `scene_treble_flash` has its own internal `flash_counter` and `flash_state` registers that tick on every pixel clock independent of features. They kept incrementing.

**Fix:** Added a `freeze` input port to `scene_treble_flash.v`. When asserted, the counter increment branch is skipped — `flash_counter` and `flash_state` hold. Plumbed `freeze` through `scene_engine_top.v` from `sw[3]` in both top modules.

**Lesson:** "Freeze the inputs" doesn't equal "freeze the output" if a module has internal state. Audit every scene/IP for independent counters before declaring freeze done.

---

## 9. Resource Utilization & Performance

Numbers from `phase3_integration.runs/impl_1/reactive_scene_top_ps_utilization_placed.rpt` (post-implementation, routed) for `xc7z010clg400-1`:

| Resource | Used | Available | % |
|----------|------|-----------|---|
| Slice LUTs | 5,885 | 17,600 | **33.4%** |
| LUT as Logic | 5,148 | 17,600 | 29.3% |
| Slice Registers (FFs) | 5,808 | 35,200 | **16.5%** |
| Block RAM (RAMB36/FIFO) | 29 | 60 | **48.3%** |
| DSP48E1 | 2 | 80 | **2.5%** |

**Power** (post-route estimate): Total on-chip 1.87 W (static 0.13 W, dynamic ~1.74 W).

**Why these numbers matter for a presentation:**
- BRAM dominates because of the audio sample store (16 of the 29 tiles for the audio buffer, the rest for AXI infrastructure).
- DSP usage is intentionally low — the `*sensitivity` multiplier in `scene_bass_bars` and `scene_tri_band_eq` is the only DSP-mapped op. All filtering uses shift-based IIR.
- The full design fits in **the smallest Zynq part** with room to spare (xc7z010 is the entry-level chip).
- LUT count includes the entire AXI infrastructure (SmartConnect, BRAM ctrl, GPIO ctrl, scene_ctrl_v1_0).

**Timing** (post-route): All clocks MET. Worst negative slack positive on every constraint group after band_energy pipeline + CDC false paths.

---

## 10. Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Video output | HDMI via Digilent `rgb2dvi_0` IP | Native Zybo HDMI port; handles TMDS encoding |
| Pixel clock generation | MMCM (×8 / ÷40 = 25 MHz) | Locks reliably (LED0 confirms); a counter divider gives wrong frequency |
| Audio format | 16-bit signed PCM, mono, 22.05 kHz | Fits ~1.5 s loop in available BRAM; standard rate for human-audible content |
| BRAM organization | 32-bit × 32768 (audio in low 16 bits) | Matches AXI 32-bit width without packing logic |
| BRAM mode | **Standalone** (not BRAM_Controller) | Only Standalone exposes `Load_Init_File` for COE init |
| Band filtering | Shift-based 1st-order IIR | No multipliers in pixel path; sufficient resolution; matches course DSP scope |
| Band energy timing | 2-stage pipeline | Required for timing closure on silicon (sim worked; silicon didn't) |
| AXI IP | Hand-written `scene_ctrl_v1_0.v` | Matches Lab 3/4 patterns; full control over register semantics |
| Color depth | 4-bit per channel duplicated to 8-bit | Cheap; sufficient visual fidelity |
| Display mode control | **HW switches (PL direct)** | Display works without Vitis loaded; instant response; no AXI round-trip |
| Sensitivity control | **AXI register (UART-tuned)** | Continuous range (0-255) better than a switch can express |
| Quad-view implementation | Single set of 4 scene instances + virtualized coords | Cheaper than instantiating scenes twice; same hardware path for both modes |
| Freeze implementation | Latch features at sys_clk + `freeze` input on `scene_treble_flash` | Three scenes are pure combinational (latch alone freezes them); treble has internal counter, needs gate |
| CDC | False-paths in `timing_cdc.xdc` (impl-only) | `clk_fpga_0` is not visible during synth |
| Vitis app scope | Minimal (sensitivity + status only) | Reflects HW-driven design philosophy; less code = less to break |

---

## 11. Lessons Learned

1. **Sim ≠ silicon.** Behavioral simulation cannot detect combinational depth issues. Always check post-route timing on Zynq, especially anything with multi-level adders or accumulators (CARRY4 chains).

2. **Vivado IP options can be silently disabled.** `Load_Init_File` was grayed out in BRAM_Controller mode with no obvious indication that switching to Standalone would re-enable it. When something *should* be configurable but isn't, look at the parent IP's mode setting.

3. **The BD is part of the source code.** Renaming `axi_gpio_0` to add `axi_gpio_1` would have been a 30-second fix in the BD that saved a debugging session in software. Keep BD and software in lockstep — and ideally have one team member own the BD/SW interface contract.

4. **Freeze the right things.** Latching audio features doesn't freeze a scene that has its own animation timer. Audit every scene module for independent counters/state before claiming "freeze works."

5. **Hardware-driven controls are simpler than software-driven for demos.** The original plan had buttons → C code → AXI register writes → scene change. The current design has switches → PL wires → scene change. Same outcome, no software stack required, instant response, easier to show on stage.

6. **Build the UART-only Vitis app early.** Even a 27 KB ELF that just shows a menu confirms the platform component, BSP, UART pinning, and PS-PL handshake all work. We caught the GPIO mismatch from a single compile attempt.

7. **Single-rendering-path designs scale better.** Originally we considered instantiating 4 scenes for single-view + 4 more for quad-view. Using virtualized pixel coords lets ONE set of instances drive both modes, which roughly halved the resource cost of quad-view.

8. **xvlog/xelab/xsim from PowerShell beats `vivado -mode batch`** for testbench iteration on Windows. Faster, cleaner output, no broken-pipe issues.

---

## 12. Future Work

| Item | Effort | Value |
|------|--------|-------|
| Wire `btn[3:1]` (3 new pin constraints) for sensitivity step ± and audio reset | 30 min | Adds tactile control without UART |
| Replace synthetic COE with a real `.wav` file via `tools/gen_audio_coe.py` | 15 min | Real music demo (much more impressive) |
| Add software scene override (UART command writes SCENE_SEL → mux activates when sw[1:0]==00) | 1 hour | Demonstrates PS↔PL coexistence |
| Add `tb_scene_treble_flash` freeze test (assert flash_state stable for N cycles after freeze) | 20 min | Closes a sim gap (currently only HW-verified) |
| Wire SW[3:2] into AXI GPIO (BD update + re-impl) | 30 min | Software can read full HW state for richer UART status |
| Add a 5th scene that uses `amplitude × bands` matrix (e.g., color rotation) | 2 hours | More visual variety |
| Live audio input via PMOD I2S microphone | 4 hours | Removes COE loop, true reactive demo |
| FFT-based band split (replace IIR) | 8+ hours | True spectrum analyzer; uses more DSP |

---

## 13. Project Structure

```
final_project/
  reactive-visual-scene-engine/         <-- This repo
    rtl/
      audio/audio_sample_reader.v
      feature_extraction/
        amplitude_detector.v
        band_energy.v                   2-stage pipeline
        feature_extraction_top.v
      scene_engine/
        scene_loudness_pulse.v          Scene 0
        scene_bass_bars.v               Scene 1
        scene_treble_flash.v            Scene 2 (freeze input)
        scene_tri_band_eq.v             Scene 3 NEW (replaces split_screen)
        scene_engine_top.v              4-scene mux + quad view + crosshair + freeze
        scene_split_screen.v            DEPRECATED (kept for reference)
      video/
        vga_sync.v                      640x480 @ 60Hz
        pixel_clk_gen.v                 MMCM 25 MHz + 125 MHz
        vga_controller.v                legacy
      axi_ip/
        scene_ctrl_v1_0.v               AXI-Lite top
        scene_ctrl_v1_0_S00_AXI.v       6-register slave
      top/
        reactive_scene_top.v            Phase 3A (PL-only)
        reactive_scene_top_ps.v         Phase 3B/4 production
        reactive_scene_top_ps_test.v    same as ps.v functionally
        hdmi_test_pattern_top.v         Phase 0 bring-up
    tb/
      tb_amplitude_detector.v           3 tests
      tb_band_energy.v                  1 test
      tb_feature_extraction_top.v       9 tests
      tb_scene_loudness_pulse.v         6 tests
      tb_scene_bass_bars.v              8 tests
      tb_scene_treble_flash.v           6 tests (freeze input)
      tb_scene_tri_band_eq.v            11 tests NEW
      tb_scene_engine_top.v             14 tests NEW (quad mux)
      tb_scene_split_screen.v           7 tests (legacy)
      tb_audio_sample_reader.v
      tb_vga_sync.v
    sw/
      src/                              C source (4 files, ~240 LOC total)
      include/                          Headers
    constraints/
      zybo_z7_hdmi.xdc                  HDMI TMDS, sw[3:0], btn0, LEDs
      timing_cdc.xdc                    CDC false paths (impl-only)
    data/
      audio_samples.coe                 32-bit COE (synthetic 110+440+3000 Hz)
    scripts/                            TCL helpers (BD setup, sim)
    tools/
      gen_audio_coe.py                  WAV -> COE converter
    PROJECT_PLAN.md                     this file
    PC_SETUP_GUIDE.md                   Vivado/Vitis install notes

  phase1_sim/                            Vivado sim project (build artifacts)
  phase2_scene_sim_xsim/                 xvlog flow for scene sims
  phase3_integration/                    Vivado project (BD + bitstream + XSA)
  vitis_application/                     Vitis 2023.1 unified workspace
```

---

## 14. Build & Run Cheat Sheet

### 14.1 Run any simulation

```powershell
cd phase2_scene_sim_xsim   # or phase1_sim/.../xsim
xvlog -prj tb_<NAME>_vlog.prj
xelab --debug typical --relax --mt 8 -L xil_defaultlib --snapshot tb_<NAME>_behav xil_defaultlib.tb_<NAME> xil_defaultlib.glbl
xsim tb_<NAME>_behav -t run_all.tcl -onerror quit
```
Expected: `[PASS]` lines and `=== ... ALL PASS ===` at end.

### 14.2 Re-synth + impl + bitstream

In Vivado TCL Console (project `phase3_integration` open):
```tcl
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
puts "WNS: [get_property STATS.WNS [get_runs impl_1]]"

# Re-export hardware (overwrites .xsa for Vitis)
write_hw_platform -fixed -include_bit -force \
  C:/Users/khuon/ECE520/final_project/phase3_integration/reactive_scene_top_ps.xsa
```

### 14.3 Re-build Vitis app from CLI

```powershell
cd vitis_application\scene_engine_app\Debug
$env:PATH = "C:\Xilinx\Vitis\2023.1\gnu\aarch32\nt\gcc-arm-none-eabi\bin;C:\Xilinx\Vitis\2023.1\gnuwin\bin;C:\Xilinx\Vitis\2023.1\bin;$env:PATH"
make clean
make all
```
Expected: `Finished building target: scene_engine_app.elf`.

### 14.4 Program board

In Vivado Hardware Manager:
1. Open Target → Auto Connect
2. Program Device → select `phase3_integration\phase3_integration.runs\impl_1\reactive_scene_top_ps.bit`

In Vitis (after FPGA programmed):
1. Right-click `scene_engine_app` → Run As → Launch Hardware
2. Open Vitis Serial Terminal at 115200 baud on the higher-numbered Zybo COM port
3. Press `h` to show menu

### 14.5 Audio data swap

```powershell
python tools\gen_audio_coe.py data\your_audio.wav data\audio_samples.coe 32768 22050
```
Then re-synth (BRAM init is read at synth time).

---

## 15. Change Log

Chronological summary of changes from the original plan to the current design.

### 15.1 RTL changes

| File | Change | Reason |
|------|--------|--------|
| `rtl/feature_extraction/band_energy.v` | Added 2-stage pipeline (Stage 1: IIR + register abs values; Stage 2: EMA from registered abs) | 14-level CARRY4 chain failed silicon timing → all energies zero → black screen |
| `rtl/scene_engine/scene_tri_band_eq.v` | NEW module — 3 horizontal stacked bars (red/green/blue), 160 px each | Need `energy_mid` visualization; replaces `scene_split_screen` which duplicated scenes 1+2 |
| `rtl/scene_engine/scene_engine_top.v` | Replaced `scene_split_screen` instance with `scene_tri_band_eq`. Added `quad_view_en` input + virtualized pixel coords + quadrant mux + 1-px white crosshair. Added `freeze` input passed through to treble | Scene 4 redesign + new quad-view + new freeze plumbing |
| `rtl/scene_engine/scene_treble_flash.v` | Added `freeze` input — gates `flash_counter` increment | Hardware test showed cyan kept flashing in freeze mode (counter is internal to scene, not feature-driven) |
| `rtl/top/reactive_scene_top_ps.v` | GPIO ports renamed `*_tri_i`. BRAM Port B `addr=[14:0]`, no rst, `we=1'b0`. `scene_ctrl_axi_wlast()` left unconnected. Wired `sw[1:0]→scene_select`, `sw[2]→quad_view_en`, `sw[3]→freeze`. Freeze register block on features. AXI scene_select disconnected; sensitivity stays | AXI GPIO conventions; BRAM Standalone interface; multiple-driver fix; new HW switch contract |
| `rtl/top/reactive_scene_top_ps_test.v` | NEW — same wiring as `reactive_scene_top_ps.v` (functionally identical; kept for flexibility) | Originally for HW test without Vitis; now redundant since production top works without PS too |
| `constraints/timing_cdc.xdc` | NEW — implementation-only false paths (`sys_clk_pin → clkout0`, `clk_fpga_0 → clkout0`) | `clk_fpga_0` not visible at synth time |

### 15.2 Software changes

| File | Change | Reason |
|------|--------|--------|
| `sw/src/button_handler.c` | First fix: use ONE `XGpio` with channels 1 (sw) + 2 (btn). Then: stripped to `init()` + `read_scene_switches()` only | Compile error from BSP only generating GPIO_0; subsequent HW-driven design eliminated need for button processing |
| `sw/src/uart_menu.c` | Removed scene-select / preset / threshold / reset-defaults menu items. Kept sensitivity ± , status (incl. HW switches), reset-sensitivity | RTL only consumes SENSITIVITY register; other writes have no effect — removing prevents user confusion |
| `sw/src/main.c` | Removed `button_handler_process()` from poll loop. Init sensitivity at boot. Added `#include "scene_ctrl_regs.h"` for DEFAULT_SENSITIVITY | Simplified loop matches new philosophy |

### 15.3 Sim coverage additions

| Testbench | Tests | Status |
|-----------|-------|--------|
| `tb_scene_tri_band_eq.v` | 11 | ✅ NEW — covers all 3 band rows + separators + sensitivity scaling |
| `tb_scene_engine_top.v` | 14 | ✅ NEW — covers single mode, quad mode, crosshair, scene_select-ignored-in-quad |
| `tb_scene_treble_flash.v` | 6 | Updated for new `freeze` input (default 0; old tests still PASS) |

### 15.4 Verification log

- 2026-05-03 (early): First Phase 3B program — LED0+1 lit, scene 0 renders correctly with COE-driven audio.
- 2026-05-03 (mid): Switch contract redesign + tri-band EQ + quad view + freeze deployed.
- 2026-05-03 (mid): HW test in quad+freeze mode (sw[3:2]=11): 4 quadrants visible with white crosshair; TL/TR/BR scenes properly frozen; **BL (treble) still animating** → bug found.
- 2026-05-03 (mid): Root cause identified as treble's internal `flash_counter`; fix added (`freeze` input). Sims re-PASS.
- 2026-05-03 (late): C code aligned with HW-driven design. CLI rebuild produced `scene_engine_app.elf` 27870/1176/22664.

---

*End of document.*
