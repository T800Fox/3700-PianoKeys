// Conditions SW0 into a held reset level without requiring a reset input.
module switch_conditioner #(
    parameter RELEASE_COUNTS = 2500
) (
    input  logic clk,
    input  logic switch,
    output logic switch_state
);

    localparam COUNT_WIDTH =
        (RELEASE_COUNTS <= 1) ? 1 : $clog2(RELEASE_COUNTS);

    logic switch_q0, switch_q1;
    logic [COUNT_WIDTH-1:0] release_count;

    // Quartus implements these as FPGA register power-up values. They also
    // prevent unknown reset state before SW0 has been operated in simulation.
    initial begin
        switch_q0    = 1'b0;
        switch_q1    = 1'b0;
        release_count = '0;
        switch_state = 1'b0;
    end

    // Assert immediately; release through two clocked synchroniser stages.
    always @(posedge clk or posedge switch) begin
        if (switch) begin
            switch_q0 <= 1'b1;
            switch_q1 <= 1'b1;
        end
        else begin
            switch_q0 <= 1'b0;
            switch_q1 <= switch_q0;
        end
    end

    // A bouncing release restarts the stable-low interval.
    always @(posedge clk or posedge switch) begin
        if (switch) begin
            release_count <= '0;
            switch_state  <= 1'b1;
        end
        else if (switch_q1) begin
            release_count <= '0;
        end
        else if (release_count >= RELEASE_COUNTS - 1) begin
            release_count <= '0;
            switch_state  <= 1'b0;
        end
        else begin
            release_count <= release_count + 1'b1;
        end
    end

endmodule
