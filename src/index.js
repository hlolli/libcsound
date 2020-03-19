/* eslint-disable */
// import libcsoundPreInit from "@root/libcsound";
// import getLibcsoundWasm, { wasmFs } from "./module";
// import { makeLibcsoundFrontEnd } from "./utils";
// import "./development";

import worker from "workerize-loader?ready&inline!./worker";

/*
export default async function init() {
  const wasm = await getLibcsoundWasm();
  const libcsound = makeLibcsoundFrontEnd(wasm, wasmFs, libcsoundPreInit);
  return libcsound;
}
*/

/**
 * The default entry for libcsound es7 module
 * @async
 * @return {Promise.<Object>}
 */

export default async function init() {
  // const wasm = await getLibcsoundWasm();
  // const libcsound = makeLibcsoundFrontEnd(wasm, wasmFs, libcsoundPreInit);
  const csoundWorker = worker();
  await csoundWorker.ready;
  csoundWorker.onmessage = ({ data }) => {
    if (typeof data["error"] === "object") {
      console.log(`[worker:error] ${data.error.message}`);
    }
  };
  csoundWorker.onerror = args => {
    console.log("ERROR?", args);
  };
  console.log(csoundWorker);
  await csoundWorker.initWasm();
  const csound = await csoundWorker.csoundCreate();
  const sr = await csoundWorker.csoundGetSr(csound);
  // console.log("SR:", sr);
  return sr;
}

init().then(r => {
  console.log("RESULT", r);
});
