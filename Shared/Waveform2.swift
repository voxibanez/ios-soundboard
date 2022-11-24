//
//  Waveform2.swift
//  Soundboard
//
//  Created by Tim Barber on 11/20/22.
//

import Foundation
import AVFoundation
import SwiftUI
import Waveform

struct WaveformEditor2 : View{
    var waveformGenerator: WaveformGenerator?
    @ObservedObject var audioSample: AudioSample
    @State var attributes: SoundAttributes
    @State var selection: Range<Int>
    @State var selectionEnabled = false
    
    init(audioSample: AudioSample, attributes: SoundAttributes){
        // Audio file must be "Rewound" to properly load
        audioSample.audioFile?.framePosition = 0
        self.audioSample = audioSample
        self.attributes = attributes
        self.selection = Int(audioSample.startOffset)..<Int(audioSample.endOffset)
        self.waveformGenerator = WaveformGenerator(audioFile: audioSample.audioFile!)
    }
    
    var body: some View {
        VStack{
            if (waveformGenerator != nil){
                ZStack{
                    Waveform(generator: waveformGenerator!, selectedSamples: $selection, selectionEnabled: $selectionEnabled, playMarker: $audioSample.currentSampleRange, playing: $audioSample.playing)
                }
                .onChange(of: selection){ value in
                    DispatchQueue.global().async {
                        audioSample.setRange(range: value)
                        self.attributes.sampleStartOffset = audioSample.startOffset
                        self.attributes.sampleEndOffset = audioSample.endOffset
                    }
                }
                HStack{
                    Spacer()
                    Button(selectionEnabled ? "Done" : "Trim"){
                        selectionEnabled.toggle()
                        if !selectionEnabled{
                            self.attributes.sampleStartOffset = audioSample.startOffset
                            self.attributes.sampleEndOffset = audioSample.endOffset
                        }
                    }
                    Spacer()
                    
                    Image(systemName: audioSample.playing ? "stop.circle" : "play.circle")
                        .font(.largeTitle)
                        .onTapGesture {
                            if !audioSample.playing{
                                audioSample.play()
                            }
                            else{
                                audioSample.stop()
                            }
                        }
                    Spacer()
                }

            }
            else{
                Text("Error loading waveform")
            }
        }
    } 
}
