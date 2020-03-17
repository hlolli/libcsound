/* eslint-disable */
/* eslint-disable new-cap */
import { WASI } from "@wasmer/wasi/lib/index.esm.js";
import { WasmFs } from "@wasmer/wasmfs";
import browserBindings from "@wasmer/wasi/lib/bindings/browser";
import { lowerI64Imports } from "@wasmer/wasm-transformer";
import { cleanStdout, uint2Str } from "./utils";
import * as path from "path";

export const wasmFs = new WasmFs();

const bindings = {
  ...browserBindings,
  fs: wasmFs.fs,
  path
};

const preopens = {
  "/": "/"
};

const wasi = new WASI({
  preopens,
  env: {},
  bindings
});

const defaultMessageCallback = data => {
  const cleanString = cleanStdout(uint2Str(data));
  cleanString.split("\n").forEach(line => {
    console.log(line);
  });
};

const load = async () => {
  const { default: response } = await import("../lib/libcsound.wasm");
  await wasmFs.volume.mkdirpBase("/csound");
  const wasmBytes = new Uint8Array(response);
  const transformedBinary = await lowerI64Imports(wasmBytes);
  const module = await WebAssembly.compile(transformedBinary);
  const options = wasi.getImports(module);
  options["env"] = {};
  const instance = await WebAssembly.instantiate(module, options);
  wasi.start(instance);
  const stdout = wasmFs.fs.ReadStream("/dev/stdout", "utf8");
  const stderr = wasmFs.fs.ReadStream("/dev/stderr", "utf8");
  stdout.on("data", defaultMessageCallback);
  stderr.on("data", defaultMessageCallback);
  return instance;
};

/**
 * The module which downloads/loads and
 * instanciates the wasm binary.
 * @async
 * @return {Promise.<Object>}
 */
export default async function getLibcsoundWasm() {
  const wasm = await load();
  return wasm;
}
