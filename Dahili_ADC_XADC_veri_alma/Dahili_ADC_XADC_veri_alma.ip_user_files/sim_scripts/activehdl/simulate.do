transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

asim +access +r +m+xadc__drp_master  -L xil_defaultlib -L secureip -O5 xil_defaultlib.xadc__drp_master

do {xadc__drp_master.udo}

run 1000ns

endsim

quit -force
