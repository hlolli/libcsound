const test = require("ava");

const test1 = `
<CsoundSynthesizer>
<CsInstruments>
sr = 44100
ksmps = 32
nchnls = 2
0dbfs = 1
instr 1
asig  bamboo p4, 0.01
      outs asig, asig
endin
</CsInstruments>
<CsScore>
i1 0 1 0.2
e
</CsScore>
</CsoundSynthesizer>
`;

var libcsound;

const load = () => {
    return new Promise((resolve, reject) => {
        libcsound = require("./result/lib/libcsound_node.js")({
            onRuntimeInitialized: () => resolve(),
            print: m => console.log(m),
            printErr: m => console.log(m)
        });
    })
}


load().then(() => {
    const csound = libcsound.cwrap("CsoundObj_new", ["number"], null)();

    ["-+rtaudio=null", "-+rtmidi=null"].forEach(opt => {
        libcsound.cwrap("CsoundObj_setOption", null, ["number", "string"])(
            csound, opt
        );
    });

    libcsound.cwrap("CsoundObj_compileCSD", null, ["number", "string"])(
        csound, test1
    );

    test('adds 1 + 2 to equal 3', () => {
        expect(sum(1, 2)).toBe(3);
    });
})


setTimeout(() => process.exit(0), 10 * 1000)
