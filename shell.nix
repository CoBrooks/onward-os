{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShellNoCC {
  nativeBuildInputs = with pkgs; [
    fasm
    gnumake
  ];

  packages = with pkgs; [
    qemu
    bochs
    gdb
  ];
}
