# CHIP-8 Core for Game Bub

An FPGA CHIP-8 core for the Game Bub handheld.

The project contains a Game Bub wrapper, a VHDL CHIP-8 CPU and framebuffer, 60 Hz delay and sound timers, and ROM loading. Instructions start at about 700 per second from the 10 MHz system clock; the instruction rate is set by `INSTRUCTION_DIVIDER` in `rtl/chip8_pkg.vhdl`.

## Structure

- `rtl/chip8_core.sv`: Game Bub host, video, input, and audio wrapper
- `rtl/chip8_engine.vhdl`: CHIP-8 engine and 64 x 32 framebuffer

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
