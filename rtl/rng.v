

module rng #(
    parameter SEED = 17
) (
    input clk,
    input [3:0] range_lower,
    input [3:0] range_upper,

    output reg [3:0] random_val,
    output reg output_valid //Flag for whether result is valid (rejection sampling may mean generation takes mpultiple ticks)
);

    wire [4:0] range;
    wire [4:0] greatest_mult;

    assign range = range_upper - range_lower + 1;
    assign greatest_mult = (16/range) * range; 

    reg [10:1] lfsr; // The 4-bit Linear Feedback Shift Register. 

    // Initialise the shift reg to SEED, which should be a non-zero value:
    initial lfsr = SEED;

    // Set the feedback:
    wire feedback;
    assign feedback = lfsr[10] ^ lfsr[7];

    // Put shift register logic here (use an always @(posedge clk) block):
    //    Make sure to shift left from bit 1 (LSB) towards bit 10 (MSB).


    always @(*) begin
        //Make sure output is marked invalid
        output_valid = 0;
        random_val = 0;

        if ({1'b0, lfsr[4:1]} < greatest_mult) begin
            random_val = lfsr[4:1] % range[3:0] + range_lower;
            output_valid = 1;
        end
        
    end

    // Your code here!
    always @(posedge clk) begin
        lfsr <= {lfsr[9:1], feedback};        
    end


endmodule
