module score_handler #(
	parameter MAX_SCORE=99
) (
	input logic			clk, rst,
	input logic			l_0_quality_valid,
	input logic [1:0] l_0_quality_value,
	
	input logic			l_1_quality_valid,
	input logic [1:0] l_1_quality_value,
	
	input logic			l_2_quality_valid,
	input logic [1:0] l_2_quality_value,
	
	input logic			l_3_quality_valid,
	input logic [1:0] l_3_quality_value,
	
	output reg [$clog2(MAX_SCORE)-1:0] score,
	output reg  [1:0] curr_multi_state
);
	localparam logic [1:0] QUALITY_PERFECT = 2'b00;
	localparam logic [1:0] QUALITY_NORMAL  = 2'b01;
   	// localparam logic [1:0] QUALITY_POOR    = 2'b10;
   	localparam logic [1:0] QUALITY_BAD     = 2'b11;
	
	logic 			multi_fsm_quality_valid;
	logic 	[1:0] 	multi_fsm_quality_input;
	logic 	[2:0] 	multi_fsm_multiplier;
	

	score_multiplier_fsm multi_fsm (
		.clk(clk),
		.rst(rst),
		.reaction_valid(multi_fsm_quality_valid),
		.reaction_quality(multi_fsm_quality_input),
		.current_multiplier(multi_fsm_multiplier),
		.enc_curr_state(curr_multi_state)
	);
	

	initial begin
		score = 0;
	end
	
	always_comb begin : demuxLaneQualitySignals
		multi_fsm_quality_valid = l_0_quality_valid | l_1_quality_valid | l_2_quality_valid | l_3_quality_valid;

		priority casez ({l_0_quality_valid, l_1_quality_valid, l_2_quality_valid,  l_3_quality_valid})
			4'b1???: multi_fsm_quality_input = l_0_quality_value;
			4'b01??: multi_fsm_quality_input = l_1_quality_value;
			4'b001?: multi_fsm_quality_input = l_2_quality_value;
			4'b0001: multi_fsm_quality_input = l_3_quality_value;
			default: multi_fsm_quality_input = QUALITY_NORMAL; 
		endcase
	end

	// PERFECT	-> add to score w/ multiplier @ enforce ceil of MAX_SCORE
	// NORMAL 	-> add to score w/ multiplier @ enforce ceil of MAX_SCORE
	// POOR		-> no change to score
	// BAD		-> remove 1 from score @ enforce floor of 0
	always_ff @(posedge clk) begin : scoreUpdateLogic
		if (rst) score <= 0;

		if (multi_fsm_quality_valid) begin			
			if (multi_fsm_quality_input == QUALITY_PERFECT || multi_fsm_quality_input == QUALITY_NORMAL) begin
				score <= (score + 1 * multi_fsm_multiplier >= MAX_SCORE) ? MAX_SCORE : score + 1 * multi_fsm_multiplier;
			end
			else if (multi_fsm_quality_input == QUALITY_BAD) begin
				score <= (score == 0) ? 0 : score - 1;
			end
			else score <= score;
		end
	end

endmodule
