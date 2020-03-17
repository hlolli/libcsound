with import <nixpkgs> {
  # overlays = [ overlay ];
  config = { allowUnsupportedSystem = true; };
  crossSystem = {
    config = "wasm32-unknown-wasi";
    libc = "wasilibc";
    useLLVM = true;
  };
};
pkgs.callPackage
  (
    { mkShell }:
    let
      pkgsOrig = import <nixpkgs> {};
      wasilibc = pkgs.callPackage ./wasilibc.nix {
        stdenv = pkgs.stdenv;
        fetchFromGitHub = pkgs.fetchFromGitHub;
        lib = pkgs.lib;
      };
      # preprocFlags = ''
      #   -DUSE_DOUBLE=1 \
      #   -DLINUX=0 \
      #   -DO_NDELAY=O_NONBLOCK \
      #   -DHAVE_STRLCAT=1 \
      #   -DMEMDEBUG=1 \
      #   -Wno-unknown-attributes \
      #   -Wno-shift-op-parentheses \
      #   -Wno-bitwise-op-parentheses \
      #   -Wno-many-braces-around-scalar-init \
      #   -Wno-macro-redefined \
      # '';
      testP = pkgs.stdenv.mkDerivation {
        name = "short-test-deleteme";
        phases = [ "buildPhase" ];
        nosource = true;
        buildPhase = ''
          cp ${./test/read_file.c} ./read_file.c
          clang -O3 -flto \
            -emit-llvm --target=wasm32-wasi -c -S \
            -I${wasilibc}/include \
            -D__wasi__=1 \
            read_file.c
          ${pkgsOrig.llvm_9}/bin/llc -march=wasm32 -filetype=obj read_file.s
          ls
          ${pkgsOrig.lld_9}/bin/wasm-ld \
            --lto-O3 \
            --export-all \
            --no-entry \
            -L${wasilibc}/lib \
            -lc -lm -ldl \
            -o libcsound.wasm \
            read_file.s.o

            mkdir $out
            cp libcsound.wasm $out
        '';
      };
    in
      mkShell {
        nativeBuildInputs = [];
        buildInputs = [ testP ];
        shellHook = ''
          echo ${testP}
          rm -f .lib/libcsound.wasm
          mkdir -p lib
          cp ${testP}/libcsound.wasm lib
          chmod 0600 lib/libcsound.wasm
          exit 0
        '';
      }
  ) {}
