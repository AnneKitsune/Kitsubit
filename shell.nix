# This shell.nix provides the same environment as the flake.nix file
# for use with nix-shell
{
  pkgs ? import <nixpkgs> {},
  system ? builtins.currentSystem,
}:

let
  # Import the flake
  flake = builtins.getFlake "github:bandithedoge/devkitNix";

  # Apply the overlay to get access to devkitNix
  pkgs-with-devkit = import <nixpkgs> {
    overlays = [ flake.overlays.default ];
  };

in
pkgs-with-devkit.mkShell.override {
  stdenv = pkgs-with-devkit.devkitNix.stdenvARM;
} {
  # Add any additional packages if needed
  buildInputs = with pkgs-with-devkit; [
    # Add any additional tools here if needed
  ];
}
