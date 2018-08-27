{ stdenv, llvm, fetchFromGitHub, cmake, python, gtest, ... }:

let
  rev = "1.38.11";
  gcc = if stdenv.cc.isGNU then stdenv.cc.cc else stdenv.cc.cc.gcc;
in
stdenv.mkDerivation rec {
  name = "emscripten-fastcomp-${rev}";

  src = fetchFromGitHub {
    owner = "kripken";
    repo = "emscripten-fastcomp";
    sha256 = "1rli0m4xwvy0k0bccl471vw7m1qch4cikr7k5j76bhkh27pvc64i";
    inherit rev;
  };

  srcFL = fetchFromGitHub {
    owner = "kripken";
    repo = "emscripten-fastcomp-clang";
    sha256 = "076dicy6r8j8hsf16bipfjd2avy78xqr5fjkwmvly70bx895bwqd";
    inherit rev;
  };

  nativeBuildInputs = [ cmake python gtest ];
  preConfigure = ''
    cp -Lr ${srcFL} tools/clang
    chmod +w -R tools/clang
  '';
  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DLLVM_TARGETS_TO_BUILD='X86;JSBackend'"
    "-DLLVM_INCLUDE_EXAMPLES=OFF"
    "-DLLVM_INCLUDE_TESTS=ON"
    #"-DLLVM_CONFIG=${llvm}/bin/llvm-config"
    "-DLLVM_BUILD_TESTS=ON"
    "-DCLANG_INCLUDE_TESTS=ON"
  ] ++ (stdenv.lib.optional stdenv.isLinux
    # necessary for clang to find crtend.o
    "-DGCC_INSTALL_PREFIX=${gcc}"
  );
  enableParallelBuilding = true;

  passthru = {
    isClang = true;
    inherit gcc;
  };

  meta = with stdenv.lib; {
    homepage = https://github.com/kripken/emscripten-fastcomp;
    description = "Emscripten LLVM";
    platforms = platforms.all;
    maintainers = with maintainers; [ qknight matthewbauer ];
    license = stdenv.lib.licenses.ncsa;
  };
}
