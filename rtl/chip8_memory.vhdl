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
        -- Standard CHIP-8 font, hexadecimal digits 0-F, five bytes each.
        result(16#050#) := x"F0"; result(16#051#) := x"90"; result(16#052#) := x"90"; result(16#053#) := x"90"; result(16#054#) := x"F0";
        result(16#055#) := x"20"; result(16#056#) := x"60"; result(16#057#) := x"20"; result(16#058#) := x"20"; result(16#059#) := x"70";
        result(16#05A#) := x"F0"; result(16#05B#) := x"10"; result(16#05C#) := x"F0"; result(16#05D#) := x"80"; result(16#05E#) := x"F0";
        result(16#05F#) := x"F0"; result(16#060#) := x"10"; result(16#061#) := x"F0"; result(16#062#) := x"10"; result(16#063#) := x"F0";
        result(16#064#) := x"90"; result(16#065#) := x"90"; result(16#066#) := x"F0"; result(16#067#) := x"10"; result(16#068#) := x"10";
        result(16#069#) := x"F0"; result(16#06A#) := x"80"; result(16#06B#) := x"F0"; result(16#06C#) := x"10"; result(16#06D#) := x"F0";
        result(16#06E#) := x"F0"; result(16#06F#) := x"80"; result(16#070#) := x"F0"; result(16#071#) := x"90"; result(16#072#) := x"F0";
        result(16#073#) := x"F0"; result(16#074#) := x"10"; result(16#075#) := x"20"; result(16#076#) := x"40"; result(16#077#) := x"40";
        result(16#078#) := x"F0"; result(16#079#) := x"90"; result(16#07A#) := x"F0"; result(16#07B#) := x"90"; result(16#07C#) := x"F0";
        result(16#07D#) := x"F0"; result(16#07E#) := x"90"; result(16#07F#) := x"F0"; result(16#080#) := x"10"; result(16#081#) := x"F0";
        result(16#082#) := x"F0"; result(16#083#) := x"90"; result(16#084#) := x"F0"; result(16#085#) := x"90"; result(16#086#) := x"90";
        result(16#087#) := x"E0"; result(16#088#) := x"90"; result(16#089#) := x"E0"; result(16#08A#) := x"90"; result(16#08B#) := x"E0";
        result(16#08C#) := x"F0"; result(16#08D#) := x"80"; result(16#08E#) := x"80"; result(16#08F#) := x"80"; result(16#090#) := x"F0";
        result(16#091#) := x"E0"; result(16#092#) := x"90"; result(16#093#) := x"90"; result(16#094#) := x"90"; result(16#095#) := x"E0";
        result(16#096#) := x"F0"; result(16#097#) := x"80"; result(16#098#) := x"F0"; result(16#099#) := x"80"; result(16#09A#) := x"F0";
        result(16#09B#) := x"F0"; result(16#09C#) := x"80"; result(16#09D#) := x"F0"; result(16#09E#) := x"80"; result(16#09F#) := x"80";

        return result;
    end function;

    signal memory : memory_t := initialize_memory;

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
