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
            const result = data.replace(new RegExp(regex, 'is'), "");
            fs.writeFile(myFile, result, 'utf8', function (err) {
              if (err) return console.log(err);
            });
          });
        '';
      };
      patchPrint = pkgsOrig.writeTextFile {
        name = "patchPrint";
        executable = true;
        destination = "/bin/patchPrint";
        text = ''
          #!${pkgsOrig.nodejs}/bin/node

          const myArgs = process.argv.slice(2);
          const myFile = myArgs[0];
          const fs = require('fs')
          fs.readFile(myFile, 'utf8', function (err,data) {
            if (err) { return console.log(err); }
            const regex = "static void print_messages.*" +
                          "#define QUEUESIZ 64";
            const result = data.replace(new RegExp(regex, 'is'),
             "extern void print_messages(CSOUND *csound, int attr, const char *str); \n" +
             "#define QUEUESIZ 64");
            fs.writeFile(myFile, result, 'utf8', function (err) {
              if (err) return console.log(err);
            });
          });
        '';
      };
      /*
      .replace("if(csound->oparms_.msglevel)",
      "csoundMessageStringCallback = print_messages;" +
      "\nif(csound->oparms_.msglevel)").replace(
      "csoundSetMessageCallback(csound, no_op);", "");
      */

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
        -DMEMDEBUG=1 \
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
           # find ./ -type f -exec sed -i -e 's/u?int_least64_t/uint64_t/g' {} \;

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

           # Patch csoundMessage
           # {patchPrint}/bin/patchPrint Engine/insert.c

           touch include/float-version.h
           substituteInPlace Top/csmodule.c \
             --replace '#include <dlfcn.h>' ""
           substituteInPlace Engine/csound_orc.y \
             --replace 'csound_orcnerrs' "0"
           substituteInPlace include/sysdep.h \
             --replace '#if defined(HAVE_GCC3) && !defined(SWIG)' \
           '#if defined(HAVE_GCC3) && !defined(__wasi__)'

           # debug fileOpen
           substituteInPlace Engine/envvar.c \
             --replace '/* check file type */' \
             ' printf ("Opening file: : %s  \n", (char*) name);'

          # debug findVariableWithName
          substituteInPlace Engine/csound_type_system.c \
            --replace 'CS_VARIABLE* returnValue = cs_hash_table_get' \
            'printf ("Loading var with name:  %s  \n", (char*) name);
             CS_VARIABLE* returnValue = cs_hash_table_get'

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
                      --replace 'signal(sigs[i], signal_handler);' "" \
                        --replace 'HAVE_RDTSC' '__NOT_HERE___' \
                        --replace 'static double timeResolutionSeconds = -1.0;' \
                          'static double timeResolutionSeconds = 0.000001;'

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

                                  # substituteInPlace Opcodes/scansyn.c \
                                  #   --replace PUBLIC "static"

                                  # substituteInPlace Opcodes/framebuffer/OpcodeEntries.c \
                                  #   --replace PUBLIC "static"

                                  # substituteInPlace Opcodes/emugens/beosc.c \
                                  #   --replace PUBLIC "static"

                                  # substituteInPlace Top/csound.c \
                                  # --replace '|| defined(__MACH__)' '|| defined(__MACH__) || defined(__wasi__)'

                                  # sed -n 1210,1220p Top/argdecode.c
                                  # exit 1

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
          cp ${./CsoundObjWasi.c} ./CsoundObjWasi.c
          clang -O3 -flto \
            -emit-llvm --target=wasm32-wasi -c -S \
            -I./H -I./Engine -I./include -I./ \
            -I./InOut/libmpadec \
            -I${libsndfileP.dev}/include \
            -I${wasilibc}/include \
            -S -emit-llvm \
            -D__BUILDING_LIBCSOUND \
            -D__wasi__=1 ${preprocFlags} \
            CsoundObjWasi.c \
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
            Top/csound.c \

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
            echo ${pkgs.stdenv.cc.cc} ${libsndfileP.out} ${wasilibc}/lib

            echo "Link wasm obj to single exe"
            # rm csound_scoparse.s.o
            ${pkgsOrig.lld_9}/bin/wasm-ld \
              --lto-O3 \
              --no-demangle \
              --no-entry \
              -error-limit=0 \
              --allow-undefined \
              --stack-first \
              -z stack-size=5242880 \
              --initial-memory=536870912 \
              -L${wasilibc}/lib \
              -L${libsndfileP.out}/lib \
              -lc -lm -ldl -lsndfile \
              --export-all \
              -o libcsound.wasm *.o

                                # --max-memory=536870912 \
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
