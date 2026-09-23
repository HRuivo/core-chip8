library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity chip8_engine_tb is
end entity chip8_engine_tb;

architecture simulation of chip8_engine_tb is
    constant CLOCK_PERIOD : time := 100 ns; -- 10 MHz

    signal clock : std_logic := '0';
    signal reset : std_logic := '1';
    signal run_enable : std_logic := '0';

    signal keypad   : std_logic_vector(15 downto 0) := (others => '0');
    signal pixel_x  : std_logic_vector(5 downto 0) := (others => '0');
    signal pixel_y  : std_logic_vector(4 downto 0) := (others => '0');
    signal pixel_on : std_logic;
    signal sound_active : std_logic;

    signal rom_write_enable  : std_logic := '0';
    signal rom_write_address : std_logic_vector(11 downto 0) := (others => '0');
    signal rom_write_data    : std_logic_vector(7 downto 0) := (others => '0');
begin
    -- Clock generation
    clock <= not clock after CLOCK_PERIOD / 2;

    -- Device under test
    dut : entity work.chip8_engine
        port map (
            clock => clock,
            reset => reset,
            run_enable => run_enable,
            keypad => keypad,
            pixel_x => pixel_x,
            pixel_y => pixel_y,
            pixel_on => pixel_on,
            sound_active => sound_active,
            rom_write_enable => rom_write_enable,
            rom_write_address => rom_write_address,
            rom_write_data => rom_write_data
        );

    -- Test process
    stimulus : process
    begin
        -- Reset the complete engine
        reset <= '1';
        run_enable <= '0';

        wait for 5 * CLOCK_PERIOD;
        wait until rising_edge(clock);

        reset <= '0';

        wait for 2 * CLOCK_PERIOD;

        -- Start the CHIP-8 CPU
        run_enable <= '1';

        -- Let the CPU run long enough to exercise several fetch cycles.
        wait for 10 us;

        report "CHIP-8 engine smoke test completed" severity note;
        finish;
        wait;
    end process;
end architecture simulation;
