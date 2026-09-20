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
    input  wire logic [3:0]     host_mem_writeStrobe,
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
    localparam ADDR_REG0 = 32'hF0000000;
    localparam ADDR_REG1 = 32'hF0000004;
    localparam CMD_GET_STATUS     = 16'h0000;
    localparam CMD_CORE_RUN       = 16'h0100;
    localparam CMD_CORE_HALT      = 16'h0101;
    localparam CMD_SETUP_COMPLETE = 16'h0102;
    localparam CMD_NOTIFY_FOCUS   = 16'h0200;

    logic reg_core_setup = 1'b0;
    logic reg_core_reset = 1'b1;
    logic reg_core_focus = 1'b0;

    logic [31:0] reg_command_host_0, reg_command_host_1;
    logic mem_busy;

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

    always_ff @(posedge clk_10mhz) begin
        if (reset) begin
            host_mem_dataRead  <= 32'h0;
            reg_command_host_0 <= 32'h0;
            reg_command_host_1 <= 32'h0;
            command_host_state <= CMD_STATE_IDLE;
            reg_core_setup     <= 1'b0;
            reg_core_reset     <= 1'b1;
            reg_core_focus     <= 1'b0;

            reg_config_color   <= 24'hFFFFFF;
        end else begin
            // Host memory interface
            if (host_mem_enable && !mem_busy) begin
                mem_busy      <= 1'b1;

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
            end else begin
                mem_busy      <= 1'b0;
            end

            // Host command channel
            if (host_commandHost_request) begin
                if (command_host_state == CMD_STATE_IDLE) begin
                    command_host_state <= CMD_STATE_DONE;
                    reg_command_host_0 <= 32'h0;

                    if (cmd_opcode == CMD_GET_STATUS) begin
                        reg_command_host_0 <= reg_core_setup
                            ? (reg_core_reset ? STATUS_CORE_HALT : STATUS_CORE_RUN)
                            : (STATUS_SETUP);
                    end else if (cmd_opcode == CMD_SETUP_COMPLETE) begin
                        reg_core_setup <= 1'b1;
                    end else if (cmd_opcode == CMD_CORE_RUN) begin
                        reg_core_reset <= 1'b0;
                    end else if (cmd_opcode == CMD_CORE_HALT) begin
                        reg_core_reset <= 1'b1;
                    end else if (cmd_opcode == CMD_NOTIFY_FOCUS) begin
                        reg_core_focus <= reg_command_host_1[0];
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
    logic frame_tick;

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

    always_comb begin
        video_data_r = 5'h1F;
        video_data_g = 5'h1F;
        video_data_b = 5'h1F;
    end

    // =========================================================================
    // Audio output
    // =========================================================================
    localparam CLOCKS_PER_SAMPLE = 208; // 10MHz / 208 = 48.077 kHz

    // Frequency counters (Sample Rate / (2 * MAX))
    localparam TONE_WALL   = 106; // ~226 Hz
    localparam TONE_PADDLE = 53;  // ~452 Hz
    localparam TONE_LOSE   = 133;  // ~180 Hz

    // Durations in sample ticks
    localparam DURATION_WALL    = 3072;  // 64 ms
    localparam DURATION_PADDLE  = 3072;  // 64 ms
    localparam DURATION_LOSE    = 12288; // 256 ms

    logic [7:0]  sample_counter = '0;
    logic        sample_tick;
    logic [15:0] sound_counter  = '0;
    logic [8:0]  tone_counter   = '0;
    logic [8:0]  tone_max       = '0;
    logic        square_wave    = 1'b0;

    // 48 kHz tick generator
    always_ff @(posedge clk_10mhz) begin
        if (reset || sample_counter == CLOCKS_PER_SAMPLE - 1) begin
            sample_counter <= '0;
            sample_tick    <= 1'b1;
        end else begin
            sample_counter <= sample_counter + 1'b1;
            sample_tick    <= 1'b0;
        end
    end

    // 16-bit signed output
    assign audio_left = 16'sh2000;
    assign audio_right = audio_left;
endmodule
