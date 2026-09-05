module score_multiplier_fsm #(
	parameter CONSEC_PERFECT_TO_2=2,
	parameter CONSEC_PERFECT_TO_4=4
) (
	input rst, clk,
	input logic 	 	reaction_valid,
	input logic [1:0] reaction_quality,
	output logic [2:0] current_multiplier,
	output reg	[1:0]	enc_curr_state
);
	localparam logic [1:0] QUALITY_PERFECT = 2'b00;
	localparam logic [1:0] QUALITY_NORMAL  = 2'b01;
   	localparam logic [1:0] QUALITY_POOR    = 2'b10;
   	localparam logic [1:0] QUALITY_BAD     = 2'b11;

	typedef enum logic [1:0] {
        X1=2'b00, 
        X2=2'b01, 
        X4=2'b11
    } state_type;
	state_type current_state;
	
	logic [2:0] c_consecutive_perfect;
	
	initial begin
		current_state = X1;
	end
	
	 always_ff @(posedge clk) begin : state_transition_logic
        if (rst) begin
            c_consecutive_perfect <= 0;
            current_state         <= X1;
        end
        else if (reaction_valid) begin
            case (current_state)
                X1: begin
                    case (reaction_quality)
                        QUALITY_PERFECT: begin
                            if (c_consecutive_perfect + 1 == CONSEC_PERFECT_TO_2) begin
                                current_state         <= X2;
                                c_consecutive_perfect <= 0;
                            end
                            else begin
                                c_consecutive_perfect <= c_consecutive_perfect + 1;
                            end
                        end
                        default: c_consecutive_perfect <= 0;
                    endcase
                end

                X2: begin
                    case (reaction_quality)
                        QUALITY_PERFECT: begin
                            if (c_consecutive_perfect + 1 == CONSEC_PERFECT_TO_4) begin
                                current_state         <= X4;
                                c_consecutive_perfect <= 0;
                            end
                            else begin
                                c_consecutive_perfect <= c_consecutive_perfect + 1;
                            end
                        end
                        QUALITY_NORMAL: c_consecutive_perfect <= 0;
                        QUALITY_POOR, QUALITY_BAD: begin
                            current_state         <= X1;
                            c_consecutive_perfect <= 0;
                        end
                    endcase
                end

                X4: begin
                    c_consecutive_perfect <= 0;
                    if (reaction_quality == QUALITY_POOR || reaction_quality == QUALITY_BAD)
                        current_state <= X1;
                end

                default: begin
                    current_state         <= X1;
                    c_consecutive_perfect <= 0;
                end
            endcase
        end
    end
	

	// set current multiplier based on state
    always_comb begin
        unique case (current_state)
            X1: begin
                enc_curr_state     = 2'b00;
                current_multiplier = 1;
            end
            X2: begin
                enc_curr_state     = 2'b01;
                current_multiplier = 2;
            end
            X4: begin
                enc_curr_state     = 2'b10;
                current_multiplier = 4;
            end
            default: begin
                enc_curr_state     = 2'b00;
                current_multiplier = 1;
            end
        endcase
    end
	
endmodule

