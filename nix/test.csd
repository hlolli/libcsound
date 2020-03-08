<CsoundSynthesizer>
<CsOptions>
</CsOptions>
<CsInstruments>

sr = 44100
ksmps = 32
nchnls = 2
0dbfs = 1.0

opcode EnvOsc,a,aaiiij
  amp,afr,irise,idur,idec,ifn xin
  a1 oscili amp,afr,ifn
  a2 linen a1, irise, idur, idec
  xout a2
endop

instr 1
  amod1 EnvOsc a(p6*p5),a(p5),0.1,p3,0.1
  amod2 EnvOsc a(p7*p5),a(p5*2),0.2,p3,0.4
  amod3 EnvOsc a(p7*p5),a(p5*3),0.2,p3,0.4
  asig EnvOsc a(p4),amod1+amod2+amod3+p5,0.01,p3,0.1
  outs asig, asig
endin

</CsInstruments>
<CsScore>

i1 0 2 1 1000 900 100.1


</CsScore>
</CsoundSynthesizer>
