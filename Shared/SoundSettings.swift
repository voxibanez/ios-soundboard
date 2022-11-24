//
//  SoundSettings.swift
//  Soundboard
//
//  Created by Tim Barber on 10/24/21.
//

import Foundation
import SwiftUI
import CoreData

struct SoundFileSettingsView : View{
    @State var attributes: SoundAttributes
    @State private var newFileName = ""
    var body: some View {
        Form{
            Section(header: Text("File Name")) {
                
                TextField("File Name", text: $newFileName, onCommit: {
                    self.attributes.name = self.newFileName
                })
                .onAppear {
                    self.newFileName = self.attributes.name != nil ? "\(self.attributes.name!)" : ""
                }
                .disableAutocorrection(true)
                .onDisappear {
                    self.attributes.name = self.newFileName
                }
                
            }
        }
    }
}

struct SoundSettingsView : View{
    @State var attributes: SoundAttributes
    @State var audioSample: AudioSample
    var updateSettings: (()->Void)?
    @State private var newName: String
    
    init(attributes: SoundAttributes, audioSample: AudioSample, updateSettings: (()->Void)?){
        self.attributes = attributes
        self.audioSample = audioSample
        self.updateSettings = updateSettings
        self.newName = attributes.name != nil ? "\(attributes.name!)" : ""
    }
    
    var body: some View {
        VStack{
            Section(header: Text("Name")) {
                
                TextField("Name", text: $newName, onCommit: {
                    self.attributes.name = self.newName
                })
                .disableAutocorrection(true)
                .onDisappear {
                    self.attributes.name = self.newName
                }
                
            }
            WaveformEditor(audioSample: audioSample, attributes: attributes)
            NavigationView{
                Form{
                    NavigationLink(destination: ReverbEffectSettingsview(attributes: attributes, name: "Reverb", updateSettings: updateSettings)) {
                        Text("Reverb")
                    }
                    NavigationLink(destination: DelayEffectSettingsview(attributes: attributes, name: "Delay", updateSettings: updateSettings)) {
                        Text("Delay")
                    }
                    NavigationLink(destination: DistortionEffectSettingsview(attributes: attributes, name: "Distortion", updateSettings: updateSettings)) {
                        Text("Distortion")
                    }
                    NavigationLink(destination: PitchEffectSettingsview(attributes: attributes, name: "Pitch", updateSettings: updateSettings)) {
                        Text("Pitch")
                    }
                    NavigationLink(destination: SpeedEffectSettingsview(attributes: attributes, name: "Speed", updateSettings: updateSettings)) {
                        Text("Speed")
                    }
                }
                
            }
            
        }
    }
}
struct ReverbEffectSettingsview : View{
    @State var attributes: SoundAttributes
    var name: String
    var updateSettings: (()->Void)?
    
    var body: some View {
        Form{
            Section(header: Text(name)) {
                EffectToggle(value: $attributes.reverbEnabled, updateSettings: updateSettings)
                TextSlider(text: "Wet/Dry", defaultValue: 0.0, range: 0.0...100.0, value: $attributes.reverbWet, updateSettings: updateSettings)
            }
    }
    }
}

struct DelayEffectSettingsview : View{
    @State var attributes: SoundAttributes
    var name: String
    var updateSettings: (()->Void)?
    
    var body: some View {
        Form{
            Section(header: Text(name)) {
                EffectToggle(value: $attributes.delayEnabled, updateSettings: updateSettings)
                TextSlider(text: "Wet/Dry", defaultValue: 0.0, range: 0.0...100.0, value: $attributes.delayWet, updateSettings: updateSettings)
            }
    }
    }
}

struct DistortionEffectSettingsview : View{
    @State var attributes: SoundAttributes
    var name: String
    var updateSettings: (()->Void)?
    
    var body: some View {
        Form{
            Section(header: Text(name)) {
                EffectToggle(value: $attributes.distortionEnabled, updateSettings: updateSettings)
                TextSlider(text: "Wet/Dry", defaultValue: 0.0, range: 0.0...100.0, value: $attributes.distortionWet, updateSettings: updateSettings)
            }
    }
    }
}

struct PitchEffectSettingsview : View{
    @State var attributes: SoundAttributes
    var name: String
    var updateSettings: (()->Void)?
    
    var body: some View {
        Form{
            Section(header: Text(name)) {
                EffectToggle(value: $attributes.pitchEnabled, updateSettings: updateSettings)
                TextSlider(text: "Pitch", defaultValue: 1.0, range: -2400.0...2400.0, value: $attributes.pitchLevel, updateSettings: updateSettings)
                TextSlider(text: "Playback Rate", defaultValue: 1.0, range: 0.1...4.00, value: $attributes.pitchRate, updateSettings: updateSettings)
                TextSlider(text: "Overlap", defaultValue: 8.0, range: 3.0...32.00, value: $attributes.pitchOverlap, updateSettings: updateSettings)
            }
    }
    }
}

struct EffectToggle : View{
    @Binding var value: Bool
    @State private var tempValue = false
    var updateSettings: (()->Void)?
    
    var body: some View {
        let binding = Binding(
            get: { tempValue },
            set: { self.value = $0
                tempValue = $0
                updateSettings!()
            })
        Toggle("Enabled", isOn: binding).onChange(of: binding.wrappedValue){ value in
            updateSettings!()
        }.onAppear {
            self.tempValue = self.value
        }
    }
}

struct TextSlider : View{
    var text: String
    var defaultValue: Float
    var range: ClosedRange<Float>
    @Binding var value: Float
    var updateSettings: (()->Void)?
    @State private var tempValue = 0.0 as Float

    var body: some View {
        let binding = Binding(
            get: { tempValue },
            set: { self.value = $0
                tempValue = $0
                updateSettings!()
            }
        )
        VStack{
            Text(text)
            HStack{
                Slider(value: binding, in: range)
                Button(action:{
                    self.value = self.defaultValue
                    self.tempValue = self.defaultValue
                    updateSettings!()
                }){
                    Image(systemName: "arrow.clockwise")
                }
                Text("\(binding.wrappedValue, specifier: "%.1f")")
            }
        }
        .onAppear {
            self.tempValue = self.value
        }
    }
}

struct SpeedEffectSettingsview : View{
    @State var attributes: SoundAttributes
    var name: String
    var updateSettings: (()->Void)?
    
    var body: some View {
        Form{
            Section(header: Text(name)) {
                EffectToggle(value: $attributes.speedEnabled, updateSettings: updateSettings)
                TextSlider(text: "Speed", defaultValue: 1.0, range: 0.25...4.0, value: $attributes.speedLevel, updateSettings: updateSettings)
            }
    }
    }
}

func ??<T>(lhs: Binding<Optional<T>>, rhs: T) -> Binding<T> {
    Binding(
        get: { lhs.wrappedValue ?? rhs },
        set: { lhs.wrappedValue = $0 }
    )
}

