// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2026.1 (win64) Build 6511674 Tue Jun 16 11:02:23 MDT 2026
// Date        : Sat Oct 10 21:08:51 2026
// Host        : xae running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub -rename_top decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix -prefix
//               decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_ xadc_wiz_0_stub.v
// Design      : xadc_wiz_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tcsg324-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* CORE_GENERATION_INFO = "xadc_wiz_0,xadc_wiz_v3_3_15,{component_name=xadc_wiz_0,enable_axi=false,enable_axi4stream=false,dclk_frequency=100,enable_busy=true,enable_convst=false,enable_convstclk=false,enable_dclk=true,enable_drp=true,enable_eoc=true,enable_eos=true,enable_vbram_alaram=true,enable_vccddro_alaram=false,enable_Vccint_Alaram=true,enable_Vccaux_alaram=true,enable_vccpaux_alaram=false,enable_vccpint_alaram=false,ot_alaram=true,user_temp_alaram=true,timing_mode=continuous,channel_averaging=None,sequencer_mode=off,startup_channel_selection=single_channel}" *) 
module decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix(daddr_in, dclk_in, den_in, di_in, dwe_in, reset_in, 
  vauxp4, vauxn4, busy_out, channel_out, do_out, drdy_out, eoc_out, eos_out, ot_out, 
  vccaux_alarm_out, vccint_alarm_out, user_temp_alarm_out, vbram_alarm_out, alarm_out, vp_in, 
  vn_in)
/* synthesis syn_black_box black_box_pad_pin="daddr_in[6:0],den_in,di_in[15:0],dwe_in,reset_in,vauxp4,vauxn4,busy_out,channel_out[4:0],do_out[15:0],drdy_out,eoc_out,eos_out,ot_out,vccaux_alarm_out,vccint_alarm_out,user_temp_alarm_out,vbram_alarm_out,alarm_out,vp_in,vn_in" */
/* synthesis syn_force_seq_prim="dclk_in" */;
  input [6:0]daddr_in;
  input dclk_in /* synthesis syn_isclock = 1 */;
  input den_in;
  input [15:0]di_in;
  input dwe_in;
  input reset_in;
  input vauxp4;
  input vauxn4;
  output busy_out;
  output [4:0]channel_out;
  output [15:0]do_out;
  output drdy_out;
  output eoc_out;
  output eos_out;
  output ot_out;
  output vccaux_alarm_out;
  output vccint_alarm_out;
  output user_temp_alarm_out;
  output vbram_alarm_out;
  output alarm_out;
  input vp_in;
  input vn_in;
endmodule
