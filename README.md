# CHIP-8 Core for Game Bub

An FPGA CHIP-8 core for the Game Bub handheld.

The project contains a Game Bub wrapper, a VHDL CHIP-8 CPU and framebuffer, 60 Hz delay and sound timers, and ROM loading. Instructions start at about 700 per second from the 10 MHz system clock; the instruction rate is set by `INSTRUCTION_DIVIDER` in `rtl/chip8_pkg.vhdl`.

## AI-assisted development

I used AI agents while developing this project to:

- learn how the Game Bub template repository, from which this project was forked, is structured and how a core integrates with its framework;
- explore how VHDL modules can be included in the build and connected to the existing SystemVerilog top-level module, `rtl/chip8_core.sv`;
- review my previous CHIP-8 core and suggest improvements to its organization, readability, and integration with the Game Bub framework;
- understand how the settings metadata system works;
- connect the CHIP-8 framebuffer to the framework's video output.

I reviewed and tested the resulting implementation and remain responsible for the final design.

## Structure

- `rtl/chip8_core.sv`: SystemVerilog top level that connects the Game Bub host, video, input, and audio interfaces to the VHDL engine
- `rtl/chip8_pkg.vhdl`: shared CHIP-8 constants, data types, and opcode helpers
- `rtl/chip8_cpu.vhdl`: CHIP-8 instruction decoder and execution state machine, including keypad input, timers, drawing, and sound
- `rtl/chip8_memory.vhdl`: 4 KiB CHIP-8 memory with the built-in hexadecimal font
- `rtl/chip8_engine.vhdl`: joins the CPU, memory, and 64 x 32 monochrome framebuffer and exposes pixels to the SystemVerilog wrapper
- `metadata/core.json`: core identity and target bitstream metadata
- `metadata/files.json`: supported ROM extensions, load address, and maximum ROM size
- `metadata/settings.json`: user-facing display color setting mapped to the wrapper's configuration register
- `testbench/chip8_engine_tb.vhdl`: VHDL testbench for ROM loading, instruction timing, and framebuffer drawing

Keep VHDL source files using the `.vhdl` extension so the build framework includes them.

## Build

Vivado must be available in `PATH`.

```sh
./mill --no-server root.buildCore --target gamebub_rev4
```

The bitstream is generated at:

```text
build/Chip8Core-gamebub_rev4/Chip8Core-gamebub_rev4.bit
```

See the [Game Bub core development documentation](https://docs.gamebub.net/developing-cores/overview/) for framework details.
