# Cmake toolchain description file for the Makefile

# This is arbitrary, AFAIK, for now.
cmake_minimum_required(VERSION 3.4.0)

set(CMAKE_SYSTEM_NAME Wasm)
set(CMAKE_SYSTEM_VERSION 1)
set(CMAKE_SYSTEM_PROCESSOR wasm32)
set(triple wasm32-wasi)

# set(CMAKE_C_COMPILER ${WASI_SDK_PREFIX}/bin/clang)
# set(CMAKE_CXX_COMPILER ${WASI_SDK_PREFIX}/bin/clang++)
# set(CMAKE_AR ${WASI_SDK_PREFIX}/bin/llvm-ar CACHE STRING "wasi-sdk build")
# set(CMAKE_RANLIB ${WASI_SDK_PREFIX}/bin/llvm-ranlib CACHE STRING "wasi-sdk build")
set(CMAKE_C_COMPILER_TARGET ${triple} CACHE STRING "wasi-sdk build")
set(CMAKE_CXX_COMPILER_TARGET ${triple} CACHE STRING "wasi-sdk build")
set(CMAKE_C_FLAGS "-v" CACHE STRING "wasi-sdk build")
set(CMAKE_CXX_FLAGS "-v -std=c++11" CACHE STRING "wasi-sdk build")
set(CMAKE_EXE_LINKER_FLAGS "-Wl,--no-threads" CACHE STRING "wasi-sdk build")

set(CMAKE_SYSROOT ${WASI_SDK_PREFIX}/share/wasi-sysroot CACHE STRING "wasi-sdk build")
set(CMAKE_STAGING_PREFIX ${WASI_SDK_PREFIX}/share/wasi-sysroot CACHE STRING "wasi-sdk build")

# Don't look in the sysroot for executables to run during the build
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# Only look in the sysroot (not in the host paths) for the rest
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Some other hacks
set(CMAKE_C_COMPILER_WORKS ON)
set(CMAKE_CXX_COMPILER_WORKS ON)

# Csound
project(Csound)

find_package(LLVM REQUIRED CONFIG)
find_package(FLEX)
find_package(BISON)

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")
list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")

# Set your project compile flags.
# E.g. if using the C++ header files
# you will need to enable C++11 support
# for your compiler.
set(LINUX YES)
set(APIVERSION "6.0")
set(CSOUNDLIB "csound64")
set(LIBRARY_INSTALL_DIR "lib")
set(PLUGIN_INSTALL_DIR "${LIBRARY_INSTALL_DIR}/csound/plugins64-${APIVERSION}")
set(BUILD_DIR "./")
set(BUILD_PLUGINS_DIR ${BUILD_DIR})
set(BUILD_BIN_DIR ${BUILD_DIR})
set(BUILD_LIB_DIR ${BUILD_DIR})
set(CMAKE_COMPILER_IS_CLANG 1)
set(EXECUTABLE_INSTALL_DIR "bin")
set(LOCALE_INSTALL_DIR "share/locale")
set(HEADER_INSTALL_DIR "include/csound")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} --target=wasm32 -O2 -D__BUILDING_LIBCSOUND -emit-llvm -c")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} --target=wasm32 -O2 -D__BUILDING_LIBCSOUND -emit-llvm -c")
# set(libcsound_CFLAGS "${CMAKE_C_FLAGS} --target=wasm32 -O2 -D__BUILDING_LIBCSOUND -emit-llvm -c")
set(DEFAULT_OPCODEDIR "${CMAKE_INSTALL_PREFIX}/${PLUGIN_INSTALL_DIR}")
# set(libcsound_CFLAGS -D__BUILDING_LIBCSOUND)

add_definitions("-DCS_DEFAULT_PLUGINDIR=\"${DEFAULT_OPCODEDIR}\"")
add_definitions("-Wall -g -D_CSOUND_RELEASE_ ${LLVM_DEFINITIONS} -DHAVE_ATOMIC_BUILTIN=0")
remove_definitions(-DHAVE_PTHREAD)

INCLUDE(CheckFunctionExists)
INCLUDE(CheckIncludeFile)
include(TestBigEndian)
include(CheckIncludeFileCXX)
include(CheckLibraryExists)
include(CMakeParseArguments)
include(CheckCCompilerFlag)
include(CheckCXXCompilerFlag)
include(CMakePushCheckState)
include(cmake/CompilerOptimizations.cmake)

include_directories(${LLVM_INCLUDE_DIRS})
include_directories(./include)
include_directories(./H)
include_directories(./Engine)
include_directories(./util)
include_directories(./)

# find_library(LIBSNDFILE_LIBRARY NAMES sndfile libsndfile-1 libsndfile)
set(libcsound_LIBS ${LIBSNDFILE_LIBRARY})

function(make_executable name srcs libs)
  add_executable(${name} ${srcs})
  target_link_libraries (${name} PUBLIC ${libs})
  set_target_properties(${name} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${BUILD_BIN_DIR})

  if(${ARGC} EQUAL 4)
    set_target_properties(${name} PROPERTIES
      OUTPUT_NAME ${ARGV3})
  endif()
  install(TARGETS ${name}
    RUNTIME DESTINATION "${EXECUTABLE_INSTALL_DIR}" )
endfunction(make_executable)

function(add_dependency_to_framework pluginlib dependency)
endfunction(add_dependency_to_framework)

function(make_utility name srcs)
  # make_executable(${name} "${srcs}" "${CSOUNDLIB}")
  # add_dependencies(${name} ${CSOUNDLIB})
  # set(i 2)
  # while( ${i} LESS ${ARGC} )
  #   target_link_libraries(${name} ${ARGV${i}})
  #   math(EXPR i "${i}+1")
  # endwhile()
endfunction()

function(check_deps option)
  if(${option})
    set(i 1)
    while( ${i} LESS ${ARGC} )
      set(dep ${ARGV${i}})
      if(NOT ${dep})
        if(FAIL_MISSING)
          message(FATAL_ERROR
            "${option} is enabled, but ${dep}=\"${${dep}}\"")
        else()
          message(STATUS "${dep}=\"${${dep}}\", so disabling ${option}")
          set(${option} OFF PARENT_SCOPE)
          # Set it in the local scope too
          set(${option} OFF)
        endif()
      endif()
      math(EXPR i "${i}+1")
    endwhile()
  endif()
  if(${option})
    message(STATUS "${option} is enabled.")
  else()
    message(STATUS "${option} is disabled.")
  endif()
endfunction(check_deps)

function(make_plugin libname srcs)
  add_library(${libname} OBJECT ${srcs})
  set(i 2)
  while( ${i} LESS ${ARGC} )
    target_link_libraries(${libname} ${ARGV${i}})
    math(EXPR i "${i}+1")
  endwhile()

  set_target_properties(${libname} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${BUILD_PLUGINS_DIR}
    LIBRARY_OUTPUT_DIRECTORY ${BUILD_PLUGINS_DIR}
    ARCHIVE_OUTPUT_DIRECTORY ${BUILD_PLUGINS_DIR}
    LINKER_LANGUAGE C
    )

  install(TARGETS ${libname}
    LIBRARY DESTINATION "${PLUGIN_INSTALL_DIR}" )
endfunction(make_plugin)

# Now build our tools
# add_executable(simple-tool tool.cpp)

# The csound library
set(libcsound_SRCS
  Top/csound.c
  Engine/auxfd.c
  Engine/cfgvar.c
  Engine/corfiles.c
  Engine/entry1.c
  Engine/envvar.c
  Engine/extract.c
  Engine/fgens.c
  Engine/insert.c
  Engine/linevent.c
  Engine/memalloc.c
  Engine/memfiles.c
  Engine/musmon.c
  Engine/namedins.c
  Engine/rdscor.c
  Engine/scsort.c
  Engine/scxtract.c
  Engine/sort.c
  Engine/sread.c
  Engine/swritestr.c
  Engine/twarp.c
  Engine/csound_type_system.c
  Engine/csound_standard_types.c
  Engine/csound_data_structures.c
  Engine/pools.c
  InOut/libsnd.c
  InOut/libsnd_u.c
  InOut/midifile.c
  InOut/midirecv.c
  InOut/midisend.c
  InOut/winascii.c
  InOut/windin.c
  InOut/window.c
  InOut/winEPS.c
  InOut/circularbuffer.c
  OOps/aops.c
  OOps/bus.c
  OOps/cmath.c
  OOps/diskin2.c
  OOps/disprep.c
  OOps/dumpf.c
  OOps/fftlib.c
  OOps/pffft.c
  OOps/goto_ops.c
  OOps/midiinterop.c
  OOps/midiops.c
  OOps/midiout.c
  OOps/mxfft.c
  OOps/oscils.c
  OOps/pstream.c
  OOps/pvfileio.c
  OOps/pvsanal.c
  OOps/random.c
  OOps/schedule.c
  OOps/sndinfUG.c
  OOps/str_ops.c
  OOps/ugens1.c
  OOps/ugens2.c
  OOps/ugens3.c
  OOps/ugens4.c
  OOps/ugens5.c
  OOps/ugens6.c
  OOps/ugtabs.c
  OOps/ugrw1.c
  OOps/vdelay.c
  OOps/compile_ops.c
  Opcodes/babo.c
  Opcodes/bilbar.c
  Opcodes/compress.c
  Opcodes/eqfil.c
  Opcodes/Vosim.c
  Opcodes/squinewave.c
  Opcodes/pinker.c
  Opcodes/pitch.c
  Opcodes/pitch0.c
  Opcodes/spectra.c
  Opcodes/ambicode1.c
  Opcodes/sfont.c
  Opcodes/grain4.c
  Opcodes/hrtferX.c
  Opcodes/loscilx.c
  Opcodes/minmax.c
  Opcodes/pan2.c
  Opcodes/arrays.c
  Opcodes/phisem.c
  Opcodes/hrtfopcodes.c
  Opcodes/vbap.c
  Opcodes/vbap1.c
  Opcodes/vbap_n.c
  Opcodes/vbap_zak.c
  Opcodes/vaops.c
  Opcodes/ugakbari.c
  Opcodes/harmon.c
  Opcodes/pitchtrack.c
  Opcodes/partikkel.c
  Opcodes/shape.c
  Opcodes/tabaudio.c
  Opcodes/tabsum.c
  Opcodes/crossfm.c
  Opcodes/pvlock.c
  Opcodes/fareyseq.c
  Opcodes/modmatrix.c
  Opcodes/scoreline.c
  Opcodes/modal4.c
  Opcodes/physutil.c
  Opcodes/physmod.c
  Opcodes/mandolin.c
  Opcodes/singwave.c
  Opcodes/fm4op.c
  Opcodes/moog1.c
  Opcodes/shaker.c
  Opcodes/bowedbar.c
  Opcodes/gab/tabmorph.c
  Opcodes/gab/hvs.c
  Opcodes/gab/sliderTable.c
  Opcodes/gab/newgabopc.c
  Opcodes/ftest.c
  Opcodes/hrtfearly.c
  Opcodes/hrtfreverb.c
  Opcodes/cpumeter.c
  Opcodes/gendy.c
  Opcodes/tl/sc_noise.c
  Opcodes/afilters.c
  Opcodes/wpfilters.c
  Opcodes/zak.c
  Top/argdecode.c
  Top/csdebug.c
  Top/cscore_internal.c
  Top/cscorfns.c
  Top/csmodule.c
  Top/getstring.c
  Top/main.c
  Top/new_opts.c
  Top/one_file.c
  Top/opcode.c
  Top/threads.c
  Top/utility.c
  Top/threadsafe.c
  Top/server.c)

#Opcode Sources
set(stdopcod_SRCS
  Opcodes/ambicode.c
  Opcodes/bbcut.c
  Opcodes/biquad.c
  Opcodes/butter.c
  Opcodes/clfilt.c
  Opcodes/cross2.c
  Opcodes/dam.c
  Opcodes/dcblockr.c
  Opcodes/filter.c
  Opcodes/flanger.c
  Opcodes/follow.c
  Opcodes/fout.c
  Opcodes/freeverb.c
  Opcodes/ftconv.c
  Opcodes/ftgen.c
  Opcodes/gab/gab.c
  Opcodes/gab/vectorial.c
  Opcodes/grain.c
  Opcodes/locsig.c
  Opcodes/lowpassr.c
  Opcodes/metro.c
  Opcodes/midiops2.c
  Opcodes/midiops3.c
  Opcodes/newfils.c
  Opcodes/nlfilt.c
  Opcodes/oscbnk.c
  Opcodes/pluck.c
  Opcodes/paulstretch.c
  Opcodes/repluck.c
  Opcodes/reverbsc.c
  Opcodes/seqtime.c
  Opcodes/sndloop.c
  Opcodes/sndwarp.c
  Opcodes/space.c
  Opcodes/spat3d.c
  Opcodes/syncgrain.c
  Opcodes/ugens7.c
  Opcodes/ugens9.c
  Opcodes/ugensa.c
  Opcodes/uggab.c
  Opcodes/ugmoss.c
  Opcodes/ugnorman.c
  Opcodes/ugsc.c
  Opcodes/wave-terrain.c
  Opcodes/stdopcod.c)

set(cs_pvs_ops_SRCS
  Opcodes/ifd.c
  Opcodes/partials.c
  Opcodes/psynth.c
  Opcodes/pvsbasic.c
  Opcodes/pvscent.c
  Opcodes/pvsdemix.c
  Opcodes/pvs_ops.c
  Opcodes/pvsband.c
  Opcodes/pvsbuffer.c)

set(oldpvoc_SRCS
  Opcodes/dsputil.c
  Opcodes/pvadd.c
  Opcodes/pvinterp.c
  Opcodes/pvocext.c
  Opcodes/pvread.c
  Opcodes/ugens8.c
  Opcodes/vpvoc.c
  Opcodes/pvoc.c)

set(mp3in_SRCS
  Opcodes/mp3in.c
  InOut/libmpadec/layer1.c
  InOut/libmpadec/layer2.c
  InOut/libmpadec/layer3.c
  InOut/libmpadec/synth.c
  InOut/libmpadec/tables.c
  InOut/libmpadec/mpadec.c
  InOut/libmpadec/mp3dec.c)

list(APPEND libcsound_SRCS ${stdopcod_SRCS} ${cs_pvs_ops_SRCS} ${oldpvoc_SRCS} ${mp3in_SRCS})

# set(static_modules_SRCS
#   Top/init_static_modules.c
#   Opcodes/ampmidid.cpp
#   Opcodes/doppler.cpp
#   Opcodes/tl/fractalnoise.cpp
#   Opcodes/ftsamplebank.cpp
#   Opcodes/mixer.cpp
#   Opcodes/signalflowgraph.cpp)

# set_source_files_properties(${static_modules_SRCS} PROPERTIES COMPILE_FLAGS -DINIT_STATIC_MODULES)

# list(APPEND libcsound_SRCS ${static_modules_SRCS})

set(YACC_SRC ${CMAKE_CURRENT_SOURCE_DIR}/Engine/csound_orc.y)
set(YACC_OUT ${CMAKE_CURRENT_BINARY_DIR}/csound_orcparse.c)
set(YACC_OUTH ${CMAKE_CURRENT_BINARY_DIR}/csound_orcparse.h)

set(LEX_SRC ${CMAKE_CURRENT_SOURCE_DIR}/Engine/csound_orc.lex)
set(LEX_OUT ${CMAKE_CURRENT_BINARY_DIR}/csound_orclex.c)
set_source_files_properties(${CMAKE_CURRENT_BINARY_DIR}/csound_orclex.c
  PROPERTIES COMPILE_FLAGS "-Wno-implicit-fallthrough")
set(PRELEX_SRC ${CMAKE_CURRENT_SOURCE_DIR}/Engine/csound_pre.lex)
set(PRELEX_OUT ${CMAKE_CURRENT_BINARY_DIR}/csound_prelex.c)
set_source_files_properties(${CMAKE_CURRENT_BINARY_DIR}/csound_prelex.c
  PROPERTIES COMPILE_FLAGS "-Wno-implicit-fallthrough")
add_custom_command(
  OUTPUT ${LEX_OUT}
  DEPENDS ${LEX_SRC}
  COMMAND ${FLEX_EXECUTABLE} ARGS -B -t ${LEX_SRC} > ${LEX_OUT}
  )

add_custom_command(
  DEPENDS ${PRELEX_SRC}
  COMMAND ${FLEX_EXECUTABLE} ARGS -B ${PRELEX_SRC} > ${PRELEX_OUT}
  OUTPUT ${PRELEX_OUT}
  )

add_custom_command(
  OUTPUT ${YACC_OUT} ${YACC_OUTH}
  DEPENDS ${YACC_SRC} ${LEX_OUT}
  COMMAND ${BISON_EXECUTABLE}
  ARGS -pcsound_orc -d --report=itemset -o ${YACC_OUT} ${YACC_SRC}
  )

list(APPEND libcsound_SRCS
  ${LEX_OUT} ${YACC_OUT} ${PRELEX_OUT}
  Engine/csound_orc_semantics.c
  Engine/csound_orc_expressions.c
  Engine/csound_orc_optimize.c
  Engine/csound_orc_compile.c
  Engine/new_orc_parser.c
  Engine/symbtab.c)

set_source_files_properties(${YACC_OUT} GENERATED)
set_source_files_properties(${YACC_OUTH} GENERATED)
set_source_files_properties(${LEX_OUT} GENERATED)
set_source_files_properties(${PRELEX_OUT} GENERATED)

set(PRELEX_SCOSRC ${CMAKE_CURRENT_SOURCE_DIR}/Engine/csound_prs.lex)
set(PRELEX_SCOOUT ${CMAKE_CURRENT_BINARY_DIR}/csound_prslex.c)

add_custom_command(
  OUTPUT ${PRELEX_SCOOUT}
  DEPENDS ${PRELEX_SCOSRC}
  COMMAND ${FLEX_EXECUTABLE} ARGS -B -t -d ${PRELEX_SCOSRC} > ${PRELEX_SCOOUT}
  )

list(APPEND libcsound_SRCS ${PRELEX_SCOOUT})
set_source_files_properties(${PRELEX_SCOOUT} GENERATED)

include_directories(${CMAKE_CURRENT_BINARY_DIR})
include_directories(${CMAKE_CURRENT_BINARY_DIR}/include)


list(APPEND libcsound_SRCS
  Engine/cs_new_dispatch.c
  Engine/cs_par_base.c
  Engine/cs_par_orc_semantic_analysis.c)

# list(APPEND libcsound_CFLAGS -DPARCS)


message(STATUS "Building on Linux.")
add_definitions(-DLINUX -DPIPES -DNO_FLTK_THREADS -D_GNU_SOURCE -DHAVE_SOCKETS)
list(APPEND libcsound_LIBS ${MATH_LIBRARY} dl)

find_library(LIBRT_LIBRARY rt)

if(LIBRT_LIBRARY)
  list(APPEND libcsound_LIBS ${LIBRT_LIBRARY})
  message(STATUS "  ADDING LIBRT LIBRARY: ${LIBRT_LIBRARY}.")
endif()

find_library(LIBEXECINFO_LIBRARY execinfo)

if(LIBEXECINFO_LIBRARY)
  list(APPEND libcsound_LIBS ${LIBEXECINFO_LIBRARY})
  message(STATUS "  ADDING LIBEXECINFO LIBRARY: ${LIBEXECINFO_LIBRARY}.")
endif()

check_function_exists(strlcat HAVE_STRLCAT)
if(HAVE_STRLCAT)
  add_definitions(-DHAVE_STRLCAT)
endif()

# Locale-aware reading and printing
check_function_exists(strtok_r HAVE_STRTOK_R)
check_function_exists(strtod_l HAVE_STRTOD_L)
check_function_exists(sprintf_l HAVE_SPRINTF_L)

if(HAVE_STRTOK_R)
  add_definitions(-DHAVE_STRTOK_R)
endif()
if(HAVE_STRTOD_L)
  add_definitions(-DHAVE_STRTOD_L)
endif()
if(HAVE_SPRINTF_L)
  add_definitions(-DHAVE_SPRINTF_L)
endif()

# Same for Windows
check_function_exists(_strtok_r HAVE__STRTOK_R)
check_function_exists(_strtod_l HAVE__STRTOD_L)
check_function_exists(_sprintf_l HAVE__SPRINTF_L)

if(HAVE__STRTOK_R)
  add_definitions(-DHAVE__STRTOK_R)
endif()
if(HAVE__STRTOD_L)
  add_definitions(-DHAVE__STRTOD_L)
endif()
if(HAVE__SPRINTF_L)
  add_definitions(-DHAVE__SPRINTF_L)
endif()
if(HAVE_WINSOCK_H OR HAVE_SYS_SOCKETS_H)
  list(APPEND libcsound_CFLAGS -DHAVE_SOCKETS)
endif()
if(HAVE_DIRENT_H)
  list(APPEND libcsound_CFLAGS -DHAVE_DIRENT_H)
endif()
if(HAVE_FCNTL_H)
  list(APPEND libcsound_CFLAGS -DHAVE_FCNTL_H)
endif()
if(HAVE_UNISTD_H)
  list(APPEND libcsound_CFLAGS -DHAVE_UNISTD_H)
endif()
if(HAVE_STDINT_H)
  list(APPEND libcsound_CFLAGS -DHAVE_STDINT_H)
endif()
if(HAVE_SYS_TIME_H)
  list(APPEND libcsound_CFLAGS -DHAVE_SYS_TIME_H)
endif()
if(HAVE_SYS_TYPES_H)
  list(APPEND libcsound_CFLAGS -DHAVE_SYS_TYPES_H)
endif()
if(HAVE_TERMIOS_H)
  list(APPEND libcsound_CFLAGS -DHAVE_TERMIOS_H)
endif()
if(HAVE_VALUES_H)
  list(APPEND libcsound_CFLAGS -DHAVE_VALUES_H)
endif()
if(BIG_ENDIAN)
  list(APPEND libcsound_CFLAGS -DWORDS_BIGENDIAN)
endif()

## Preprocessor flags
add_compile_definitions(RD_OPTS=0644)
add_compile_definitions(WR_OPTS=0644)
add_compile_definitions(O_RDONLY=00)
add_compile_definitions(O_WRONLY=01)
add_compile_definitions(O_CREAT=0100)
add_compile_definitions(O_TRUNC=01000)
add_compile_definitions(O_NONBLOCK=04000)
add_compile_definitions(O_NDELAY=04000)
add_compile_definitions(F_GETFL=3)
add_compile_definitions(F_SETFL=4)
add_compile_definitions(LINUX=0)
add_compile_definitions(RTLD_GLOBAL=0)
add_compile_definitions(RTLD_LAZY=1)
add_compile_definitions(RTLD_NOW=2)


add_subdirectory(include)
add_library(${CSOUNDLIB} ${libcsound_SRCS})
SET_TARGET_PROPERTIES(${CSOUNDLIB} PROPERTIES OUTPUT_NAME ${CSOUNDLIB})
SET_TARGET_PROPERTIES(${CSOUNDLIB} PROPERTIES PREFIX "lib")

add_subdirectory(Opcodes)
add_subdirectory(InOut)
add_subdirectory(interfaces)
add_subdirectory(Frontends)
add_subdirectory(util)
add_subdirectory(util1)
add_subdirectory(po)


target_compile_options(${CSOUNDLIB} PRIVATE ${libcsound_CFLAGS})
target_link_libraries(${CSOUNDLIB} LLVM)

# set_target_properties(${CSOUNDLIB} PROPERTIES
#   RUNTIME_OUTPUT_DIRECTORY ${BUILD_BIN_DIR}
#   LIBRARY_OUTPUT_DIRECTORY ${BUILD_LIB_DIR}
#   ARCHIVE_OUTPUT_DIRECTORY ${BUILD_LIB_DIR}
#   LINKER_LANGUAGE CXX
#   )
# install(TARGETS ${CSOUNDLIB}
#   LIBRARY DESTINATION "${LIBRARY_INSTALL_DIR}"
#   ARCHIVE DESTINATION "${LIBRARY_INSTALL_DIR}")
