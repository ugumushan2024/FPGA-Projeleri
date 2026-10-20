transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib activehdl/xil_defaultlib

vmap xil_defaultlib activehdl/xil_defaultlib

vcom -work xil_defaultlib -93  \
"../../../Dahili_ADC_XADC_veri_alma.srcs/sources_1/new/xadc__drp_master.vhd" \


