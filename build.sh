#!/usr/bin/env bash
nix-build -E "with import <nixpkgs> {}; callPackage ./build_libcsound_wasm.nix {}" && \
    rm -rf lib && \
    mkdir lib && \
    cp -Lrf ./result/lib/* ./lib && \
    chmod +w ./lib -R
