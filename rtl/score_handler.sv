
module score_handler #(
    parameter MAX_SCORE = 99,
    parameter CONSEC_PERFECT_FOR_MOVE_TO_X2 = 2,
    parameter CONSEC_PERFECT_FOR_MOVE_TO_X4 = 4
) (
    input logic clk,
    input logic rst,

    input logic l_0_quality_valid,
    input logic [1:0] l_0_quality_value,

    input logic l_1_quality_valid,
    input logic [1:0] l_1_quality_value,

    input logic l_2_quality_valid,
    input logic [1:0] l_2_quality_value,

    input logic l_3_quality_valid,
    input logic [1:0] l_3_quality_value,

    output logic [$clog2(MAX_SCORE)-1:0] score,
    output logic [1:0] curr_multi_state
);

    localparam logic [1:0] QUALITY_PERFECT = 2'b00;
    localparam logic [1:0] QUALITY_NORMAL  = 2'b01;
    localparam logic [1:0] QUALITY_POOR    = 2'b10;
    localparam logic [1:0] QUALITY_BAD     = 2'b11;

    logic quality_valid;
    logic [1:0] quality_value;

    logic [2:0] multiplier;


    score_multiplier_fsm #(
        .CONSEC_PERFECT_TO_2(
            CONSEC_PERFECT_FOR_MOVE_TO_X2
        ),
        .CONSEC_PERFECT_TO_4(
            CONSEC_PERFECT_FOR_MOVE_TO_X4
        )
    ) u_multi_fsm (
        .clk(clk),
        .rst(rst),

        .reaction_valid(quality_valid),
        .reaction_quality(quality_value),

        .current_multiplier(multiplier),
        .enc_curr_state(curr_multi_state)
    );


    initial begin
        score = 0;
    end


    always_comb begin

        quality_valid =
            l_0_quality_valid |
            l_1_quality_valid |
            l_2_quality_valid |
            l_3_quality_valid;

        priority casez ({
            l_0_quality_valid,
            l_1_quality_valid,
            l_2_quality_valid,
            l_3_quality_valid
        })

            4'b1???:
                quality_value = l_0_quality_value;

            4'b01??:
                quality_value = l_1_quality_value;

            4'b001?:
                quality_value = l_2_quality_value;

            4'b0001:
                quality_value = l_3_quality_value;

            default:
                quality_value = QUALITY_NORMAL;

        endcase
    end


    always_ff @(posedge clk) begin

        if (rst) begin

            score <= 0;

        end
        else if (quality_valid) begin

            case (quality_value)

                QUALITY_PERFECT: begin

                    if (
                        score >=
                        MAX_SCORE - multiplier
                    )
                        score <= MAX_SCORE;
                    else
                        score <=
                            score + multiplier;

                end


                QUALITY_NORMAL: begin

                    if (score >= MAX_SCORE)
                        score <= MAX_SCORE;
                    else
                        score <= score + 1;

                end


                QUALITY_BAD: begin

                    if (score == 0)
                        score <= 0;
                    else
                        score <= score - 1;

                end


                QUALITY_POOR: begin
                    score <= score;
                end


                default: begin
                    score <= score;
                end

            endcase
        end
    end

endmodule
