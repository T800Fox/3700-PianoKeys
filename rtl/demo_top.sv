// demo_top.sv, scaffold demo top level.

/*
    Module 'demo_top'

    Building off Aditya's code in game_core.sv...
    I've had a crack at integrating in the display driver and the score 
    handler modules. 

    When it comes to a point that we can start testing stuff on the board,
    I feel like the shout will be to comment out a lot of this stuff and 
    then slowly build it up?
    
*/

module demo_top #(
    parameter COUNTDOWN_WIDTH    = 4,
    parameter MS_PER_SUBBEAT     = 83,
    parameter SUBBEATS_PER_BEAT  = 6,
    parameter CLKS_PER_MS        = 50000,
    parameter WINDOW_HALF_TICKS  = 3,
    parameter PERFECT_START_TICK = 5,
    parameter PERFECT_END_TICK   = 7,
    parameter HIT_FLASH_TICKS    = 4,
    parameter MAX_SCORE          = 99
) (
    input  logic       CLOCK_50,
    input  logic [3:0] KEY,
    input  logic [9:0] SW,
    output logic [9:0] LEDR,
    output logic [6:0] HEX0,
    output logic [6:0] HEX1,
    output logic [6:0] HEX2,
    output logic [6:0] HEX3,
    output logic [6:0] HEX4,
    output logic [6:0] HEX5
);

    logic [(4*COUNTDOWN_WIDTH)-1:0] spawn_countdown;

    logic [3:0] readys;
    logic [3:0] display_actives;
    logic [(4*COUNTDOWN_WIDTH)-1:0] display_values;

    // two quality bits per lane
    logic [7:0] hit_qualitys;
    logic [3:0] quality_valids;

    logic [3:0] spawn_rejected_pulse;
    logic [3:0] hit_led;

    logic beat_tick;
    logic subbeat_tick;

    reg   [$clog2(MAX_SCORE)-1:0] game_score;
    reg   [1:0] encoded_multi_state;


    // Shared timing generator
    beat_gen #(
        .MS_PER_SUBBEAT(MS_PER_SUBBEAT),
        .SUBBEATS_PER_BEAT(SUBBEATS_PER_BEAT),
        .CLKS_PER_MS(CLKS_PER_MS)
    ) u_beat_gen (
        .clk(CLOCK_50),
        .reset(reset),
        .beat_tick(beat_tick),
        .subbeat_tick(subbeat_tick)
    );

    // Four independent piano tiles lanes
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
                .clk(CLOCK_50),
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

                .ready(ready[i]),
                .display_active(display_active[i]),

                .display_value(
                    display_value[
                        i*COUNTDOWN_WIDTH +: COUNTDOWN_WIDTH
                    ]
                ),

                .hit_quality(
                    hit_quality[i*2 +: 2]
                ),

                .quality_valid(quality_valid[i]),
                .spawn_rejected_pulse(spawn_rejected_pulse[i]),
                .hit_led(hit_led[i])
            );

        end
    endgenerate

    // Score Module
    score_handler #(
        .MAX_SCORE(MAX_SCORE)
    ) u_score (
        .clk(CLOCK_50),
        .rst(reset),

        .l_0_quality_valid(quality_valid[0]),
        .l_0_quality_value(hit_quality[0*2 +: 2]),

        .l_1_quality_valid(quality_valid[1]),
        .l_1_quality_value(hit_quality[1*2 +: 2]),

        .l_2_quality_valid(quality_valid[2]),
        .l_2_quality_value(hit_quality[2*2 +: 2]),

        .l_3_quality_valid(quality_valid[3]),
        .l_3_quality_value(hit_quality[3*2 +: 2]),

        .score(game_score),
        .enc_curr_state(encoded_multi_state)

    )

    // Display driver
    piano_keys_display u_game_display (
        .score_value(game_score),
        .score_multi(encoded_multi_state),

        .lane_0_value(display_values[0*COUNTDOWN_WIDTH +: COUNTDOWN_WIDTH]),
        .lane_1_value(display_values[1*COUNTDOWN_WIDTH +: COUNTDOWN_WIDTH]),
        .lane_2_value(display_values[2*COUNTDOWN_WIDTH +: COUNTDOWN_WIDTH]),
        .lane_3_value(display_values[3*COUNTDOWN_WIDTH +: COUNTDOWN_WIDTH]),

        .lane_0_led(hit_led[0]),
        .lane_1_led(hit_led[1]),
        .lane_2_led(hit_led[2]),
        .lane_3_led(hit_led[3]),

        .lane_0_HEX(HEX0),
        .lane_1_HEX(HEX1),
        .lane_2_HEX(HEX2),
        .lane_3_HEX(HEX3),

        .lane_leds(LEDR[3:6]),

        .score_ones_HEX(HEX4),
        .score_tens_HEX(HEX5),

        .score_multi_leds(LEDR[7:9])
    );




    // assign LEDR[0]   = heartbeat;
    // assign LEDR[4:1] = ~KEY;    // Active low push button, so invert to drive LEDs
    // assign LEDR[6:5] = SW[9:8];
    // assign LEDR[9:7] = 3'b000;  // Assign every output bit, even unused ones

    // assign HEX0 = ~SW[7:1];
    // assign HEX1 = 7'b1111111;   // All ones = display off (active low)
    // assign HEX2 = 7'b1111111;
    // assign HEX3 = 7'b1111111;
    // assign HEX4 = 7'b1111111;
    // assign HEX5 = 7'b1111111;

endmodule
