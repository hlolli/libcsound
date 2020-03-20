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

// @module/attributes
export function csoundGetSr(...args) {
  return L.csoundGetSr(wasm).apply(null, args);
}
export function csoundGetKr(...args) {
  return L.csoundGetKr(wasm).apply(null, args);
}
export function csoundGetKsmps(...args) {
  return L.csoundGetKsmps(wasm).apply(null, args);
}
export function csoundGetNchnls(...args) {
  return L.csoundGetNchnls(wasm).apply(null, args);
}
export function csoundGetNchnlsInput(...args) {
  return L.csoundGetNchnlsInput(wasm).apply(null, args);
}
export function csoundGet0dBFS(...args) {
  return L.csoundGet0dBFS(wasm).apply(null, args);
}
export function csoundGetA4(...args) {
  return L.csoundGetA4(wasm).apply(null, args);
}
export function csoundGetCurrentTimeSamples(...args) {
  return L.csoundGetCurrentTimeSamples(wasm).apply(null, args);
}
export function csoundGetSizeOfMYFLT(...args) {
  return L.csoundGetSizeOfMYFLT(wasm).apply(null, args);
}
export function csoundSetOption(...args) {
  return L.csoundSetOption(wasm).apply(null, args);
}
export function csoundSetParams(...args) {
  return L.csoundSetParams(wasm).apply(null, args);
}
export function csoundGetParams(...args) {
  return L.csoundGetParams(wasm).apply(null, args);
}
export function csoundGetDebug(...args) {
  return L.csoundGetDebug(wasm).apply(null, args);
}
export function csoundSetDebug(...args) {
  return L.csoundSetDebug(wasm).apply(null, args);
}

// @module/performance
export function csoundParseOrc(...args) {
  return L.csoundParseOrc(wasm).apply(null, args);
}
export function csoundCompileTree(...args) {
  return L.csoundCompileTree(wasm).apply(null, args);
}
export function csoundCompileOrc(...args) {
  return L.csoundCompileOrc(wasm).apply(null, args);
}
export function csoundEvalCode(...args) {
  return L.csoundEvalCode(wasm).apply(null, args);
}
export function csoundStart(...args) {
  return L.csoundStart(wasm).apply(null, args);
}
export function csoundCompileCsd(...args) {
  return L.csoundCompileCsd(wasm).apply(null, args);
}
export function csoundCompileCsdText(...args) {
  return L.csoundCompileCsdText(wasm).apply(null, args);
}
export function csoundPerformKsmps(...args) {
  return L.csoundPerformKsmps(wasm).apply(null, args);
}
export function csoundPerformBuffer(...args) {
  return L.csoundPerformBuffer(wasm).apply(null, args);
}
export function csoundStop(...args) {
  return L.csoundStop(wasm).apply(null, args);
}
export function csoundCleanup(...args) {
  return L.csoundCleanup(wasm).apply(null, args);
}
export function csoundReset(...args) {
  return L.csoundReset(wasm).apply(null, args);
}

let GCBlocker;

// @module/instantiation
export function csoundCreate(...args) {
  const res = L.csoundCreate(wasm).apply(null, args);
  GCBlocker = res;
  return res;
}
export function csoundDestroy(...args) {
  return L.csoundDestroy(wasm).apply(null, args);
}
export function csoundGetAPIVersion(...args) {
  return L.csoundGetAPIVersion(wasm).apply(null, args);
}
export function csoundGetVersion(...args) {
  return L.csoundGetVersion(wasm).apply(null, args);
}
export function csoundInitialize(...args) {
  return L.csoundInitialize(wasm).apply(null, args);
}
