{ pkgs, fetchurl, fetchFromGitHub, llvmPackages }:
let
  pkgsX = import <nixos> {
    llvmPackages_8 = llvmPackages;
    config = { allowUnsupportedSystem = true; };
    crossSystem = {
      config = "wasm64-unknown-wasi";
      libc = "wasilibc";
      useLLVM = true;
      # useLLVM = true;
    };
  };

  csound-repo-data = with builtins;
    fromJSON (readFile ../csound-repo-data.json);
  sndfile = fetchurl {
    url = "http://www.mega-nerd.com/libsndfile/files/libsndfile-1.0.25.tar.gz";
    sha256 = "59016dbd326abe7e2366ded5c344c853829bebfd1702ef26a07ef662d6aa4882";
  };
  wasilibc = pkgsX.stdenv.callPackage ./wasilibc.nix {};
in
llvmPackages.stdenv.mkDerivation {
  version = csound-repo-data.rev;
  name = "libcsound-wasi-${csound-repo-data.rev}";
  src = fetchFromGitHub csound-repo-data;
  buildInputs = [ pkgsX.libsndfile pkgsX.clang_8 pkgsX.cmake ];

  buildPhase = ''
    # Download and build libsndfile
    mkdir -p build/deps && cd build
    tar -xzf ${sndfile} -C ./deps
    substituteInPlace deps/libsndfile-1.0.25/src/sndfile.c \
      --replace 'assert (sizeof (sf_count_t) == 8) ;' ""
    cd deps/libsndfile-1.0.25

    CC=clang ./configure \
      --enable-static \
      --disable-shared \
      --disable-libtool-lock \
      --disable-cpu-clip \
      --disable-sqlite \
      --disable-alsa \
      --disable-external-libs \
      --build=i686
    make
    cp ./src/.libs/libsndfile.a libsndfile-wasm.a
    cp ${./CsoundObjWasi.c} ./
    cp ${ ./CmakeListsWasi.cmake } ../CmakeLists.txt
    cmake ../ \
      -DSNDFILE_H_PATH=./deps/libsndfile-1.0.25/src \
      -DLIBSNDFILE_LIBRARY=./deps/libsndfile-1.0.25/libsndfile-wasm.a


  '';
  installPhase = ''
    mkdir -p $out/lib
    touch $out/lib/success.txt
  '';
}
