with import <nixpkgs> {
  # overlays = [ overlay ];
  config = { allowUnsupportedSystem = true; };
  crossSystem = {
    config = "wasm32-unknown-wasi";
    libc = "wasilibc";
    cc = (import <nixpkgs> {}).llvmPackages_9.lldClang;
    useLLVM = true;
  };
};
pkgs.callPackage
  (
    { mkShell }:
    let
      exports = with builtins; (fromJSON (readFile ./exports.json));
      pkgsOrig = import <nixpkgs> {};
      patchClock = pkgsOrig.writeTextFile {
        name = "patchClock";
        executable = true;
        destination = "/bin/patchClock";
        text = ''
          #!${pkgsOrig.nodejs}/bin/node
          const myArgs = process.argv.slice(2);
          const myFile = myArgs[0];
          const fs = require('fs')
          fs.readFile(myFile, 'utf8', function (err,data) {
            if (err) { return console.log(err); }
            const regex = "\\/\\* find out CPU frequency based on.*" +
                          "initialise a timer structure \\*\\/";
            const replace = `static int getTimeResolution(void) { return 0; }
            int gettimeofday (struct timeval *__restrict, void *__restrict);
            static inline int_least64_t get_real_time(void) {
              struct timeval tv;
              gettimeofday(&tv, NULL);
              return ((int_least64_t) tv.tv_usec
                + (int_least64_t) ((uint32_t) tv.tv_sec * (uint64_t) 1000000));}
            clock_t clock (void);
            static inline int_least64_t get_CPU_time(void) {
              return ((int_least64_t) ((uint32_t) clock()));
            }`;
            const result = data.replace(new RegExp(regex, 'is'), replace);
            fs.writeFile(myFile, result, 'utf8', function (err) {
              if (err) return console.log(err);
            });
          });
        '';
      };

      patchGetCWD = pkgsOrig.writeTextFile {
        name = "patchGetCWD";
        executable = true;
        destination = "/bin/patchGetCWD";
        text = ''
          #!${pkgsOrig.nodejs}/bin/node

          const myArgs = process.argv.slice(2);
          const myFile = myArgs[0];
          const fs = require('fs')
          fs.readFile(myFile, 'utf8', function (err,data) {
            if (err) { return console.log(err); }
            const regex = "static int32_t getcurdir.*" +
                          "#ifndef MAXLINE";
            const result = data.replace(new RegExp(regex, 'is'),
             `
             static int32_t getcurdir(CSOUND *csound, GETCWD *p) {
               p->Scd->size = 2;
               p->Scd->data = "/";
               return OK;
             }
             #ifndef MAXLINE`);
            fs.writeFile(myFile, result, 'utf8', function (err) {
              if (err) return console.log(err);
            });
            });
        '';
      };

      libsndfileP = import ./sndfileWasi.nix {
        inherit pkgs;
      };
      wasilibc = pkgs.callPackage ./wasilibc.nix {
        stdenv = pkgs.stdenv;
        fetchFromGitHub = pkgs.fetchFromGitHub;
        lib = pkgs.lib;
      };
      preprocFlags = ''
        -DUSE_DOUBLE=1 \
        -DLINUX=0 \
        -DO_NDELAY=O_NONBLOCK \
        -DHAVE_STRLCAT=1 \
        -Wno-unknown-attributes \
        -Wno-shift-op-parentheses \
        -Wno-bitwise-op-parentheses \
        -Wno-many-braces-around-scalar-init \
        -Wno-macro-redefined \
      '';
      csoundP = pkgs.stdenv.mkDerivation {
        name = "csound-wasi";
        src = fetchFromGitHub {
          owner = "csound";
          repo = "csound";
          rev = "2d1d5eece2e532026f9b98f22e24662acb2fde90";
          sha256 = "1v0pai5n1ajl033ck59nby295p7gk14f1ag0529jy6pvmsyfiidp";
        };

        buildInputs = [ libsndfileP pkgsOrig.flex pkgsOrig.bison ];
        patches = [ ./argdecode.patch ];
        postPatch = ''
          echo ${wasilibc}
          # Experimental setjmp patching
          find ./ -type f -exec sed -i -e 's/#include <setjmp.h>//g' {} \;
          find ./ -type f -exec sed -i -e 's/csound->LongJmp(.*)//g' {} \;
          find ./ -type f -exec sed -i -e 's/longjmp(.*)//g' {} \;
          find ./ -type f -exec sed -i -e 's/jmp_buf/int/g' {} \;
          find ./ -type f -exec sed -i -e 's/setjmp(csound->exitjmp)/0/g' {} \;

          find ./ -type f -exec sed -i -e 's/HAVE_PTHREAD/FFS_NO_PTHREADS/g' {} \;
          find ./ -type f -exec sed -i -e 's/#ifdef LINUX/#ifdef _NOT_LINUX_/g' {} \;
          find ./ -type f -exec sed -i -e 's/if(LINUX)/if(_NOT_LINUX_)/g' {} \;
          find ./ -type f -exec sed -i -e 's/if (LINUX)/if(_NOT_LINUX_)/g' {} \;
          find ./ -type f -exec sed -i -e 's/defined(LINUX)/defined(_NOT_LINUX_)/g' {} \;

          # don't export dynamic modules
          find ./ -type f -exec sed -i -e 's/PUBLIC.*int.*csoundModuleCreate/static int csoundModuleCreate/g' {} \;
          find ./ -type f -exec sed -i -e 's/PUBLIC.*int32_t.*csoundModuleCreate/static int32_t csoundModuleCreate/g' {} \;
          find ./ -type f -exec sed -i -e 's/PUBLIC.*int.*csound_opcode_init/static int csound_opcode_init/g' {} \;
          find ./ -type f -exec sed -i -e 's/PUBLIC.*int32_t.*csound_opcode_init/static int32_t csound_opcode_init/g' {} \;
          find ./ -type f -exec sed -i -e 's/PUBLIC.*int.*csoundModuleInfo/static int csoundModuleInfo/g' {} \;
          find ./ -type f -exec sed -i -e 's/PUBLIC.*int32_t.*csoundModuleInfo/static int32_t csoundModuleInfo/g' {} \;
          find ./ -type f -exec sed -i -e 's/PUBLIC.*NGFENS.*\*csound_fgen_init/static NGFENS *csound_fgen_init/g' {} \;

          # Don't initialize static_modules which are not compiled in wasm env
          substituteInPlace Top/csmodule.c \
            --replace '#ifndef NACL' '#ifndef __wasi__'

          # Patch 64bit integer clock
          ${patchClock}/bin/patchClock Top/csound.c

          # Patch getCWD
          ${patchGetCWD}/bin/patchGetCWD Opcodes/date.c

          touch include/float-version.h
          substituteInPlace Top/csmodule.c \
            --replace '#include <dlfcn.h>' ""
          substituteInPlace Engine/csound_orc.y \
            --replace 'csound_orcnerrs' "0"
          substituteInPlace include/sysdep.h \
            --replace '#if defined(HAVE_GCC3) && !defined(SWIG)' \
          '#if defined(HAVE_GCC3) && !defined(__wasi__)'

          # don't open .csound6rc
          substituteInPlace Top/main.c \
            --replace 'checkOptions(csound);' ""

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
                   --replace 'umask(0077);' "" \
                   --replace 'mkstemp(lbuf)' \
                   'open(lbuf, 02)' \
                   --replace 'system(sys)' '-1'

          substituteInPlace Engine/linevent.c \
            --replace '#include <ctype.h>' \
               '#include <ctype.h>
                #include <string.h>
                #include <stdlib.h>
                #include <unistd.h>
                #include <fcntl.h>
                #include <errno.h>'

          substituteInPlace Opcodes/urandom.c \
            --replace '__HAIKU__' \
              '__wasi__
               #include <unistd.h>'

          substituteInPlace InOut/libmpadec/mp3dec.c \
            --replace '#include "csoundCore.h"' \
                      '#include "csoundCore.h"
                       #include <stdlib.h>
                       #include <stdio.h>
                       #include <sys/types.h>
                       #include <unistd.h>
                       '

          substituteInPlace Opcodes/mp3in.c \
            --replace '#include "mp3dec.h"' \
              '#include "mp3dec.h"
               #include <unistd.h>
               #include <fcntl.h>'

          substituteInPlace Top/csound.c \
            --replace 'signal(sigs[i], signal_handler);' "" \
            --replace 'HAVE_RDTSC' '__NOT_HERE___' \
            --replace 'static double timeResolutionSeconds = -1.0;' \
                      'static double timeResolutionSeconds = 0.000001;'

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

          substituteInPlace Top/main.c \
            --replace 'csoundUDPServerStart(csound,csound->oparms->daemon);' ""
                       substituteInPlace Engine/musmon.c \
            --replace 'csoundUDPServerClose(csound);' ""

          substituteInPlace Engine/new_orc_parser.c \
            --replace 'csound_orcdebug = O->odebug;' ""


          rm CMakeLists.txt
        '';
        configurePhase = "
          ${pkgsOrig.flex}/bin/flex -B ./Engine/csound_orc.lex > ./Engine/csound_orc.c
          ${pkgsOrig.flex}/bin/flex -B ./Engine/csound_pre.lex > ./Engine/csound_pre.c
          ${pkgsOrig.flex}/bin/flex -B ./Engine/csound_prs.lex > ./Engine/csound_prs.c
          ${pkgsOrig.flex}/bin/flex -B ./Engine/csound_sco.lex > ./Engine/csound_sco.c
          ${pkgsOrig.bison}/bin/bison -pcsound_orc -d --report=itemset ./Engine/csound_orc.y -o ./Engine/csound_orcparse.c
        ";

        # Opcodes/chua/ChuaOscillator.cpp
        # Opcodes/fluidOpcodes/fluidOpcodes.cpp
        # Opcodes/ampmidid.cpp
        # Opcodes/arrayops.cpp
        # Opcodes/doppler.cpp
        # Opcodes/ftsamplebank.cpp
        # Opcodes/linear_algebra.cpp
        # Opcodes/mixer.cpp
        # Opcodes/padsynth_gen.cpp
        # Opcodes/pvsops.cpp
        # Opcodes/signalflowgraph.cpp
        # Opcodes/stk/stkOpcodes.cpp
        # Opcodes/tl/fractalnoise.cpp

        # -I./Opcodes -I./InOut -I./interfaces -I./Frontends
        # Engine/csound_orc.c \
        #   Engine/csound_pre.c \
        #   Engine/csound_prs.c \
        #   Engine/csound_sco.c \
        #   Engine/csound_scoparse.c \
        #   Engine/csound_orcparse.c \
        #  -I{lame}/include/lame \

        buildPhase = ''
          cp ${./helpers.c} ./helpers.c
          clang -O3 -flto \
            -emit-llvm --target=wasm32-wasi -c -S \
            -I./H -I./Engine -I./include -I./ \
            -I./InOut/libmpadec \
            -I${libsndfileP.dev}/include \
            -I${wasilibc}/include \
            -D_WASI_EMULATED_MMAN \
            -D__BUILDING_LIBCSOUND \
            -D__wasi__=1 ${preprocFlags} \
            ${wasilibc}/share/wasm32-wasi/include-all.c \
            helpers.c \
            Engine/auxfd.c \
            Engine/cfgvar.c \
            Engine/corfiles.c \
            Engine/cs_new_dispatch.c \
            Engine/cs_par_base.c \
            Engine/cs_par_orc_semantic_analysis.c \
            Engine/csound_data_structures.c \
            Engine/csound_orc.c \
            Engine/csound_orc_compile.c \
            Engine/csound_orc_expressions.c \
            Engine/csound_orc_optimize.c \
            Engine/csound_orc_semantics.c \
            Engine/csound_orcparse.c \
            Engine/csound_pre.c \
            Engine/csound_prs.c \
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
            Engine/new_orc_parser.c \
            Engine/new_orc_parser.c \
            Engine/pools.c \
            Engine/rdscor.c \
            Engine/scope.c \
            Engine/scsort.c \
            Engine/scxtract.c \
            Engine/sort.c \
            Engine/sread.c \
            Engine/swritestr.c \
            Engine/symbtab.c \
            Engine/symbtab.c \
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
            Opcodes/ambicode.c \
            Opcodes/ambicode1.c \
            Opcodes/arrays.c \
            Opcodes/babo.c \
            Opcodes/bbcut.c \
            Opcodes/bilbar.c \
            Opcodes/biquad.c \
            Opcodes/bowedbar.c \
            Opcodes/buchla.c \
            Opcodes/butter.c \
            Opcodes/cellular.c \
            Opcodes/clfilt.c \
            Opcodes/compress.c \
            Opcodes/cpumeter.c \
            Opcodes/cross2.c \
            Opcodes/crossfm.c \
            Opcodes/dam.c \
            Opcodes/date.c \
            Opcodes/dcblockr.c \
            Opcodes/dsputil.c \
            Opcodes/emugens/beosc.c \
            Opcodes/emugens/emugens.c \
            Opcodes/emugens/scugens.c \
            Opcodes/eqfil.c \
            Opcodes/exciter.c \
            Opcodes/fareygen.c \
            Opcodes/fareyseq.c \
            Opcodes/filter.c \
            Opcodes/flanger.c \
            Opcodes/fm4op.c \
            Opcodes/follow.c \
            Opcodes/fout.c \
            Opcodes/framebuffer/Framebuffer.c \
            Opcodes/framebuffer/OLABuffer.c \
            Opcodes/framebuffer/OpcodeEntries.c \
            Opcodes/freeverb.c \
            Opcodes/ftconv.c \
            Opcodes/ftest.c \
            Opcodes/ftgen.c \
            Opcodes/gab/gab.c \
            Opcodes/gab/hvs.c \
            Opcodes/gab/newgabopc.c \
            Opcodes/gab/sliderTable.c \
            Opcodes/gab/tabmorph.c \
            Opcodes/gab/vectorial.c \
            Opcodes/gammatone.c \
            Opcodes/gendy.c \
            Opcodes/getftargs.c \
            Opcodes/grain.c \
            Opcodes/grain4.c \
            Opcodes/harmon.c \
            Opcodes/hrtfearly.c \
            Opcodes/hrtferX.c \
            Opcodes/hrtfopcodes.c \
            Opcodes/hrtfreverb.c \
            Opcodes/ifd.c \
            Opcodes/liveconv.c \
            Opcodes/locsig.c \
            Opcodes/loscilx.c \
            Opcodes/lowpassr.c \
            Opcodes/mandolin.c \
            Opcodes/metro.c \
            Opcodes/midiops2.c \
            Opcodes/midiops3.c \
            Opcodes/minmax.c \
            Opcodes/modal4.c \
            Opcodes/modmatrix.c \
            Opcodes/moog1.c \
            Opcodes/mp3in.c \
            Opcodes/newfils.c \
            Opcodes/nlfilt.c \
            Opcodes/oscbnk.c \
            Opcodes/pan2.c \
            Opcodes/partials.c \
            Opcodes/partikkel.c \
            Opcodes/paulstretch.c \
            Opcodes/phisem.c \
            Opcodes/physmod.c \
            Opcodes/physutil.c \
            Opcodes/pinker.c \
            Opcodes/pitch.c \
            Opcodes/pitch0.c \
            Opcodes/pitchtrack.c \
            Opcodes/platerev.c \
            Opcodes/pluck.c \
            Opcodes/psynth.c \
            Opcodes/pvadd.c \
            Opcodes/pvinterp.c \
            Opcodes/pvlock.c \
            Opcodes/pvoc.c \
            Opcodes/pvocext.c \
            Opcodes/pvread.c \
            Opcodes/pvs_ops.c \
            Opcodes/pvsband.c \
            Opcodes/pvsbasic.c \
            Opcodes/pvsbuffer.c \
            Opcodes/pvscent.c \
            Opcodes/pvsdemix.c \
            Opcodes/pvsgendy.c \
            Opcodes/quadbezier.c \
            Opcodes/repluck.c \
            Opcodes/reverbsc.c \
            Opcodes/scansyn.c \
            Opcodes/scansynx.c \
            Opcodes/scoreline.c \
            Opcodes/select.c \
            Opcodes/seqtime.c \
            Opcodes/sfont.c \
            Opcodes/shaker.c \
            Opcodes/shape.c \
            Opcodes/singwave.c \
            Opcodes/sndloop.c \
            Opcodes/sndwarp.c \
            Opcodes/space.c \
            Opcodes/spat3d.c \
            Opcodes/spectra.c \
            Opcodes/squinewave.c \
            Opcodes/stackops.c \
            Opcodes/stdopcod.c \
            Opcodes/syncgrain.c \
            Opcodes/tabaudio.c \
            Opcodes/tabsum.c \
            Opcodes/tl/sc_noise.c \
            Opcodes/ugakbari.c \
            Opcodes/ugens7.c \
            Opcodes/ugens8.c \
            Opcodes/ugens9.c \
            Opcodes/ugensa.c \
            Opcodes/uggab.c \
            Opcodes/ugmoss.c \
            Opcodes/ugnorman.c \
            Opcodes/ugsc.c \
            Opcodes/urandom.c \
            Opcodes/vaops.c \
            Opcodes/vbap.c \
            Opcodes/vbap1.c \
            Opcodes/vbap_n.c \
            Opcodes/vbap_zak.c \
            Opcodes/vpvoc.c \
            Opcodes/wave-terrain.c \
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

            # echo "Compile c++ modules"
            # find ./ -type f -exec sed -i -e 's/u?int_least64_t/uint64_t/g' {} \;
            # clang++ -O3 -flto -std=c++14 \
            #   -emit-llvm --target=wasm32-wasi -c -S \
            #   -I./H -I./Engine -I./include -I./ \
            #   -I./InOut/libmpadec \
            #   -I{lame}/include/lame \
            #   -I{libsndfileP.dev}/include \
            #   -I{wasilibc}/include \
            #   -I{pkgsOrig.llvmPackages_9.libcxx}/include/c++/v1 \
            #   -S -emit-llvm \
            #   -D__BUILDING_LIBCSOUND \
            #   -D__thread='^-^' \
            #   -D__wasi__=1 {preprocFlags} \
            #   Opcodes/ampmidid.cpp \
            #   Opcodes/arrayops.cpp \

            # TODO
            # Opcodes/stk/stkOpcodes.cpp
            # Opcodes/chua/ChuaOscillator.cpp \
            # Opcodes/fluidOpcodes/fluidOpcodes.cpp \
            # Opcodes/doppler.cpp \
            # Opcodes/ftsamplebank.cpp \
            # Opcodes/linear_algebra.cpp \
            # Opcodes/mixer.cpp \
            # Opcodes/padsynth_gen.cpp \
            # Opcodes/pvsops.cpp \
            # Opcodes/signalflowgraph.cpp \
            # Opcodes/tl/fractalnoise.cpp \

            echo "Compile to wasm objects"
            for f in *.s
              do
              ${pkgsOrig.llvm_9}/bin/llc -march=wasm32 -filetype=obj $f
            done

            echo "Link wasm obj to single exe"
            ${pkgsOrig.lld_9}/bin/wasm-ld \
              --lto-O3 \
              --no-demangle \
              -entry=_start \
              -error-limit=0 \
              --allow-undefined \
              --stack-first \
              -z stack-size=5242880 \
              --initial-memory=536870912 \
              -L${wasilibc}/lib \
              -L${libsndfileP.out}/lib \
              -lc -lm -ldl -lsndfile \
              -lwasi-emulated-mman \
              --export-all \
              ${wasilibc}/lib/crt1.o *.o \
              -o libcsound.wasm

        '';
        installPhase = ''
          mkdir -p $out/lib
          cp -rf ./* $out
        '';
      };
    in
      mkShell {
        nativeBuildInputs = [];
        buildInputs = [ csoundP pkgsOrig.file ];
        shellHook = ''
          echo ${csoundP}
          rm -f .lib/libcsound.wasm
          mkdir -p lib
          cp ${csoundP}/libcsound.wasm lib
          chmod 0600 lib/libcsound.wasm
          exit 0
        '';
      }
  ) {}
