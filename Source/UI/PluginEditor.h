/*
  ==============================================================================

    This file contains the basic framework code for a JUCE plugin editor.

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "../PluginProcessor.h"
#include "../Scope/Spectroscope.h"

class MainComponent;


//==============================================================================
/**
*/
class FaugAudioProcessorEditor  : public juce::AudioProcessorEditor
{
public:
    FaugAudioProcessorEditor (FaugAudioProcessor&, juce::MidiKeyboardState& state, juce::AudioProcessorValueTreeState& vts);
    virtual ~FaugAudioProcessorEditor() override;

    //==============================================================================
    void paint (juce::Graphics&) override;
    void resized() override;


private:
    FaugAudioProcessor& audioProcessor;
    std::unique_ptr<MainComponent> m_main;

    juce::Rectangle<int> originalScreen;
    juce::Rectangle<int> currentWindow;
    float scaleConstant;


    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(FaugAudioProcessorEditor)
};