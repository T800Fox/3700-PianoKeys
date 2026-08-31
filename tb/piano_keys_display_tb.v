/*
BASH verilator --binary --trace -Wall -j 0 --top-module piano_keys_display_tb piano_keys_display_tb.v piano_keys_display.v seven_seg.v
./obj_dir/Vpiano_keys_display_tb
gtkwave waveform.vcd
*/


`timescale 1ms/1us
module piano_keys_display_tb;
    reg  [6:0] score_value;
	 reg  [1:0] score_multi;
    reg  [3:0] lane_0_value, lane_1_value, lane_2_value, lane_3_value;
	 reg        lane_0_led;
	 reg        lane_1_led;
	 reg        lane_2_led;
	 reg        lane_3_led;
	 /* verilator lint_off UNUSEDSIGNAL */
    wire [6:0] lane_0_HEX, lane_1_HEX, lane_2_HEX, lane_3_HEX;
    wire [6:0] score_ones_HEX, score_tens_HEX;
	 wire [3:0] lane_leds;
	 wire [2:0] score_multi_leds;
 	 /* verilator lint_on UNUSEDSIGNAL */
	 integer i;

    piano_keys_display DUT (
        .score_value(score_value),
		  .score_multi(score_multi),
        .lane_0_value(lane_0_value),
        .lane_1_value(lane_1_value),
        .lane_2_value(lane_2_value),
        .lane_3_value(lane_3_value),
		  
		  .lane_0_led(lane_0_led),
		  .lane_1_led(lane_1_led),
		  .lane_2_led(lane_2_led),
		  .lane_3_led(lane_3_led),
		  
        .lane_0_HEX(lane_0_HEX),
        .lane_1_HEX(lane_1_HEX),
        .lane_2_HEX(lane_2_HEX),
        .lane_3_HEX(lane_3_HEX),
		  
		  .lane_leds(lane_leds),
		  
        .score_ones_HEX(score_ones_HEX),
        .score_tens_HEX(score_tens_HEX),
		  
		  .score_multi_leds(score_multi_leds)
    );

    initial begin
		  $dumpfile("waveform.vcd");
		  $dumpvars(0, piano_keys_display_tb);
	 
        lane_0_value = 0; lane_1_value = 0; lane_2_value = 0; lane_3_value = 0;
		  score_multi = 2'b11;
		  
		  
		  lane_0_led = 1;
		  #100;
		  lane_0_led = 0;
		  lane_1_led = 1;
		  #100;
		  lane_1_led = 0;
		  lane_2_led = 1;
		  #100;
		  lane_2_led = 0;
		  lane_3_led = 1;
		  #100;
		  lane_3_led = 0;
		  
		  #200;
		  score_multi = 2'b00;
		  #100;
		  score_multi = 2'b01;
		  #100;
		  score_multi = 2'b10;
		  #100;
		  score_multi = 2'b11;
		  #100;
		  score_multi = 2'b00;
		  
		  #200;
		  for (i = 0; i <= 110; i = i + 1) begin
				score_value = 7'(i);
				#100;
		  end
		  
		  for (i = 0; i < 12; i = i + 1)begin
				lane_0_value = 4'(i);
				lane_1_value = 4'(i);
				lane_2_value = 4'(i);
				lane_3_value = 4'(i);
				#500;
		  end
		  
        $finish;
    end
endmodule

