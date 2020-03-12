import React from "react";
import logo from "./logo.svg";
import "./App.css";

import { WASI } from "@wasmer/wasi";
import { WasmFs } from "@wasmer/wasmfs";

function timeout(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
async function sleep(fn, ...args) {
  await timeout(3000);
  return fn(...args);
}

const cleanStdout = stdout => {
  const pattern = [
    "[\\u001B\\u009B][[\\]()#;?]*(?:(?:(?:[a-zA-Z\\d]*(?:;[-a-zA-Z\\d\\/#&.:=?%@~_]*)*)?\\u0007)",
    "(?:(?:\\d{1,4}(?:;\\d{0,4})*)?[\\dA-PR-TZcf-ntqry=><~]))"
  ].join("|");

  const regexPattern = new RegExp(pattern, "g");
  return stdout.replace(regexPattern, "");
};

function str2ab(str) {
  var buf = new ArrayBuffer(str.length * 2); // 2 bytes for each char
  var bufView = new Uint16Array(buf);
  for (var i = 0, strLen = str.length; i < strLen; i++) {
    bufView[i] = str.charCodeAt(i);
  }
  return buf;
}

// Instantiate a new WASI Instance
const wasmFs = new WasmFs();

const wasi = new WASI({
  bindings: {
    ...WASI.defaultBindings,
    fs: wasmFs.fs
  }
});

// const memory = new WebAssembly.Memory({ initial: 10, maximum: 100 });

const getStdError = async () => {
  let promise = new Promise(resolve => {
    resolve(wasmFs.fs.readFileSync("/dev/stderr", "utf8"));
  });
  return promise;
};

console.log(wasmFs.fs);
let csound;

// console.log("M", memory);

const startWasiTask = async () => {
  const response = await fetch("./libcsound.wasm");
  const responseArrayBuffer = await response.arrayBuffer();
  const wasm_bytes = new Uint8Array(responseArrayBuffer).buffer;
  const module = await WebAssembly.compile(wasm_bytes);
  // const opts = wasi.getImports(module);
  // opts.env = {};
  // opts.env.memory = memory;
  // opts.env.get_real_time = () => performance.now();
  // opts.env.get_CPU_time = () => performance.now();
  // opts.env.getTimeResolution = () => {};
  // opts.env.yylex = () => {};
  // opts.env.yyerror = () => {};
  // opts.env.csound_orcparse = () => {};
  // opts.env.mkstemp = () => {};
  // opts.env.system = () => {};

  const opts = Object.assign(wasi.getImports(module), {
    args: ["-odac"],
    // memory: new WebAssembly.Memory({ initial: 8 }),
    // import: { memory: new WebAssembly.Memory({ initial: 8 }) },
    env: {
      get_real_time: () => performance.now(),
      get_CPU_time: () => performance.now(),
      getTimeResolution: () => {},
      longjmp: (x, y) => x,
      yylex: () => {},
      yyerror: () => {},
      zzlex: () => {},
      zzerror: () => {},
      csound_orcparse: () => {},
      mkstemp: () => {},
      system: () => {},
      ifd_init_: () => {}
    },
    bindings: {
      ...WASI.defaultBindings,
      fs: wasmFs.fs
    }
  });

  console.log("OPTS", opts);

  const instance = await WebAssembly.instantiate(module, opts);

  // instance.exports.memory = memory;
  // console.log("MEMORY?", opts, instance);
  // Start the WebAssembly WASI instance!

  const {
    exports: {
      csoundInitialize,
      csoundCreate,
      csoundCompileOrc,
      csoundEvalCode,
      csoundSetOption,
      csoundSetHostImplementedAudioIO,
      csoundGet0dBFS,
      csoundStart,
      CsoundObj_new,
      CsoundObj_compile,
      CsoundObj_compileOrc,
      CsoundObj_play,
      CsoundObj_evaluateCode,
      csoundMessage,
      csoundSetMessageCallback,
      csoundSetDefaultMessageCallback
    }
  } = instance;

  wasi.start(instance);
  // debugger;

  // Output what's inside of /dev/stdout!
  csoundInitialize(3);
  csound = csoundCreate(null);
  csoundSetHostImplementedAudioIO(csound, 1, 0);
  // csound = csoundCreate();
  wasmFs.getStdOut().then(response => {
    console.log(response); // Would log: 'Quick Start!'
  });

  // csoundSetOption(csound, "-o /__out__.wav");
  // csoundSetOption(csound, "-i null");
  // csoundSetOption(csound, "-+rtaudio=dummy");

  getStdError().then(response => {
    console.log(response); // Would log: 'Quick Start!'
  });

  // csoundSetMessageCallback(csound, console.log);
  // csoundSetDefaultMessageCallback(csound, console.log);
  // console.log(wasi);
  csoundMessage(csound, "HELLO WOLLI");

  //
  // CsoundObj_play(csound);
  // console.log(Object.keys(instance.exports).filter(k => k.includes("Message")));
  // instance.exports.CsoundObj_reset(csound);
  // CsoundObj_play(csound);
  // csoundMessage(csound, "PRUFA!");
  // csoundMessage(csound, "PRUFA2");
  const orc = `
    instr 1
    iamp = ampdbfs(p5)
    ipch = cps2pch(p4,12)
    ipan = 0.5
    asig = vco2(iamp, ipch)
    al, ar pan2 asig, ipan
    out(al, ar)
    endin`;
  const orcBuffer = new TextEncoder("utf-8").encode(orc);

  console.log(csoundGet0dBFS(csound), orcBuffer);
  // csoundEvalCode(csound, buffer);
  try {
    csoundStart(csound);
    // csoundCompileOrc(csound, orcBuffer);
    CsoundObj_compile(csound, orc);
  } catch (e) {
    console.log(e);
  }
  wasmFs.getStdOut().then(response => {
    console.log(response);
  });
  getStdError().then(response => {
    console.log(response);
  });
};

let stdOutLine = 0;
let stdErrLine = 1;

function App() {
  React.useEffect(() => {
    startWasiTask();
    // wasmFs.fs.writeFileSync("/dev/stdout", "Quick Start!");
    // wasmFs.fs.writeFileSync("/dev/stdout", "Second time around");
    const i = setInterval(async () => {
      let stdout = await wasmFs.getStdOut();
      // await wasmFs.fs.promises.unlink("/dev/stdout");
      // await wasmFs.fs.promises.touch("/dev/stdout");
      let stderr = await getStdError();
      const splitClearStdout = stdout.split("[J");
      if (splitClearStdout.length > stdOutLine) {
        stdOutLine += 1;
        stdout =
          splitClearStdout[stdOutLine - 2] + splitClearStdout[stdOutLine - 1];
        stdout = `\n${cleanStdout(stdout)}\n`;
        console.log(stdout);
      }
      const splitClearStderr = stderr.split("[J");
      if (splitClearStderr.length > stdErrLine) {
        stdErrLine += 1;
        stdout =
          splitClearStderr[stdErrLine - 1] + splitClearStderr[stdErrLine];
        stderr = `\n${cleanStdout(stderr)}\n`;
        console.log(stderr);
      }
    }, 100);
    return () => clearInterval(i);
  }, []);
  return (
    <div>
      <button onClick={startWasiTask}>
        <h1>START</h1>
      </button>
    </div>
  );
}

export default App;
