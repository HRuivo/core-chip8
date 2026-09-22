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
        mem_addr : out address_t;

        display_clear     : out std_logic;
        display_draw      : out std_logic;
        display_x         : out std_logic_vector(5 downto 0);
        display_y         : out std_logic_vector(4 downto 0);
        display_sprite    : out byte_t;
        display_collision : in  std_logic
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
        DRAW_RESULT,
        --
        HALT_STATE
    );
    signal state : state_t := RESET;

    signal pc : UNSIGNED(11 downto 0) := (others => '0');
    signal opcode : opcode_t := (others => '0');
    signal v : register_file_t;
    signal index_register : address_t := (others => '0');

    signal clear_display : std_logic := '0';

    signal draw_x      : unsigned(5 downto 0) := (others => '0');
    signal draw_y      : unsigned(4 downto 0) := (others => '0');
    signal draw_height : natural range 0 to 15 := 0;
    signal draw_row_index : natural range 0 to 15 := 0;
    signal draw_sprite : byte_t := (others => '0');

    signal dt, st : byte_t := (others => '0');

    signal stack : stack_t := (others => (others => '0'));
    signal sp : natural range 0 to CHIP8_STACK_DEPTH := 0;

begin

    mem_addr <= std_logic_vector(
        unsigned(index_register) + to_unsigned(draw_row_index, address_t'length)
    ) when state = DRAW_ADDRESS or state = DRAW_DATA else
        std_logic_vector(pc);

    display_clear  <= clear_display;
    display_draw   <= '1' when state = DRAW_ROW else '0';
    display_x      <= std_logic_vector(draw_x);
    display_y      <= std_logic_vector(
        draw_y + to_unsigned(draw_row_index, draw_y'length)
    );
    display_sprite <= draw_sprite;

    process (clk)
        variable op_group : nibble_t;

        variable x : register_index_t;
        variable y : register_index_t;

        variable n : nibble_t;
        variable nn : byte_t;
        variable nnn : address_t;

        variable sum : unsigned(8 downto 0);

    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= RESET;
                pc <= to_unsigned(CHIP8_PROGRAM_START, pc'length);
                opcode <= (others => '0');
                index_register <= (others => '0');
                stack <= (others => (others => '0'));
                sp <= 0;
                draw_x <= (others => '0');
                draw_y <= (others => '0');
                draw_height <= 0;
                draw_row_index <= 0;
                draw_sprite <= (others => '0');
            else
                clear_display <= '0';

                case state is
                    when RESET =>
                        v <= (others => (others => '0'));
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
                        op_group := opcode_group(opcode);
                        x := opcode_x(opcode);
                        y := opcode_y(opcode);
                        n := opcode_n(opcode);
                        nn := opcode_nn(opcode);
                        nnn := opcode_nnn(opcode);

                        -- Most instructions complete in this clock. Multi-cycle
                        -- instructions such as DXYN override this state below.
                        state <= FETCH_HIGH_ADDRESS;

                        case op_group is
                            when x"0" =>
                                if opcode = x"00E0" then
                                    clear_display <= '1';
                                elsif opcode = x"00EE" then
                                    if sp > 0 then
                                        sp <= sp - 1;
                                        pc <= unsigned(stack(sp - 1));
                                    else
                                        state <= HALT_STATE;
                                    end if;
                                end if;

                            when x"1" =>
                                pc <= unsigned(nnn);

                            when x"2" =>
                            if sp < CHIP8_STACK_DEPTH then
                                stack(sp) <= std_logic_vector(pc);
                                sp <= sp + 1;
                                pc <= unsigned(nnn);
                            else
                                state <= HALT_STATE;
                            end if;

                            when x"3" =>
                                if v(x) = nn then
                                    PC <= PC + 2;
                                end if;

                            when x"4" =>
                                if v(x) /= nn then
                                    PC <= PC + 2;
                                    end if;

                            when x"5" =>
                                if n = x"0" then
                                    if v(x) = v(y) then
                                        PC <= PC + 2;
                                    end if;
                                end if;

                            when x"6" =>
                                v(x) <= nn;

                            when x"7" =>
                                v(x) <= std_logic_vector(unsigned(v(x)) + unsigned(nn));

                            when x"8" =>
                                case n is
                                    when x"0" =>
                                        v(x) <= v(y);

                                    when x"1" =>
                                        v(x) <= v(x) or v(y);

                                    when x"2" =>
                                        v(x) <= v(x) and v(y);

                                    when x"3" =>
                                        v(x) <= v(x) xor v(y);

                                    when x"4" =>
                                        sum := unsigned('0' & v(x)) + unsigned('0' & v(y));
                                        v(x) <= byte_t(sum(7 downto 0));
                                        if sum(8) = '1' then
                                            v(15) <= x"01";
                                        else
                                            v(15) <= x"00";
                                        end if;

                                    when x"5" =>
                                        if unsigned(v(x)) >= unsigned(v(y)) then
                                            v(15) <= x"01";
                                        else
                                            v(15) <= x"00";
                                        end if;

                                        v(x) <= std_logic_vector(unsigned(v(x)) - unsigned(v(y)));

                                    when x"6" =>
                                        -- VF receives the bit shifted out.
                                        v(15) <= "0000000" & v(x)(0);
                                        v(x) <= '0' & v(x)(7 downto 1);

                                    when x"7" =>
                                        -- VX := VY - VX
                                        if unsigned(v(y)) >= unsigned(v(x)) then
                                            v(15) <= x"01";
                                        else
                                            v(15) <= x"00";
                                        end if;

                                        v(x) <= std_logic_vector(unsigned(v(y)) - unsigned(v(x)));

                                    when x"E" =>
                                        -- VF receives the bit shifted out.
                                        v(15) <= "0000000" & v(x)(7);
                                        v(x)  <= v(x)(6 downto 0) & '0';

                                    when others =>
                                        null;
                                end case;

                            when x"9" =>
                                if n = x"0" then
                                    if v(x) /= v(y) then
                                        PC <= PC + 2;
                                    end if;
                                end if;

                            when x"A" =>
                                index_register <= nnn;

                            when x"B" =>
                                PC <= unsigned(v(0)) + unsigned(nnn);

                            when x"C" =>
                                null;

                            when x"D" =>
                                draw_x <= unsigned(v(x)(5 downto 0));
                                draw_y <= unsigned(v(y)(4 downto 0));
                                draw_height <= to_integer(unsigned(n));
                                draw_row_index <= 0;
                                v(15) <= x"00";

                                -- DXY0 draws no rows in the base CHIP-8 mode.
                                if n /= x"0" then
                                    state <= DRAW_ADDRESS;
                                end if;

                            when x"F" =>
                                case nn is
                                    when x"07" =>
                                        v(x) <= dt;

                                    when x"0A" =>
                                        null;

                                    when x"15" =>
                                        dt <= v(x);

                                    when x"18" =>
                                        st <= v(x);

                                    when x"1E" =>
                                        null;

                                    when x"29" =>
                                    index_register <= v(x) * 5;

                                    when others =>
                                        null;
                                end case;

                            when others =>
                                null;
                        end case;

                    when DRAW_ADDRESS =>
                        -- The memory address is I + draw_row. Give the
                        -- synchronous memory one clock to read it.
                        state <= DRAW_DATA;

                    when DRAW_DATA =>
                        draw_sprite <= mem_data;
                        state <= DRAW_ROW;

                    when DRAW_ROW =>
                        -- display_draw is high for this complete clock cycle.
                        state <= DRAW_RESULT;

                    when DRAW_RESULT =>
                        if display_collision = '1' then
                            v(15) <= x"01";
                        end if;

                        if draw_row_index + 1 < draw_height then
                            draw_row_index <= draw_row_index + 1;
                            state <= DRAW_ADDRESS;
                        else
                            state <= FETCH_HIGH_ADDRESS;
                        end if;

                    when HALT_STATE =>
                        state <= HALT_STATE;

                    when others =>
                        state <= RESET;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
