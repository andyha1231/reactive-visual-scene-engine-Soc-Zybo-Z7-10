## zybo_z7_vga.xdc
## Pin constraints for Reactive Visual Scene Engine on Zybo Z7
## Uncomment and modify as needed based on your VGA PMOD connection.
##
## NOTE: If using the Zybo Z7's built-in VGA port (Z7-20 only),
## update pin assignments to match the board schematic.
## If using a VGA PMOD on JB/JC, use the PMOD pin mappings below.

## ========================================
## System Clock (125 MHz)
## ========================================
set_property -dict { PACKAGE_PIN K17   IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 8.000 -waveform {0.000 4.000} [get_ports { clk }];

## ========================================
## Buttons (active high)
## ========================================
set_property -dict { PACKAGE_PIN K18   IOSTANDARD LVCMOS33 } [get_ports { btn[0] }];
set_property -dict { PACKAGE_PIN P16   IOSTANDARD LVCMOS33 } [get_ports { btn[1] }];
set_property -dict { PACKAGE_PIN K19   IOSTANDARD LVCMOS33 } [get_ports { btn[2] }];
set_property -dict { PACKAGE_PIN Y16   IOSTANDARD LVCMOS33 } [get_ports { btn[3] }];

## ========================================
## Switches
## ========================================
set_property -dict { PACKAGE_PIN G15   IOSTANDARD LVCMOS33 } [get_ports { sw[0] }];
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { sw[1] }];
set_property -dict { PACKAGE_PIN W13   IOSTANDARD LVCMOS33 } [get_ports { sw[2] }];
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { sw[3] }];

## ========================================
## LEDs
## ========================================
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { led[3] }];

## ========================================
## VGA Output (via PMOD on JB + JC)
## Directly driving resistor-DAC VGA PMOD
## Adjust pin mappings to your specific PMOD connector
## ========================================
## VGA Red (4-bit)
# set_property -dict { PACKAGE_PIN V8    IOSTANDARD LVCMOS33 } [get_ports { vga_r[0] }];
# set_property -dict { PACKAGE_PIN W8    IOSTANDARD LVCMOS33 } [get_ports { vga_r[1] }];
# set_property -dict { PACKAGE_PIN U7    IOSTANDARD LVCMOS33 } [get_ports { vga_r[2] }];
# set_property -dict { PACKAGE_PIN V7    IOSTANDARD LVCMOS33 } [get_ports { vga_r[3] }];

## VGA Green (4-bit)
# set_property -dict { PACKAGE_PIN Y7    IOSTANDARD LVCMOS33 } [get_ports { vga_g[0] }];
# set_property -dict { PACKAGE_PIN Y6    IOSTANDARD LVCMOS33 } [get_ports { vga_g[1] }];
# set_property -dict { PACKAGE_PIN V6    IOSTANDARD LVCMOS33 } [get_ports { vga_g[2] }];
# set_property -dict { PACKAGE_PIN W6    IOSTANDARD LVCMOS33 } [get_ports { vga_g[3] }];

## VGA Blue (4-bit)
# set_property -dict { PACKAGE_PIN T5    IOSTANDARD LVCMOS33 } [get_ports { vga_b[0] }];
# set_property -dict { PACKAGE_PIN U5    IOSTANDARD LVCMOS33 } [get_ports { vga_b[1] }];
# set_property -dict { PACKAGE_PIN V5    IOSTANDARD LVCMOS33 } [get_ports { vga_b[2] }];
# set_property -dict { PACKAGE_PIN W5    IOSTANDARD LVCMOS33 } [get_ports { vga_b[3] }];

## VGA HSync
# set_property -dict { PACKAGE_PIN W12   IOSTANDARD LVCMOS33 } [get_ports { vga_hsync }];

## VGA VSync
# set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports { vga_vsync }];
