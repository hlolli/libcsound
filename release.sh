#!/bin/sh

# Expects nix package manager and nodejs!
cd nix

nix-build -E 'with import <nixpkgs> {}; callPackage ./wasm.nix {}'

sudo cp -Lrf ./result/* ../

cd ../

chmod +rw libcsound.js

node datauri.js
