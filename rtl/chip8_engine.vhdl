library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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
    type framebuffer_t is array (0 to 31) of std_logic_vector(63 downto 0);
    signal framebuffer : framebuffer_t := (others => (others => '0'));

    type state_t is (RST, FETCH_HI, FETCH_LO, DECODE, EXECUTE);
    signal state : state_t := RST;

    signal PC : UNSIGNED(11 downto 0) := (others => '0');
    signal IR : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');

    signal op : STD_LOGIC_VECTOR(3 downto 0);
    signal x, y : integer range 3 downto 0;

    type register_file_t is array(0 to 15) of UNSIGNED(7 downto 0);
    signal V : register_file_t := (others => (others => '0'));
    signal I : UNSIGNED(15 downto 0) := (others => '0');
begin
    -- The Verilog wrapper continuously queries the pixel being displayed.
    pixel_on <= framebuffer(to_integer(unsigned(pixel_y)))
                           (to_integer(unsigned(pixel_x)));

    process (clock)
        variable test_pattern : framebuffer_t;

        variable pc_tmp : UNSIGNED(11 downto 0) := (others => '0');
        variable ir_tmp : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
        variable sum : UNSIGNED(8 downto 0);
    begin
        if rising_edge(clock) then
            if reset = '1' then
                state <= RST;
                PC <= (others => '0');

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
                case state is
                    when RST =>
                        pc_tmp := TO_UNSIGNED(16#200#, PC'length);
                        PC <= pc_tmp;
                        state <= FETCH_HI;

                    when FETCH_HI =>
                        pc_tmp := PC + 1;
                        PC <= pc_tmp;
                        state <= FETCH_LO;

                    when DECODE =>
                        state <= EXECUTE;

                    when EXECUTE =>
                        state <= FETCH_HI;

                    when others =>
                        null;
                end case;

                -- TODO: Implement the CHIP-8 CPU, timers, and keypad handling.
                -- Dxyn should XOR sprite bits into framebuffer and set VF when
                -- an enabled pixel is erased.
                null;
            end if;
        end if;
    end process;
end architecture rtl;
