# PC Setup Guide — Phase 1: HDMI Test Pattern on Zybo Z7

This guide walks you through getting the Reactive Visual Scene Engine from GitHub onto your Windows PC and displaying a test pattern over HDMI on your Zybo Z7. It assumes Vivado 2024.1 is already installed (Lab 0).

---

## Part 0: Prerequisites — Verify Your Setup

Before starting, confirm these are working on your PC:

1. **Vivado 2024.1** is installed (from Lab 0)
2. **Digilent board files** are in `C:\Xilinx\Vivado\2024.1\data\boards\board_files\` (from Lab 0)
3. **Git** is installed — check by opening Command Prompt and running:
   ```cmd
   git --version
   ```
   If not installed, download from https://git-scm.com/download/win
4. **Zybo Z7 board** with USB cable
5. **HDMI cable** + a monitor with an HDMI input

---

## Part 1: Clone the Repo

### Step 1.1 — Choose a Location
Pick a folder on your PC for the project. **Important:** avoid paths with spaces or special characters (Vivado hates them). Recommended:

```
C:\xilinx_projects\reactive-visual-scene-engine
```

### Step 1.2 — Clone from GitHub
Open **Command Prompt** (or Git Bash) and run:

```cmd
cd C:\
mkdir xilinx_projects
cd xilinx_projects
git clone https://github.com/macyvar/reactive-visual-scene-engine.git
cd reactive-visual-scene-engine
```

You should now have all the source files locally. Verify by running:
```cmd
dir
```
You should see folders like `rtl`, `tb`, `sw`, `constraints`, and `PROJECT_PLAN.md`.

### Step 1.3 — Clone the Digilent IP Library
The HDMI test pattern needs Digilent's `rgb2dvi` IP. Clone it next to your project:

```cmd
cd C:\xilinx_projects
git clone https://github.com/Digilent/vivado-library.git
```

You should now have two folders side-by-side:
```
C:\xilinx_projects\reactive-visual-scene-engine\
C:\xilinx_projects\vivado-library\
```

---

## Part 2: Create the Vivado Project

### Step 2.1 — Launch Vivado
1. Start menu → **Vivado 2024.1** → click to open
2. On the welcome screen, click **Create Project**

### Step 2.2 — Project Setup
1. Click **Next**
2. **Project name:** `hdmi_test`
3. **Project location:** `C:\xilinx_projects\reactive-visual-scene-engine` (or any non-spaced path)
4. Check **Create project subdirectory**
5. Click **Next**

### Step 2.3 — Project Type
1. Select **RTL Project**
2. **Do NOT** check "Do not specify sources at this time"
3. Click **Next**

### Step 2.4 — Add Sources
On the "Add Sources" page:
1. Click the **+** icon → **Add Files**
2. Navigate to `C:\xilinx_projects\reactive-visual-scene-engine\rtl` and add:
   - `top\hdmi_test_pattern_top.v`
   - `video\vga_sync.v`
   - `video\pixel_clk_gen.v`
3. Make sure **Copy sources into project** is **UNCHECKED** (we want Vivado to reference, not copy)
4. Click **Next**

### Step 2.5 — Add Constraints
1. Click **+** → **Add Files**
2. Navigate to `C:\xilinx_projects\reactive-visual-scene-engine\constraints`
3. Add `zybo_z7_hdmi.xdc`
4. Click **Next**

### Step 2.6 — Default Part / Board
1. Click the **Boards** tab (very important — don't use the Parts tab)
2. In the search box, type: `zybo`
3. Select **Zybo Z7-10** (or **Zybo Z7-20** if you have that variant)
   - If nothing shows up, your board files aren't installed correctly — go back to Lab 0 instructions
4. Click **Next**
5. Click **Finish**

The project will open. You should see your three Verilog files in the **Sources** panel on the left.

---

## Part 3: Add the Digilent IP Repository

### Step 3.1 — Add IP Repository Path
1. In Vivado, click **Tools** menu → **Settings**
2. In the left tree, expand **IP** → click **Repository**
3. Click the **+** (green plus) on the right
4. Navigate to and select: `C:\xilinx_projects\vivado-library`
5. Click **Select**
6. Vivado will scan and tell you it found IPs (you should see `rgb2dvi` mentioned)
7. Click **OK** → **OK** to close Settings

### Step 3.2 — Generate the rgb2dvi IP
1. In the left **Flow Navigator** panel, click **IP Catalog**
2. In the search box at the top, type: `rgb2dvi`
3. Double-click **RGB to DVI Video Encoder** (under Digilent)
4. A customization dialog appears:
   - **Component Name:** keep default `rgb2dvi_0`
   - **TMDS clock range:** select **<120 MHz** (we're using 25 MHz pixel clock)
   - **Generate SerialClk internally:** ✅ **CHECK THIS BOX** (very important!)
   - Leave other settings at defaults
5. Click **OK**
6. A "Generate Output Products" dialog appears → click **Generate**
7. Wait for IP generation to complete (status bar at top right). When done, you'll see `rgb2dvi_0` in your Sources panel under "IP Sources"

---

## Part 4: Verify Top Module

### Step 4.1 — Set Top Module
1. In the **Sources** panel, expand **Design Sources**
2. Right-click `hdmi_test_pattern_top` (it should already be bold/highlighted)
3. If not bold, right-click → **Set as Top**

### Step 4.2 — Hierarchy Check
You should see this hierarchy:
```
hdmi_test_pattern_top (top)
├── pixel_clk_gen (u_pclk)
├── vga_sync (u_sync)
└── rgb2dvi_0 (u_rgb2dvi)
```

If `rgb2dvi_0` shows as missing/red, go back to Step 3.2 and verify the IP was generated.

---

## Part 5: Build the Bitstream

### Step 5.1 — Run Synthesis
1. In the **Flow Navigator** (left panel) → click **Run Synthesis**
2. A dialog asks about resources/jobs → click **OK**
3. Wait 1-3 minutes. You'll see "Synthesis Complete" pop up.
4. Choose **Run Implementation** → click **OK**

### Step 5.2 — Run Implementation
1. Wait 2-5 minutes for implementation
2. When complete, choose **Generate Bitstream** → click **OK**

### Step 5.3 — Generate Bitstream
1. Wait another 2-5 minutes
2. When done, a dialog says "Bitstream Generation Successfully Completed"
3. Choose **Open Hardware Manager** → click **OK**

If you get **errors** during these steps, the most common causes:
- Missing IP — go back to Part 3
- Constraint pin name mismatch — verify pin names in `.xdc` file match port names in `hdmi_test_pattern_top.v`
- Timing warnings (yellow) are usually OK at this stage

---

## Part 6: Connect and Program the Board

### Step 6.1 — Physical Setup
1. Set Zybo Z7 to **JTAG** boot mode:
   - Find the **JP5** jumper (boot mode select)
   - Set it to **JTAG** position
2. Connect **USB cable** from Zybo's PROG/UART port to your PC
3. Connect **HDMI cable** from Zybo's **HDMI TX** port (the one labeled "TX", NOT RX) to your monitor
4. Turn on the Zybo Z7 (power switch). The red **PWR** LED should light.
5. Make sure your monitor is on and set to the HDMI input

### Step 6.2 — Connect to Hardware
1. In **Hardware Manager** (the panel that opened after bitstream generation):
2. Click **Open target** → **Auto Connect**
3. Vivado should detect the Zybo Z7 — you'll see `xc7z010_1` in the panel

### Step 6.3 — Program the FPGA
1. Right-click on `xc7z010_1` → **Program Device**
2. The bitstream path should auto-fill (something like `...hdmi_test.runs/impl_1/hdmi_test_pattern_top.bit`)
3. Click **Program**
4. Wait ~5 seconds. The green **DONE** LED on the Zybo Z7 should light up.

---

## Part 7: Verify on Hardware

### What You Should See

**On the Zybo Z7:**
- ✅ Red **PWR** LED on (power)
- ✅ Green **DONE** LED on (FPGA configured)
- ✅ **LED0** solid on (MMCM locked = clock generation working)
- ✅ **LED1** appears mostly on (active video pulse)

**On the monitor:**
- 8 vertical color bars from left to right:
  - White, Yellow, Cyan, Green, Magenta, Red, Blue, Black

### Quick Functional Test
- Press **BTN0** on the Zybo → screen goes black (reset pulled MMCM)
- Release **BTN0** → bars come back, LED0 re-lights
- Flip **SW0** / **SW1** → LED2 / LED3 mirror the switch states

If you see all of this, **Phase 1 is complete!** Your VGA timing, HDMI encoding, clock generation, and pin mapping are all verified.

---

## Part 8: Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Monitor says "No Signal" | HDMI cable in wrong port (RX instead of TX), monitor not on right input, or DONE LED off | Check cable, set monitor to correct HDMI input, verify DONE LED |
| LED0 is off | MMCM not locking | Verify `K17` is the right clock pin in your `.xdc`. Check the 125 MHz clock constraint. |
| Bars are visible but flickering/garbled | Pixel clock not stable, OR rgb2dvi `<120 MHz` setting is wrong | Re-check rgb2dvi IP settings (Part 3.2) |
| Colors look wrong (e.g., red/blue swapped) | Bit ordering in `vid_pData` | Check `hdmi_test_pattern_top.v` — should be `{tp_r, tp_g, tp_b}` |
| Implementation fails with "unconstrained ports" | Constraint file pin names don't match top module port names | Open `zybo_z7_hdmi.xdc`, ensure each `[get_ports {NAME}]` matches exactly |
| `gh` says "fatal: not a git repository" | You ran git in the wrong folder | `cd C:\xilinx_projects\reactive-visual-scene-engine` first |
| Vivado complains about board files | Board files not installed | Re-do Lab 0 step 4 (copy `board_files` folder into Vivado data dir) |

---

## What's Next

Once Phase 1 works:
- **Phase 2:** Run testbenches in Vivado simulator to verify audio feature extraction
- **Phase 3:** Hook up the scene engine modules to display real visuals (still hardcoded audio for now)
- **Phase 4:** Full SoC integration with Zynq PS, BRAM audio, AXI control IP, and Vitis software

Each phase is detailed in [PROJECT_PLAN.md](PROJECT_PLAN.md).

---

## Pulling Future Updates

When I make changes on the Mac and push them, you can pull on your PC by:

```cmd
cd C:\xilinx_projects\reactive-visual-scene-engine
git pull
```

Vivado will detect file changes when you reopen the project. If new source files are added, you may need to **Add Sources** again.
