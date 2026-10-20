vlib questa_lib/work
vlib questa_lib/msim

vlib questa_lib/msim/xil_defaultlib

vmap xil_defaultlib questa_lib/msim/xil_defaultlib

vcom -work xil_defaultlib  -93  \
"../../../Dahili_ADC_XADC_veri_alma.srcs/sources_1/new/xadc__drp_master.vhd" \


