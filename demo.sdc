# demo.sdc, timing constraints.
#
# Without this file the timing analyser has no idea how fast your clock is, so it
# reports nothing useful ("timing met" would be meaningless).

# The DE1-SoC's 50 MHz oscillator has a 20 ns period. Its pin assignment is CLOCK_50.
create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]

# Model the real, non-ideal clock (jitter and so on) rather than a perfect one.
derive_clock_uncertainty

# Buttons and switches are asynchronous human inputs, and LEDs and 7-segment
# displays are visual UI elements. None of them has a meaningful setup/hold
# relationship to the clock, so tell the timing analyser to ignore them:
set_false_path -from [get_ports {KEY[*] SW[*]}]
set_false_path -to   [get_ports {LEDR[*] HEX0[*] HEX1[*] HEX2[*] HEX3[*] HEX4[*] HEX5[*]}]
