/* eslint-disable new-cap */
import { WASI } from "@wasmer/wasi";
import { WasmFs } from "@wasmer/wasmfs";
import { cleanStdout, uint2Str } from "./utils";

const wasmFs = new WasmFs();

const env = {
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
};

const bindings = {
  ...WASI.defaultBindings,
  fs: wasmFs.fs
};

const wasi = new WASI({
  env,
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
  const wasmBytes = new Uint8Array(response).buffer;
  const module = await WebAssembly.compile(wasmBytes);
  const options = wasi.getImports(module);
  options["env"] = env;
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
