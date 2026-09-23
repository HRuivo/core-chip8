library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity chip8_engine_tb is
end entity chip8_engine_tb;

architecture simulation of chip8_engine_tb is
    constant CLOCK_PERIOD : time := 100 ns; -- 10 MHz
    type program_t is array (natural range <>) of std_logic_vector(7 downto 0);
    constant DRAW_PROGRAM : program_t := (
        x"60", x"00", -- V0 := 0 (x)
        x"61", x"00", -- V1 := 0 (y)
        x"A0", x"50", -- I := font sprite for 0
        x"D0", x"15", -- draw five rows
        x"12", x"08"  -- loop without drawing again
    );

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

        -- Load a visible program before releasing the CPU from reset.
        rom_write_enable <= '1';
        for i in DRAW_PROGRAM'range loop
            rom_write_address <= std_logic_vector(to_unsigned(16#200# + i, 12));
            rom_write_data <= DRAW_PROGRAM(i);
            wait until rising_edge(clock);
            wait for 1 ns;
        end loop;
        rom_write_enable <= '0';
        wait until rising_edge(clock);
        wait for 1 ns;

        reset <= '0';
        run_enable <= '1';

        -- Four instructions take four paced ticks, about 5.7 ms at 700 Hz.
        wait for 5 ms;
        assert pixel_on = '0'
            report "draw completed before the paced instruction tick"
            severity failure;

        wait for 1 ms;
        assert pixel_on = '1'
            report "font sprite was not drawn after four instruction ticks"
            severity failure;

        report "CHIP-8 instruction timing and drawing test completed" severity note;
        finish;
        wait;
    end process;
end architecture simulation;
