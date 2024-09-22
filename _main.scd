(

// 22 September responsive improvior. This will totally work.

var detectingPitch = true, dEBUG=true, semaphore, bufs, riffs, current, phraseStart = -1, internalArousal=0.1,
arousalSempahore, generatedRiffs, startTime=0, elapsedTime=0, storeRiff, shortCount=0, layoutGate=0, layoutBus,
soloInclination=0, clock, compBus, serpentBus, recPuter, recSerpent, looper, startSynth, routs, section=0,
looperSemaphore, sourceGroup, processGroup, fxGroup, sectionUpdater, shouldEnd=false, totalDur=1800,
shouldChange = false, lastNOnsets, onsetArrSize=20, getAvgTempo, getAvgOctave, getRiffTempo,
skipAheadForTesting = false, win;

win =  Window.new("Emergency Change");

Button(win, Rect(20, 20, 340, 30))
.states_([
	["should change"]
])
.action_({ arg butt;
	"forcing change".postln;
	shouldChange = true;
});

TextView(win, Rect(20, 70, 340, 250)).string_("Go Slow.\nDrone\nSpecial FX over Loops\nSlow\nMellow\nThink 1970s\nPeople want to like this\n\nVoice\nMouth shape\nShake horn");

win.front;





semaphore = Semaphore(1);
arousalSempahore = Semaphore(1);
looperSemaphore = Semaphore(1);

bufs = [];
riffs = [ ];
current = [];
lastNOnsets = Array(onsetArrSize);

getAvgTempo = {
	var timings;
	(lastNOnsets.size > 2).if({ // making this 2 instead of 1 prevents a race condition
		timings = lastNOnsets.differentiate;
		timings.removeAt(0);
		timings.median;
	}, {
		1
	});
};

getRiffTempo = {|riff|

	var timings;

	timings = riff.collect({|pair| pair.last });
	timings.median;
};


getAvgOctave = {
	var freqs, ret = 4;

	freqs = [];

	// this can get clobbered by race conditions, but it waiting for a semaphore will fuck up
	// timing, so just put in a try in case it fucks up

	try {

		(current.size > 0).if({
			freqs = current[(current.size-5).max(0), current.size-1];
		});

		(freqs. size < 5).if({
			(riffs.size > 0).if({
				freqs = riffs.last[(riffs.last.size - (5-freqs.size)).max(0), riffs.last.size-1];
			}); // ok, that's quite enough
		});

		(freqs.size > 0).if({

			freqs = freqs.div(15);
			ret = freqs.mean;
		});
	} {};

	ret ? 4;
};

// put notes into current, massage out the pbding at the EOF, use phRase start to get the start time and build from there

s.options.memSize = s.options.memSize * 16;

generatedRiffs = 10.collect({
	5.rrand(20).collect ({ [5.rand, [2, 1].wchoose([0.7, 0.3])] }).pyramid(10.rand);
});

//riffs = [ generatedRiffs.last ];

storeRiff = { arg collected, time;
	var noteStartTime, prevFreq, prevStart=0, noteDur = 0, riff;

	"storeRiff".postln;
	collected.postln;

	riff = [];


	(collected.size > 1).if({
		shortCount = 0;

		collected.do({|note|
			// current.add([value, time]);
			note.postln;
			noteStartTime = note[1];
			(prevStart !=0).if({
				noteDur =  noteStartTime - prevStart;
				//"found note % %".format(prevFreq, noteDur).postln;
				(noteDur > 0.09).if({ // don't add super short notes
					//"add note % %".format(prevFreq, noteDur).postln;
					(prevFreq > 30).if({
						riff = riff.add([prevFreq, noteDur]);
					}, {
						riff = riff.add([Rest(noteDur), noteDur]);
					});
					prevStart = noteStartTime;
				});

			},{
				prevStart = noteStartTime; // get the initial time!!
			});
			// assume later frequencies are correct because of onsets etc
			prevFreq = note[0];
		});
		// add the last note
		noteDur = (time - 2) - prevStart;
		((noteDur >= 0.1) && (noteDur < 30)).if({
			(prevFreq > 30).if({
				riff = riff.add([prevFreq, noteDur]);
			}, {
				riff = riff.add([Rest(noteDur), noteDur]);
			});
		});
		// add all the notes to the list of riffs
		(riff.size > 1).if({
			riffs = riffs.add(riff);
		})
	}, {
		shortCount = shortCount +1;
	});
};

sectionUpdater = {|current, adjustedTime|

	var elapsedTime;
	adjustedTime = adjustedTime ? startTime;

	elapsedTime = (Date.getDate.rawSeconds - adjustedTime).abs;

	"update suggested at %".format(elapsedTime).postln;

	// Section 0 must last for 2 minutes
	((elapsedTime > 120) && current == 0) .if({
		section = 1;
	});
	// Section 1 must last for at least 3.5 minutes
	((elapsedTime > ((3.5+2) * 60)) && current == 1).if({
		section = 2;
	});

};


s.waitForBoot({

	// Discconect from internal mic
	"pw-link -d alsa_input.pci-0000_00_1f.3.analog-stereo:capture_FL SuperCollider:in_1".unixCmd;
	"pw-link -d alsa_input.pci-0000_00_1f.3.analog-stereo:capture_FR SuperCollider:in_2".unixCmd;
	"pw-link -d alsa_output.pci-0000_00_1f.3.analog-stereo:monitor_FL SuperCollider:in_3".unixCmd;
	"pw-link -d alsa_output.pci-0000_00_1f.3.analog-stereo:monitor_FR SuperCollider:in_4".unixCmd;

	// connect the first channel of the card to (both inputs??) of supercollider
	"pw-link alsa_input.usb-M-Audio_Fast_Track_Ultra-00.analog-surround-71:capture_FL SuperCollider:in_1".unixCmd;
	"pw-link alsa_input.usb-M-Audio_Fast_Track_Ultra-00.analog-surround-71:capture_FL SuperCollider:in_2".unixCmd;



	// Connect SC out to the card
	"pw-link SuperCollider:out_1 alsa_output.usb-M-Audio_Fast_Track_Ultra-00.analog-surround-71:playback_FL".unixCmd;
	"pw-link SuperCollider:out_2 alsa_output.usb-M-Audio_Fast_Track_Ultra-00.analog-surround-71:playback_FR".unixCmd;
	"pw-link SuperCollider:out_3 alsa_output.usb-M-Audio_Fast_Track_Ultra-00.analog-surround-71:playback_RL".unixCmd;


	// Disconnect SC output from built in audio
	//"pw-link -d SuperCollider:out_1 alsa_output.pci-0000_00_1f.3.analog-stereo:playback_FL".unixCmd;
	//"pw-link -d SuperCollider:out_2 alsa_output.pci-0000_00_1f.3.analog-stereo:playback_FR".unixCmd;





	"-------router then unmute-----------------".postln;

	s.meter;

	ClockFace().start;


	layoutBus = Bus.control(s);
	compBus = Bus.audio(s, 2);
	serpentBus = Bus.audio(s);

	sourceGroup = Group(s);
	processGroup = Group(sourceGroup, \addAfter);
	fxGroup = Group(processGroup, \addAfter);

	bufs =[
		Buffer.alloc(s, s.sampleRate * 60, 1),
		Buffer.alloc(s, s.sampleRate * 60, 1),
		Buffer.alloc(s, s.sampleRate * 60, 1)
	];
	b = bufs;

	s.sync;

	// Let's have a delay line
	SynthDef(\delay, { arg gate=1, in=0, delayTime=60, maxDelay=120, out=0, amp=1, pan= -1;

		var input, delay, env, buf, panner;

		buf = LocalBuf(SampleRate.ir * maxDelay);

		input = SoundIn.ar(in, 1);
		env = EnvGen.kr(Env.asr, gate, doneAction:2);
		//delay = DelayC.ar(input, maxDelay, delayTime, amp);
		delay = BufDelayN.ar(buf, input, delayTime, amp);
		panner = Pan2.ar(delay, pan, env);

		Out.ar(out, panner);
	}).add;


	// looping recorder
	SynthDef(\record, {arg gate=1, in=0, loop=1, bufnum=0, offset=0, loopPoint=1;

		var input, recorder, env, min, max, index, frames;

		frames = BufFrames.ir(bufnum);
		max = loopPoint * frames;
		min = offset * frames;

		input = SoundIn.ar(in, 1);
		env = EnvGen.kr(Env.asr, gate, doneAction:2);
		//recorder = RecordBuf.ar(input * env, bufnum, loop:loop, doneAction:2);
		index = Phasor.ar(0, 1,min, max, min);
		recorder = BufWr.ar(input * env, bufnum, index, loop);
	}). add;

	SynthDef(\recordBus, {arg gate=1, in=0, loop=1, bufnum=0, offset=0, loopPoint=1;

		var input, recorder, env, min, max, index, frames;

		frames = BufFrames.ir(bufnum);
		max = loopPoint * frames;
		min = offset * frames;

		input = In.ar(in, 1);
		env = EnvGen.kr(Env.asr, gate, doneAction:2);
		//recorder = RecordBuf.ar(input * env, bufnum, loop:loop, doneAction:2);
		index = Phasor.ar(0, 1,min, max, min);
		recorder = BufWr.ar(input * env, bufnum, index, loop);
	}). add;

	// looping buffer player
	SynthDef(\player, { arg gate=1, out=0, amp=0.2, bufnum=0, offset=0, loopPoint=0.25, rate=1, pan=0, loop=1;

		var env, player, index, max, min, loopDur, frames, lpf, panner, verb;

		frames = BufFrames.ir(bufnum);
		max = loopPoint * frames;
		min = offset * frames;
		//loopDur =  rate;// rate * (loopPoint - offset);
		index = Phasor.ar(0, BufRateScale.kr(bufnum) * rate, min, max, min);

		player = BufRd.ar(1, bufnum, index, loop);
		env = EnvGen.kr(Env.asr(1,1,5), gate, doneAction:2) * Lag.kr(amp, 3);

		lpf = LPF.ar(player, 1500);
		verb = FreeVerb.ar(lpf);
		panner = Pan2.ar(verb, pan, env);

		Out.ar(out, panner);
	}).add;

	SynthDef(\player2, { arg gate=1, out=0, amp=0.2, bufnum=0, offset=0, loopPoint=0.25, rate=1, pan=0, loop=1;

		var env, player, index, max, min, loopDur, frames, lpf, panner, verb, shaped;

		frames = BufFrames.ir(bufnum);
		max = loopPoint * frames;
		min = offset * frames;
		//loopDur =  rate;// rate * (loopPoint - offset);
		index = Phasor.ar(0, BufRateScale.kr(bufnum) * rate, min, max, min);

		player = BufRd.ar(1, bufnum, index, loop);
		shaped = SinOsc.ar(Rand(0.0, 0.001), player).distort;
		env = EnvGen.kr(Env.asr(1,1,5), gate, doneAction:2) * Lag.kr(amp, 3);

		lpf = LPF.ar(shaped, 1500);
		verb = FreeVerb.ar(lpf);
		panner = Pan2.ar(verb, pan, env);

		Out.ar(out, panner);
	}).add;


	SynthDef(\bajorSpa, { arg gate=1, out=0, amp=1, freq=440, spread = 1, centre=0, dur = 1;

		var env, saws, lpf, fenv;

		env = EnvGen.kr(Env.adsr(Rand(0.005, 0.02), Rand(02, 0.4)), gate, doneAction:2);
		saws = Splay.ar([
			Saw.ar(freq),
			Saw.ar(freq + 1) * WhiteNoise.kr(0.02, 0.9),
			Saw.ar(freq -1) * WhiteNoise.kr(0.01, 0.9),
			Saw.ar(freq + 2) * WhiteNoise.kr(0.02, 0.9),
			Saw.ar(freq - 2) * WhiteNoise.kr(0.01, 0.9),
			Saw.ar(freq + 3) * WhiteNoise.kr(0.01, 0.9),
		].scramble, spread, amp, centre);

		fenv = EnvGen.kr(Env([1.5, 3, 1], [dur/3, dur/3, 1], \exp, releaseNode:3), gate);

		lpf = RLPF.ar(saws, freq * fenv, mul:env);

		Out.ar(out, lpf);
	}).add;

	SynthDef(\fm1, {|gate=1, amp=1, freq=440, dur=2, pan=0, out=0|

		var env, penv, fenv, fm, lpf, panner;

		env = EnvGen.kr(Env.adsr(sustainLevel:0.7), gate, doneAction:2);
		penv = EnvGen.kr(Env([0, 2pi, 0.1], [dur/2, dur/4], \sin, 2), gate);
		fenv = EnvGen.kr(Env([2, 4, 1], [dur/2, dur/2], \exp, 2), gate);

		fm = SinOsc.ar(freq,
			SinOsc.ar( freq * Demand.kr(Impulse.kr(0.000001), 0, Drand([1.5,2,3,4])),
				0, penv),
			amp);
		lpf = RLPF.ar(fm, freq * fenv);
		panner = Pan2.ar(lpf, pan, env);

		Out.ar(out, panner * amp*2);

	}).add;

	SynthDef(\binaural, {|out =0,freq=440, gate=1, amp=0.2, dur=1|

		var sinL, sinR, modSin, fmL, fmR, env, penv;

		penv = EnvGen.kr(Env.asr(0.05), gate) * 2pi;

		modSin = SinOsc.ar(freq * (15/11), penv);
		fmL = SinOsc.ar(Rand(0.08, 0.1), Rand(0, 2pi), 10, freq - 5);
		fmR = SinOsc.ar(Rand(0.08, 0.1), Rand(0, 2pi), 10, freq + 5);
		sinL = SinOsc.ar(fmL, modSin, amp/2.3);
		sinR = SinOsc.ar(fmR, modSin, amp/2.3);

		env = EnvGen.kr(Env.adsr(sustainLevel: 0.8, releaseTime:3), gate, doneAction:2);

		Out.ar(out, [sinL, sinR] * env);
	}).add;



	SynthDef(\vosim, {|freq=440, out=0, amp=0.2, gate=1, pan=0, dur=1|

		var vos, filt, fenv, env, frenv, panner;

		frenv = (EnvGen.kr(Env.adsr, gate) * 10) + (freq-5);
		vos = VOSIM.ar(Impulse.ar(XLine.kr(Rand(80, 90), Rand(98, 100), 0.1)),
			frenv, 3, XLine.kr(0.99, 0.8, 2));
		fenv = EnvGen.kr(Env.adsr, gate) * freq * 8;
		filt = RLPF.ar(vos, fenv);
		env = EnvGen.kr(Env.asr, gate, doneAction:2);
		panner = Pan2.ar(filt, pan, env);

		Out.ar(out, panner*amp*0.5);
	}).add;

	// One mode: track pitch, use that to do something

	SynthDef(\pitch, { arg gate=1, in=0, thresh=0.2, space= /* 0.5 */1, longspace= /* 1 */ 3, layout= /* 3 */ 5,
		rmswindow = 1600, layoutBus, soloRandTrig, lineBreakEnvDelay, lineBreakEnvDelayTime;

		var input, env, fft_pitch, onset, chain, hasfreq, paused, linebreak, rest,
		rms, xings, peaks, freq, fgate, ftrig, changed, lineBreakGate, lineBreakEnv;

		input = SoundIn.ar(in, 1);
		env = EnvGen.kr(Env.asr, gate, doneAction:2);

		chain = FFT(LocalBuf(2048), input);
		onset = Onsets.kr(chain, odftype:\phase);//odftype:\wphase);
		#fft_pitch, hasfreq = Pitch.kr(input, maxFreq:300, ampThreshold:thresh);
		paused = DetectSilence.ar(input, thresh, space);
		linebreak = DetectSilence.ar(input, thresh, longspace);
		rest = DetectSilence.ar(input, thresh, layout);

		// time donaim
		rms = (RunningSum.ar(input.squared, rmswindow)/rmswindow).sqrt;
		peaks = input - rms;
		xings = ZeroCrossing.ar(peaks);
		freq = xings /2;

		//send pitch
		SendTrig.kr(hasfreq, 0, fft_pitch);

		// triggering/gating time domain pitch
		//fgate = A2K.kr(EnvFollow.ar(input));
		fgate = (A2K.kr(paused) - 1 ).abs;
		// when paused is 1, paused -1 is zero, else, non zero

		// time domain pitch - send after the onset
		//ftrig = Impulse.kr(10/60);
		//hasfreq + (TDelay.kr(onset, 0.1));// + fgate;
		changed = A2K.kr(Changed.ar(freq, 5));
		ftrig = changed.not;
		//freq = freq * fgate;
		//SendTrig.kr(hasfreq * fgate, 4, freq);
		//SendTrig.kr(TDelay.kr(onset, 0.05) * fgate, 4, freq);
		SendTrig.kr(ftrig * fgate, 4, freq);
		//SentTrig.kr(TDelay.kr(changed, 0.05), 4, freq);


		// send onsets
		SendTrig.kr(onset, 1, 1);

		// send silence
		SendTrig.kr(A2K.kr(paused), 2, 1);

		// long silence (End of line)
		lineBreakGate = A2K.kr(linebreak);
		SendTrig.kr(lineBreakGate, 3, 1);

		soloRandTrig = Dust.kr(0.005);
		lineBreakGate = lineBreakGate + EnvGen.kr(Env([0, 1, 1, 0], [1, Rand(5, 60),1]),soloRandTrig);
		// This gate is additive, so it goes up to 1, then subtracts to -1 <-- NO!!
		lineBreakEnv = EnvGen.kr(Env.asr(40, 4, 40),lineBreakGate );//EnvGen.kr(Env([0, 1, 0], [2, 0.1, 4], \lin, 1), lineBreakGate);
		lineBreakEnvDelayTime = Demand.kr(lineBreakGate, 0, Dwhite(0, 39));
		lineBreakEnvDelay = DelayN.kr(lineBreakEnv, lineBreakEnvDelayTime, 40);
		Out.kr(layoutBus, lineBreakEnv);


		// laying out for a bit
		SendTrig.kr(A2K.kr(rest), 5, 1);

	}).add;

	OSCdef(\domifare_in, {|msg, time, addr, recvPort|
		var tag, node, id, value, letter, result, err, last, diffRatio;

		{
			semaphore.wait;

			#tag, node, id, value = msg;
			//[tag, id, value].postln;
			case
			{ id ==0 } { /* pitch */
				//"pitch".postln;
				layoutGate=0;

				//"not recording".postln;
				detectingPitch.if({
					dEBUG.if({
						"autocorrelation %".format(value).postln;
					});

					//(phraseStart -- inprogress
					//lang.input_method.if ({
					//	this.freq_(value, time);
					//},{"not auto".postln;});

					// check for changes
					last = current.last;

					last.notNil.if({
						// Get difference
						diffRatio = last[0].max(value) / last[0].min(value);
					}, { // actually infinite ratio, but we'll say 2
						diffRatio = 2
					});

					(diffRatio > 1.02).if({

						// append the [value, time]
						((value > 45) && (value <1500)).if({
							current = current.add([value, time]);
						});
						current.postln;
					});
				});

			}
			{ id ==1 } { /* onset */
				//this.received_onset = time;
				layoutGate=0;
				(lastNOnsets.size >= onsetArrSize).if({
					lastNOnsets.removeAt(0);
				});
				lastNOnsets.add(time);

			}
			{ id ==2 } { /* space */

				detectingPitch.if({

					dEBUG.if({ "space".postln });

					// We don't start with a rest with this algorithm

					last = current.last;

					last.notNil.if({
						((time - last[1]).abs > 0.1).if ({
							current = current.add([0, time]); // half a second before a space is detected
						})
					});
					//this.received_space = time;


				});

			}
			{ id ==3 } { /* EOL */

				detectingPitch.if({
					dEBUG.if({ "eol".postln; });
					//lang.eol;
					storeRiff.(current, time);
					current = [];
					0.1.coin.if({ shouldChange = true });
				});

				layoutGate=1;
			}
			{ id == 5 } { /* layout */
				detectingPitch.if({


					dEBUG.if({
						"layout %".format(value).postln;
					});
					//lang.input_method.not.if({
					//	this.freq_(value, time);
					//},{"not time".postln;});

					//0.5.coin.if({ shouldChange = true });
				});

			};

			semaphore.signal;
		}.fork;

	}, '/tr', s.addr);



	// Another mode, make a recording, delay it, play it back (this may rely on EOLs

	s.sync;
	Synth(\pitch,[\layoutBus, layoutBus],sourceGroup);
	recPuter = Synth(\recordBus, [\in, compBus, \bufnum, bufs[0]], processGroup);
	recSerpent = Synth(\record, [\bufnum, bufs[1]], sourceGroup);

	s.sync;

	startTime = Date.getDate.rawSeconds;
	clock = TempoClock(1/20);
	clock.play;

	routs = [ // 0
		{|interactionStart=10|
			var adjustedTime;
			adjustedTime = ((interactionStart - startTime)/2) + startTime;
			{
				var playingRiff, next;
				"section 0".postln;

				playingRiff = Pseq([
					Pseq(generatedRiffs.choose, 4),
					Pseq(generatedRiffs.choose, 4),
					Pseq(generatedRiffs.choose, 4)
				], inf).asStream;

				{section == 0}.while({
					//"note".postln;
					playingRiff.next.yield;
					(riffs.size > 0).if({
						sectionUpdater.(section, adjustedTime);
					});
				});

				//section = 1;
				startSynth = [ \bajorSpa, \fm1].choose;
				nil.yield;
			}
		},
		{ // 1

			var playingRiff, index, next, stretch;

			"section 1".postln;

			{section == 1}.while({
				index = (riffs.size -6).max(0).rrand(riffs.size-1);
				0.2.coin.if({
					0.2.coin.if({
						playingRiff = riffs[index].scramble.pyramid(10.rand);
					}, {
						playingRiff = riffs[index].pyramid(10.rand);
					})
				} , {
					playingRiff = riffs[index];
				});

				//riffs.postln;
				riffs.size.postln;

				playingRiff.postln;

				stretch = [2, 4, 8].wchoose([0.1, 0.45, 0.45]);

				playingRiff = Pseq(playingRiff, 2).asStream;
				next = playingRiff.next.copy;

				{next.notNil}.while({
					//next.postln;
					(next[1] < 1).if({
						//next[1] = next[1] * stretch;
					}, {
						(next[1] > 10).if({
							next[1] = next[1]/stretch;
						});
					});
					next.yield;
					next = playingRiff.next.copy;
				});
				"loop".postln;
			});
			startSynth = [ \bajorSpa, \fm1].choose;
			nil.yield;
		},
		{ //2
			var playingRiff, index, next, stretch, octave, pseq;

			"section 2".postln;

			pseq = [];
			//{shouldChange.not}.while({
			4.do({
				index = (riffs.size -6).max(0).rrand(riffs.size-1);
				0.2.coin.if({
					0.2.coin.if({
						playingRiff = riffs[index].scramble.pyramid(10.rand);
					}, {
						playingRiff = riffs[index].pyramid(10.rand);
					})
				} , {
					playingRiff = riffs[index];
				});

				pseq = pseq.add(Pseq(playingRiff, 2));
			});
			//riffs.postln;
			//riffs.size.postln;

			//playingRiff.postln;

			stretch = [2, 4, 8].wchoose([0.1, 0.45, 0.45]);
			octave = [1, 2, 0.5].choose;

			playingRiff = Pseq(pseq, 2).asStream;
			next = playingRiff.next.copy;

			{next.notNil && shouldChange.not}.while({
				//next.postln;
				next[0] = next[0] * octave;
				((next[1] < 2) && (next[1] > 0.1)).if({
					(soloInclination > 3).if({
						next[1] = next[1] / 1.5;
					});
				}, {
					(next[1] > 10).if({
						next[1] = next[1]/stretch;
					});
				});
				next.yield;
				next = playingRiff.next.copy;
			});
			//"loop".postln;
			//});
			nil.yield;
		}, // 3
		{|funcs, maxDur=420, maxLoops=10|
			{
				var playingRiff, index, next, stretch, octave, timeToMoveOn=false, loops=0;

				"can match or contrast".postln;

				Task({
					maxDur.wait;
					timeToMoveOn = true;
					"time to move on".postln;
				}).play;

				{timeToMoveOn.not && (loops < maxLoops)}.while({
					index = (riffs.size -6).max(0).rrand(riffs.size-1);
					0.2.coin.if({
						0.2.coin.if({
							playingRiff = riffs[index].scramble.pyramid(10.rand);
						}, {
							playingRiff = riffs[index].pyramid(10.rand);
						})
					} , {
						playingRiff = riffs[index];
					});

					funcs.do({|func|
						playingRiff = func.(playingRiff);
					});

					playingRiff = Pseq(playingRiff, 2).asStream;
					next = playingRiff.next.copy;

					{next.notNil && shouldChange.not}.while({
						next.yield;
						next = playingRiff.next.copy;
					});

					"loop".postln;
					loops = loops+1;
				});
				"ending match or contrast".postln;
				nil;

			}
		},
		{ //4
			var playingRiff, stretch = 1, dur=1, next;

			shouldChange = false;

			playingRiff = Pseq([
				Pseq(generatedRiffs.choose, 4),
				Pseq(generatedRiffs.choose, 4)
			], inf).asStream;

			next = playingRiff.next.copy;

			{shouldChange.not}.while({
				dur = next[1] * stretch
				[next[0], dur].yield;

				next = playingRiff.next.copy;
				stretch = stretch + 0.1;
				(dur > 10).if({
					shouldChange = true;
				});

			});
			nil.yield;

		}
	];


	// start slowly creeping up the energy level

	Task({

		var div, index, offset, loopPoint, rate, buf;

		"in task".postln;
		{ elapsedTime < (1800) }.while({  // 60 * 30
			arousalSempahore.wait;

			internalArousal = internalArousal +  0.00054; // 1 /1800

			arousalSempahore.signal;
			clock.tempo =  internalArousal;
			4.do({
				layoutBus.get({|val|
					//val.postln;
					arousalSempahore.wait;
					//internalArousal = internalArousal + val;
					soloInclination = val;
					arousalSempahore.signal;

					(section == 1 ).if({
						clock.tempo =  5.min(internalArousal + (soloInclination/2));
					});
					((soloInclination > 2) && (section > 0)).if({

						looper.isNil.if({
							looperSemaphore.wait;
							looper.isNil.if({
								"starting looper".postln;
								"section %".format(section).postln;
								div = 3.rrand(5);
								index = div.rand;
								offset = div.reciprocal * index;
								loopPoint = offset + div.reciprocal;
								//"% %".format(offset, loopPoint).postln;
								rate = 0.99.rrand(1.1);
								(section > 1).if({
									rate = 0.99.rrand(1.1) * [1, 0.5, 2].choose;
								});

								(section ==1).if({
									buf = bufs[1];
								}, {
									buf = [bufs[0], bufs[1]].choose;
								});

								looper = 4.rrand(6).collect({
									Synth(\player, [
										\bufnum, buf,
										\amp, 0.1,
										\pan, -0.75.rrand(0.75),
										\rate, rate,
										\offset, offset,
										\loopPoint, (loopPoint + 0.1.rand).min(1)
									], fxGroup)
								});
							});
							looperSemaphore.signal;
						}, {
							//"amp %".format(soloInclination/10).postln;
							//delayAmp = soloInclination/10;
							looper.do({|l| l.set(\amp, soloInclination/9);});
						});
					}, {
						//delayAmp = 0;
						looper.notNil.if({
							looper.do({|l| l.set(\gate, 0);});
							{
								looperSemaphore.wait;
								looper.notNil.if({
									"ending looper".postln;
									"elapsed total time %".format((Date.getDate.rawSeconds - startTime).abs).postln;
									"section %".format(section).postln;
									5. wait;
									//(((Date.getDate.rawSeconds - startTime).abs > 60) && (section == 1)).if({
									//	section = 2;
									//});
									(section ==1).if({
										sectionUpdater.(section)
									});
									(section == 2).if({
										0.5.coin.if({ shouldChange = true });
									});
									looper = nil;
								});
								looperSemaphore.signal;
							}.fork;
						});
					});
				});
				//internalArousal.postln;
				0.25.wait;
			});
			elapsedTime = Date.getDate.rawSeconds - startTime;
		});

		shouldChange = true;
		shouldEnd = true;
		"timeToEnd".postln;
		looper.notNil.if({
			looper.do({|l| l.set(\gate, 0);});
		});
	}).play;



	// use a Pspawner

	Pspawner({|ps|
		var interactionStart, activeSynth, algorithms, checkChange, basic, delayLoop, contrastPitch,
		matchSpeed, contrastSpeed, matchOrDont, layerSerp;

		"pspawner running".postln;

		activeSynth =  [ \bajorSpa, \fm1].choose;

		checkChange = Pfunc({ //"checking for change".postln;
			(shouldChange).if({
				"changing".postln;
				nil
			}, {
				//"not changing".postln;
				false
			});
		});


		(skipAheadForTesting && dEBUG).not.if({

			// make sure we get to section 0
			{
				180.wait;
				sectionUpdater.(0);
			}.fork;

			ps.wait((30 + 10.rand) * clock.tempo); // the clock is slow

			"waited".postln;
			interactionStart = Date.getDate.rawSeconds;



			// section 0
			"sound starting".postln;
			ps.seq(
				Ppar([
					Pbind(
						\instrument, activeSynth,
						[\degree, \dur], Prout(routs[0].(interactionStart)),
						\legato, 1.1,
						\out, [0, compBus],
						\group, sourceGroup
					),
					Pbind(
						\instrument, activeSynth,
						[\degree, \dur], Prout(routs[0].(interactionStart)),
						\legato, 1.1,
						\out, [0, compBus],
						\group, sourceGroup,
						\octave, 4
					)
				]);
			);

			//section 1
			activeSynth =  [ \bajorSpa, \fm1].choose;
			shouldChange = false;

			ps.seq(
				Ptpar([
					0, Pbind(
						\instrument, activeSynth,
						[\freq, \dur], Prout(routs[1]),
						\legato, 1.1,
						\out, [0, compBus],
						\group, sourceGroup,
						\shouldChange, checkChange.copy
					),
					0, Pbind(
						\instrument, activeSynth,
						[\freq, \dur], Prout(routs[1]),
						\legato, 1.1,
						\out, [0, compBus],
						\group, sourceGroup,
						\octave, 4,
						\freq, Pkey(\freq)/2,
						\shouldChange, checkChange.copy
					),
					120, Pbind(
						\instrument, [ \bajorSpa, \fm1].choose,
						[\freq, \dur], Prout(routs[1]),
						\legato, 1.1,
						\out, [0, compBus],
						\group, sourceGroup,
						\octave, 4,
						\freq, Pkey(\freq)*2,
						\shouldChange, checkChange.copy
					),
				]);
			);
		} , {
			var scale;
			scale = Scale.major;
			"skipped forward".postln;
			interactionStart = Date.getDate.rawSeconds;
			section = 2;
			riffs = generatedRiffs.choose.collect({|note|
				[scale.degreeToFreq(note[0], 440, 0), note[1]]
			});
			riffs = [ riffs];
		});

		basic = [
			Pbind(
				\instrument, activeSynth,
				[\freq, \dur], Prout(routs[2]),
				\legato, 1.1,
				\out, [0, compBus],
				\group, sourceGroup,
				\shouldChange, checkChange.copy
			),
			Pbind(
				\instrument, activeSynth,
				[\freq, \dur], Prout(routs[2]),
				\legato, 1.1,
				\out, [0, compBus],
				\group, sourceGroup,
				\octave, 4,
				\freq, Pkey(\freq)/2,
				\shouldChange, checkChange.copy
			)
		];

		delayLoop = {|minLoops=4, maxLoops=6, lowDiv-3, highDiv=5, delayAmp|

			delayAmp  = delayAmp ? Pfunc({
				(soloInclination >= 2).if({
					soloInclination /10;
				}, {
					0;
				});
			});

			[
				Pmono(
					\delay,
					\delayTime, Pwhite(5, 25),
					\out, serpentBus,
					\shouldChange, checkChange.copy,
					\group, sourceGroup
				),
				Pmono(
					\recordBus,
					\bufnum, bufs[2],
					\in, serpentBus,
					\group, processGroup,
					\shouldChange, checkChange.copy
				),
				Ppar(
					minLoops.rrand(maxLoops).collect({
						var rate, div, index, offset, loopPoint;
						div = lowDiv.rrand(highDiv);
						index = div.rand;
						offset = div.reciprocal * index;
						loopPoint = offset + div.reciprocal;

						Pmono(
							[\player,\player2].choose,
							\bufnum, bufs[2],
							\amp, delayAmp /4,
							\pan, -0.75.rrand(0.75),
							\rate, rate,
							\offset, offset,
							\loopPoint, (loopPoint + 0.1.rand).min(1),
							\group, fxGroup,
							\shouldChange, checkChange.copy
						)
					})
				)
			]
		};

		layerSerp =  {|minLoops=2, maxLoops=4, lowDiv-3, highDiv=5, delayAmp|

			delayAmp  = delayAmp ? Pfunc({
				(soloInclination >= 2).if({
					soloInclination /10;
				}, {
					0;
				});
			});

			[
				Ppar(
					minLoops.rrand(maxLoops).collect({
						var rate, div, index, offset, loopPoint;
						div = lowDiv.rrand(highDiv);
						index = div.rand;
						offset = div.reciprocal * index;
						loopPoint = offset + div.reciprocal;

						Pmono(
							[\player,\player2].choose,
							\bufnum, bufs[1],
							\amp, delayAmp /4,
							\pan, -0.75.rrand(0.75),
							\rate, rate,
							\offset, offset,
							\loopPoint, (loopPoint + 0.1.rand).min(1),
							\group, fxGroup,
							\shouldChange, checkChange.copy
						)
					})
				)
			]
		};


		matchSpeed = {|activeRiff|
			var tempo, riffTempo, ratio, modifiedRiff;

			tempo = getAvgTempo.value;
			riffTempo = getRiffTempo.(activeRiff);

			ratio = tempo/riffTempo;

			modifiedRiff = activeRiff.collect({|item|
				[item.first, item.last * ratio]
			});

			modifiedRiff
		};

		contrastSpeed= {|activeRiff|
			var tempo, riffTempo, ratio, correctiveRatio, modifiedRiff;

			tempo = getAvgTempo.value;
			riffTempo = getRiffTempo.(activeRiff);

			ratio = tempo.max(riffTempo)/tempo.min(riffTempo);
			// If this number is near 1, they're well matched

			(ratio < 1.5).if ({ // we must act!

				(tempo > 2).if({ // we're fast

					correctiveRatio = 0.5;
				}, {
					(tempo < 0.8).if({ // we're slow

						correctiveRatio = tempo.reciprocal
					}, {
						// we're median, so pick something
						correctiveRatio = [0.5, 2, 4].choose;
					})
				});

				modifiedRiff = activeRiff.collect({|item|
					[item.first, item.last * correctiveRatio]
				});
			});

			modifiedRiff ? activeRiff;
		};


		contrastPitch = {|activeRiff|

			var range, modifiedRiff, correctiveRatio;

			// no checking here, we'll just act

			range = getAvgOctave.();

			// 3 is low
			// 4 is mid
			// 5 is high

			(range < 4).if({
				correctiveRatio = [2,3,4, 6, 8].choose;

			}, {
				(range > 4).if({
					correctiveRatio = [2,3].choose.reciprocal;
				}, {
					// we're mid, so pick either
					correctiveRatio = [0.5, 2, 3].choose;
				})
			});

			"correctiveRatio %".format(correctiveRatio).postln;

			modifiedRiff = activeRiff.collect({|item|
				[item.first * correctiveRatio, item.last]
			});

			modifiedRiff;
		};

		matchOrDont = {|funcs|
			var maxDur;
			maxDur = (3.0.rrand(7) * 60);

			[
				Pbind(
					\instrument,  [ \bajorSpa, \fm1, \binaural, \vosim].choose;,
					[\freq, \dur], Prout(routs[3].(funcs, maxDur)),
					\legato, 1.1,
					\out, [0, compBus],
					\group, sourceGroup,
					\shouldChange, checkChange.copy
				),
				Pbind(
					\instrument,  [ \bajorSpa, \fm1, \binaural, \vosim].choose;,
					[\freq, \dur], Prout(routs[3].(funcs, maxDur)),
					\legato, 1.1,
					\out, [0, compBus],
					\group, sourceGroup,
					\octave, 4,
					\freq, Pkey(\freq)/2,
					\shouldChange, checkChange.copy
				)
			];
		};




		algorithms = [
			{
				"basic".postln;
				Ppar(basic);
			},
			{
				"matchSpeed".postln;
				Ppar(matchOrDont.([matchSpeed]))
			},
			{
				"basic ++ delayLoop".postln;
				Ppar(basic ++ delayLoop.value())
			},
			{
				"contrastSpeed".postln;
				Ppar(matchOrDont.([contrastSpeed]))
			},
			{
				"contrastPitch matchSpeed".postln;
				Ppar(matchOrDont.([contrastPitch, matchSpeed]))
			},
			{
				"contrastPitch matchSpeed ++ delayLoop".postln;
				Ppar(matchOrDont.([contrastPitch, matchSpeed]) ++ delayLoop.value())
			},

			{
				"contrastPitch".postln;
				Ppar(matchOrDont.([contrastPitch]))
			},
			{
				"contrastSpeed contrastPitch".postln;
				Ppar(matchOrDont.([contrastSpeed, contrastPitch]))
			},
			{
				"layer serpent".postln;
				Ppar(layerSerp.value())
			},
			{
				"rest".postln;
				Pbind(\degree, \rest,
					\keepGoing, Pfunc({
						(soloInclination < 2).if({
							true
						}, {
							nil
						})
					}),
					\shouldChange, checkChange.copy)
			},
			{
				"rest".postln;
				Pbind(\degree, \rest,
					\keepGoing, Pfunc({
						(soloInclination < 2).if({
							true
						}, {
							nil
						})
					}),
					\shouldChange, checkChange.copy)
			}
		];


		// Now is a free for all on the sections
		{shouldEnd.not}.while({

			"in main loop".postln;
			shouldChange = false;
			activeSynth =  [ \bajorSpa, \fm1, \binaural, \vosim].choose;
			ps.seq(algorithms.choose.value);

		});

		//end;

		activeSynth =  [ \bajorSpa, \fm1].choose;

		ps.seq(
			Ppar([
				Pbind(
					\instrument, activeSynth,
					[\degree, \dur], Prout(routs[4]),
					\legato, 1.1,
					\out, [0, compBus],
					\group, sourceGroup
				),
				Pbind(
					\instrument, activeSynth,
					[\degree, \dur], Prout(routs[4]),
					\legato, 1.1,
					\out, [0, compBus],
					\group, sourceGroup,
					\octave, 4
				)
			]);
		);



	}).play(clock);

	/*
	Pdef(\dev,
	Pseq([
	Ppar([
	Pbind(
	\instrument, startSynth,
	//\dur, Pseq(10.collect({[2, 1].wchoose([0.7, 0.3])}), inf)/ Pfunc({internalArousal+ soloInclination}),
	[\degree, \dur], Prout(routs[0]),

	//Pseq([
	//  Pseq(generatedRiffs.choose, 4),
	//  Pseq(generatedRiffs.choose, 4),
	//  Pseq(generatedRiffs.choose, 4),
	//  Pseq(generatedRiffs.choose, 4)], inf),
	\legato, 1.1,
	//\dur, Pfunc({|env|
	//		var dur;
	//	env.postln;
	//	dur = env[\rawDur] / (internalArousal+ soloInclination);
	//		["dur", dur].postln;
	//		dur;
	//}),
	//\foo, Pfunc({"pbind".postln})
	//	\sustain, 1.5
	\out, [0, compBus],
	\group, sourceGroup
	),
	Pbind(
	\instrument, startSynth,
	//\dur, Pseq(10.collect({[2, 1].wchoose([0.7, 0.3])}), inf)/ Pfunc({internalArousal+ soloInclination}),
	[\degree, \dur], Prout(routs[0]),
	\legato, 1.1,
	//\dur, Pfunc({|env|
	//	env.postln;
	//	env[\rawDur] / (internalArousal+ soloInclination)
	//}),
	\octave, 4,
	\out, [0, compBus],
	\group, sourceGroup
	//\foo, Pfunc({"pbind".postln})
	//	\sustain, 1.5
	)
	]),
	Ppar([
	Pbind(
	\instrument, startSynth,
	//\dur, Pseq(10.collect({[2, 1].wchoose([0.7, 0.3])}), inf)/ Pfunc({internalArousal+ soloInclination}),
	[\freq, \dur], Prout(routs[1]),

	//Pseq([
	//  Pseq(generatedRiffs.choose, 4),
	//  Pseq(generatedRiffs.choose, 4),
	//  Pseq(generatedRiffs.choose, 4),
	//  Pseq(generatedRiffs.choose, 4)], inf),
	\legato, 1.1,
	//\dur, Pfunc({|env|
	//		var dur;
	//	env.postln;
	//	dur = env[\rawDur] / (internalArousal+ soloInclination);
	//		["dur", dur].postln;
	//		dur;
	//}),
	//\foo, Pfunc({"pbind".postln})
	//	\sustain, 1.5
	\out, [0, compBus],
	\group, sourceGroup,
	\addAction, \addToHead
	),
	Pbind(
	\instrument, startSynth,
	//\dur, Pseq(10.collect({[2, 1].wchoose([0.7, 0.3])}), inf)/ Pfunc({internalArousal+ soloInclination}),
	[\freq, \dur], Prout(routs[1]),
	\legato, 1.1,
	//\dur, Pfunc({|env|
	//	env.postln;
	//	env[\rawDur] / (internalArousal+ soloInclination)
	//}),
	\octave, 4,
	\out, [0, compBus],
	\group, sourceGroup,
	\addAction, \addToHead
	//\foo, Pfunc({"pbind".postln})
	//	\sustain, 1.5
	)
	]),
	Ppar([
	Pbind(
	\instrument, startSynth,
	//\dur, Pseq(10.collect({[2, 1].wchoose([0.7, 0.3])}), inf)/ Pfunc({internalArousal+ soloInclination}),
	[\freq, \dur], Prout(routs[2]),

	//Pseq([
	//  Pseq(generatedRiffs.choose, 4),
	//  Pseq(generatedRiffs.choose, 4),
	//  Pseq(generatedRiffs.choose, 4),
	//  Pseq(generatedRiffs.choose, 4)], inf),
	\legato, 1.1,
	//\dur, Pfunc({|env|
	//		var dur;
	//	env.postln;
	//	dur = env[\rawDur] / (internalArousal+ soloInclination);
	//		["dur", dur].postln;
	//		dur;
	//}),
	//\foo, Pfunc({"pbind".postln})
	//	\sustain, 1.5
	\out, [0, compBus],
	\group, sourceGroup,
	\addAction, \addToHead
	),
	Pbind(
	\instrument, startSynth,
	//\dur, Pseq(10.collect({[2, 1].wchoose([0.7, 0.3])}), inf)/ Pfunc({internalArousal+ soloInclination}),
	[\freq, \dur], Prout(routs[2]),
	\legato, 1.1,
	//\dur, Pfunc({|env|
	//	env.postln;
	//	env[\rawDur] / (internalArousal+ soloInclination)
	//}),
	\octave, 4,
	\out, [0, compBus],
	\group, sourceGroup,
	\addAction, \addToHead
	//\foo, Pfunc({"pbind".postln})
	//	\sustain, 1.5
	),
	Pmono(
	\delay,
	\out, serpentBus,
	\keepGoing, Pfunc({
	(section == 2).if({
	true
	}, {
	nil
	})
	}),
	\group, sourceGroup
	),
	Pmono(
	\recordBus,
	\bufnum, bufs[2],
	\in, serpentBus,
	\group, processGroup,
	\keepGoing, Pfunc({
	(section == 2).if({
	true
	}, {
	nil
	})
	})
	),
	Ppar(
	4.collect({
	var rate, div, index, offset, loopPoint;
	div = 3.rrand(5);
	index = div.rand;
	offset = div.reciprocal * index;
	loopPoint = offset + div.reciprocal;

	Pmono(
	\player,
	\bufnum, bufs[2],
	\amp, Pfunc({ delayAmp/4 }),
	\pan, -0.75.rrand(0.75),
	\rate, rate,
	\offset, offset,
	\loopPoint, (loopPoint + 0.1.rand).min(1),
	\group, fxGroup,
	\keepGoing, Pfunc({
	(section == 2).if({
	"section 2".postln;
	true
	}, {
	nil
	})
	})
	)
	}))
	])
	])
	).play(clock);
	*/

	//Synth(\delay);

	//Synth(\record, [\bufnum, bufs[0].bufnum, \loop, 0]);
	//s.sync;
	//Synth(\player, [\bufnum, bufs[0].bufnum, \offset, 0.2, \loopPoint, 0.4, \rate, 1.1]);
	//Synth(\player, [\bufnum, bufs[0].bufnum, \offset, 0.39, \loopPoint, 0.8, \rate, 0.9]);


	// when running, look at the latest buffers. Are the notes very variable or not? are they empty?


})


)