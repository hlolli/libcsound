/* eslint-disable */
class CsoundWorkletProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.port.onmessage = event => {
      const arr = new Uint8Array(event.data);
      console.log(arr);
    };
  }
  process(inputs, outputs, parameters) {
    return true;
  }
}

registerProcessor("csound-worklet-processor", CsoundWorkletProcessor);
// console.log(this);
// window.addEventListener("message", data => {
//   console.log(data);
// });
