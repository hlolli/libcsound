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
      libsndfileP = import ./sndfileWasi.nix {
        inherit pkgs;
      };
      wasilibc = pkgs.callPackage ./wasilibc.nix {
        stdenv = pkgs.stdenv;
        fetchFromGitHub = pkgs.fetchFromGitHub;
        lib = pkgs.lib;
      };
      preprocFlags = ''
        -DRD_OPTS=0644 \
        -DWR_OPTS=0644 \
        -DO_RDONLY=00 \
        -DO_WRONLY=01 \
        -DO_CREAT=0100 \
        -DO_TRUNC=01000 \
        -DO_NONBLOCK=04000 \
        -DO_NDELAY=04000 \
        -DF_GETFL=3 \
        -DF_SETFL=4 \
        -DLINUX=0 \
        -DRTLD_GLOBAL=0 \
        -DRTLD_LAZY=1 \
        -DRTLD_NOW=2 \
        -DHAVE_STRLCAT=1 \
        -DPARSER_DEBUG=1 \
        -Wno-unknown-attributes \
        -Wno-shift-op-parentheses \
        -Wno-bitwise-op-parentheses \
        -Wno-many-braces-around-scalar-init \
        -Wno-macro-redefined \
      '';
      csoundP = pkgs.stdenv.mkDerivation {
        name = "csound-wasi";
        src = fetchFromGitHub {
          owner = "hlolli";
          repo = "csound";
          rev = "e1fcf75277ad157a8fecf8568af14e7a6af42e09";
          sha256 = "1dslw5hmgpw8m38czxdzsq20qpmm2nar346hdis4yn9ln53xpkmb";
        };

        buildInputs = [ libsndfileP pkgsOrig.flex pkgsOrig.bison ];
        patches = [ ./setjmp.patch ./argdecode.patch ];
        postPatch = ''
          echo ${wasilibc}

          find ./ -type f -exec sed -i -e 's/HAVE_PTHREAD/FFS_NO_PTHREADS/g' {} \;
          find ./ -type f -exec sed -i -e 's/#ifdef LINUX/#ifdef _NOT_LINUX_/g' {} \;
          find ./ -type f -exec sed -i -e 's/if(LINUX)/if(_NOT_LINUX_)/g' {} \;
          find ./ -type f -exec sed -i -e 's/if (LINUX)/if(_NOT_LINUX_)/g' {} \;
          find ./ -type f -exec sed -i -e 's/defined(LINUX)/defined(_NOT_LINUX_)/g' {} \;
          # find ./ -type f -exec sed -i -e 's/u?int_least64_t/uint64_t/g' {} \;

          touch include/float-version.h
          substituteInPlace Top/csmodule.c \
            --replace '#include <dlfcn.h>' ""
          substituteInPlace Engine/csound_orc.y \
            --replace 'csound_orcnerrs' "0"
          substituteInPlace include/sysdep.h \
            --replace '#if defined(HAVE_GCC3) && !defined(SWIG)' \
                      '#if defined(HAVE_GCC3) && !defined(__wasi__)'


          substituteInPlace Top/one_file.c \
             --replace '#include "corfile.h"' \
               '#include "corfile.h"
               #include <sys/types.h>
               #include <sys/stat.h>
               #include <string.h>
               #include <stdlib.h>
               #include <unistd.h>
               #include <fcntl.h>
               #include <errno.h>' \
             --replace 'umask(0077);' ""

          substituteInPlace Engine/linevent.c \
            --replace '#include <ctype.h>' \
              '#include <ctype.h>
               #include <string.h>
               #include <stdlib.h>
               #include <unistd.h>
               #include <fcntl.h>
               #include <errno.h>'

          # substituteInPlace Engine/cs_new_dispatch.c \
          #   --replace '#include "csoundCore.h"' \
          #             '#include "csoundCore.h"
          #              #include <atomic.h>'

          substituteInPlace Engine/envvar.c \
             --replace 'UNLIKELY(getcwd(cwd, len)==NULL)' '0' \
             --replace '#include <math.h>' \
                       '#include <math.h>
                       #include <string.h>
                       #include <stdlib.h>
                       #include <unistd.h>
                       #include <fcntl.h>
                       #include <errno.h>
                       '

          substituteInPlace Top/csound.c \
            --replace 'signal(sigs[i], signal_handler);' \
                      'psignal(sigs[i], signal_handler);' \
            --replace 'HAVE_RDTSC' '__NOT_HERE___'

          substituteInPlace Top/main.c \
            --replace 'csoundUDPServerStart(csound,csound->oparms->daemon);' ""
          substituteInPlace Engine/musmon.c \
            --replace 'csoundUDPServerClose(csound);' ""

          substituteInPlace InOut/libmpadec/mp3dec.c \
            --replace '#include "csoundCore.h"' \
                      '#include "csoundCore.h"
                       #include <stdlib.h>
                       #include <stdio.h>
                       #include <sys/types.h>
                       #include <unistd.h>
                      '

          substituteInPlace Engine/new_orc_parser.c \
            --replace 'csound_orcdebug = O->odebug;' ""

          substituteInPlace Top/csound.c \
            --replace '|| defined(__MACH__)' '|| defined(__MACH__) || defined(__wasi__)'


            # --replace 'int_least64_t get_real_time(void)' 'int get_real_time(void)' \
            # --replace '(int_least64_t) tv.tv_usec' '(int) tv.tv_usec' \
            # --replace '(int_least64_t) ((uint32_t) tv.tv_sec * (uint64_t) 1000000))' \
            #   '(tv.tv_sec * 1000000))'

            # --replace 'return ((int_least64_t) tmp.LowPart + ((int_least64_t) tmp.HighPart <<32));' \
            # '#elif defined(__wasi__)
            #  struct timespec ts;
            #  __wasi_clock_time_get(0, (__wasi_timestamp_t) &ts, NULL);
            #  /* clock_gettime(CLOCK_REALTIME, &ts); */
            #  return (uint32_t) (ts.tv_sec + (ts.tv_nsec * 0.000001));'

          # struct timeval t;
          # int r = gettimeofday(&t, NULL);
          # return (double) t.tv_sec + (t.tv_usec * 0.000001);
          # #elif defined(HAVE_GETTIMEOFDAY)

          # sed -i '/^typedef long.*$/,$d' Top/csmodule.c
          # echo 'CS_NOINLINE int csoundInitStaticModules(CSOUND *csound)
          #       {return CSOUND_SUCCESS;}' >> Top/csmodule.c

          # substituteInPlace Top/csmodule.c \
          #   --replace '#ifndef NACL' '#ifndef __wasi__' \
          #   --replace 'extern long pvsbuffer_localops_init(CSOUND *, void *);' "" \
          #   --replace 'pvsbuffer_localops_init,' ""

          rm CMakeLists.txt
        '';
        configurePhase = "
          ${pkgsOrig.flex}/bin/flex -B ./Engine/csound_orc.lex > ./Engine/csound_orc.c
          ${pkgsOrig.flex}/bin/flex -B ./Engine/csound_pre.lex > ./Engine/csound_pre.c
          ${pkgsOrig.flex}/bin/flex -B ./Engine/csound_prs.lex > ./Engine/csound_prs.c
          ${pkgsOrig.flex}/bin/flex -B ./Engine/csound_sco.lex > ./Engine/csound_sco.c

          ${pkgsOrig.bison}/bin/bison -d ./Engine/csound_orc.y -o ./Engine/csound_orcparse.c
          ${pkgsOrig.bison}/bin/bison -d ./Engine/csound_sco.y -o ./Engine/csound_scoparse.c
        ";
        # -I./Opcodes -I./InOut -I./interfaces -I./Frontends
        # Engine/csound_orc.c \
        #   Engine/csound_pre.c \
        #   Engine/csound_prs.c \
        #   Engine/csound_sco.c \
        #   Engine/csound_scoparse.c \
        #   Engine/csound_orcparse.c \
        buildPhase = ''
          cp ${./CsoundObjWasi.c} ./CsoundObjWasi.c
          clang -g -emit-llvm --target=wasm32-wasi -c -S \
          -I./H -I./Engine -I./include -I./ \
          -I./InOut/libmpadec \
          -I${libsndfileP.dev}/include \
          -I${wasilibc}/include \
          -S -emit-llvm \
          -D__BUILDING_LIBCSOUND \
          -D__wasi__=1 ${preprocFlags} \
            CsoundObjWasi.c \
            Engine/csound_pre.c \
            Engine/csound_prs.c \
            Engine/csound_orc.c \
            Engine/csound_orc_semantics.c \
            Engine/csound_orc_expressions.c \
            Engine/csound_orc_optimize.c \
            Engine/csound_orc_compile.c \
            Engine/csound_orcparse.c \
            Engine/csound_scoparse.c \
            Engine/cs_par_base.c \
            Engine/cs_new_dispatch.c \
            Engine/cs_par_orc_semantic_analysis.c \
            Engine/new_orc_parser.c \
            Engine/symbtab.c \
            Engine/auxfd.c \
            Engine/cfgvar.c \
            Engine/corfiles.c \
            Engine/csound_data_structures.c \
            Engine/csound_standard_types.c \
            Engine/csound_type_system.c \
            Engine/entry1.c \
            Engine/envvar.c \
            Engine/extract.c \
            Engine/fgens.c \
            Engine/insert.c \
            Engine/linevent.c \
            Engine/memalloc.c \
            Engine/memfiles.c \
            Engine/musmon.c \
            Engine/namedins.c \
            Engine/pools.c \
            Engine/rdscor.c \
            Engine/scsort.c \
            Engine/scxtract.c \
            Engine/sort.c \
            Engine/sread.c \
            Engine/swritestr.c \
            Engine/twarp.c \
            InOut/circularbuffer.c \
            InOut/libmpadec/layer1.c \
            InOut/libmpadec/layer2.c \
            InOut/libmpadec/layer3.c \
            InOut/libmpadec/mp3dec.c \
            InOut/libmpadec/mpadec.c \
            InOut/libmpadec/synth.c \
            InOut/libmpadec/tables.c \
            InOut/libsnd.c \
            InOut/libsnd_u.c \
            InOut/midifile.c \
            InOut/midirecv.c \
            InOut/midisend.c \
            InOut/winEPS.c \
            InOut/winascii.c \
            InOut/windin.c \
            InOut/window.c \
            OOps/aops.c \
            OOps/bus.c \
            OOps/cmath.c \
            OOps/compile_ops.c \
            OOps/diskin2.c \
            OOps/disprep.c \
            OOps/dumpf.c \
            OOps/fftlib.c \
            OOps/goto_ops.c \
            OOps/midiinterop.c \
            OOps/midiops.c \
            OOps/midiout.c \
            OOps/mxfft.c \
            OOps/oscils.c \
            OOps/pffft.c \
            OOps/pstream.c \
            OOps/pvfileio.c \
            OOps/pvsanal.c \
            OOps/random.c \
            OOps/remote.c \
            OOps/schedule.c \
            OOps/sndinfUG.c \
            OOps/str_ops.c \
            OOps/ugens1.c \
            OOps/ugens2.c \
            OOps/ugens3.c \
            OOps/ugens4.c \
            OOps/ugens5.c \
            OOps/ugens6.c \
            OOps/ugrw1.c \
            OOps/ugtabs.c \
            OOps/vdelay.c \
            Opcodes/Vosim.c \
            Opcodes/afilters.c \
            Opcodes/ambicode1.c \
            Opcodes/arrays.c \
            Opcodes/babo.c \
            Opcodes/bilbar.c \
            Opcodes/bowedbar.c \
            Opcodes/butter.c \
            Opcodes/compress.c \
            Opcodes/cpumeter.c \
            Opcodes/crossfm.c \
            Opcodes/eqfil.c \
            Opcodes/fareyseq.c \
            Opcodes/fm4op.c \
            Opcodes/ftest.c \
            Opcodes/gab/hvs.c \
            Opcodes/gab/newgabopc.c \
            Opcodes/gab/sliderTable.c \
            Opcodes/gab/tabmorph.c \
            Opcodes/gendy.c \
            Opcodes/grain4.c \
            Opcodes/harmon.c \
            Opcodes/hrtfearly.c \
            Opcodes/hrtferX.c \
            Opcodes/hrtfopcodes.c \
            Opcodes/hrtfreverb.c \
            Opcodes/loscilx.c \
            Opcodes/mandolin.c \
            Opcodes/minmax.c \
            Opcodes/modal4.c \
            Opcodes/modmatrix.c \
            Opcodes/moog1.c \
            Opcodes/pan2.c \
            Opcodes/partikkel.c \
            Opcodes/phisem.c \
            Opcodes/physmod.c \
            Opcodes/physutil.c \
            Opcodes/pinker.c \
            Opcodes/pitch.c \
            Opcodes/pitch0.c \
            Opcodes/pitchtrack.c \
            Opcodes/pvs_ops.c \
            Opcodes/pvlock.c \
            Opcodes/scoreline.c \
            Opcodes/sfont.c \
            Opcodes/shaker.c \
            Opcodes/shape.c \
            Opcodes/singwave.c \
            Opcodes/spectra.c \
            Opcodes/stdopcod.c \
            Opcodes/squinewave.c \
            Opcodes/tabaudio.c \
            Opcodes/tabsum.c \
            Opcodes/tl/sc_noise.c \
            Opcodes/ugakbari.c \
            Opcodes/vaops.c \
            Opcodes/vbap.c \
            Opcodes/vbap1.c \
            Opcodes/vbap_n.c \
            Opcodes/vbap_zak.c \
            Opcodes/wpfilters.c \
            Opcodes/zak.c \
            Top/argdecode.c \
            Top/cscore_internal.c \
            Top/cscorfns.c \
            Top/csdebug.c \
            Top/csmodule.c \
            Top/getstring.c \
            Top/main.c \
            Top/new_opts.c \
            Top/one_file.c \
            Top/opcode.c \
            Top/threads.c \
            Top/threadsafe.c \
            Top/utility.c \
            Top/csound.c

            echo "Compile to wasm objects"
            for f in *.ll
              do
                ${pkgsOrig.llvm_9}/bin/llc -march=wasm32 -filetype=obj $f
            done
            echo ${pkgs.stdenv.cc.cc} ${libsndfileP.out} ${wasilibc}/lib
            echo "Link wasm obj to single exe"
            rm csound_scoparse.o
            ${pkgsOrig.lld_9}/bin/wasm-ld \
              -O0 \
              --no-demangle \
              --no-entry \
              -error-limit=0 \
              --allow-undefined \
              --max-memory=536870912 \
              -L${wasilibc}/lib \
              -L${libsndfileP.out}/lib \
              -lc -lm -ldl -lsndfile \
              --export-all \
              -o libcsound.wasm *.o

              # --export csoundInitialize \
              # --export csoundCreate \
            # clang --target=wasm32-wasi -O3 *.ll -o libcsound.wasm
            # {pkgsOrig.llvm_8}/bin/llvm-link *.ll -o libcsound.wasm
              # -Wall \
              # -o libcsound.wasm
              # -I{pkgs.stdenv.cc.bintools.libc}/include \
        '';
        installPhase = ''
              mkdir -p $out/lib
              # cp libcsound.wasm $out/lib
              cp -rf ./* $out
          # substituteInPlace cmake_install.cmake \
          #   --replace '/sysroot' sysroot
          # cmake -P cmake_install.cmake -DCMAKE_INSTALL_PREFIX=$out
        '';
      };
    in
      mkShell {
        nativeBuildInputs = [];
        buildInputs = [ csoundP pkgsOrig.file ];
        shellHook = ''
          echo ${csoundP}
          rm ../tests/wasi/public/libcsound.wasm
          cp ${csoundP}/libcsound.wasm ../tests/wasi/public
        '';
      }
  ) {}
