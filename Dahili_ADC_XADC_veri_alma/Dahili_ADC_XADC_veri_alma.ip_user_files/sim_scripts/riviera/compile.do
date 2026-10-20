transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib riviera/xil_defaultlib

vmap xil_defaultlib riviera/xil_defaultlib

vcom -work xil_defaultlib -93  -incr \
"../../../Dahili_ADC_XADC_veri_alma.srcs/sources_1/new/xadc__drp_master.vhd" \


