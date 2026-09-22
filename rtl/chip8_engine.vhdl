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
    signal mem_wdata : byte_t := (others => '0');
    signal mem_rdata : byte_t;
    signal mem_we : std_logic := '0';

    signal cpu_reset : std_logic;

    signal display_clear : std_logic;
    signal display_draw : std_logic;
    signal display_x : std_logic_vector(5 downto 0);
    signal display_y : std_logic_vector(4 downto 0);
    signal display_sprite : byte_t;
    signal display_collision : std_logic := '0';
begin
    -- The Verilog wrapper continuously queries the pixel being displayed.
    pixel_on <= framebuffer(to_integer(unsigned(pixel_y)))
                           (to_integer(unsigned(pixel_x)));

    process (clock)
        variable row_pixels : framebuffer_row_t;
        variable pixel_index : natural range 0 to CHIP8_SCREEN_WIDTH - 1;
        variable collision : std_logic;
    begin
        if rising_edge(clock) then
            if reset = '1' then
                framebuffer <= (others => (others => '0'));
                display_collision <= '0';
            elsif run_enable = '1' then
                display_collision <= '0';

                if display_clear = '1' then
                    framebuffer <= (others => (others => '0'));
                elsif display_draw = '1' then
                    row_pixels := framebuffer(to_integer(unsigned(display_y)));
                    collision := '0';

                    for bit_index in 0 to 7 loop
                        if display_sprite(7 - bit_index) = '1' then
                            pixel_index := (
                                to_integer(unsigned(display_x)) + bit_index
                            ) mod CHIP8_SCREEN_WIDTH;

                            if row_pixels(pixel_index) = '1' then
                                collision := '1';
                            end if;

                            row_pixels(pixel_index) := not row_pixels(pixel_index);
                        end if;
                    end loop;

                    framebuffer(to_integer(unsigned(display_y))) <= row_pixels;
                    display_collision <= collision;
                end if;
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
        mem_addr => mem_addr,
        display_clear => display_clear,
        display_draw => display_draw,
        display_x => display_x,
        display_y => display_y,
        display_sprite => display_sprite,
        display_collision => display_collision
    );

end architecture rtl;
