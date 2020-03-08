#!/usr/bin/env bash
nix-build -E "with import <nixpkgs> { }; callPackage ./nix/build_wasi.nix { llvmPackages = pkgs.llvmPackages_8; }" --show-trace
