import React from "react";
import logo from "./logo.svg";
import "./App.css";

import { WASI } from "@wasmer/wasi";
import { WasmFs } from "@wasmer/wasmfs";

function str2ab(str) {
  var buf = new ArrayBuffer(str.length * 2); // 2 bytes for each char
  var bufView = new Uint16Array(buf);
  for (var i = 0, strLen = str.length; i < strLen; i++) {
    bufView[i] = str.charCodeAt(i);
  }
  return buf;
}

const self = {};

// Instantiate a new WASI Instance
const wasmFs = new WasmFs();

const wasi = new WASI({
  bindings: {
    ...WASI.defaultBindings,
    fs: wasmFs.fs
  }
});

const getStdError = async () => {
  let promise = new Promise(resolve => {
    resolve(wasmFs.fs.readFileSync("/dev/stderr", "utf8"));
  });
  return promise;
};

let csound;

const startWasiTask = async () => {
  const response = await fetch("./libcsound.wasm");
  const responseArrayBuffer = await response.arrayBuffer();
  const wasm_bytes = new Uint8Array(responseArrayBuffer).buffer;
  const module = await WebAssembly.compile(wasm_bytes);
  const instance = await WebAssembly.instantiate(
    module,
    Object.assign(wasi.getImports(module), {
      args: [],
      env: {
        // dir: ".",
        // pwd: "/",
        // print_messages: (c, i, msg) => console.log(c, i, msg),
        // memory: new WebAssembly.Memory({ initial: 1024 }),
        get_real_time: () => performance.now(),
        get_CPU_time: () => performance.now(),
        getTimeResolution: () => {},
        longjmp: (x, y) => x,
        yylex: () => {},
        yyerror: () => {},
        csound_orcparse: () => {},
        mkstemp: () => {},
        system: () => {},
        ifd_init_: () => {},
        // partials_init_: () => {},
        // psynth_init_: () => {},
        // pvsbasic_init_: () => {},
        // pvscent_init_: () => {},
        // pvsdemix_init_: () => {},
        // pvsband_init_: () => {},
        pvsbuffer_localops_init: () => {}
        // pvoc_localops_init: () => {},
        // paulstretch_localops_init: () => {},
        // mp3in_localops_init: () => {},
        // sockrecv_localops_init: () => {},
        // socksend_localops_init: () => {},
        // ambicode_init_: () => {},
        // bbcut_init_: () => {},
        // biquad_init_: () => {},
        // clfilt_init_: () => {},
        // cross2_init_: () => {},
        // dam_init_: () => {},
        // dcblockr_init_: () => {},
        // filter_init_: () => {},
        // flanger_init_: () => {},
        // follow_init_: () => {},
        // fout_init_: () => {},
        // freeverb_init_: () => {},
        // ftconv_init_: () => {},
        // ftgen_init_: () => {},
        // gab_gab_init_: () => {},
        // gab_vectorial_init_: () => {},
        // grain_init_: () => {},
        // locsig_init_: () => {},
        // lowpassr_init_: () => {},
        // metro_init_: () => {},
        // midiops2_init_: () => {},
        // midiops3_init_: () => {},
        // newfils_init_: () => {},
        // nlfilt_init_: () => {},
        // oscbnk_init_: () => {},
        // pluck_init_: () => {},
        // repluck_init_: () => {},
        // reverbsc_init_: () => {},
        // seqtime_init_: () => {},
        // sndloop_init_: () => {},
        // sndwarp_init_: () => {},
        // space_init_: () => {},
        // spat3d_init_: () => {},
        // syncgrain_init_: () => {},
        // ugens7_init_: () => {},
        // ugens9_init_: () => {},
        // ugensa_init_: () => {},
        // uggab_init_: () => {},
        // ugmoss_init_: () => {},
        // ugnorman_init_: () => {},
        // ugsc_init_: () => {},
        // wave_terrain_init_: () => {}
      },
      bindings: {
        ...WASI.defaultBindings,
        fs: wasmFs.fs
      }
    })
  );

  // Start the WebAssembly WASI instance!
  wasi.start(instance);

  const {
    exports: {
      csoundInitialize,
      CsoundObj_new,
      CsoundObj_compileOrc,
      CsoundObj_play,
      CsoundObj_evaluateCode,
      csoundMessage,
      csoundSetMessageCallback,
      csoundSetDefaultMessageCallback
    }
  } = instance;

  // debugger;

  // Output what's inside of /dev/stdout!
  csoundInitialize(1);
  csound = CsoundObj_new();
  wasmFs.getStdOut().then(response => {
    console.log(response); // Would log: 'Quick Start!'
  });

  getStdError().then(response => {
    console.log(response); // Would log: 'Quick Start!'
  });

  // csoundSetMessageCallback(csound, console.log);
  // csoundSetDefaultMessageCallback(csound, console.log);
  // console.log(wasi);
  // csoundMessage(csound, str2ab("HELLO WORLD!"));

  //
  // CsoundObj_play(csound);
  // console.log(Object.keys(instance.exports).filter(k => k.includes("Message")));
  // instance.exports.CsoundObj_reset(csound);
  // CsoundObj_play(csound);
  // csoundMessage(csound, "PRUFA!");
  //   console.log(
  //     csound,
  //     `instr 1

  //   iamp = ampdbfs(p5)
  //   ipch = cps2pch(p4,12)
  //   ipan = 0.5

  //   asig = vco2(iamp, ipch)

  //   al, ar pan2 asig, ipan

  //   out(al, ar)
  // endin`
  //   );
};

function App() {
  React.useEffect(() => {
    startWasiTask();
    // wasmFs.fs.writeFileSync("/dev/stdout", "Quick Start!");
    // wasmFs.fs.writeFileSync("/dev/stdout", "Second time around");
    // const i = setInterval(
    //   async () => console.log(await wasmFs.getStdOut()),
    //   100
    // );
    // return () => clearInterval(i);
  }, []);
  return <div></div>;
}

export default App;
