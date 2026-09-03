module piano_keys_display (
    input  [6:0] score_value, // {0 <= x <= 99}
	 input  [1:0] score_multi, // {00, 01, 10}
	 input  [3:0] lane_0_value,
	 input  [3:0] lane_1_value,
	 input  [3:0] lane_2_value,
	 input  [3:0] lane_3_value,
	 input lane_0_led,
	 input lane_1_led,
	 input lane_2_led,
	 input lane_3_led,
	 input 	[2:0] difficulty_level,
	 
	 output [6:0] score_ones_HEX,
	 output [6:0] score_tens_HEX,
	 output [2:0] score_multi_leds,
	 output [6:0] lane_0_HEX,
	 output [6:0] lane_1_HEX,
	 output [6:0] lane_2_HEX,
	 output [6:0] lane_3_HEX,
	 output [3:0] lane_leds,
	 output [2:0] difficulty_leds
);

	reg [3:0] ones_segment_value;
	reg [3:0] tens_segment_value;
	
	reg [3:0] lane_leds_buffer;
	reg [2:0] score_multi_leds_buffer;
	
	seven_seg seven_seg_l0 (
		.bcd(lane_0_value),
		.segments(lane_0_HEX)
	);
	seven_seg seven_seg_l1 (
		.bcd(lane_1_value),
		.segments(lane_1_HEX)
	);
	seven_seg seven_seg_l2 (
		.bcd(lane_2_value),
		.segments(lane_2_HEX)
	);
	seven_seg seven_seg_l3 (
		.bcd(lane_3_value),
		.segments(lane_3_HEX)
	);

	seven_seg seven_seg_s0 (
		.bcd(ones_segment_value),
		.segments(score_ones_HEX)
	);
	seven_seg seven_seg_s1 (
		.bcd(tens_segment_value),
		.segments(score_tens_HEX)
	);
	
	
	
	initial begin
		// turn off score displays @ init
		ones_segment_value = 10;
		tens_segment_value = 10;
		
		// turn off lane and score multi leds
		lane_leds_buffer = {1'b0, 1'b0, 1'b0, 1'b0};
		score_multi_leds_buffer = {1'b0, 1'b0, 1'b0};
	end
	
	
	// --- Score Display Logic ---
	/* verilator lint_off WIDTHTRUNC */
	always @(score_value) begin
		if (score_value > 99) begin
			// lowest overflow value
			ones_segment_value = 11;	
			tens_segment_value = 11;
		end
		else begin
			ones_segment_value = (score_value % 10);
			tens_segment_value = ((score_value - score_value % 10) / 10);
		end
	end
	/* verilator lint_on WIDTHTRUNC */
	
	
	// --- Lane LED Logic ---
	always @(lane_0_led) begin
		lane_leds_buffer[0] = lane_0_led;
	end
	always @(lane_1_led) begin
		lane_leds_buffer[1] = lane_1_led;
	end
	always @(lane_2_led) begin
		lane_leds_buffer[2] = lane_2_led;
	end
	always @(lane_3_led) begin
		lane_leds_buffer[3] = lane_3_led;
	end
	
	
	// --- Score Multiplier Display Logic ---
	always @(*) begin
		case(score_multi)
			2'b00: score_multi_leds_buffer = {1'b1, 1'b0, 1'b0};
			2'b01: score_multi_leds_buffer = {1'b0, 1'b1, 1'b0};
			2'b10: score_multi_leds_buffer = {1'b0, 1'b0, 1'b1};
			default: score_multi_leds_buffer = {1'b0, 1'b0, 1'b0};
		endcase
	end 
	
	assign difficulty_leds = (difficulty_level == 2'd0) ? 3'b001 :
        (difficulty_level == 2'd1) ? 3'b010 : 3'b100;

	assign lane_leds = lane_leds_buffer;
	assign score_multi_leds = score_multi_leds_buffer;
	
endmodule
