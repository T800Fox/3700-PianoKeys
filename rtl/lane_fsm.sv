// One Piano Tiles lane: countdown, centred judgement window and hit feedback.
// Adapted from reaction_time_modules/reaction_time_fsm.sv.

module lane_fsm #(
    parameter COUNTDOWN_WIDTH = 4,
    parameter SUBBEATS_PER_BEAT = 6,
    parameter WINDOW_HALF_TICKS = 3,
    parameter PERFECT_START_TICK = SUBBEATS_PER_BEAT,
    parameter PERFECT_END_TICK = SUBBEATS_PER_BEAT + 1,
    parameter HIT_FLASH_TICKS = 4
) (
    input logic clk,
    input logic reset,
    input logic beat_tick,
    input logic subbeat_tick,
    input logic press_pulse,
    input logic spawn,
    input logic [COUNTDOWN_WIDTH-1:0] spawn_countdown,
    output logic ready,
    output logic [COUNTDOWN_WIDTH-1:0] display_value,
    output logic [1:0] hit_quality,
    output logic quality_valid,
    output logic hit_led
);

    localparam logic [1:0] QUALITY_PERFECT = 2'b00;
    localparam logic [1:0] QUALITY_NORMAL  = 2'b01;
    localparam logic [1:0] QUALITY_POOR    = 2'b10;
    localparam logic [1:0] QUALITY_BAD     = 2'b11;
    localparam logic [COUNTDOWN_WIDTH-1:0] DISPLAY_BLANK = 4'd10;
    localparam TARGET_TICK = SUBBEATS_PER_BEAT;
    localparam HIT_START_TICK = TARGET_TICK;
    localparam HIT_END_TICK = TARGET_TICK + WINDOW_HALF_TICKS;
    localparam JUDGEMENT_COUNTER_WIDTH =
        (HIT_END_TICK <= 1) ? 1 : $clog2(HIT_END_TICK);

    typedef enum logic [1:0] { INACTIVE, COUNTDOWN, JUDGEMENT } state_type;

    state_type current_state, next_state;

    assign ready = (current_state == INACTIVE);
    logic [COUNTDOWN_WIDTH-1:0] countdown;
    logic [JUDGEMENT_COUNTER_WIDTH-1:0] judgement_tick;
    logic pending_valid;
    logic [COUNTDOWN_WIDTH-1:0] pending_countdown;
    logic resolved;
    logic valid_spawn;
    logic perfect_now;
    logic window_ended;
    logic successful_press;

    always_comb begin
        valid_spawn = (spawn_countdown != 0 && spawn_countdown <= 9);
        perfect_now = (judgement_tick >= PERFECT_START_TICK &&
                       judgement_tick < PERFECT_END_TICK);
        window_ended = (judgement_tick >= HIT_END_TICK - 1);
        successful_press = (current_state == JUDGEMENT && !resolved &&
                            press_pulse && judgement_tick >= HIT_START_TICK);

        case (current_state)
            COUNTDOWN: display_value = countdown;
            JUDGEMENT: begin
                if (resolved)
                    display_value = DISPLAY_BLANK;
                else
                    display_value = (judgement_tick < TARGET_TICK) ? 1 : 0;
            end
            default: display_value = DISPLAY_BLANK;
        endcase
    end

    hit_flash #(.FLASH_TICKS(HIT_FLASH_TICKS)) u_hit_flash (
        .clk(clk), .reset(reset), .subbeat_tick(subbeat_tick),
        .trigger(successful_press), .led(hit_led)
    );

    always_comb begin
        next_state = current_state;
        case (current_state)
            INACTIVE:
                if (!press_pulse && spawn && valid_spawn)
                    next_state = (spawn_countdown == 1) ? JUDGEMENT : COUNTDOWN;
            COUNTDOWN:
                if (press_pulse)
                    next_state = INACTIVE;
                else if (beat_tick && countdown == 2)
                    next_state = JUDGEMENT;
            JUDGEMENT:
                if (subbeat_tick && window_ended) begin
                    if (pending_valid)
                        next_state = (pending_countdown == 1) ? JUDGEMENT : COUNTDOWN;
                    else if (spawn && valid_spawn)
                        next_state = (spawn_countdown == 1) ? JUDGEMENT : COUNTDOWN;
                    else
                        next_state = INACTIVE;
                end
            default: next_state = INACTIVE;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset)
            current_state <= INACTIVE;
        else
            current_state <= next_state;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            countdown <= '0;
            judgement_tick <= '0;
            pending_valid <= 1'b0;
            pending_countdown <= '0;
            resolved <= 1'b0;
            hit_quality <= QUALITY_POOR;
            quality_valid <= 1'b0;
        end
        else begin
            quality_valid <= 1'b0;
            case (current_state)
                INACTIVE: begin
                    countdown <= '0;
                    judgement_tick <= '0;
                    pending_valid <= 1'b0;
                    resolved <= 1'b0;
                    if (press_pulse) begin
                        hit_quality <= QUALITY_BAD;
                        quality_valid <= 1'b1;
                    end
                    else if (spawn && valid_spawn) begin
                        if (spawn_countdown == 1) begin
                            countdown <= '0;
                            judgement_tick <= '0;
                        end
                        else
                            countdown <= spawn_countdown;
                    end
                end

                COUNTDOWN: begin
                    if (press_pulse) begin
                        hit_quality <= QUALITY_BAD;
                        quality_valid <= 1'b1;
                        countdown <= '0;
                    end
                    else if (beat_tick) begin
                        if (countdown > 2)
                            countdown <= countdown - 1'b1;
                        else begin
                            countdown <= '0;
                            judgement_tick <= '0;
                            resolved <= 1'b0;
                        end
                    end
                end

                JUDGEMENT: begin
                    if (press_pulse) begin
                        if (resolved)
                            hit_quality <= QUALITY_BAD;
                        else if (judgement_tick < HIT_START_TICK)
                            hit_quality <= QUALITY_POOR;
                        else if (perfect_now)
                            hit_quality <= QUALITY_PERFECT;
                        else
                            hit_quality <= QUALITY_NORMAL;
                        quality_valid <= 1'b1;
                        resolved <= 1'b1;
                    end

                    if (spawn && valid_spawn && !pending_valid &&
                        !(subbeat_tick && window_ended)) begin
                        pending_countdown <= spawn_countdown;
                        pending_valid <= 1'b1;
                    end

                    if (subbeat_tick) begin
                        if (window_ended) begin
                            if (!resolved && !press_pulse) begin
                                hit_quality <= QUALITY_POOR;
                                quality_valid <= 1'b1;
                            end
                            judgement_tick <= '0;
                            resolved <= 1'b0;
                            pending_valid <= 1'b0;
                            if (pending_valid)
                                countdown <= (pending_countdown == 1) ? '0 : pending_countdown;
                            else if (spawn && valid_spawn)
                                countdown <= (spawn_countdown == 1) ? '0 : spawn_countdown;
                            else
                                countdown <= '0;
                        end
                        else
                            judgement_tick <= judgement_tick + 1'b1;
                    end
                end

                default: begin
                    countdown <= '0;
                    judgement_tick <= '0;
                    pending_valid <= 1'b0;
                    resolved <= 1'b0;
                end
            endcase
        end
    end

endmodule
