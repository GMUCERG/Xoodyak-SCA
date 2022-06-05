#Purpose : XDC file for CW305 target board to connect to FOBOS Shield 20-pin connector
#Author : Abubakr Abdulgadir
#Date : 3/25/2021
#Note make sure that the xdc file in pynq board is pynq_cw305_half_duplex.xdc

#CW305 20-pin connector pin map
#+----------+----------+-------------+-------------+-------------+----------+----------+----------+----------+----------+
#|   GND  19|   GND  17|           15|     R15   13|      P15  11|         9|    N16  7|         5|    3V3  3|     5V  1|
#|          |          |             |handshake_d2c|handshake_c2d|          |        io|          |          |          |
#+----------+----------+-------------+-------------+-------------+----------+----------+----------+----------+----------+
#|    5V  20|   3V3  18|     T14   16|     T15   14|    R16    12|   P16  10|         8|   N14   6|    M16  4|    GND  2|
#|          |          |         dio3|         dio2|         dio1|      dio0|          |   clk_c2d|  d_rst   |          |
#+----------+----------+-------------+-------------+-------------+----------+----------+----------+----------+----------+

#clock
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports clk_c2d]
create_clock -period 50.000 -name sys_clk [get_ports clk_c2d]

#handshake
set_property -dict { PACKAGE_PIN N16    IOSTANDARD LVCMOS33 } [get_ports { io }];
set_property -dict { PACKAGE_PIN M16    IOSTANDARD LVCMOS33 } [get_ports { d_rst }];
set_property -dict { PACKAGE_PIN P15    IOSTANDARD LVCMOS33 } [get_ports { handshake_c2d }];
set_property -dict { PACKAGE_PIN R15    IOSTANDARD LVCMOS33 } [get_ports { handshake_d2c }];

#data
set_property -dict { PACKAGE_PIN P16    IOSTANDARD LVCMOS33 } [get_ports { dio[0] }];
set_property -dict { PACKAGE_PIN R16    IOSTANDARD LVCMOS33 } [get_ports { dio[1] }];
set_property -dict { PACKAGE_PIN T15    IOSTANDARD LVCMOS33 } [get_ports { dio[2] }];
set_property -dict { PACKAGE_PIN T14    IOSTANDARD LVCMOS33 } [get_ports { dio[3] }];

#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_IBUF]
