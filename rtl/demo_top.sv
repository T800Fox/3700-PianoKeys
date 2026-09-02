// demo_top.sv, scaffold demo top level.

/*
    Module 'demo_top'

    Building off Aditya's code in game_core.sv...
    I've had a crack at integrating in the display driver and the score 
    handler modules. Even though it's structured as a top level file, it 
    should be simple to bring it back to a module if need be?

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
    parameter MAX_SCORE          = 99,
    parameter DIFFICULTY         = 1
) 
(
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

    logic [3:0] press_pulses;
    logic reset;
    logic game_active;
    logic new_game_pulse;
    logic score_reset;
    logic [3:0] lane_press_pulses;
    logic [3:0] lane_ready;
    logic all_lanes_ready;
    logic count_active;
    logic [3:0] count_val;
    logic sequencer_beat_reset;
    logic beat_reset;

    assign lane_press_pulses = press_pulses & {4{game_active}};
    assign new_game_pulse = press_pulses[0] & ~(game_active | count_active);
    assign score_reset = reset | new_game_pulse;
    assign all_lanes_ready = &lane_ready;

    // Keep musical timing stopped until the count-in begins.
    assign beat_reset =
        reset |
        sequencer_beat_reset |
        ~(count_active | game_active);
    logic spawns[4];

    logic [COUNTDOWN_WIDTH-1:0] spawn_countdowns [4];
    logic [(4*COUNTDOWN_WIDTH)-1:0] display_values;

    // two quality bits per lane
    logic [7:0] hit_qualitys;
    logic [3:0] quality_valids;

    logic [3:0] hit_leds;

    logic beat_tick;
    logic subbeat_tick;

    reg   [$clog2(MAX_SCORE)-1:0] game_score;
    reg   [1:0] encoded_multi_state;

    // Condition SW0 into the game reset
    switch_conditioner u_reset_conditioner (
        .clk(CLOCK_50),
        .switch(SW[0]),
        .switch_state(reset)
    );

    // Condition the four push buttons
    genvar b;
    generate
        for (b = 0; b < 4; b = b + 1) begin : GEN_BUTTONS
            button_conditioner u_button_conditioner (
                .clk(CLOCK_50),
                .reset(reset),
                .button(KEY[b]),
                .press_pulse(press_pulses[b])
            );
        end
    endgenerate

    // Shared timing generator
    beat_gen #(
        .MS_PER_SUBBEAT(MS_PER_SUBBEAT),
        .SUBBEATS_PER_BEAT(SUBBEATS_PER_BEAT),
        .CLKS_PER_MS(CLKS_PER_MS)
    ) u_beat_gen (
        .clk(CLOCK_50),
        .reset(beat_reset),
        .beat_tick(beat_tick),
        .subbeat_tick(subbeat_tick)
    );


    sequencer u_sequencer (
            .clk(CLOCK_50), 
            .beat_clk(beat_tick),
            .start_button(press_pulses[0]), //Assuming this will be debounced sync-edge of buttons
            .reset(reset),
            .all_lanes_ready(all_lanes_ready),
            .difficulty_ind(DIFFICULTY),
            .lane_countdowns(spawn_countdowns),
            .lane_resets(spawns),
            .count_val(count_val), //CONNECT TO SEVEN SEG +need a display count flag to override value
            .beat_clk_reset(sequencer_beat_reset),
            .game_active(game_active) ,
            .count_active(count_active)
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

                .press_pulse(lane_press_pulses[i]),
                .spawn(spawns[i]),

                .spawn_countdown(spawn_countdowns[i]),
                .ready(lane_ready[i]),
                .display_value(
                    display_values[
                        i*COUNTDOWN_WIDTH +: COUNTDOWN_WIDTH
                    ]
                ),

                .hit_quality(
                    hit_qualitys[i*2 +: 2]
                ),

                .quality_valid(quality_valids[i]),

                .hit_led(hit_leds[i])
            );

        end
    endgenerate

    // Score Module
    score_handler #(
        .MAX_SCORE(MAX_SCORE)
    ) u_score (
        .clk(CLOCK_50),
        .rst(score_reset),

        .l_0_quality_valid(quality_valids[0]),
        .l_0_quality_value(hit_qualitys[0*2 +: 2]),

        .l_1_quality_valid(quality_valids[1]),
        .l_1_quality_value(hit_qualitys[1*2 +: 2]),

        .l_2_quality_valid(quality_valids[2]),
        .l_2_quality_value(hit_qualitys[2*2 +: 2]),

        .l_3_quality_valid(quality_valids[3]),
        .l_3_quality_value(hit_qualitys[3*2 +: 2]),

        .score(game_score),
        .curr_multi_state(encoded_multi_state)

    );
    logic [3:0] lane_0_display;
    logic [3:0] lane_1_display;
    logic [3:0] lane_2_display;
    logic [3:0] lane_3_display;

    assign lane_0_display = count_active ? count_val :
                            display_values[0*COUNTDOWN_WIDTH +: COUNTDOWN_WIDTH];

    assign lane_1_display = count_active ? count_val :
                            display_values[1*COUNTDOWN_WIDTH +: COUNTDOWN_WIDTH];

    assign lane_2_display = count_active ? count_val :
                            display_values[2*COUNTDOWN_WIDTH +: COUNTDOWN_WIDTH];

    assign lane_3_display = count_active ? count_val :
                            display_values[3*COUNTDOWN_WIDTH +: COUNTDOWN_WIDTH];
    // Display driver
    piano_keys_display u_game_display (
        .score_value(game_score),
        .score_multi(encoded_multi_state),

        .lane_0_value(lane_0_display),
        .lane_1_value(lane_1_display),
        .lane_2_value(lane_2_display),
        .lane_3_value(lane_3_display),

        .lane_0_led(hit_leds[0]),
        .lane_1_led(hit_leds[1]),
        .lane_2_led(hit_leds[2]),
        .lane_3_led(hit_leds[3]),

        .lane_0_HEX(HEX0),
        .lane_1_HEX(HEX1),
        .lane_2_HEX(HEX2),
        .lane_3_HEX(HEX3),

        .lane_leds(LEDR[6:3]),

        .score_ones_HEX(HEX4),
        .score_tens_HEX(HEX5),

        .score_multi_leds(LEDR[9:7])
    );

endmodule
