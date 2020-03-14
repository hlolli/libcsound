import libcsoundPreInit from "@root/libcsound";
import getLibcsoundWasm from "./module";
import { makeLibcsoundFrontEnd } from "./utils";
import "./development";

/**
 * The default entry for libcsound es7 module
 * @async
 * @return {Promise.<Object>}
 */
export default async function() {
  const wasm = await getLibcsoundWasm();
  const libcsound = makeLibcsoundFrontEnd(wasm, libcsoundPreInit);
  return libcsound;
}
