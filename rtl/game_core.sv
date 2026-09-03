module game_core #(
    parameter COUNTDOWN_WIDTH    = 4,
    parameter MS_PER_SUBBEAT     = 83,
    parameter SUBBEATS_PER_BEAT  = 6,
    parameter CLKS_PER_MS        = 50000,
    parameter WINDOW_HALF_TICKS  = 3,
    parameter PERFECT_START_TICK = 5,
    parameter PERFECT_END_TICK   = 7,
    parameter HIT_FLASH_TICKS    = 4
) (
    input  logic clk,
    input  logic reset,
    input  logic [3:0] press_pulse,
    input  logic [3:0] spawn,

    // four 4 bit countdown values packed together
    // lane 0 = bits 3:0
    // lane 1 = bits 7:4
    // lane 2 = bits 11:8
    // lane 3 = bits 15:12
    input  logic [(4*COUNTDOWN_WIDTH)-1:0] spawn_countdown,

    output logic [3:0] display_active,
    output logic [(4*COUNTDOWN_WIDTH)-1:0] display_value,

    // two quality bits per lane
    output logic [7:0] hit_quality,
    output logic [3:0] quality_valid,

    output logic [3:0] hit_led,

    // expose for future modules??
    output logic beat_tick,
    output logic subbeat_tick
);
    //shared timing generator
    beat_gen #(
        .MS_PER_SUBBEAT(MS_PER_SUBBEAT),
        .SUBBEATS_PER_BEAT(SUBBEATS_PER_BEAT),
        .CLKS_PER_MS(CLKS_PER_MS)
    ) u_beat_gen (
        .clk(clk),
        .reset(reset),
        .beat_tick(beat_tick),
        .subbeat_tick(subbeat_tick)
    );
    //fFour independent piano tiles lanes

    genvar i;

    generate
        for (i = 0; i < 4; i = i + 1) begin : GEN_LANES

            lane_fsm #(
                .COUNTDOWN_WIDTH(COUNTDOWN_WIDTH),
                .SUBBEATS_PER_BEAT(SUBBEATS_PER_BEAT),
                .WINDOW_HALF_TICKS(WINDOW_HALF_TICKS),
                .PERFECT_START_TICK(PERFECT_START_TICK),
                .PERFECT_END_TICK(PERFECT_END_TICK),
                .HIT_FLASH_TICKS(HIT_FLASH_TICKS)
            ) u_lane (
                .clk(clk),
                .reset(reset),

                .beat_tick(beat_tick),
                .subbeat_tick(subbeat_tick),

                .press_pulse(press_pulse[i]),
                .spawn(spawn[i]),

                .spawn_countdown(
                    spawn_countdown[
                        i*COUNTDOWN_WIDTH +: COUNTDOWN_WIDTH
                    ]
                ),
                .display_value(
                    display_value[
                        i*COUNTDOWN_WIDTH +: COUNTDOWN_WIDTH
                    ]
                ),

                .hit_quality(
                    hit_quality[i*2 +: 2]
                ),

                .quality_valid(quality_valid[i]),
                .hit_led(hit_led[i])
            );

        end
    endgenerate

    // New lane_fsm encodes an inactive/blank lane as value 10.
    // Keep display_active here for backwards compatibility with tb_game_core.
    assign display_active[0] =
        (display_value[0*COUNTDOWN_WIDTH +: COUNTDOWN_WIDTH] != 4'd10);
    assign display_active[1] =
        (display_value[1*COUNTDOWN_WIDTH +: COUNTDOWN_WIDTH] != 4'd10);
    assign display_active[2] =
        (display_value[2*COUNTDOWN_WIDTH +: COUNTDOWN_WIDTH] != 4'd10);
    assign display_active[3] =
        (display_value[3*COUNTDOWN_WIDTH +: COUNTDOWN_WIDTH] != 4'd10);

endmodule
