/* eslint-disable */
import L from "@root/libcsound";
import getLibcsoundWasm, { wasmFs } from "./module";
import { makeLibcsoundFrontEnd } from "./utils";

let wasm;

export const initWasm = async () => {
  wasm = await getLibcsoundWasm();
  return 0;
};

// all worker exports must be static
// that means very noisy code :(
export function csoundCreate(...args) {
  return L.csoundCreate(wasm).apply(null, args);
}

export function csoundGetSr(...args) {
  return L.csoundGetSr(wasm).apply(null, args);
}
