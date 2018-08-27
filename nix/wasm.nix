{ stdenv, nodejs, fetchFromGitHub, fetchurl,
  flex, bison, alsaLib, cmake, libsndfile}:

let
    emscriptenfastcomp = with import <nixpkgs> {}; callPackage ./emscripten/fastcomp {};
    emscripten = with import <nixpkgs> {}; callPackage ./emscripten {};

in stdenv.mkDerivation rec {
    version = "6.11.0-0";
    name = "csound_wasm-${version}";

    src = fetchFromGitHub {
      owner = "csound";
      repo = "csound";
      rev = "9b19ad44a81916d322588d061e4eabfe64e9a705";
      sha256 = "0rvbrlq3q4miyr0z7b0820a4bg2a4l53594m7p8qjylf98ri0b0l";
    };

    sndfile = fetchurl {
      url = "http://www.mega-nerd.com/libsndfile/files/libsndfile-1.0.25.tar.gz";
      sha256 = "59016dbd326abe7e2366ded5c344c853829bebfd1702ef26a07ef662d6aa4882";
    };

    buildInputs = [ nodejs cmake flex bison alsaLib libsndfile];

    buildPhase = ''
      export EMSCRIPTEN=${emscripten}/share/emscripten
      export EM_CACHE=`pwd`/.emscripten_cache
      export PATH=$PATH:${emscripten}/bin
      cd ../
      echo "#define USE_DOUBLE" > include/float-version.h
      cd Emscripten

      # Download and build libsndfile
      mkdir -p deps
      tar -xzf ${sndfile} -C ./deps
      patch deps/libsndfile-1.0.25/src/sndfile.c < \
        ./patches/sndfile.c.patch
      cd deps/libsndfile-1.0.25

      emconfigure ./configure \
        --enable-static \
        --disable-shared \
        --disable-libtool-lock \
        --disable-cpu-clip \
        --disable-sqlite \
        --disable-alsa \
        --disable-external-libs \
        --build=i686
        
      emmake make
      cp ./src/.libs/libsndfile.a libsndfile-wasm.a

      # Build csound-wasm
      cd ../../
      mkdir -p build
      cd build

      cmake -DCMAKE_VERBOSE_MAKEFILE=1 \
            -DUSE_COMPILER_OPTIMIZATIONS=0 \
            -DWASM=1 \
            -DINIT_STATIC_MODULES=0 \
            -DUSE_DOUBLE=NO \
            -DBUILD_MULTI_CORE=0 \
            -DBUILD_JACK_OPCODES=0 \
            -DEMSCRIPTEN=1 \
            -DCMAKE_TOOLCHAIN_FILE=$EMSCRIPTEN/cmake/Modules/Platform/Emscripten.cmake \
            -DCMAKE_MODULE_PATH=$EMSCRIPTEN/cmake \
            -DCMAKE_BUILD_TYPE=Release -G"Unix Makefiles" \
            -DHAVE_BIG_ENDIAN=0 \
            -DCMAKE_16BIT_TYPE="unsigned short"  \
            -DHAVE_STRTOD_L=0 \
            -DBUILD_STATIC_LIBRARY=YES \
            -DHAVE_ATOMIC_BUILTIN=0 \
            -DHAVE_SPRINTF_L=NO \
            -DUSE_GETTEXT=NO \
            -DLIBSNDFILE_LIBRARY=../deps/libsndfile-1.0.25/libsndfile-wasm.a \
            -DSNDFILE_H_PATH=../deps/libsndfile-1.0.25/src \
            ../..

      emmake make csound-static -j6
      emcc -s LINKABLE=1 \
           -s ASSERTIONS=0 \
           ../src/FileList.c \
           -Iinclude \
           -o FileList.bc
           
      emcc -s LINKABLE=1 \
           -s ASSERTIONS=0 \
           ../src/CsoundObj.c \
           -I../../include \
           -Iinclude \
           -o CsoundObj.bc

      # Build libcsound.js
      emcc -v -O2 -g4 \
          -DINIT_STATIC_MODULES=0 \
          -s WASM=1 \
          -s ASSERTIONS=1 \
          -s "BINARYEN_METHOD='native-wasm'" \
          -s LINKABLE=1 \
          -s RESERVED_FUNCTION_POINTERS=1 \
          -s TOTAL_MEMORY=268435456 \
          -s ALLOW_MEMORY_GROWTH=1 \
          -s NO_EXIT_RUNTIME=0 \
          -s BINARYEN_ASYNC_COMPILATION=1 \
          -s MODULARIZE=1 \
          -s EXPORT_NAME=\"'libcsound'\" \
          -s EXTRA_EXPORTED_RUNTIME_METHODS='["FS", "ccall", "cwrap"]' \
          CsoundObj.bc FileList.bc libcsound.a \
          ../deps/libsndfile-1.0.25/libsndfile-wasm.a \
          -o libcsound.js
    '';

    installPhase = ''
      mkdir -p $out
      cp ./libcsound.js $out
      cp ./libcsound.wasm $out
    '';

}
