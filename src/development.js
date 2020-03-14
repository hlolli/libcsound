/* eslint-disable */

const orcTest = `
  instr 1
    prints "GOOD"
    aout vco2 0.5, 440
    outs aout, aout
  endin
`;

import("./").then(async ({ default: getLibcsound }) => {
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
    csoundSetDebug
  } = libcsound;
  console.log("csound version", csoundGetVersion());
  console.log("csound api version", csoundGetAPIVersion());
  csoundInitialize(0);
  const csound = csoundCreate();
  // const { testCsoundGetDebug, testCsoundSetDebug } = libcsound.wasm.exports;
  // csoundSetOption(csound, "-+rtaudio=jack");
  // csoundSetOption(csound, "-odac:dummy");
  // csoundSetOption(csound, "--0dbfs=1");
  // console.log("wasm?", testCsoundGetDebug(csound));
  // testCsoundSetDebug(csound, 1);
  // console.log("wasm?", testCsoundGetDebug(csound));

  // console.log("debug pre: ", csoundGetDebug(csound));
  // console.log("params pre: ", csoundGetParams(csound));
  // csoundSetDebug(csound, 1);
  // console.log("debug post: ", csoundGetDebug(csound));
  // setTimeout(() => , 0);
  // console.log("params post: ", csoundGetParams(csound));
  // csoundCompileOrc(csound, orcTest);
  // csoundStart(csound);
  // csoundEvalCode(csound, orcTest);
});

// import libcsound from "./libcsound";

// const csound = libcsound.csoundCreate();
// console.log(libcsound);
