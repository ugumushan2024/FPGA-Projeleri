# 100 MHz Sistem Saati
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports {clk}];

# Reset (Test için en soldaki SW15 switch'ini kullanalım, butonların bounce etkisiyle uğraşmamak için)
set_property -dict { PACKAGE_PIN V10   IOSTANDARD LVCMOS33 } [get_ports { reset }]; 

# JXADC Pmod Portu Bağlantıları (Vaux4 Kanalı)
set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { vauxp4 }]; # JXADC Portu Pin 1
set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { vauxn4 }]; # JXADC Portu Pin 7 (GND hattının yanı)

# 12-Bit Veriyi Göstermek İçin LED'ler (LED 0'dan LED 11'e kadar)
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN N14   IOSTANDARD LVCMOS33 } [get_ports { led[3] }];
set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 } [get_ports { led[4] }];
set_property -dict { PACKAGE_PIN V17   IOSTANDARD LVCMOS33 } [get_ports { led[5] }];
set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports { led[6] }];
set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS33 } [get_ports { led[7] }];
set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports { led[8] }];
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS33 } [get_ports { led[9] }];
set_property -dict { PACKAGE_PIN U14   IOSTANDARD LVCMOS33 } [get_ports { led[10] }];
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { led[11] }];