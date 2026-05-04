# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Toolchain

- **Vivado 2023.1** — RTL simulation and FPGA implementation
- **Vitis 2023.1** — ARM C application (separate IDE from Vivado)
- **Python 3** — audio COE file generation
- **Board:** Zybo Z7-10 | **Part:** `xc7z010clg400-1`
- **Board file ID:** `digilentinc.com:zybo-z7-10:part0:1.2`

Launching Vivado GUI (opens project):
```powershell
vivado C:\Users\khuon\ECE520\final_project\phase3_integration\phase3_integration.xpr
```

> **NOTE:** `vivado -mode batch` + `launch_simulation` causes broken pipe on Windows. Use xvlog/xelab/xsim directly for simulation (see Phase 1-Sim).

---

## Continue Protocol

Throughout this guide, **STOP blocks** mark steps that require you to act in the Vivado/Vitis GUI or run a command yourself. When you finish a STOP block:

1. Type **`continue`** in this chat.
2. Claude will check the relevant output (log file, sim transcript, project state) to verify success.
3. If verification passes, Claude proceeds to the next step.
4. If verification fails, Claude will diagnose the issue, suggest RTL fixes or configuration changes, and ask you to re-run before continuing.

---

## Source Management Rule (critical)

**All `.v` files live in `reactive-visual-scene-engine/rtl/` and `tb/`.** Vivado projects reference them via relative paths. **Never copy sources into a Vivado project** — always use "Add Files" (not "Copy into project") in the GUI, or `add_files` (no `-force`) in TCL.

---

## Phase 1-Sim: Audio Pipeline Verification

**Status: ALL PASS ✅**
- `tb_amplitude_detector` — 3/3 PASS
- `tb_band_energy` — 1/1 PASS
- `tb_feature_extraction_top` — 9/9 PASS

Simulations were run using xvlog/xelab/xsim directly (not Vivado batch mode). Sim files are in `phase1_sim/phase1_sim.sim/sim_1/behav/xsim/`.

---

## Phase 2: Scene Simulation

**Status: ALL PASS ✅**
- `tb_scene_loudness_pulse` — 6/6 PASS
- `tb_scene_bass_bars` — 8/8 PASS
- `tb_scene_treble_flash` — 6/6 PASS
- `tb_scene_split_screen` — 7/7 PASS

Sim files are in `phase2_scene_sim_xsim/`.

---

## Phase 3: Block Design + Hardware Integration

### Phase 3A — PL-only hardware test ✅ COMPLETE

- Top module: `reactive_scene_top.v` (PL-only, no PS)
- Project: `phase3_integration/phase3_integration.xpr`
- All 4 scenes visible on HDMI, sw[1:0] switches scenes
- Oscillating triangle wave drives audio features
- **Hardware verified on Zybo Z7-10**

### Phase 3B — Full PS integration

**Status: Bitstream generated. Hardware verification in progress.**

**Top module:** `reactive_scene_top_ps.v` (at `rtl/top/`)
**Project:** `phase3_integration/phase3_integration.xpr`

#### Block Design (`design_1`) — COMPLETE ✅

Components:
- `processing_system7_0` — Zynq PS7
- `proc_sys_reset_0` — driven by `const_1` (dcm_locked tied to 1)
- `axi_smc` — AXI SmartConnect, 3 masters: M00→BRAM, M01→GPIO, M02→scene_ctrl_axi
- `axi_bram_ctrl_0` — AXI BRAM Controller, single port
- `axi_bram_ctrl_0_bram_0` — True Dual Port BRAM, 32-bit × 32768, **Standalone mode** (NOT BRAM_Controller — must be Standalone to enable COE loading)
- `axi_gpio_0` — AXI GPIO, ch1=`sws_4bits`, ch2=`btns_4bits`

External ports:
- `BRAM_PORTB_0` — Port B of BRAM (15-bit addr, no rst, 1-bit we in Standalone mode)
- `sws_4bits_tri_i` — switches (AXI GPIO appends `_tri_i`)
- `btns_4bits_tri_i` — buttons (AXI GPIO appends `_tri_i`)
- `scene_ctrl_axi` — M02_AXI for AXI4 scene control
- `FCLK_CLK0_0` — PS clock exported (feeds scene_ctrl_v1_0 AXI clock)
- `DDR`, `FIXED_IO` — Zynq PS pins

Address map:
- `axi_bram_ctrl_0` → `0x4000_0000`, 128K
- `axi_gpio_0` → `0x4120_0000`, 64K
- `scene_ctrl_axi` → `0x43C0_0000`, 64K

#### COE Loading — CRITICAL NOTE

**BRAM must be in "Standalone" mode** for COE initialization to work. In "BRAM_Controller" mode, the `Load_Init_File` property is disabled and the BRAM synthesizes as all-zeros → black screen.

To check: In Vivado BD, double-click `axi_bram_ctrl_0_bram_0` → Basic tab → Mode must show **Standalone**. Other Options tab → Load Init File = checked, COE = `data/audio_samples.coe`.

To verify in synthesis log: `C_LOAD_INIT_FILE = 1`, `C_INIT_FILE_NAME = audio_samples.coe`.

#### Timing — RESOLVED ✅

- `band_energy.v` has a **2-stage pipeline** (added to break 14-level CARRY4 chain):
  - Stage 1: IIR filter update + register abs_low/mid/high values
  - Stage 2: EMA energy update from registered abs values
  - Without this, EMA computation fails in silicon → all energies = 0 → black screen
- **`sys_clk_pin` internal WNS = +0.486 ns** (timing MET after pipeline fix)
- CDC false paths in `constraints/timing_cdc.xdc` (marked `used_in_synthesis false`)
  - `set_false_path -from sys_clk_pin -to clkout0` (audio → pixel clock)
  - `set_false_path -from clk_fpga_0 -to clkout0` (PS → pixel clock)
  - These must be in a **separate implementation-only file** — they cannot go in the main XDC because `clk_fpga_0` is not visible during synthesis

#### Synthesis/Implementation

```tcl
# Re-run if sources changed:
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
puts "WNS: [get_property STATS.WNS [get_runs impl_1]]"
```

Bitstream: `phase3_integration/phase3_integration.runs/impl_1/reactive_scene_top_ps.bit`

#### Next step for Phase 3B

Verify on hardware:
1. Program bitstream via Hardware Manager
2. LED0 ON (MMCM locked) ✅
3. LED1 ON (active_video) ✅
4. HDMI display shows scene 0 (loudness pulse with audio)
5. Export hardware with bitstream → proceed to Phase 4

---

## Phase 4: Vitis Software

**Status:** Not started. C source files exist in `sw/` ✅.

### Step 4A — Export hardware with bitstream

In Vivado:
```
File → Export → Export Hardware → Include Bitstream → Next → Finish
```
Creates `phase3_integration.xsa`.

### Step 4B — Create Vitis project

1. Launch Vitis 2023.1
2. Create workspace: `C:\Users\khuon\ECE520\final_project\vitis_workspace`
3. **File → New → Platform Project** → name: `zybo_platform` → select `.xsa` → Standalone OS → Finish
4. **File → New → Application Project** → `zybo_platform` → name: `scene_engine_app` → Empty Application → Finish
5. Import `reactive-visual-scene-engine/sw/src/` (4 `.c` files)
6. Import `reactive-visual-scene-engine/sw/include/` (4 `.h` files)
7. Build → verify 0 errors

### Step 4C — Verify AXI base address

`scene_ctrl_regs.h` base address = `0x43C0_0000` matches address map. No change needed.

### Step 4D — Program and test

1. Xilinx → Program FPGA
2. Run → Launch on Hardware
3. Serial terminal: 115200 baud
4. BTN0 = next scene, BTN1 = prev scene, BTN2 = cycle preset, BTN3 = toggle auto
5. SW0/SW1 = sensitivity up/down, SW2 = debug overlay, SW3 = freeze

---

## Architecture Quick Reference

```
BRAM (audio_samples.coe, 32-bit × 32768 words, Standalone mode)
  Port A ← AXI BRAM Controller ← AXI SmartConnect ← Zynq PS (PS loads audio)
  Port B → BRAM_PORTB_0 → audio_sample_reader (rtl/audio/)
                └─ feature_extraction_top (rtl/feature_extraction/)
                     ├─ amplitude_detector  (ATTACK=2, DECAY=6)
                     └─ band_energy (LOW=4, MID=1, EMA=5) ← 2-stage pipeline
                          └─ scene_engine_top (rtl/scene_engine/)
                               ├─ scene_loudness_pulse  [select=0]
                               ├─ scene_bass_bars        [select=1]
                               ├─ scene_treble_flash     [select=2]
                               └─ scene_split_screen     [select=3]
                                    └─ pixel RGB → pixel_clk_gen + rgb2dvi_0 → HDMI

Zynq PS (AXI GP0) → AXI SmartConnect
  ├─ M00 → AXI BRAM Controller → BRAM Port A
  ├─ M01 → AXI GPIO → sws_4bits_tri_i, btns_4bits_tri_i
  └─ M02 → scene_ctrl_axi (external) → scene_ctrl_v1_0 (PL, clocked by FCLK_CLK0)
              ├─ SCENE_SEL[1:0]   → scene_engine_top.scene_select
              └─ SENSITIVITY[7:0] → scene_engine_top.sensitivity
```

**Clock domains:**
- `sys_clk_pin` = 125 MHz — PL input (K17), drives audio pipeline, BRAM Port B, feature extraction
- `clk_fpga_0` = 100 MHz — PS FCLK_CLK0, drives AXI interconnect and scene_ctrl_v1_0
- `clkout0` = 25 MHz — MMCM pixel clock, drives vga_sync and scene_engine_top
- `clkout1` = 125 MHz — MMCM serial clock, drives rgb2dvi_0 SerialClk

**CDC crossings (false-pathed):**
- `sys_clk_pin → clkout0`: amplitude, energy_low/mid/high (change at 22 kHz — safe)
- `clk_fpga_0 → clkout0`: scene_select, sensitivity (change on PS write — safe)

**rgb2dvi_0 settings (Digilent v1.4):**
- `kGenerateSerialClk = false` → SerialClk is an INPUT (driven by MMCM clkout1)
- `kRstActiveHigh = true`
- vid_data packing: `[23:16]=R`, `[15:8]=B`, `[7:0]=G` (Digilent non-standard order)
- Top uses: `{scene_r, scene_r}, {scene_b, scene_b}, {scene_g, scene_g}`

**VGA timing:** 640×480 @ 60Hz, H_TOTAL=800, V_TOTAL=525, hsync/vsync active-low.

**AXI registers (base 0x43C0_0000):**

| Offset | Name | Default |
|--------|------|---------|
| 0x00 | SCENE_SEL [1:0] | 0 |
| 0x04 | PRESET_SEL [7:0] | 0 |
| 0x08 | SENSITIVITY [7:0] | 128 |
| 0x0C | THRESHOLD [15:0] | 0 |
| 0x10 | MODE_CTRL [0] | 0 |
| 0x14 | DEBUG_EN [0] | 0 |

---

## Known RTL Changes from Original Design

| File | Change | Reason |
|------|--------|--------|
| `rtl/feature_extraction/band_energy.v` | Added 2-stage pipeline (abs_low/mid/high registered before EMA) | 14-level CARRY4 timing violation caused all-zero energies in silicon |
| `rtl/top/reactive_scene_top_ps.v` | GPIO ports renamed to `sws_4bits_tri_i`/`btns_4bits_tri_i` | AXI GPIO wrapper appends `_tri_i` to tristate input ports |
| `rtl/top/reactive_scene_top_ps.v` | BRAM Port B: addr=[14:0], no rst, we=1'b0 | Standalone mode changes interface (15-bit word addr, no reset pin, 1-bit write enable) |
| `rtl/top/reactive_scene_top_ps.v` | `scene_ctrl_axi_wlast` left unconnected `()` | Was connected to `sc_wvalid` causing multiple driver on that net |
| `constraints/timing_cdc.xdc` | New file, implementation-only | CDC false paths cannot go in main XDC (clk_fpga_0 not visible during synthesis) |

---

## Troubleshooting Quick Reference

| Symptom | Phase | Likely cause | Action |
|---------|-------|-------------|--------|
| Black screen, LED0+LED1 on | 3B | BRAM all zeros (COE not loaded) | Check BRAM mode = Standalone, COE file set, C_LOAD_INIT_FILE=1 in OOC synth log |
| Black screen, LED0+LED1 on | 3B | band_energy timing violation | Verify `band_energy.v` has 2-stage pipeline (valid_d register present) |
| WNS failing on CDC paths only | 3B | False path constraints not applied | Check `timing_cdc.xdc` exists, `used_in_synthesis=false`, applied in implementation |
| `sws_4bits does not exist` synthesis | 3B | AXI GPIO port name mismatch | Use `sws_4bits_tri_i` and `btns_4bits_tri_i` |
| `BRAM_PORTB_0_rst does not exist` | 3B | BRAM changed to Standalone mode | Remove rst connection, update addr to [14:0], we to 1'b0 |
| Multiple driver on `m_axi_wvalid` | 3B | SmartConnect OOC netlist stale | Reset `design_1_axi_smc_0_synth_1` and re-synthesize |
| MMCM not locking | 3 | Wrong MMCM params | Verify CLKFBOUT_MULT=8, CLKOUT0_DIVIDE_F=40, CLKOUT1_DIVIDE=8 |
| No HDMI signal | 3 | rgb2dvi SerialClk issue | kGenerateSerialClk=false, SerialClk driven by MMCM clkout1 |
| `[FAIL] Test 4` band energy | 1-Sim | LOW_SHIFT too small | Increase LOW_SHIFT in band_energy.v |
| UART menu doesn't appear | 4 | Wrong COM port or baud | Use 115200, 8N1; verify Zybo UART MIO pins in PS config |
| Wrong scene on button press | 4 | Button GPIO wiring | Check axi_gpio_0 channel assignment vs. button_handler.c |
