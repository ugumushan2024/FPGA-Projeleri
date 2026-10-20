## ============================================================================
## 1. 100 MHz Sistem Saati (CLK100MHZ)
## ============================================================================
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## ============================================================================
## 2. Reset Butonu (Aktif-Dusuk CPU_RESETN Kirmizi Buton)
## ============================================================================
set_property -dict { PACKAGE_PIN C12   IOSTANDARD LVCMOS33 } [get_ports { rst_n }];

## ============================================================================
## 3. PMOD JA - BMP280 SPI Arayuzu (Ust Sira Pin 1-4)
## ============================================================================
set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33 } [get_ports { spi_cs_n }]; # JA1 - CSB
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { spi_mosi }]; # JA2 - SDI (SDA)
set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS33 } [get_ports { spi_miso }]; # JA3 - SDO
set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { spi_sclk }]; # JA4 - SCK (SCL)

## ============================================================================
## 4. LED Cikislar (20-bit Verinin Ust 16 Biti -> LED15..LED0)
## ============================================================================
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[4] }];  # LED0
set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[5] }];  # LED1
set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[6] }];  # LED2
set_property -dict { PACKAGE_PIN N14   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[7] }];  # LED3
set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[8] }];  # LED4
set_property -dict { PACKAGE_PIN V17   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[9] }];  # LED5
set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[10] }]; # LED6
set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[11] }]; # LED7
set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[12] }]; # LED8
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[13] }]; # LED9
set_property -dict { PACKAGE_PIN U14   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[14] }]; # LED10
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[15] }]; # LED11
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[16] }]; # LED12
set_property -dict { PACKAGE_PIN V14   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[17] }]; # LED13
set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[18] }]; # LED14
set_property -dict { PACKAGE_PIN V11   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[19] }]; # LED15

## ============================================================================
## 5. Kalan Alt 4-Bit (XLSB) ve Data Valid Sinyali (RGB LED / PMOD JB'ye Atama)
## Vivado'nun Bitstream uretirken "Unconstrained Port" hatasi vermemesi icindir.
## ============================================================================
set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { data_valid }];       # LED16_G (Yesil RGB)
set_property -dict { PACKAGE_PIN D14   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[0] }];  # JB1
set_property -dict { PACKAGE_PIN F16   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[1] }];  # JB2
set_property -dict { PACKAGE_PIN G16   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[2] }];  # JB3
set_property -dict { PACKAGE_PIN H14   IOSTANDARD LVCMOS33 } [get_ports { temp_raw_out[3] }];  # JB4