import("stdfaust.lib");

display(name, mini, maxi) = _ <: attach(_,vbargraph("[00]%name[style:numerical]",mini,maxi));
limit_range(mini,maxi) = _, mini : max : _, maxi : min;
gain = hslider("gain[style:knob]",1.0,0.0,1.0,0.01);

// Midi note 48, 130.81hz, C2 is default 1V in model D
// Will use as center for keyTrackingDiff
keyboardCenter = 130.81;

// currently I only have 44.1khz
// the things relying on this require it to be known at compile time anyway
nyquist = 22050.0;//ma.SR/2;

// todo variable keytracking per oscillator

generateSound(fdb) = output(fdb) : filter : _*envelope
with{
    gate = button("[00]gate");

    frequencyIn = nentry("[01]freq[unit:Hz]",     440, 20, 20000, 0.01);
    prevfreq    = nentry("[02]prevFreq[unit:Hz]", 440, 20, 20000, 0.01);

    pitchbend  = hslider("[03]pitchBend[style:knob]", 0, -2.5, 2.5, 0.01) : ba.semi2ratio;
    glide      = hslider("[04]glide[style:knob]", 0.01, 0.001, 3.0, 0.001);
    start_time = ba.latch(frequencyIn != frequencyIn', ba.time);
    dt         = ba.time - start_time;
    epsilon    = 0.01;
    expo(tau)  = exp((0-dt)/(tau*ma.SR)), epsilon : max;

    blend(rate, f, pf) = f*(1 - expo(rate)) + pf*expo(rate);
    glideOn = checkbox("[05]glideOn");

    freq = blend(glide, frequencyIn, ba.if(glideOn, prevfreq, frequencyIn)) 
                       <: attach(_,vbargraph("finalFreq[style:numerical]",0,20000));

// Oscillators
    scale = 1.0, oscOnePower*oscOneGain*0.4 + 
               oscTwoPower*oscTwoGain*0.4 + 
               oscThreePower*oscThreeGain*0.4 : max;

    oscOnePower   = checkbox("[06]oscOnePower");
    oscTwoPower   = checkbox("[07]oscTwoPower");
    oscThreePower = checkbox("[08]oscThreePower");

    oscOneGain   = hslider("[09]oscOneGain[style:knob]",  1.0,0.0,1.0,0.01);
    oscTwoGain   = hslider("[10]oscTwoGain[style:knob]",  1.0,0.0,1.0,0.01);
    oscThreeGain = hslider("[11]oscThreeGain[style:knob]",1.0,0.0,1.0,0.01);

    oscModOn = checkbox("[12]oscModOn");

    // oscillators
    oscOne         = waveOneTwo(freqOne,   rangeOne,   waveSelectOne)*oscOneGain*oscOnePower;
    oscTwoSignal   = waveOneTwo(freqTwo,   rangeTwo,   waveSelectTwo);
    oscThreeSignal = waveThree (freqThree, rangeThree, waveSelectThree);

    oscTwo   = oscTwoSignal  *oscTwoGain  *oscTwoPower;
    oscThree = oscThreeSignal*oscThreeGain*oscThreePower;

    oscillators = (oscOne + oscTwo + oscThree)/scale;

    freqOne   = freq, 2^(rangeOne-4) : * : _*globalDetune*driftOne*pitchbend : modulate(oscModOn);
    freqTwo   = freq, 2^(rangeTwo-4) : * : _*detuneTwo   *driftTwo*pitchbend : modulate(oscModOn);

    oscThreeKeyTrack    = checkbox("[13]oscThreeKeyTrack");
    freqThreePre = freq, keyboardCenter : select2(oscThreeKeyTrack); 
    freqThree    = freqThreePre : _, 2^(rangeThree-4) : * : _*detuneThree *driftThree*pitchbend;

    // Oscillator wave selectors. 3rd option in waves one and two is a triangle saw
    //                            3rd option in wave three is a reverse saw
    waveSelectOne   = hslider("[14]waveOne[style:knob]"  ,1,0,5,1);
    waveSelectTwo   = hslider("[15]waveTwo[style:knob]"  ,1,0,5,1);
    waveSelectThree = hslider("[16]waveThree[style:knob]",1,0,5,1);
    waveOneTwo(f,r,ws) = tri(f,r), triSaw(f,r), saw(f,r), square(f,r),
        rectangle(f,r,0.70), rectangle(f,r,0.85) : ba.selectn(6,ws);
    waveThree(f,r,ws) = tri(f,r), revSaw(f,r), saw(f,r), square(f,r), 
        rectangle(f,r,0.70), rectangle(f,r,0.85) : ba.selectn(6,ws);

    driftOne   = os.osc(0.05)*0.01 : 2^_ : @(ma.SR/100);
    driftTwo   = driftOne@(ma.SR/100);
    driftThree = driftTwo@(ma.SR/100);

    rangeOne   = hslider("[17]rangeOne[style:knob]",2,0,5,1);
    rangeTwo   = hslider("[18]rangeTwo[style:knob]",2,0,5,1);
    rangeThree = hslider("[19]rangeThree[style:knob]",2,0,5,1);

    globalDetuneSemi = hslider("[20]globalDetune[style:knob]", 0, -2.5, 2.5, 0.01);
    globalDetune = globalDetuneSemi : ba.semi2ratio;
    detuneTwo    = hslider("[21]detuneTwo[style:knob]", 0, -7.5, 7.5, 0.01)   + globalDetuneSemi : ba.semi2ratio;
    detuneThree  = hslider("[22]detuneThree[style:knob]", 0, -7.5, 7.5, 0.01) + globalDetuneSemi : ba.semi2ratio;

    tri(f,type)    = os.lf_triangle(f),   os.triangle(f) : select2(type);
    saw(f,type)    = os.lf_saw(f),        os.sawtooth(f) : select2(type);
    square(f,type) = os.lf_squarewave(f), os.square(f)   : select2(type);

    rectangle(f,type,n) = os.lf_pulsetrain(f,n), os.pulsetrain(f,n) : select2(type);
    revSaw(f,type)      = saw(f,type), -1: *;
    triSaw(f,type)      = (saw(f,type) + tri(f,type))/2;


// Envelope Section
    envelope    = en.adsr(attack,decay,sustain,release,gate) <: _, si.smoo : select2(decayButton);
    decayButton = checkbox("[23]decayOn");
    attack      = hslider("[24]attack[style:knob]",1,1,10000,1)*0.001;
    decay       = hslider("[25]decay[style:knob]",4,1,24000,1)*0.001;
    sustain     = hslider("[26]sustain[style:knob]",0.8,0.01,1,0.01);
    release     = 10*0.001, decay : select2(decayButton);

// Filter Section
    // filter response is 32k, cutoff max is 20k
    // Have to have constant value know at compile time.
    // Maybe have multiple hardcoded values for different sample rates

    filterMax = 20000.0/nyquist;
    filterMin = 10.0/nyquist;
    cutoffIn = hslider("[27]cutoff[style:knob]",0.5,filterMin,filterMax,0.001);
    cutoffFreq = cutoffIn*nyquist;

// key tracking stuff
    // offset of played frequency from keyboard center
    keyTrackDiff = frequencyIn-keyboardCenter;

    //oneThird, twoThird
    keyTrackOne = checkbox("[28]keyTrackOne")*keyTrackDiff;
    keyTrackTwo = checkbox("[29]keyTrackTwo")*2.0*keyTrackDiff;
    keyTrackSum = (keyTrackOne + keyTrackTwo)/3.0;
    cutoff_KeyTrack = cutoffFreq + keyTrackSum;

// filter contour
    reverseContour = hslider("[30]contour_direction[style:radio{'+':0;'-':1}]",0,0,1,1);
    contourAmount = hslider("[31]contourAmount[style:knob]",0.0,0.0,1.0,0.001);
    fAttack = hslider("[32]fAttack[style:knob]",1,1,7000,1)*0.001;
    fDecay = hslider("[33]fDecay[style:knob]",4,1,30000,1)*0.001;
    fSustain = hslider("[34]fSustain[style:knob]",0.8,0.01,1.0,0.01);
    fRelease = 10*0.001, fDecay : select2(decayButton);

    // either up 4 octaves, or down 4 octaves
    contourPeak = 16.0, (1/16) : select2(reverseContour) : _*cutoff_KeyTrack;

    filterUp   = cutoff_KeyTrack <: _ + contourAmount*filterContour*(contourPeak-_);
    filterDown = cutoff_KeyTrack <: _ - contourAmount*filterContour*(_-contourPeak); 
    filterContour = en.adsr(fAttack, fDecay, fSustain, fRelease, gate) <: _, si.smoo : select2(decayButton);

    // set signal up/down a percentage of 4 octaves from the set cutoff-frequency(plus keyTrack)
    cutOffCombine = filterUp, filterDown : select2(reverseContour) : modulate(filterModOn) : _/nyquist : limit_range(filterMin,filterMax);

    filterModOn = checkbox("[35]filterModOn");
    modulate(on) = _ <: _, _*(2^(modulation)) : select2(on);

    emphasis = hslider("[36]emphasis[style:knob]",1,0.707,25.0,0.001);
    filter = ve.moogLadder(cutOffCombine, emphasis);

// Noise
    noiseSelect = checkbox("[37]noiseType");
    noiseOn = checkbox("[38]noiseOn");
    noiseGain = hslider("[39]noiseGain[style:knob]", 0.0, 0.0, 1.0, 0.01);
    noise = no.noise, no.pink_noise : select2(noiseSelect)*noiseGain*noiseOn;

// Modulation
    modLeft = oscThreeSignal, filterContour : select2(checkbox("[40]oscThree_filterEg"));
    
    lfoRate = hslider("[41]lfoRate[style:knob]",10.0,0.5,200.0,0.01) ;
    lfo = os.lf_triangle(lfoRate), os.lf_squarewave(lfoRate) : select2(checkbox("[42]lfoShape"));

    lowBandLimit = 20;
    bw3 = 0.7 * ma.SR/2.0 - lowBandLimit;
    redNoise = no.noise : fi.spectral_tilt(3,lowBandLimit,bw3,-0.25);
    modNoise = no.pink_noise, redNoise : select2(noiseSelect);

    modRight  = modNoise, lfo : select2(checkbox("[43]noise_lfo")) ;
    modMix = hslider("[44]modMix[style:knob]",0.0,0.0,1.0,0.01);
    modAmount = hslider("[45]modAmount[style:knob]",0.0,0.0,1.0,0.01);
    modulation = (1-modMix)*modLeft + (modMix)*modRight : _*modAmount;

    load = hslider("[46]load[style:knob]",1.0,1.0,3.0,0.01);
    output(fdb) = ((oscillators+noise)*load)+fdb;
};

process = hgroup("faug", (generateSound ~ fdBackSignal) : drive : _*on*masterVolume) <: _,_
with {
    // Inverting power button so it defaults to on
    powerButton = checkbox("on");
    on = 1.0,0.0 : select2(powerButton);
    masterVolume = hslider("masterVolume[style:knob]",1.0,0.0,1.0,0.01);

    fdbackOn = checkbox("feedbackOn");
    fdback = hslider("feedbackGain[style:knob]",0,0,1,0.01);
    fdBackSignal = _*fdback*fdbackOn;
    drive = _ <: drySig, wetSig : + : aa.Ratanh;
    drySig = _, (1-fdback)*_ : select2(fdbackOn);
    wetSig = 0.0, _*(2^fdback) : select2(fdbackOn);
};