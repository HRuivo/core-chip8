library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.chip8_pkg.all;

entity chip8_engine is
    port (
        clock      : in  std_logic;
        reset      : in  std_logic;
        run_enable : in  std_logic;
        keypad     : in  std_logic_vector(15 downto 0);
        pixel_x    : in  std_logic_vector(5 downto 0);
        pixel_y    : in  std_logic_vector(4 downto 0);
        pixel_on   : out std_logic
    );
end entity chip8_engine;

architecture rtl of chip8_engine is
    signal framebuffer : framebuffer_t := (others => (others => '0'));

    signal mem_addr : address_t;
    signal mem_wdata : byte_t;
    signal mem_rdata : byte_t;
    signal mem_we : std_logic;

    signal cpu_reset : std_logic;
begin
    -- The Verilog wrapper continuously queries the pixel being displayed.
    pixel_on <= framebuffer(to_integer(unsigned(pixel_y)))
                           (to_integer(unsigned(pixel_x)));

    process (clock)
        variable test_pattern : framebuffer_t;
    begin
        if rising_edge(clock) then
            if reset = '1' then
                test_pattern := (others => (others => '0'));

                test_pattern(0) := (others => '1');
                test_pattern(31) := (others => '1');

                for y in 0 to 31 loop
                    test_pattern(y)(0) := '1';
                    test_pattern(y)(63) := '1';
                    test_pattern(y)(2 * y) := '1';
                    test_pattern(y)(63 - 2*y) := '1';
                end loop;

                framebuffer <= test_pattern;
            elsif run_enable = '1' then
                -- TODO: Implement the CHIP-8 CPU, timers, and keypad handling.
                -- Dxyn should XOR sprite bits into framebuffer and set VF when
                -- an enabled pixel is erased.
                null;
            end if;
        end if;
    end process;

    mem : entity work.chip8_memory
    port map (
        clock => clock,
        address => mem_addr,
        write_enable => mem_we,
        write_data => mem_wdata,
        read_data => mem_rdata
    );

    cpu_reset <= reset or not run_enable;

    cpu : entity work.chip8_cpu
    port map (
        clk => clock,
        rst => cpu_reset,
        mem_data => mem_rdata,
        mem_addr => mem_addr
    );

end architecture rtl;
