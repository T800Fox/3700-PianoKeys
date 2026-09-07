module rng #(
    parameter [9:0] SEED = 10'd17
) (
    input clk,
    input [3:0] range_lower,
    input [3:0] range_upper,

    output reg [3:0] random_val,
    output reg output_valid
);

    reg [10:1] lfsr;

    wire feedback;
    wire [3:0] raw_value;

    reg [4:0] range;
    reg [4:0] greatest_mult;
    reg [3:0] remainder;

    initial lfsr = SEED;

    assign feedback = lfsr[10] ^ lfsr[7];
    assign raw_value = lfsr[4:1];

    always @(*) begin
        range = {1'b0, range_upper} -
                {1'b0, range_lower} + 5'd1;

        greatest_mult = 5'd0;
        remainder = 4'd0;

        case (range)

            5'd1: begin
                greatest_mult = 5'd16;
                remainder = 4'd0;
            end

            5'd2: begin
                greatest_mult = 5'd16;
                remainder = {3'b000, raw_value[0]};
            end

            5'd3: begin
                greatest_mult = 5'd15;
                if (raw_value >= 4'd12)
                    remainder = raw_value - 4'd12;
                else if (raw_value >= 4'd9)
                    remainder = raw_value - 4'd9;
                else if (raw_value >= 4'd6)
                    remainder = raw_value - 4'd6;
                else if (raw_value >= 4'd3)
                    remainder = raw_value - 4'd3;
                else
                    remainder = raw_value;
            end

            5'd4: begin
                greatest_mult = 5'd16;
                remainder = {2'b00, raw_value[1:0]};
            end

            5'd5: begin
                greatest_mult = 5'd15;
                if (raw_value >= 4'd10)
                    remainder = raw_value - 4'd10;
                else if (raw_value >= 4'd5)
                    remainder = raw_value - 4'd5;
                else
                    remainder = raw_value;
            end

            5'd6: begin
                greatest_mult = 5'd12;
                remainder =
                    (raw_value >= 4'd6) ?
                    raw_value - 4'd6 :
                    raw_value;
            end

            5'd7: begin
                greatest_mult = 5'd14;
                remainder =
                    (raw_value >= 4'd7) ?
                    raw_value - 4'd7 :
                    raw_value;
            end

            5'd8: begin
                greatest_mult = 5'd16;
                remainder = {1'b0, raw_value[2:0]};
            end

            5'd9: begin
                greatest_mult = 5'd9;
                remainder = raw_value;
            end

            5'd10: begin
                greatest_mult = 5'd10;
                remainder = raw_value;
            end

            5'd11: begin
                greatest_mult = 5'd11;
                remainder = raw_value;
            end

            5'd12: begin
                greatest_mult = 5'd12;
                remainder = raw_value;
            end

            5'd13: begin
                greatest_mult = 5'd13;
                remainder = raw_value;
            end

            5'd14: begin
                greatest_mult = 5'd14;
                remainder = raw_value;
            end

            5'd15: begin
                greatest_mult = 5'd15;
                remainder = raw_value;
            end

            5'd16: begin
                greatest_mult = 5'd16;
                remainder = raw_value;
            end

            default: begin
                greatest_mult = 5'd0;
                remainder = 4'd0;
            end

        endcase

        output_valid = 1'b0;
        random_val = 4'd0;

        if (
            range >= 5'd1 &&
            range <= 5'd16 &&
            {1'b0, raw_value} < greatest_mult
        ) begin
            random_val = remainder + range_lower;
            output_valid = 1'b1;
        end
    end

    always @(posedge clk) begin
        lfsr <= {lfsr[9:1], feedback};
    end

endmodule
