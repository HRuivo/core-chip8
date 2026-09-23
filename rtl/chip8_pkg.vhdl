library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package chip8_pkg is
    constant CHIP8_MEMORY_SIZE      : natural := 4096;
    constant CHIP8_PROGRAM_START    : natural := 16#200#;
    constant CHIP8_FONT_START       : natural := 16#050#;

    constant CHIP8_SCREEN_WIDTH     : natural := 64;
    constant CHIP8_SCREEN_HEIGHT    : natural := 32;

    constant CHIP8_REGISTER_COUNT   : natural := 16;
    constant CHIP8_STACK_DEPTH      : natural := 16;

    constant TIMER_DIVIDER : natural := 166667;
    -- 10 MHz system clock / 14286 ~= 700 CHIP-8 instructions per second.
    constant INSTRUCTION_DIVIDER : natural := 14286;

    subtype nibble_t is std_logic_vector(3 downto 0);
    subtype byte_t is std_logic_vector(7 downto 0);
    subtype address_t is std_logic_vector(11 downto 0);
    subtype opcode_t is std_logic_vector(15 downto 0);

    subtype register_index_t is natural range 0 to 15;

    type register_file_t is array (0 to CHIP8_REGISTER_COUNT - 1) of byte_t;
    type stack_t is array (0 to CHIP8_STACK_DEPTH - 1) of address_t;
    type memory_t is array (0 to CHIP8_MEMORY_SIZE - 1) of byte_t;

    subtype framebuffer_row_t is std_logic_vector(CHIP8_SCREEN_WIDTH - 1 downto 0);
    type framebuffer_t is array (0 to CHIP8_SCREEN_HEIGHT - 1) of framebuffer_row_t;

    function opcode_group(opcode : opcode_t) return nibble_t;
    function opcode_x(opcode : opcode_t) return register_index_t;
    function opcode_y(opcode : opcode_t) return register_index_t;
    function opcode_n(opcode : opcode_t) return nibble_t;
    function opcode_nn(opcode : opcode_t) return byte_t;
    function opcode_nnn(opcode : opcode_t) return address_t;
end package chip8_pkg;

package body chip8_pkg is
    function opcode_group(opcode : opcode_t) return nibble_t is
    begin
        return opcode(15 downto 12);
    end function;

    function opcode_x(opcode : opcode_t) return register_index_t is
    begin
        return to_integer(unsigned(opcode(11 downto 8)));
    end function;

    function opcode_y(opcode : opcode_t) return register_index_t is
    begin
        return to_integer(unsigned(opcode(7 downto 4)));
    end function;

    function opcode_n(opcode : opcode_t) return nibble_t is
    begin
        return opcode(3 downto 0);
    end function;

    function opcode_nn(opcode : opcode_t) return byte_t is
    begin
        return opcode(7 downto 0);
    end function;

    function opcode_nnn(opcode : opcode_t) return address_t is
    begin
        return opcode(11 downto 0);
    end function;
end package body chip8_pkg;
