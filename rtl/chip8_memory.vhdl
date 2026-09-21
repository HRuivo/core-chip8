library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.chip8_pkg.all;

entity chip8_memory is
    port (
        clock : in std_logic;

        address : in address_t;
        write_enable : in std_logic;
        write_data : in byte_t;
        read_data : out byte_t
    );
end entity chip8_memory;

architecture rtl of chip8_memory is
    signal memory : memory_t := (others => (others => '0'));

    attribute ram_style : string;
    attribute ram_style of memory : signal is "block";
begin
    process (clock)
    begin
        if rising_edge(clock) then
            if write_enable = '1' then
            memory(to_integer(unsigned(address))) <= write_data;
            end if;

            read_data <= memory(to_integer(unsigned(address)));
        end if;
    end process;
end architecture rtl;
