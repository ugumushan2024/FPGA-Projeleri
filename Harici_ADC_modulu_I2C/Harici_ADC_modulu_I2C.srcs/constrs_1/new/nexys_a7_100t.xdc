## ============================================================================
## 1. Saat Sinyali (100 MHz On-Board Kristal Osilatör)
## ============================================================================
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## ============================================================================
## 2. Reset Butonu (Kırmızı "CPU RESET" Butonu - Aktif Düşük)
## ============================================================================
set_property -dict { PACKAGE_PIN C12   IOSTANDARD LVCMOS33 } [get_ports { rst_n }];

## ============================================================================
## 3. Pmod Header JA (I2C SDA ve SCL Hatları)
## JA[1] (Pin C17) -> SDA
## JA[2] (Pin D18) -> SCL
## ============================================================================
set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33   PULLUP true } [get_ports { i2c_sda }];
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33   PULLUP true } [get_ports { i2c_scl }];

## ============================================================================
## 4. 16-Bit Ham ADC Çıkış LED'leri (LED0 .. LED15)
## ============================================================================
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { adc_led[0] }];
set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports { adc_led[1] }];
set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports { adc_led[2] }];
set_property -dict { PACKAGE_PIN N14   IOSTANDARD LVCMOS33 } [get_ports { adc_led[3] }];
set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 } [get_ports { adc_led[4] }];
set_property -dict { PACKAGE_PIN V17   IOSTANDARD LVCMOS33 } [get_ports { adc_led[5] }];
set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports { adc_led[6] }];
set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS33 } [get_ports { adc_led[7] }];
set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports { adc_led[8] }];
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS33 } [get_ports { adc_led[9] }];
set_property -dict { PACKAGE_PIN U14   IOSTANDARD LVCMOS33 } [get_ports { adc_led[10] }];
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { adc_led[11] }];
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports { adc_led[12] }];
set_property -dict { PACKAGE_PIN V14   IOSTANDARD LVCMOS33 } [get_ports { adc_led[13] }];
set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports { adc_led[14] }];
set_property -dict { PACKAGE_PIN V11   IOSTANDARD LVCMOS33 } [get_ports { adc_led[15] }];

## ============================================================================
## 5. Durum ve Hata Gösterge LED'leri (RGB LED 16 Kırmızı & RGB LED 17 Yeşil)
## ============================================================================
set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { ack_err_led }];
set_property -dict { PACKAGE_PIN R11   IOSTANDARD LVCMOS33 } [get_ports { busy_led }];