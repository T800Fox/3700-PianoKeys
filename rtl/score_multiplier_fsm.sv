
module score_multiplier_fsm #(
    parameter CONSEC_PERFECT_TO_2 = 2,
    parameter CONSEC_PERFECT_TO_4 = 4
) (
    input logic rst,
    input logic clk,

    input logic reaction_valid,
    input logic [1:0] reaction_quality,

    output logic [2:0] current_multiplier,
    output logic [1:0] enc_curr_state
);

    localparam logic [1:0] QUALITY_PERFECT = 2'b00;
    localparam logic [1:0] QUALITY_NORMAL  = 2'b01;
    localparam logic [1:0] QUALITY_POOR    = 2'b10;
    localparam logic [1:0] QUALITY_BAD     = 2'b11;

    typedef enum logic [1:0] {
        X1,
        X2,
        X4
    } state_type;

    state_type current_state;

    logic [2:0] consecutive_perfect;


    initial begin
        current_state = X1;
        consecutive_perfect = 0;
    end


    always_ff @(posedge clk) begin

        if (rst) begin

            current_state <= X1;
            consecutive_perfect <= 0;

        end
        else if (reaction_valid) begin

            case (current_state)

                X1: begin

                    if (reaction_quality == QUALITY_PERFECT) begin

                        if (
                            consecutive_perfect + 1
                            >=
                            CONSEC_PERFECT_TO_2
                        ) begin

                            current_state <= X2;
                            consecutive_perfect <= 0;

                        end
                        else begin

                            consecutive_perfect <=
                                consecutive_perfect + 1;

                        end

                    end
                    else begin

                        consecutive_perfect <= 0;

                    end
                end


                X2: begin

                    if (reaction_quality == QUALITY_PERFECT) begin

                        if (
                            consecutive_perfect + 1
                            >=
                            CONSEC_PERFECT_TO_4
                        ) begin

                            current_state <= X4;
                            consecutive_perfect <= 0;

                        end
                        else begin

                            consecutive_perfect <=
                                consecutive_perfect + 1;

                        end

                    end
                    else if (
                        reaction_quality == QUALITY_POOR ||
                        reaction_quality == QUALITY_BAD
                    ) begin

                        current_state <= X1;
                        consecutive_perfect <= 0;

                    end
                    else begin

                        // NORMAL: accurate enough to retain multiplier,
                        // but it breaks the perfect streak.
                        consecutive_perfect <= 0;

                    end
                end


                X4: begin

                    consecutive_perfect <= 0;

                    if (
                        reaction_quality == QUALITY_POOR ||
                        reaction_quality == QUALITY_BAD
                    )
                        current_state <= X1;

                end


                default: begin
                    current_state <= X1;
                    consecutive_perfect <= 0;
                end

            endcase
        end
    end


    // Moore-style multiplier output.
    always_comb begin

        case (current_state)

            X1: begin
                current_multiplier = 3'd1;
                enc_curr_state = 2'b00;
            end

            X2: begin
                current_multiplier = 3'd2;
                enc_curr_state = 2'b01;
            end

            X4: begin
                current_multiplier = 3'd4;
                enc_curr_state = 2'b10;
            end

            default: begin
                current_multiplier = 3'd1;
                enc_curr_state = 2'b00;
            end

        endcase
    end

endmodule
