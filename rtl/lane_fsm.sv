// One Piano Tiles lane: countdown, hit classification, penalties and hit LED.
// Adapted from the state-machine structure used by the Reaction Time Game
// lesson module in reaction_time_modules/reaction_time_fsm.sv.

module lane_fsm #(
    parameter COUNTDOWN_WIDTH    = 4,
    parameter HIT_WINDOW_TICKS   = 5,
    parameter PERFECT_START_TICK = 2,
    parameter PERFECT_END_TICK   = 4,
    parameter HIT_FLASH_TICKS    = 4
) (
    input  logic                         clk,
    input  logic                         reset,
    input  logic                         beat_tick,
    input  logic                         subbeat_tick,
    input  logic                         press_pulse,
    input  logic                         spawn,
    input  logic [COUNTDOWN_WIDTH-1:0]   spawn_countdown,

    output logic                         display_active,
    output logic [COUNTDOWN_WIDTH-1:0]   display_value,
    output logic                         normal_hit_pulse,
    output logic                         perfect_hit_pulse,
    output logic                         miss_pulse,
    output logic                         bad_press_pulse,
    output logic                         spawn_rejected_pulse,
    output logic                         hit_led
);

    localparam WINDOW_COUNTER_WIDTH =
        (HIT_WINDOW_TICKS <= 1) ? 1 : $clog2(HIT_WINDOW_TICKS);
    typedef enum logic [1:0] {
        INACTIVE,
        COUNTDOWN,
        HIT_WINDOW
    } state_type;

    state_type current_state;
    logic [COUNTDOWN_WIDTH-1:0] countdown;
    logic [WINDOW_COUNTER_WIDTH-1:0] window_age;
    logic valid_spawn;
    logic perfect_now;
    logic window_ended;
    logic hit_trigger;

    always_comb begin
        display_active = (current_state != INACTIVE);
        display_value  = countdown;
        valid_spawn    = (spawn_countdown != 0 && spawn_countdown <= 9);
        perfect_now    = (window_age >= PERFECT_START_TICK &&
                          window_age < PERFECT_END_TICK);
        window_ended   = (window_age >= HIT_WINDOW_TICKS - 1);
        hit_trigger    = (current_state == HIT_WINDOW && press_pulse);
    end

    hit_flash #(
        .FLASH_TICKS(HIT_FLASH_TICKS)
    ) u_hit_flash (
        .clk(clk),
        .reset(reset),
        .subbeat_tick(subbeat_tick),
        .trigger(hit_trigger),
        .led(hit_led)
    );

    // State transitions are kept separate from stored lane data. A press has
    // priority over timing events in every state where both can occur.
    state_type next_state;
    always_comb begin
        next_state = current_state;

        case (current_state)
            INACTIVE:
                if (!press_pulse && spawn && valid_spawn)
                    next_state = COUNTDOWN;

            COUNTDOWN:
                if (press_pulse)
                    next_state = INACTIVE;
                else if (beat_tick && countdown == 1)
                    next_state = HIT_WINDOW;

            HIT_WINDOW:
                if (press_pulse || (subbeat_tick && window_ended))
                    next_state = INACTIVE;

            default:
                next_state = INACTIVE;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset)
            current_state <= INACTIVE;
        else
            current_state <= next_state;
    end

    // Countdown, hit-window age and one-clock event outputs.
    always_ff @(posedge clk) begin
        if (reset) begin
            countdown            <= '0;
            window_age           <= '0;
            normal_hit_pulse     <= 1'b0;
            perfect_hit_pulse    <= 1'b0;
            miss_pulse           <= 1'b0;
            bad_press_pulse      <= 1'b0;
            spawn_rejected_pulse <= 1'b0;
        end
        else begin
            // Event outputs are asserted for one clock only.
            normal_hit_pulse     <= 1'b0;
            perfect_hit_pulse    <= 1'b0;
            miss_pulse           <= 1'b0;
            bad_press_pulse      <= 1'b0;
            spawn_rejected_pulse <= 1'b0;

            case (current_state)
                INACTIVE: begin
                    countdown  <= '0;
                    window_age <= '0;

                    // A press takes priority over a simultaneous spawn. This
                    // makes pressing continuously unable to catch a new note.
                    if (press_pulse) begin
                        bad_press_pulse <= 1'b1;
                        if (spawn)
                            spawn_rejected_pulse <= 1'b1;
                    end
                    else if (spawn) begin
                        if (!valid_spawn)
                            spawn_rejected_pulse <= 1'b1;
                        else
                            countdown <= spawn_countdown;
                    end
                end

                COUNTDOWN: begin
                    if (spawn)
                        spawn_rejected_pulse <= 1'b1;

                    // An early press forfeits the current note immediately.
                    if (press_pulse) begin
                        bad_press_pulse <= 1'b1;
                        countdown       <= '0;
                    end
                    else if (beat_tick) begin
                        if (countdown > 1)
                            countdown <= countdown - 1'b1;
                        else begin
                            countdown  <= '0;
                            window_age <= '0;
                        end
                    end
                end

                HIT_WINDOW: begin
                    if (spawn)
                        spawn_rejected_pulse <= 1'b1;

                    // A press wins over expiry on the same clock edge because
                    // the displayed zero was valid immediately before it.
                    if (press_pulse) begin
                        if (perfect_now)
                            perfect_hit_pulse <= 1'b1;
                        else
                            normal_hit_pulse <= 1'b1;

                        countdown <= '0;
                    end
                    else if (subbeat_tick) begin
                        if (window_ended) begin
                            miss_pulse <= 1'b1;
                            countdown <= '0;
                            window_age <= '0;
                        end
                        else
                            window_age <= window_age + 1'b1;
                    end
                end

                default: begin
                    countdown  <= '0;
                    window_age <= '0;
                end
            endcase
        end
    end

endmodule
