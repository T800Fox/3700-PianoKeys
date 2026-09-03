
module sequencer #(
    parameter NUM_SONGS = 3,
    parameter SONG_MEM_SIZE = 256
) (
    input logic clk,
    input logic beat_clk,

    input logic start_button,

    input logic reset,
    input logic all_lanes_ready,

    input logic [1:0] difficulty_ind,
    input logic [1:0] song_selection_ind,

    output logic [3:0] lane_countdowns [0:3],
    output logic lane_resets [0:3],

    output logic [3:0] count_val,
    output logic beat_clk_reset,

    output logic game_active,
    output logic count_active
);

    typedef enum logic [1:0] {
        INIT,
        AWAITING_START,
        COUNT_IN,
        IN_GAME
    } state_type;

    state_type current_state;
    state_type next_state;

    assign game_active =
        (current_state == IN_GAME);

    assign count_active =
        (current_state == COUNT_IN);


    logic [11:0] lane_data [0:3][0:SONG_MEM_SIZE-1];
    logic [11:0] sequence_data [0:(SONG_MEM_SIZE*NUM_SONGS)-1];

    logic [7:0] num_notes;
    logic [3:0] count_in;
    logic [7:0] tempo;

    logic [1:0] clamped_song;

    logic [$clog2(SONG_MEM_SIZE*NUM_SONGS)-1:0] song_offset_i;

    assign clamped_song =
        (song_selection_ind >= NUM_SONGS) ?
        2'd0 :
        song_selection_ind;

    assign song_offset_i =
        clamped_song * SONG_MEM_SIZE;


    logic [7:0] note_index;

    logic [7:0] lane_index [0:3];
    logic [7:0] lane_len   [0:3];

    logic [1:0] lane;

    logic [7:0] delta_lane;
    logic [7:0] score_time;

    logic [3:0] prev_reset;
    logic [3:0] reset_val;


    // --------------------------------------------------------
    // Difficulty
    //
    // Easy   nominally 6..9
    // Medium nominally 3..6
    // Hard   nominally 1..3
    //
    // Values are clamped to delta_lane when the musical spacing
    // does not permit the full nominal warning period.
    // --------------------------------------------------------

    logic [3:0] diff_rng_bounds [0:3];

    logic [1:0] clamped_diff;

    assign clamped_diff =
        (difficulty_ind > 2) ?
        2'd2 :
        difficulty_ind;

    logic [3:0] rand_range [0:1];

    assign rand_range[1] =
        (diff_rng_bounds[clamped_diff] > delta_lane) ?
        delta_lane :
        diff_rng_bounds[clamped_diff];

    assign rand_range[0] =
        (diff_rng_bounds[clamped_diff + 1] > delta_lane) ?
        delta_lane :
        diff_rng_bounds[clamped_diff + 1];


    logic rand_valid;

    rng u_rng (
        .clk(clk),

        .range_lower(rand_range[0]),
        .range_upper(rand_range[1]),

        .random_val(reset_val),
        .output_valid(rand_valid)
    );


    logic [7:0] score_time_playback;
    logic [2:0] lanes_completed;


    initial begin

        // Continuous three-song memory.
        $readmemh(
            "rtl/midi_data/gy.txt",
            sequence_data,
            0*SONG_MEM_SIZE
        );

        $readmemh(
            "rtl/midi_data/jaspers_song.txt",
            sequence_data,
            1*SONG_MEM_SIZE
        );

        $readmemh(
            "rtl/midi_data/twinkle.txt",
            sequence_data,
            2*SONG_MEM_SIZE
        );


        diff_rng_bounds[0] = 4'd9;
        diff_rng_bounds[1] = 4'd6;
        diff_rng_bounds[2] = 4'd3;
        diff_rng_bounds[3] = 4'd1;


        current_state = AWAITING_START;

        count_val = 0;
        beat_clk_reset = 0;

        num_notes = 0;
        count_in = 0;
        tempo = 0;

        note_index = 2;

        lane_index[0] = 0;
        lane_index[1] = 0;
        lane_index[2] = 0;
        lane_index[3] = 0;

        score_time_playback = 0;
    end


    // --------------------------------------------------------
    // State transition logic
    // --------------------------------------------------------

    always_comb begin

        next_state = current_state;

        case (current_state)

            AWAITING_START: begin
                if (start_button)
                    next_state = INIT;
            end

            INIT: begin
                if (note_index >= num_notes + 2)
                    next_state = COUNT_IN;
            end

            COUNT_IN: begin
                if (count_val == 0)
                    next_state = IN_GAME;
            end

            IN_GAME: begin

                // IMPORTANT:
                // Reaching the end of the sequencer data is not enough.
                // The final lane FSM may still be finishing its judgement
                // window. Keep timing alive until every lane is truly idle.
                if ((lanes_completed == 4) && all_lanes_ready)
                    next_state = AWAITING_START;

            end

            default:
                next_state = AWAITING_START;

        endcase
    end


    // --------------------------------------------------------
    // Current event decoding during INIT
    // --------------------------------------------------------

    always_comb begin

        lane = 0;
        delta_lane = 0;
        prev_reset = 0;

        if (current_state == INIT &&
            note_index < SONG_MEM_SIZE) begin

            lane =
                sequence_data[
                    song_offset_i + note_index
                ][1:0];

            delta_lane =
                sequence_data[
                    song_offset_i + note_index
                ][11:4];

            if (lane_index[lane] != 0)
                prev_reset =
                    lane_data[
                        lane
                    ][
                        lane_index[lane] - 1
                    ][3:0];

        end
    end


    always_comb begin

        score_time =
            delta_lane +
            prev_reset -
            reset_val +
            (
                (lane_index[lane] != 0) ?
                lane_data[
                    lane
                ][
                    lane_index[lane] - 1
                ][11:4] :
                0
            );

    end


    // --------------------------------------------------------
    // Playback combinational logic
    // --------------------------------------------------------

    integer lane_i;

    always_comb begin

        lanes_completed = 0;

        for (lane_i = 0; lane_i < 4; lane_i = lane_i + 1) begin

            lane_resets[lane_i] = 0;
            lane_countdowns[lane_i] = 0;

            if (lane_index[lane_i] == lane_len[lane_i]) begin

                lanes_completed =
                    lanes_completed + 1;

            end
            else if (
                lane_data[
                    lane_i
                ][
                    lane_index[lane_i]
                ][11:4]
                ==
                score_time_playback
            ) begin

                lane_countdowns[lane_i] =
                    lane_data[
                        lane_i
                    ][
                        lane_index[lane_i]
                    ][3:0];

                lane_resets[lane_i] = 1;

            end
        end
    end


    // --------------------------------------------------------
    // Sequential song build/playback logic
    // --------------------------------------------------------

    always_ff @(posedge clk) begin

        if (reset) begin

            current_state <= AWAITING_START;

            count_val <= 0;
            beat_clk_reset <= 0;

            note_index <= 2;

            lane_index[0] <= 0;
            lane_index[1] <= 0;
            lane_index[2] <= 0;
            lane_index[3] <= 0;

            score_time_playback <= 0;

        end
        else begin

            current_state <= next_state;

            case (current_state)


                AWAITING_START: begin

                    beat_clk_reset <= 0;

                    if (next_state == INIT) begin

                        // Metadata belongs to selected song.
                        num_notes <=
                            sequence_data[
                                song_offset_i
                            ][11:4];

                        count_in <=
                            sequence_data[
                                song_offset_i
                            ][3:0];

                        tempo <=
                            sequence_data[
                                song_offset_i + 1
                            ][7:0];

                        note_index <= 2;

                        lane_index[0] <= 0;
                        lane_index[1] <= 0;
                        lane_index[2] <= 0;
                        lane_index[3] <= 0;

                    end
                end


                INIT: begin

                    if (next_state == COUNT_IN) begin

                        count_val <= count_in;

                        lane_index[0] <= 0;
                        lane_index[1] <= 0;
                        lane_index[2] <= 0;
                        lane_index[3] <= 0;

                        score_time_playback <= 0;

                        lane_len <= lane_index;

                    end
                    else if (rand_valid) begin

                        lane_data[
                            lane
                        ][
                            lane_index[lane]
                        ] <= {
                            score_time,
                            reset_val
                        };

                        note_index <=
                            note_index + 1;

                        lane_index[lane] <=
                            lane_index[lane] + 1;

                    end
                end


                COUNT_IN: begin

                    if (beat_clk)
                        count_val <=
                            count_val - 1;

                    if (next_state == IN_GAME)
                        beat_clk_reset <= 1;

                end


                IN_GAME: begin

                    beat_clk_reset <= 0;

                    if (beat_clk) begin

                        for (
                            lane_i = 0;
                            lane_i < 4;
                            lane_i = lane_i + 1
                        ) begin

                            if (lane_resets[lane_i])
                                lane_index[lane_i] <=
                                    lane_index[lane_i] + 1;

                        end

                        score_time_playback <=
                            score_time_playback + 1;

                    end
                end


                default: begin
                    current_state <= AWAITING_START;
                end

            endcase
        end
    end

endmodule
