/*
## SuperDirt Effects

|  S  |  P  |  M  | Name
|-----|-----|-----|--------------
| [x] | [ ] | [x] | Leslie
| [x] | [ ] | [ ] | Time Stretcher
| [x] | [ ] | [ ] | Frequency Shifter
| [x] | [ ] | [x] | Octer
| [x] | [x] | [ ] | Delay
| [x] | [x] | [ ] | Reverb
| [?] | [x] | [x] | Overdrive
| [ ] | [x] | [x] | Chorus
| [x] | [x] | [x] | Tremolo
| [x] | [x] | [x] | Distortion
| [ ] | [x] | [x] | Flanger
| [x] | [x] | [x] | Phaser
| [ ] | [x] | [ ] | Compressor
| [ ] | [x] | [ ] | Sustain
| [x] | [x] | [ ] | Bitcrusher (crush)
| [ ] | [x] | [x] | Wavefolder
| [x] | [x] | [ ] | Ring Modulator
| [ ] | [x] | [?] | Pitch Shifter
| [ ] | [x] | [?] | Sub Boost
| [ ] | [x] | [x] | Vibrato
| [ ] | [x] | [x] | Auto-Wah
| [ ] | [x] | [x] | Lo-Fi
| [ ] | [x] | [ ] | Resonator, based on Mutable Instruments Rings
| [ ] | [x] | [ ] | Granular, based on Mutable Instruments Clouds
| [ ] | [x] | [x] | Amp Simulator
| [ ] | [x] | [ ] | Equalizer

Shortcuts:
- like chorusd

depth = d
rate = r
size = sz
mode = m
feedback = f
predelay = pd
sensitivity = s
res = rs

*/

// Chorus
~dirt.addModule('chorus', { |dirtEvent|
	dirtEvent.sendSynth("dirt_chorus" ++ ~dirt.numChannels,
		[
			chorusdepth: ~chorusdepth,
     		chorusrate: ~chorusrate,
			out: ~out
		]
	)
}, { ~chorusdepth.notNil && ~chorusrate.notNil });

SynthDef("dirt_chorus" ++ ~dirt.numChannels, { |out, chorusdepth = 0.5, chorusrate = 0.5|
	var sig;
    var numDelays = 4, lfos, maxDelayTime, minDelayTime;

	sig = In.ar(out, ~dirt.numChannels);

	// Adapted from @madskjeldgaard's Sleet
    chorusrate = Select.kr(chorusrate > 0.5, [
      LinExp.kr(chorusrate, 0.0, 0.5, 0.025, 0.125),
      LinExp.kr(chorusrate, 0.5, 1.0, 0.125, 2)
    ]);
    maxDelayTime = LinLin.kr(chorusdepth, 0.0, 1.0, 0.016, 0.052);
    minDelayTime = LinLin.kr(chorusdepth, 0.0, 1.0, 0.012, 0.022);
    sig = sig * numDelays.reciprocal;
    lfos = Array.fill(numDelays, {|i|
      LFPar.kr(
        chorusrate * {rrand(0.95, 1.05)},
        \phasediff.kr(0.9) * i,
        (maxDelayTime - minDelayTime) * 0.5,
        (maxDelayTime + minDelayTime) * 0.5,
      )
    });

	ReplaceOut.ar(out, LeakDC.ar(DelayC.ar(sig, (maxDelayTime * 2), lfos).sum));
}, [\ir, \ir]).add;

// Flanger
~dirt.addModule('flanger', { |dirtEvent|
	dirtEvent.sendSynth("dirt_flanger" ++ ~dirt.numChannels,
		[
			flangerrate: ~flangerrate,
     		flangerdepth: ~flangerdepth,
			flangerfeedback: ~flangerfeedback,
			flangerpredelay: ~flangerpredelay,
			out: ~out
		]
	)
	}, { ~flangerdepth.notNil || ~flangerrate.notNil });

SynthDef("dirt_flanger" ++ ~dirt.numChannels, { |out, flangerrate = 0.5, flangerdepth = 0.5, flangerfeedback = 0.5, flangerpredelay = 0.5|
	var sig, numChannels, maxDelay, feedbackSignal, lfo, delayedSignal;

	sig = In.ar(out, ~dirt.numChannels);

	numChannels = 2;
    maxDelay = 0.0105;
	flangerrate = flangerrate.linexp(0, 1, 0.1, 8);
	flangerdepth = flangerdepth.linexp(0, 1, 0.00025, maxDelay * 0.45);
	flangerpredelay = LinLin.kr(flangerpredelay, 0, 1, flangerdepth, maxDelay - flangerdepth);
    // Allow just-beyond-unity feedback
	flangerfeedback = LinLin.kr(flangerfeedback, 0, 1, 0.0, 1.1);
    feedbackSignal = LocalIn.ar(2);
    feedbackSignal = Select.ar(flangerfeedback >= 1, [
      (feedbackSignal * flangerfeedback),
      (feedbackSignal * flangerfeedback).softclip
    ]);
    lfo = LFPar.kr(flangerrate, 0, flangerdepth, flangerpredelay);
    delayedSignal = DelayC.ar(sig + feedbackSignal, maxDelay, lfo);
    LocalOut.ar(delayedSignal + sig);

	ReplaceOut.ar(out, LeakDC.ar(sig + delayedSignal));
}, [\ir, \ir, \ir, \ir]).add;


// Auto Wah
~dirt.addModule('autowah', { |dirtEvent|
	dirtEvent.sendSynth("dirt_autowah" ++ ~dirt.numChannels,
		[
			wahrate: ~wahrate,
     		wahdepth: ~wahdepth,
			wahsensitivity: ~wahsensitivity,
			wahmode: ~wahmode,
			wahres: ~wahres,
			out: ~out
		]
	)
	}, { ~wahrate.notNil || ~wahdepth.notNil });


SynthDef("dirt_autowah" ++ ~dirt.numChannels, { |out, wahrate = 0.9, wahdepth = 0.5, wahsensitivity = 0.5, wahmode = 0.5, wahres = 0.5|

	var sig, numChannels, maxDelay, feedbackSignal, lfo, delayedSignal;
	var sensitivityMultiplier, envelopeFollower, depth, res, rq, bpMultiplier, formantRatio, minCutoffFreq1, maxCutoffFreq1, cutoffFreq1, minCutoffFreq2, maxCutoffFreq2, cutoffFreq2;

	sig = In.ar(out, ~dirt.numChannels);

    sensitivityMultiplier = LinLin.kr(wahsensitivity, 0, 1, 3, 9);

    envelopeFollower = Lag.ar(EnvFollow.ar(
      (sig * sensitivityMultiplier).clip(-1, 1), 0.999
    ),
    // 0.1225
	wahrate.linexp(0, 1, 0.4, 0.0375));

	// 194
    minCutoffFreq1 = wahdepth.linexp(0, 1, 440, 85);
    // 1386
    maxCutoffFreq1 = wahdepth.linexp(0, 1, 1100, 1750);
    cutoffFreq1 = envelopeFollower.linexp(0, 1, minCutoffFreq1, maxCutoffFreq1);
    // 1140
    minCutoffFreq2 = wahdepth.linexp(0, 1, 1450, 900);
    // 2445
    maxCutoffFreq2 = wahdepth.linexp(0, 1, 2175, 2750);
    cutoffFreq2 = envelopeFollower.linexp(0, 1, minCutoffFreq2, maxCutoffFreq2);
    rq = wahres.linexp(0, 1, 0.325, 0.01925);
    bpMultiplier = LinLin.kr(wahres, 0, 1, 2.5, 7.5);
    formantRatio = 0.75;
    sig = Select.ar(wahmode, [
      (RLPF.ar(sig, cutoffFreq1, rq, formantRatio) + RLPF.ar(sig, cutoffFreq2, rq, (1-formantRatio))) * 0.67,
      ((BPF.ar(sig, cutoffFreq1, rq * 2, formantRatio) + BPF.ar(sig, cutoffFreq2, rq * 2, (1-formantRatio))) * bpMultiplier).softclip,
      (RHPF.ar(sig, cutoffFreq1, rq, formantRatio) + RHPF.ar(sig, cutoffFreq2, rq, (1-formantRatio))) * 0.75,
    ]);

	ReplaceOut.ar(out, LeakDC.ar(sig));
}, [\ir, \ir, \ir, \ir, \ir]).add;


// Pedal Phaser
~dirt.addModule('phaser2', { |dirtEvent|
	dirtEvent.sendSynth("dirt_phaser2" ++ ~dirt.numChannels,
		[
			phaserr: ~phaserr,
     		phaserd: ~phaserd,
			out: ~out
		]
	)
	}, { ~phaserr.notNil || ~phaserd.notNil });


SynthDef("dirt_phaser2" ++ ~dirt.numChannels, { |out, phaserr = 0.5, phaserd = 0.5|
	var numChannels, maxDelay, preDelay, numAllPasses, delayedSignal, sig;

	sig = In.ar(out, ~dirt.numChannels);

    numChannels = 2;
    maxDelay = 0.01;
    phaserr = phaserr.linexp(0, 1, 0.275, 16);
    phaserd = phaserd.linexp(0, 1, 0.0005, maxDelay * 0.5);
    // multi-stage Allpass
    numAllPasses = 4;
    phaserd = phaserd * numAllPasses.reciprocal;
    delayedSignal = sig;
    for(1, numAllPasses, {|i|
      delayedSignal = AllpassL.ar(delayedSignal, maxDelay * numAllPasses.reciprocal, LFPar.kr(phaserr, i + 0.5.rand, phaserd, phaserd), 0);
    });

	ReplaceOut.ar(out, LeakDC.ar(sig + delayedSignal));
}, [\ir, \ir]).add;

// Vibrato Phaser
~dirt.addModule('vibrato', { |dirtEvent|
	dirtEvent.sendSynth("dirt_vibrato" ++ ~dirt.numChannels,
		[
			vibrator: ~vibrator,
     		vibratod: ~vibratod,
			vibratoe: ~vibratoe,
			out: ~out
		]
	)
	}, { ~vibrator.notNil || ~vibratod.notNil || ~vibratoe.notNil });


SynthDef("dirt_vibrato" ++ ~dirt.numChannels, { |out, vibrator = 0.5, vibratod = 0.5, vibratoe = 0.5|
    var sig, envelopeFollower, envMultiplier, mul, minRate, maxDepth, maxDelay;

	sig = In.ar(out, ~dirt.numChannels);

    // Track the amplitude, so we vibrato more and faster when the signal is louder
    envelopeFollower = Lag.ar(EnvFollow.ar((sig * 6).clip(-1, 1), 0.999), 0.14);
    // Expression scales how much the envelope influences our vibrato
    envMultiplier = (1 - vibratoe) + (envelopeFollower * vibratoe);
    // Delay the vibrato until after the attack  portion of a typical envelope
    envMultiplier = DelayN.ar(envMultiplier, 0.1, 0.07);
    // Rate is how many vibratos per second
    minRate = 0.75;
    vibrator = LinExp.ar(vibrator * envMultiplier, 0, 1, minRate, 60);
    // Depth is pitch bend range in cents
    maxDepth = 30;
    vibratod = LinExp.ar(vibratod * envMultiplier, 0, 1, 3.3, maxDepth);
    // Mul calculates the amplitude of the LFO for our delay to achieve the given rate and depth
    mul = ((2 ** (vibratod * 1200.reciprocal)) - 1)/(4 * vibrator);
    maxDelay = (((2 ** (maxDepth * 1200.reciprocal)) - 1)/(4 * minRate)) * 2.5;
    sig = DelayC.ar(sig, maxDelay, SinOsc.ar(vibrator, 2, mul, mul + ControlRate.ir.reciprocal));

	ReplaceOut.ar(out, LeakDC.ar(sig));
}, [\ir, \ir, \ir]).add;

// Wavefolder
~dirt.addModule('wavefolder', { |dirtEvent|
	dirtEvent.sendSynth("dirt_wavefolder" ++ ~dirt.numChannels,
		[
			wavefolderamount: ~wavefolderamount,
     		wavefoldersymmetry: ~wavefoldersymmetry,
			wavefoldersmoothing: ~wavefoldersmoothing,
			wavefolderexpression: ~wavefolderexpression,
			out: ~out
		]
	)
	}, { ~wavefolderamount.notNil || ~wavefoldersymmetry.notNil || ~wavefoldersmoothing.notNil || ~wavefolderexpression.notNil });


SynthDef("dirt_wavefolder" ++ ~dirt.numChannels, { |out, wavefolderamount = 0.5, wavefoldersymmetry = 1, wavefoldersmoothing = 0.5, wavefolderexpression = 0.5 |
	var gain, sig, compensationGain, envFollower, amp;

	sig = In.ar(out, ~dirt.numChannels);

    gain = LinLin.kr(wavefolderamount, 0, 1, 1, 20);

    // The gain needed to have the folding kick in is so huge that we wanna knock it back down after folding
    compensationGain = max(gain * 0.75, 1).reciprocal;
    // We mix this with an envelope follower so that the output envelope follows the input envelope
    envFollower = EnvFollow.ar((sig * 2).softclip, 0.9999);
    amp = (compensationGain * (1 - wavefolderexpression)) + (envFollower * wavefolderexpression);

    wavefoldersymmetry = LinLin.kr(wavefoldersymmetry, 0, 1, 1, 0);
    sig = SmoothFoldS.ar((sig + wavefoldersymmetry) * gain, smoothAmount: wavefoldersmoothing);
    // LeakDC is essential after folding due to how wavefoldersymmetry adds DC offset.
    // Luckily, the base pedal does that for us
    sig = sig * amp;

	ReplaceOut.ar(out, LeakDC.ar(sig));
}, [\ir, \ir, \ir, \ir]).add;



// Distortion
~dirt.addModule('distortion', { |dirtEvent|
	dirtEvent.sendSynth("dirt_distortion" ++ ~dirt.numChannels,
		[
			distdrive: ~distdrive,
     		disttone: ~disttone,
			out: ~out
		]
	)
	}, { ~distdrive.notNil || ~disttine.notNil });


SynthDef("dirt_distortion" ++ ~dirt.numChannels, { |out, distdrive = 0.5, disttone = 0.5 |
	var sig, freq, filterType;

	sig = In.ar(out, ~dirt.numChannels);

    // First we feed into a HPF to filter out sub-20Hz
    sig = HPF.ar(sig, 25);
    // Then we feed into the distortion
    // Drive controls 1 to 5x the volume with hard-clipping
    sig = (sig * distdrive.linexp(0, 1, 1, 10)).distort;

    // Then we feed into the Tone section
    // Tone controls a MMF, exponentially ranging from 10 Hz - 21 kHz
    // Tone above 0.75 switches to a HPF
    freq = Select.kr(disttone > 0.75, [
      Select.kr(disttone > 0.2, [
        LinExp.kr(disttone, 0, 0.2, 10, 400),
        LinExp.kr(disttone, 0.2, 0.75, 400, 20000),
      ]),
      LinExp.kr(disttone, 0.75, 1, 20, 21000),
    ]);
    filterType = Select.kr(disttone > 0.75, [0, 1]);
    sig = DFM1.ar(
      sig,
      freq,
      \res.kr(0.1),
      1.0,
      filterType,
      \noise.kr(0.0003)
    ).softclip;

	ReplaceOut.ar(out, LeakDC.ar(sig));
}, [\ir, \ir]).add;

// Analog Vintage Distortion
~dirt.addModule('analogDistortion', { |dirtEvent|
	dirtEvent.sendSynth("dirt_analogDistortion" ++ ~dirt.numChannels,
		[
			adistgain: ~adistgain,
			adisttone: ~adisttone,
			out: ~out
		]
	)
	}, { ~adistgain.notNil });

SynthDef("dirt_analogDistortion" ++ ~dirt.numChannels, { |out, adistgain = 0.5, adisttone = 0.5 |
	var sig, freq, filterType;

	sig = In.ar(out, ~dirt.numChannels);

    // First we feed into a HPF to filter out sub-20Hz
    sig = HPF.ar(sig, 25);
    // Then we feed into the distortion
    // Drive controls 1 to 5x the volume with hard-clipping

	sig = AnalogVintageDistortion.ar(sig, drivegain: adistgain, bias: 0, lowgain: 0.6, highgain: 0.1, shelvingfreq: 600, oversample:0);

    // Then we feed into the Tone section
    // Tone controls a MMF, exponentially ranging from 10 Hz - 21 kHz
    // Tone above 0.75 switches to a HPF
    freq = Select.kr(adisttone > 0.75, [
      Select.kr(adisttone > 0.2, [
        LinExp.kr(adisttone, 0, 0.2, 10, 400),
        LinExp.kr(adisttone, 0.2, 0.75, 400, 20000),
      ]),
      LinExp.kr(adisttone, 0.75, 1, 20, 21000),
    ]);
    filterType = Select.kr(adisttone > 0.75, [0, 1]);
    sig = DFM1.ar(
      sig,
      freq,
      \res.kr(0.1),
      1.0,
      filterType,
      \noise.kr(0.0003)
    ).softclip;

	ReplaceOut.ar(out, LeakDC.ar(sig));
}, [\ir, \ir]).add;


// Overdrive
~dirt.addModule('overdrive', { |dirtEvent|
	dirtEvent.sendSynth("dirt_overdrive" ++ ~dirt.numChannels,
		[
			overdrive: ~overdrive,
     		overtone: ~overtone,
			out: ~out
		]
	)
	}, { ~overdrive.notNil || ~overtone.notNil });


SynthDef("dirt_overdrive" ++ ~dirt.numChannels, { |out, overdrive = 0.5, overtone = 0.5 |
	var sig, freq, filterType;

	sig = In.ar(out, ~dirt.numChannels);

    // First we feed into a HPF to filter out sub-20Hz
    sig = HPF.ar(sig, 25);
    // Then we feed into the overdrive
    // Drive controls 1 to 3x the volume with soft-clipping
    sig = (sig * LinLin.kr(overdrive, 0, 1, 1, 3)).softclip;

    // Then we feed into the Tone section
    // Tone controls a MMF, exponentially ranging from 10 Hz - 21 kHz
    // Tone above 0.75 switches to a HPF
    freq = Select.kr(overtone > 0.75, [
      Select.kr(overtone > 0.2, [
        LinExp.kr(overtone, 0, 0.2, 10, 400),
        LinExp.kr(overtone, 0.2, 0.75, 400, 20000),
      ]),
      LinExp.kr(overtone, 0.75, 1, 20, 21000),
    ]);
    filterType = Select.kr(overtone > 0.75, [0, 1]);
    sig = DFM1.ar(
      sig,
      freq,
      \res.kr(0.1),
      1.0,
      filterType,
      \noise.kr(0.0003)
    ).softclip;

	ReplaceOut.ar(out, LeakDC.ar(sig));
}, [\ir, \ir]).add;


// Lofi
~dirt.addModule('lofi', { |dirtEvent|
	dirtEvent.sendSynth("dirt_lofi" ++ ~dirt.numChannels,
		[
			lofidrive: ~lofidrive,
     		lofitone: ~lofitone,
     		lofiwow: ~lofiwow,
     		lofinoise: ~lofinoise,
			out: ~out
		]
	)
	}, { ~lofidrive.notNil || ~lofitone.notNil || ~lofiwow.notNil || ~lofinoise.notNil });


SynthDef("dirt_lofi" ++ ~dirt.numChannels, { |out, lofidrive = 0.5, lofitone = 0.5, lofiwow = 0.5, lofinoise = 0.5 |
	var sig, bitRate, noiseSignal, wowMul, maxDelay, wowRate, minWowRate;
	var rate, depth, maxDepth, depthLfoAmount, maxLfoDepth;
	var threshold, gain, ratio;

	sig = In.ar(out, ~dirt.numChannels);

    // First we feed into a HPF to filter out sub-20Hz
    sig = HPF.ar(sig, 25);
    // Shitty compression (slow attack and release, really aggressive ratio)
    ratio = lofidrive.linexp(0, 1, 0.15, 0.01);
    threshold = LinLin.kr(lofidrive, 0, 1, 0.8, 0.33);
    // We bump the gain to keep up with the threshold and ratio, then compress it
    gain = 1/(((1.0-threshold) * ratio) + threshold);
    sig = Limiter.ar(Compander.ar(sig, sig, threshold, 1.0, ratio, 0.1, 1, gain), dur: 0.0008);

    // Wow aka flutter aka warble
    minWowRate = 0.5;
    wowRate = lofiwow.linexp(0, 1, minWowRate, 4);
    maxDepth = 35;
    maxLfoDepth = 5;
    depth = lofiwow.linexp(0, 1, 1, maxDepth - maxLfoDepth);
    depthLfoAmount = LinLin.kr(lofiwow, 0, 1, 1, maxLfoDepth).floor;
    depth = LFPar.kr(depthLfoAmount * 0.1, mul: depthLfoAmount, add: depth);
    // wowMul calculates the amplitude of the LFO for our delay to achieve the given rate and depth
    wowMul = ((2 ** (depth * 1200.reciprocal)) - 1)/(4 * wowRate);
    maxDelay = (((2 ** (maxDepth * 1200.reciprocal)) - 1)/(4 * minWowRate)) * 2.5;
    sig = DelayC.ar(sig, maxDelay, SinOsc.ar(wowRate, 2, wowMul, wowMul + ControlRate.ir.reciprocal));

    // Tape/Vinyl-esque noise
    noiseSignal = (Dust2.ar(LinLin.kr(lofinoise, 0, 1, 1, 5), 1) + Crackle.ar(1.95, 0.1) + SinOsc.ar((PinkNoise.ar(0.5) * 7500) + 40, 0, 0.006));
    noiseSignal = noiseSignal * lofinoise.linexp(0, 1, 0.01, 1);

    // Saturation
    sig = ((sig * lofidrive.linexp(0, 1, 1, 2.5)) + noiseSignal).tanh;

    // Lots of LPFs and HPFs and a little bitcrushing
    sig = LPF.ar(sig, lofitone.linexp(0, 1, 2500, 10000));
    bitRate = 48000 * LinLin.kr(lofinoise, 0, 1, 0, 3).ceil.reciprocal;
    sig = (Decimator.ar(sig, bitRate, lofinoise.linexp(0, 1, 24, 6)) * 0.3) + (sig * 0.7);
    sig = HPF.ar(sig, lofitone.linexp(0, 1, 40, 1690));
    sig = MoogFF.ar(sig, lofitone.linexp(0, 1, 1000, 10000), 0);
    sig = sig * LinLin.kr(lofidrive, 0, 1, 1, 0.66);

	ReplaceOut.ar(out, LeakDC.ar(sig));
}, [\ir, \ir, \ir, \ir]).add;


// fxArguments { ^[\drive, \room, \bass, \mid, \treble, \presence]; }

// Amp simulation
~dirt.addModule('ampsimulation', { |dirtEvent|
	dirtEvent.sendSynth("dirt_ampsimulation" ++ ~dirt.numChannels,
		[
			ampdrive: ~ampdrive,
			amproom: ~amproom,
			ampbass: ~ampbass,
			ampmid: ~ampmid,
			amptreble: ~amptreble,
			amppresence: ~ampresence,
			out: ~out
		]
	)
	}, {~ampdrive.notNil || ~amproom.notNil || ~ampbass.notNil || ~ampmid.notNil || ~amptreble.notNil || ~amppresence.notNil});


SynthDef("dirt_ampsimulation" ++ ~dirt.numChannels, { |out, ampdrive = 0.5, amproom = 0.5, ampbass = 0, ampmid = 0, amptreble = 0, amppresence = 0.5 |
	var sig, asymmetric, buf, transferFunc;

	sig = In.ar(out, ~dirt.numChannels);

    // Define a transfer function simulating the Marshall JCM800's response
    // Originally adapted from Pakarinen, J., & Yeh, D. T. "A review of digital techniques for modeling vacuum-tube guitar amplifiers."
    buf = Buffer.alloc(~dirt.server, 2048, 2);
    transferFunc = Signal.fill(1025, { |i|
      var in = i.linlin(0.0, 1024, -1.0, 1.0);
      if (in <= -1, {
        -0.9818;
      }, {
        if (in < -0.08905, {
          (-0.75 * (1 - ((1 - (in.abs - 0.029847)) ** 12) + (0.333 * (in.abs - 0.029847)))) + 0.01;
        }, {
          if (in < 0.320018, {
            (-6.153 * (in ** 2)) + (3.9375 * in);
          }, {
            0.6140341 + (0.05 * in);
          });
        });
      });
    });
    buf.sendCollection(transferFunc.asWavetableNoWrap);

    // Send through an initial pair of low-shelf filters
    sig = BLowShelf.ar(sig, 720, 1, -3.3);
    sig = BLowShelf.ar(sig, 320, 1, -5);
    // Use the transfer function (and xfade it with the "dry" signal based on the drive control)
    asymmetric = Shaper.ar(buf.bufnum, sig);
    sig = XFade2.ar(sig, asymmetric, LinLin.kr(ampdrive, 0, 1, -1, 1));
    sig = LeakDC.ar(sig);
    // Send through another low-shelf and another softclip-esque amplifier
    sig = BLowShelf.ar(sig, 720, 1, -6);
    sig = (sig * LinLin.kr(ampdrive, 0, 1, 1.5, 3.5)).tanh;

    // Send through the tone section
    sig = BLowShelf.ar(sig, freq: 100, db: ampbass);
    sig = BPeakEQ.ar(sig, freq: 1700, rq: 0.7071.reciprocal, db: ampmid);
    sig = BHiShelf.ar(sig, freq: 6500, db: amptreble);
    sig = BPeakEQ.ar(sig, freq: 3900, db: LinLin.kr(amppresence, 0, 1, -12, 12));

    // Filter out some harsh frequencies
    sig = BPeakEQ.ar(sig, freq: 10000, db: -25);
    sig = BPeakEQ.ar(sig, freq: 60, db: -19);

    // Finally, send through a basic reverb
    sig = FreeVerb.ar(
      sig, mix: amproom.linexp(0, 1, 0.2, 0.8),
      room: amproom.linexp(0, 1, 0.2, 0.8),
      damp: amproom.linexp(0, 1, 0.9, 0.1)
    );

	ReplaceOut.ar(out, LeakDC.ar(sig));
}, [\ir, \ir, \ir, \ir, \ir, \ir]).add;


// Original module order
//~dirt.orderModules(['sound', 'vowel', 'shape', 'hpf', 'bpf', 'crush', 'coarse', 'lpf', 'pshift', 'envelope', 'grenvelo', 'tremolo', 'phaser', 'waveloss', 'squiz', 'fshift', 'triode','krush', 'octer', 'ring', 'distort', 'spectral-delay', 'spectral-freeze', 'spectral-comb', 'spectral-smear', 'spectral-scram', 'spectral-binshift', 'spectral-hbrick', 'spectral-lbrick', 'spectral-conformer', 'spectral-enhance', 'dj-filter', 'out_to', 'map_from', 'chorus', 'flanger', 'autowah', 'phaser2', 'vibrato', 'wavefolder', 'distortion', 'overdrive', 'lofi', 'ampsimulation']);

~dirt.orderModules(['sound', 'autowah', 'vowel', 'shape', 'hpf', 'bpf', 'crush', 'coarse', 'lpf', 'pshift', 'envelope', 'grenvelo', 'tremolo', 'vibrato', 'phaser', 'phaser2', 'waveloss', 'wavefolder', 'squiz', 'fshift', 'triode','krush', 'octer', 'ring', 'analogDistortion', 'distort', 'distortion', 'overdrive', 'ampsimulation', 'chorus', 'flanger', 'spectral-delay', 'spectral-freeze', 'spectral-comb', 'spectral-smear', 'spectral-scram', 'spectral-binshift', 'spectral-hbrick', 'spectral-lbrick', 'spectral-conformer', 'spectral-enhance', 'dj-filter', 'lofi', 'out_to', 'map_from']);

3.linlin(0,1,1.5,3.5)