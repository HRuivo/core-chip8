library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.chip8_pkg.all;

entity chip8_cpu is
    port (
        clk : in std_logic;
        rst : in std_logic;

        mem_data : in byte_t;
        mem_addr : out address_t
    );
end entity chip8_cpu;

architecture rtl of chip8_cpu is
    type state_t is (
        RESET,
        FETCH_HI,
        FETCH_LO,
        DECODE,
        EXECUTE
    );
    signal state : state_t := RESET;

    signal PC : UNSIGNED(11 downto 0) := (others => '0');
    signal IR : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');

    signal op : STD_LOGIC_VECTOR(3 downto 0);
    signal x, y : integer range 3 downto 0;

    type register_file_t is array(0 to 15) of UNSIGNED(7 downto 0);
    signal V : register_file_t := (others => (others => '0'));
    signal I : UNSIGNED(15 downto 0) := (others => '0');

    signal clear_display : std_logic := '0';

begin

    process (clk)
        variable pc_tmp : UNSIGNED(11 downto 0) := (others => '0');
        variable ir_tmp : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
        variable sum : UNSIGNED(8 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= RESET;
                PC <= (others => '0');
                mem_addr <= (others => '0');
            else
                clear_display <= '0';

                case state is
                    when RESET =>
                        pc_tmp := to_unsigned(16#200#, PC'length);
                        PC <= pc_tmp;
                        mem_addr <= address_t(pc_tmp);
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
            end if;
        end if;
    end process;

end architecture rtl;
