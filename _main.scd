(

// 22 September responsive improvior. This will totally work.

var detectingPitch = true, dEBUG=true, semaphore;

semaphore = Semaphore(1);


s.options.memSize = s.options.memSize * 16;

s.waitForBoot({

	// Let's have a delay line
	SynthDef(\delay, { arg gate=1, in=0, delayTime=60, maxDelay=120, out=0, amp=1;

		var input, delay, env;

		input = SoundIn.ar(in, 1);
		env = EnvGen.kr(Env.asr, gate, doneAction:2);
		delay = DelayC.ar(input, maxDelay, delayTime, amp);

		Out.ar(out, delay * env);
	}).add;  // Maybe change this to use a buffer




	// One mode: track pitch, use that to do something

	SynthDef(\pitch, { arg gate=1, in=0, thresh=0.2, space=0.5, longspace=2,
		rmswindow = 1600;

		var input, env, fft_pitch, onset, chain, hasfreq, paused, linebreak,
		rms, xings, peaks, freq, fgate, ftrig, changed;

		input = SoundIn.ar(in, 1);
		env = EnvGen.kr(Env.asr, gate, doneAction:2);

		chain = FFT(LocalBuf(2048), input);
		onset = Onsets.kr(chain, odftype:\phase);//odftype:\wphase);
		#fft_pitch, hasfreq = Pitch.kr(input, maxFreq:300, ampThreshold:thresh);
		paused = DetectSilence.ar(input, thresh, space);
		linebreak = DetectSilence.ar(input, thresh, longspace);

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
		SendTrig.kr(A2K.kr(linebreak), 3, 1);

	}).add;

	OSCdef(\domifare_in, {|msg, time, addr, recvPort|
		var tag, node, id, value, letter, result, err;

		{
			semaphore.wait;

			#tag, node, id, value = msg;
			//[tag, id, value].postln;
			case
			{ id ==0 } { /* pitch */
				"pitch".postln;

				//"not recording".postln;
				detectingPitch.if({
					dEBUG.if({
						"autocorrelation %".format(value).postln;
					});
					//lang.input_method.if ({
					//	this.freq_(value, time);
					//},{"not auto".postln;});
				});

			}
			{ id ==1 } { /* onset */
				//this.received_onset = time;

			}
			{ id ==2 } { /* space */

				detectingPitch.if({

					dEBUG.if({ "space".postln });

					//this.received_space = time;


				});

			}
			{ id ==3 } { /* EOL */

				detectingPitch.if({
					dEBUG.if({ "eol".postln; });
					//lang.eol;

				});
			}
			{ id == 4 } { /* time donaim */
				detectingPitch.if({

					value = value.asInteger.abs;
					((value > 0) && (value < 300)).if ({
						dEBUG.if({
							"time domain %".format(value).postln;
						});
						//lang.input_method.not.if({
						//	this.freq_(value, time);
						//},{"not time".postln;});
					});
				});
			};

			semaphore.signal;
		}.fork;

	}, '/tr', s.addr);



// Another mode, make a recording, delay it, play it back (this may rely on EOLs

	s.sync;


	Synth(\delay);


})


)