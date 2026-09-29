module chip8_core
#(
    parameter int  DISPLAY_DIVIDER
)
(
    input  wire logic           clock,
    input  wire logic           reset,
    input  wire logic           clocks_clockIn50M,
    output logic                clocks_clockOutSystem,
    output logic                clocks_clockOutDisplay,
    output logic                clocks_clockOutSpi,
    output logic                clocks_locked,
    output logic [4:0]          video_data_r,
    output logic [4:0]          video_data_g,
    output logic [4:0]          video_data_b,
    output logic                video_dataEnable,
    output logic                video_vblank,
    output logic                video_hblank,
    output logic [15:0]         audio_left,
    output logic [15:0]         audio_right,
    input  wire logic [31:0]    host_mem_address,
    input  wire logic           host_mem_enable,
    input  wire logic           host_mem_write,
    output logic [31:0]         host_mem_dataRead,
    input  wire logic [31:0]    host_mem_dataWrite,
    output logic                host_mem_done,
    input  wire logic           host_commandHost_request,
    output logic                host_commandHost_busy,
    output logic                host_commandHost_done,
    output logic                host_commandHost_error,
    output logic                host_commandCore_request,
    input  wire logic           host_commandCore_busy,
    input  wire logic           host_commandCore_done,
    input  wire logic           host_commandCore_error,
    input  wire logic           input_buttons_a,
    input  wire logic           input_buttons_b,
    input  wire logic           input_buttons_x,
    input  wire logic           input_buttons_y,
    input  wire logic           input_buttons_up,
    input  wire logic           input_buttons_down,
    input  wire logic           input_buttons_left,
    input  wire logic           input_buttons_right,
    input  wire logic           input_buttons_l,
    input  wire logic           input_buttons_r,
    input  wire logic           input_buttons_start,
    input  wire logic           input_buttons_select
);
    // =========================================================================
    // Clock generation
    // =========================================================================
    mmcm_clock_gen #(.CLK_DISPLAY_DIVIDE  (DISPLAY_DIVIDER))
    mmcm (
        .clk_in_50mhz (clocks_clockIn50M),
        .clk_sys      (clocks_clockOutSystem),
        .clk_display  (clocks_clockOutDisplay),
        .clk_spi      (clocks_clockOutSpi),
        .locked       (clocks_locked)
    );
    logic clk_10mhz;
    assign clk_10mhz = clocks_clockOutSystem;

    // =========================================================================
    // Host MCU communication
    // =========================================================================
    localparam ADDR_CONFIG_COLOR = 32'h00001000;
    localparam ADDR_ROM_START    = 32'h00002000;
    localparam ADDR_ROM_END      = 32'h00002E00;
    localparam ADDR_REG0 = 32'hF0000000;
    localparam ADDR_REG1 = 32'hF0000004;
    localparam CMD_GET_STATUS     = 16'h0000;
    localparam CMD_CORE_RUN       = 16'h0100;
    localparam CMD_CORE_HALT      = 16'h0101;
    localparam CMD_SETUP_COMPLETE = 16'h0102;
    localparam CMD_NOTIFY_FOCUS   = 16'h0200;
    localparam CMD_FILE_WRITE_START = 16'h0300;
    localparam CMD_FILE_WRITE_END   = 16'h0301;

    logic reg_core_setup = 1'b0;
    logic reg_core_reset = 1'b1;
    logic reg_core_focus = 1'b0;

    logic [31:0] reg_command_host_0, reg_command_host_1;
    logic mem_busy;

    // The host transfers files as 32-bit words, while CHIP-8 memory is byte-wide.
    // Keep the transaction open while these four bytes are written sequentially.
    logic        rom_write_active;
    logic [1:0]  rom_write_index;
    logic [11:0] rom_write_base_address;
    logic [31:0] rom_write_word;
    logic        rom_write_enable;
    logic [11:0] rom_write_address;
    logic [7:0]  rom_write_data;

    typedef enum logic [2:0] {
        STATUS_UNKNOWN    = 3'd0,
        STATUS_INITIALIZE = 3'd1,
        STATUS_SETUP      = 3'd2,
        STATUS_CORE_HALT  = 3'd3,
        STATUS_CORE_RUN   = 3'd4
    } status_t;

    // Command Channel State
    typedef enum logic [1:0] {
        CMD_STATE_IDLE  = 2'b00,
        CMD_STATE_BUSY  = 2'b01,
        CMD_STATE_DONE  = 2'b10,
        CMD_STATE_ERROR = 2'b11
    } command_state_t;

    command_state_t command_host_state;

    assign host_mem_done = mem_busy;
    assign host_commandHost_busy = (command_host_state == CMD_STATE_BUSY);
    assign host_commandHost_done = (command_host_state == CMD_STATE_DONE);
    assign host_commandHost_error = (command_host_state == CMD_STATE_ERROR);
    assign host_commandCore_request = 1'b0;

    logic [15:0] cmd_opcode;
    assign cmd_opcode = reg_command_host_0[15:0];

    logic [23:0] reg_config_color;

    assign rom_write_enable  = rom_write_active;
    assign rom_write_address = rom_write_base_address + rom_write_index;

    always_comb begin
        case (rom_write_index)
            2'd0: rom_write_data = rom_write_word[7:0];
            2'd1: rom_write_data = rom_write_word[15:8];
            2'd2: rom_write_data = rom_write_word[23:16];
            default: rom_write_data = rom_write_word[31:24];
        endcase
    end

    always_ff @(posedge clk_10mhz) begin
        if (reset) begin
            mem_busy          <= 1'b0;
            host_mem_dataRead  <= 32'h0;
            reg_command_host_0 <= 32'h0;
            reg_command_host_1 <= 32'h0;
            command_host_state <= CMD_STATE_IDLE;
            reg_core_setup     <= 1'b0;
            reg_core_reset     <= 1'b1;
            reg_core_focus     <= 1'b0;
            rom_write_active   <= 1'b0;
            rom_write_index    <= 2'd0;
            rom_write_base_address <= 12'h200;
            rom_write_word     <= 32'h0;

            reg_config_color   <= 24'hFFFFFF;
        end else begin
            // Host memory interface
            if (rom_write_active) begin
                // The VHDL memory writes the currently selected byte on this
                // edge. Acknowledge only after byte three has been written.
                if (rom_write_index == 2'd3) begin
                    rom_write_active <= 1'b0;
                    mem_busy <= 1'b1;
                end else begin
                    rom_write_index <= rom_write_index + 1'b1;
                    mem_busy <= 1'b0;
                end
            end else if (host_mem_enable && !mem_busy) begin
                if (host_mem_write &&
                    host_mem_address >= ADDR_ROM_START &&
                    host_mem_address < ADDR_ROM_END) begin
                    rom_write_active <= 1'b1;
                    rom_write_index <= 2'd0;
                    rom_write_base_address <=
                        12'h200 + host_mem_address[11:0];
                    rom_write_word <= host_mem_dataWrite;
                    mem_busy <= 1'b0;
                end else begin
                    mem_busy <= 1'b1;

                    if (host_mem_write) begin
                        case (host_mem_address)
                            ADDR_REG0: reg_command_host_0 <= host_mem_dataWrite;
                            ADDR_REG1: reg_command_host_1 <= host_mem_dataWrite;
                            ADDR_CONFIG_COLOR: reg_config_color <= host_mem_dataWrite;
                            default: ;
                        endcase
                    end else begin
                        case (host_mem_address)
                            ADDR_REG0: host_mem_dataRead <= reg_command_host_0;
                            ADDR_REG1: host_mem_dataRead <= reg_command_host_1;
                            default:   host_mem_dataRead <= 32'h0;
                        endcase
                    end
                end
            end else begin
                mem_busy <= 1'b0;
            end

            // Host command channel
            if (host_commandHost_request) begin
                if (command_host_state == CMD_STATE_IDLE) begin
                    command_host_state <= CMD_STATE_DONE;
                    reg_command_host_0 <= 32'h0;

                    if (cmd_opcode == CMD_GET_STATUS) begin
                        reg_command_host_0 <= reg_core_setup
                            ? (reg_core_reset
                                ? {29'd0, STATUS_CORE_HALT}
                                : {29'd0, STATUS_CORE_RUN})
                            : {29'd0, STATUS_SETUP};
                    end else if (cmd_opcode == CMD_SETUP_COMPLETE) begin
                        reg_core_setup <= 1'b1;
                    end else if (cmd_opcode == CMD_CORE_RUN) begin
                        reg_core_reset <= 1'b0;
                    end else if (cmd_opcode == CMD_CORE_HALT) begin
                        reg_core_reset <= 1'b1;
                    end else if (cmd_opcode == CMD_NOTIFY_FOCUS) begin
                        reg_core_focus <= reg_command_host_1[0];
                    end else if (cmd_opcode == CMD_FILE_WRITE_START ||
                                 cmd_opcode == CMD_FILE_WRITE_END) begin
                        // File ID and size are not needed: files.json limits
                        // file 0 to the available CHIP-8 program memory.
                    end else begin
                        // Unknown command opcode
                        command_host_state <= CMD_STATE_ERROR;
                    end
                end
            end else begin
                command_host_state <= CMD_STATE_IDLE;
            end
        end
    end

    // =========================================================================
    // Video: frame timing
    // =========================================================================
    // (10 MHz) / (320 * 521) = ~59.98 Hz
    localparam H_ACTIVE = 240, H_TOTAL = 320;
    localparam V_ACTIVE = 160, V_TOTAL = 521;

    logic [9:0] h_cnt = '0;
    logic [9:0] v_cnt = '0;
    always_ff @(posedge clk_10mhz) begin
        if (reset || reg_core_reset) begin
            h_cnt <= '0;
            v_cnt <= '0;
        end else begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= '0;
                if (v_cnt == V_TOTAL - 1)
                    v_cnt <= '0;
                else
                    v_cnt <= v_cnt + 1'b1;
            end else begin
                h_cnt <= h_cnt + 1'b1;
            end
        end
    end

    assign video_hblank = (h_cnt >= H_ACTIVE);
    assign video_vblank = (v_cnt >= V_ACTIVE);
    assign video_dataEnable = !video_hblank && !video_vblank;

    // =========================================================================
    // CHIP-8 engine
    // =========================================================================
    logic        chip8_reset;
    logic        chip8_run_enable;
    logic [15:0] chip8_keypad;
    logic [5:0]  chip8_pixel_x;
    logic [4:0]  chip8_pixel_y;
    logic        chip8_pixel_on;
    logic        chip8_sound_active;

    assign chip8_reset      = reset || reg_core_reset;
    assign chip8_run_enable = !reg_core_reset && reg_core_focus;

    // Default controller mapping. This can be made configurable per game later.
    always_comb begin
        chip8_keypad = 16'h0000;
        chip8_keypad[4'h2] = input_buttons_up;
        chip8_keypad[4'h8] = input_buttons_down;
        chip8_keypad[4'h4] = input_buttons_left;
        chip8_keypad[4'h6] = input_buttons_right;
        chip8_keypad[4'h5] = input_buttons_a;
        chip8_keypad[4'h0] = input_buttons_b;
        chip8_keypad[4'h1] = input_buttons_x;
        chip8_keypad[4'h3] = input_buttons_y;
        chip8_keypad[4'hA] = input_buttons_l;
        chip8_keypad[4'hB] = input_buttons_r;
        chip8_keypad[4'hC] = input_buttons_start;
        chip8_keypad[4'hD] = input_buttons_select;
    end

    chip8_engine engine (
        .clock      (clk_10mhz),
        .reset      (chip8_reset),
        .run_enable (chip8_run_enable),
        .keypad     (chip8_keypad),
        .pixel_x    (chip8_pixel_x),
        .pixel_y    (chip8_pixel_y),
        .pixel_on   (chip8_pixel_on),
        .sound_active      (chip8_sound_active),
        .rom_write_enable  (rom_write_enable),
        .rom_write_address (rom_write_address),
        .rom_write_data    (rom_write_data)
    );

    // Scale 64x32 to 192x96 (3x) and center it in the 240x160 frame.
    localparam CHIP8_SCALE = 3;
    localparam CHIP8_X_OFF = 24;
    localparam CHIP8_Y_OFF = 32;

    logic chip8_screen_active;

    always_comb begin
        chip8_screen_active = 1'b0;
        chip8_pixel_x       = 6'd0;
        chip8_pixel_y       = 5'd0;

        if ((h_cnt >= CHIP8_X_OFF) &&
            (h_cnt < CHIP8_X_OFF + 64 * CHIP8_SCALE) &&
            (v_cnt >= CHIP8_Y_OFF) &&
            (v_cnt < CHIP8_Y_OFF + 32 * CHIP8_SCALE)) begin
            chip8_screen_active = 1'b1;
            chip8_pixel_x = 6'((h_cnt - CHIP8_X_OFF) / CHIP8_SCALE);
            chip8_pixel_y = 5'((v_cnt - CHIP8_Y_OFF) / CHIP8_SCALE);
        end
    end

    always_comb begin
        video_data_r = 5'h00;
        video_data_g = 5'h00;
        video_data_b = 5'h00;

        if (chip8_screen_active && chip8_pixel_on) begin
            video_data_r = reg_config_color[23:19];
            video_data_g = reg_config_color[15:11];
            video_data_b = reg_config_color[7:3];
        end
    end

    // =========================================================================
    // Audio output
    // =========================================================================
    localparam int BUZZER_FREQUENCY_HZ = 440;
    localparam int BUZZER_HALF_PERIOD_CYCLES =
        10_000_000 / (2 * BUZZER_FREQUENCY_HZ);
    localparam int BUZZER_COUNTER_WIDTH =
        $clog2(BUZZER_HALF_PERIOD_CYCLES);

    logic [BUZZER_COUNTER_WIDTH-1:0] buzzer_counter = '0;
    logic buzzer_phase = 1'b0;

    always_ff @(posedge clk_10mhz) begin
        if (chip8_reset || !chip8_run_enable || !chip8_sound_active) begin
            buzzer_counter <= '0;
            buzzer_phase   <= 1'b0;
        end else if (buzzer_counter ==
                     BUZZER_COUNTER_WIDTH'(BUZZER_HALF_PERIOD_CYCLES - 1)) begin
            buzzer_counter <= '0;
            buzzer_phase   <= !buzzer_phase;
        end else begin
            buzzer_counter <= buzzer_counter + 1'b1;
        end
    end

    // AudioV0 carries signed PCM. Alternating equally around zero produces an
    // audible square wave without the DC offset of a constant positive sample.
    assign audio_left = !chip8_sound_active ? 16'sh0000 :
                        buzzer_phase         ? -16'sh2000 : 16'sh2000;
    assign audio_right = audio_left;
endmodule
