{ nixpkgs ? import <nixpkgs> {} }:
let
  wasilibc2 = nixpkgs.callPackage ./wasilibc.nix {
    stdenv = nixpkgs.stdenv;
    fetchFromGitHub = nixpkgs.fetchFromGitHub;
    lib = nixpkgs.lib;
  };
  overlay = self: super: {
    self.wasilibc = wasilibc2;
  };
in
  with import <nixpkgs> {
    overlays = [ overlay ];
    config = { allowUnsupportedSystem = true; };
    crossSystem = {
      config = "wasm32-unknown-wasi";
      libc = "wasilibc";
      useLLVM = true;
    };
  };
  pkgs.callPackage
    (
      { mkShell, csound, llvm_8, libsndfile }:
      let
        libsndfileP = import ./sndfileWasi.nix {
          inherit pkgs;
        };
        # wasilibc = pkgs.callPackage ./wasilibc.nix {
        #   stdenv = pkgs.stdenv;
        #   fetchFromGitHub = pkgs.fetchFromGitHub;
        #   lib = pkgs.lib;
        # };
        # llvm-wrapped = pkgs.llvmPackages.lldClangNoCompilerRt.overrideAttrs
        #   (x: {
        #     libc = wasilibc;
        #   }
        #   );
        # llvm-wrapped = pkgs.wrapCCWith rec {
        #   cc = pkgs.stdenv.cc.cc;
        #   bintools = pkgs.wrapBintoolsWith {
        #     inherit (pkgs.llvmPackages_8) bintools;
        #     libc = wasilibc;
        #   };
        # };
        csoundP = (pkgs.csound.override {
          stdenv = pkgs.stdenv; # pkgs.overrideCC pkgs.stdenv llvm-wrapped;
          libsndfile = libsndfileP;
          libsamplerate = null;
          boost = null;
          gettext = null;
          alsaLib = null;
          libpulseaudio = null;
          libjack2 = null;
          liblo = null;
          ladspa-sdk = null;
          fluidsynth = null;
          eigen = null;
          curl = null;
          tcltk = null;
          fltk = null;
        }
        ).overrideAttrs
          (old: {
            src = fetchFromGitHub {
              owner = "hlolli";
              repo = "csound";
              rev = "e1fcf75277ad157a8fecf8568af14e7a6af42e09";
              sha256 = "1dslw5hmgpw8m38czxdzsq20qpmm2nar346hdis4yn9ln53xpkmb";
            };
            buildInputs = [ libsndfileP ];
            patches = [ ./setjmp.patch ];
            postPatch = ''
              ls ${wasilibc}
              echo ${wasilibc}
                cp ${./CmakeListsWasi.cmake} ./CMakeLists.txt
                find ./ -type f -exec sed -i -e 's/HAVE_PTHREAD/FFS_NO_PTHREADS/g' {} \;
                find ./ -type f -exec sed -i -e 's/#ifdef LINUX/#ifdef _NOT_LINUX_/g' {} \;
                find ./ -type f -exec sed -i -e 's/if(LINUX)/if(_NOT_LINUX_)/g' {} \;
                find ./ -type f -exec sed -i -e 's/if (LINUX)/if(_NOT_LINUX_)/g' {} \;
                substituteInPlace Top/csmodule.c \
                  --replace '#include <dlfcn.h>' ""
            '';
            cmakeFlags = [
              "-DWASM=1"
              "-DVERBOSE=1"
              "-DLIBSNDFILE_LIBRARY=${libsndfileP.out}/lib/libsndfile.a"
              "-DBUILD_SERIAL_OPCODES=OFF"
              "-DBUILD_DSSI_OPCODES=OFF"
              "-DBUILD_WEBSOCKET_OPCODE=OFF"
              "-DUSE_IPMIDI=OFF"
              "-DBUILD_CXX_INTERFACE=OFF"
              "-DHAVE_SPRINTF_L=0"
              "-DLLVM_TARGETS_TO_BUILD="
              "-DLLVM_TARGET_ARCH=wasm32"
              "-DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=WebAssembly"
              "-DCMAKE_INSTALL_PREFIX=$out"
            ];
            installPhase = ''
              mkdir $out
              cp -rf ./* $out
              # substituteInPlace cmake_install.cmake \
              #   --replace '/sysroot' sysroot
              # cmake -P cmake_install.cmake -DCMAKE_INSTALL_PREFIX=$out
            '';
          }
          );
      in
        mkShell {
          nativeBuildInputs = [];
          buildInputs = [ csoundP ];
          shellHook = ''
            echo ${csoundP}
          '';
        }
    ) {}
