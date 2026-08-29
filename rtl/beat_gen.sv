module beat_gen #(
    parameter MS_PER_SUBBEAT = 83,
    parameter SUBBEATS_PER_BEAT = 6,
    parameter CLKS_PER_MS = 50000
)
(
    input  logic clk,
    input  logic reset,

    output logic beat_tick,
    output logic subbeat_tick
);

    logic [10:0] timer_value;
    logic timer_reset;

    logic [$clog2(SUBBEATS_PER_BEAT)-1:0] subbeat_count;


    assign timer_reset =
        reset || (timer_value >= MS_PER_SUBBEAT - 1);


    timer #(
        .CLKS_PER_MS(CLKS_PER_MS)
        ) 
        
    u_timer (
        .clk(clk),
        .reset(timer_reset),
        .up(1'b1),
        .start_value(11'd0),
        .enable(1'b1),
        .timer_value(timer_value)
    );


    always_ff @(posedge clk) begin

        if (reset) begin

            subbeat_count <= 0;
            subbeat_tick  <= 0;
            beat_tick     <= 0;

        end 
        else begin

            subbeat_tick <= 0;
            beat_tick    <= 0;

            if (timer_value >= MS_PER_SUBBEAT - 1) begin

                subbeat_tick <= 1;

                if (subbeat_count >= SUBBEATS_PER_BEAT - 1) begin
                    subbeat_count <= 0;
                    beat_tick     <= 1;
                end else begin
                    subbeat_count <= subbeat_count + 1'b1;
                end

            end

        end

    end

endmodule