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
        --
        FETCH_HIGH_ADDRESS,
        FETCH_HIGH_DATA,
        FETCH_LOW_ADDRESS,
        FETCH_LOW_DATA,
        --
        EXECUTE,
        --
        DRAW_ADDRESS,
        DRAW_DATA,
        DRAW_ROW,
        --
        HALT_STATE
    );
    signal state : state_t := RESET;

    signal pc : UNSIGNED(11 downto 0) := (others => '0');
    signal opcode : opcode_t := (others => '0');

begin

    mem_addr <= address_t(pc);

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= RESET;
                pc <= to_unsigned(CHIP8_PROGRAM_START, pc'length);
                opcode <= (others => '0');
            else
                case state is
                    when RESET =>
                        state <= FETCH_HIGH_ADDRESS;

                    when FETCH_HIGH_ADDRESS =>
                        state <= FETCH_HIGH_DATA;

                    when FETCH_HIGH_DATA =>
                        opcode(15 downto 8) <= mem_data;
                        pc <= pc + 1;
                        state <= FETCH_LOW_ADDRESS;

                    when FETCH_LOW_ADDRESS =>
                        state <= FETCH_LOW_DATA;

                    when FETCH_LOW_DATA =>
                        opcode(7 downto 0) <= mem_data;
                        pc <= pc + 1;
                        state <= EXECUTE;

                    when EXECUTE =>
                        state <= FETCH_HIGH_ADDRESS;

                    when others =>
                        state <= RESET;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
