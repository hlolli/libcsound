/* eslint-disable */
import * as waz from "./csound.worklet.js";

const orcTest = `
  instr 1
    prints "GOOD"
    aout vco2 0.5, 440
    outs aout, aout
  endin
`;

const worker = `
console.log("HELLO WORKER!");
`;

const str2blobUrl = str =>
  URL.createObjectURL(new Blob([str], { type: "text/plain;charset=utf-8" }));

const sab = new SharedArrayBuffer(2);

window["start"] = async () => {
  console.log("HÆ");
  const audioCtx = new AudioContext();
  const module = await audioCtx.audioWorklet.addModule(waz);
  const arr = new Uint8Array(sab);
  arr[0] = 0.00000001;
  const audioWorker = new AudioWorkletNode(
    audioCtx,
    "csound-worklet-processor"
  );
  setTimeout(() => audioWorker.port.postMessage(sab));
  // whiteNoiseNode.connect(audioCtx.destination);
};

import("./").then(async ({ default: getLibcsound }) => {
  // const waz = require();
  // console.log(waz);
  const libcsound = await getLibcsound();
  const {
    csoundCreate,
    csoundDestroy,
    csoundGetAPIVersion,
    csoundGetVersion,
    csoundInitialize,
    csoundParseOrc,
    csoundCompileTree,
    csoundCompileOrc,
    csoundEvalCode,
    csoundStart,
    csoundCompileCsd,
    csoundCompileCsdText,
    csoundPerform,
    csoundPerformKsmps,
    csoundPerformBuffer,
    csoundStop,
    csoundCleanup,
    csoundReset,
    csoundGetSr,
    csoundGetKr,
    csoundGetKsmps,
    csoundGetNchnls,
    csoundGetNchnlsInput,
    csoundGet0dBFS,
    csoundGetA4,
    csoundGetCurrentTimeSamples,
    csoundGetSizeOfMYFLT,
    csoundSetOption,
    csoundSetParams,
    csoundGetParams,
    csoundGetDebug,
    csoundSetDebug,
    fs,
    wasm,
    createFileDebug
  } = libcsound;

  csoundInitialize(0);
  const csound = csoundCreate();
  // csoundSetOption(csound, "-o/csound/test1.wav");
  csoundSetOption(csound, "-odac");
  csoundCompileOrc(csound, orcTest);
  csoundStart(csound);
});
