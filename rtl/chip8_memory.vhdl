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
    function initialize_memory return memory_t is
        variable result : memory_t := (others => (others => '0'));
    begin
        -- Program
        result(16#200#) := x"00";
        result(16#201#) := x"E0";

        result(16#202#) := x"60";
        result(16#203#) := x"08";

        result(16#204#) := x"61";
        result(16#205#) := x"08";

        result(16#206#) := x"A2";
        result(16#207#) := x"0C";

        result(16#208#) := x"D0";
        result(16#209#) := x"15";

        result(16#20A#) := x"12";
        result(16#20B#) := x"0A";

        -- Sprite
        result(16#20C#) := x"F0";
        result(16#20D#) := x"90";
        result(16#20E#) := x"90";
        result(16#20F#) := x"90";
        result(16#210#) := x"F0";

        return result;
    end function;
    signal memory : memory_t := initialize_memory;
    --signal memory : memory_t := (others => (others => '0'));

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
