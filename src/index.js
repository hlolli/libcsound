/* eslint-disable */
// import libcsoundPreInit from "@root/libcsound";
// import getLibcsoundWasm, { wasmFs } from "./module";
// import { makeLibcsoundFrontEnd } from "./utils";
// import "./development";

import worker from "workerize-loader?ready&inline!./worker";
// import worker from "workerize-loader?ready!./worker";
// import worker from "workerize-loader";
// import * as csoundWorker from "./worker";

/*
export default async function init() {
  const wasm = await getLibcsoundWasm();
  const libcsound = makeLibcsoundFrontEnd(wasm, wasmFs, libcsoundPreInit);
  return libcsound;
}
*/

const orcTest = `
  instr 1
    prints "GOOD"
    aout vco2 0.5, 440
    outs aout, aout
  endin
`;

/**
 * The default entry for libcsound es7 module
 * @async
 * @return {Promise.<Object>}
 */
export default async function init() {
  const csoundWorker = worker();
  await csoundWorker.ready;
  await csoundWorker.initWasm();
  const csound = await csoundWorker.csoundCreate();
  await csoundWorker.csoundInitialize(0);
  await csoundWorker.csoundSetOption(csound, "-odac");
  await csoundWorker.csoundCompileOrc(csound, orcTest);
  await csoundWorker.csoundStart(csound);
  const sr = await csoundWorker.csoundGetSr(csound);
  return 0;
}

init().then(r => {});

if (module.hot) {
  module.hot.accept("./worker.js", function() {
    console.log("Accepting the updated printMe module!");
    init().then(r => {});
  });
}
