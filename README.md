# Onward!

A 64-bit forth-based operating system loosely inspired by [Dusk OS](http://duskos.org/)
and the Forth concept of users creating new languages to perform specific tasks.

## Goals

The high-level goal can be simply put: Everything that *can* be written in Forth,
*should* be written in Forth.

Broken down into actionable steps, this can be achieved through the following tasks:

- [ ] Create a minimal, extensible Forth interpreter
- [ ] Write an assembler (or something with equal low-level power) in this Forth
- [ ] Implement a kernel shell for real-time modification / iteration
- [ ] Create hardware abstractions for communication with I/O such as the keyboard, screen, and storage devices
  + Has a host of prerequisites, such as hardware interupt capabilities and task scheduling
- [ ] Create dictionaries for performing common tasks (a la Unix' `stdio.h`, etc)
- [ ] Maybe transition to a user shell at some point?
- [ ] Port some programs to test out the system
  + Ideas: One of the simpler `coreutils` tools, tetris, ...

## Building / Running

```sh
make run # Builds the disk image (build/boot.img) and runs QEMU
```

## Architecture

Here's a rough sketch of the architecture as of writing this:

- `src/bootloader.s` - the Stage 1 bootloader; sets up a Fat16 filesystem and loads the Stage 2 bootloader
- `src/stage2.s` - the Stage 2 bootloader; gets the system ready for the Forth kernel by loading it into memory,
  setting up memory paging, and transitioning into 64-bit Long Mode
- `src/kernel.s` - (TODO): sets the stage for Forth; implements the rudimentary interpreter and executes `kernel.fs`
- `src/kernel.fs` - (TODO): the kernel!
