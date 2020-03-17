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
    csoundSetDebug,
    fs,
    wasm,
    createFileDebug
  } = libcsound;

  csoundInitialize(0);
  const csound = csoundCreate();
  csoundSetOption(csound, "-o/csound/test1.wav");
  csoundCompileOrc(csound, orcTest);
  csoundStart(csound);
});
