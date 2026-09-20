# CHIP-8 Core for Game Bub

An FPGA CHIP-8 core for the Game Bub handheld.

The project currently contains a working Game Bub wrapper and a VHDL framebuffer test pattern. The CHIP-8 CPU, timers, instructions, and ROM loading are not implemented yet.

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
