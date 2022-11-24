//
//  Audio.swift
//  Soundboard
//
//  Created by Tim Barber on 10/8/21.
//

import Foundation
import AVFoundation

enum SoundLoadError: Error {
    case invalidExtension
    case invalidLocation
    case fileTooLarge
    case fileTooLong
}

class ValidFileExtensions {
    static var validExtensions = ["wav", "mp3", "m4a"]
    static func isValidExtension(fileExtension: String) -> Bool{
        if validExtensions.contains(fileExtension) {
            return true
        } else {
            return false
        }
    }
}

class AudioSampleLegacy {
    private var audioPlayer: AVAudioPlayer!
    init(fileName: String, fileExtension: String) throws{
        let fullUrl = try SoundFileManager.getFilePath(fileName: fileName, fileExtension: fileExtension)
        self.audioPlayer = try! AVAudioPlayer(contentsOf: fullUrl)
        self.audioPlayer.prepareToPlay()
    }
    
    func play() {
        DispatchQueue.global().async {
            self.audioPlayer.play()
        }
    }
    func stop(){
        DispatchQueue.main.async {
            if self.audioPlayer.isPlaying{
                self.audioPlayer.stop()
                self.audioPlayer.currentTime = 0
                self.audioPlayer.prepareToPlay()
            }
        }
    }
    func pause(){
        DispatchQueue.main.async {
            if self.audioPlayer.isPlaying{
            self.audioPlayer.pause()
            }
        }
    }
    func isPlaying() -> Bool{
        return self.audioPlayer.isPlaying
    }
}

class AudioSample : ObservableObject {
    var engine: AVAudioEngine
    var playerNode = AVAudioPlayerNode()
    var mixerNode: AVAudioMixerNode?
    var audioFile: AVAudioFile?
    var reverb: AVAudioUnitReverb?
    var delay: AVAudioUnitDelay?
    var distortion: AVAudioUnitDistortion?
    var pitch: AVAudioUnitTimePitch?
    var speed: AVAudioUnitVarispeed?
    var eq: AVAudioUnitEQ?
    var offset = 0
    var sampleRate: Double?
    var audioDuration: CMTime
    var audioDurationSeconds: Float64
    var initialized: Bool = false
    var sampleStart: Int64 = 0
    var startOffset: Int64 = 0
    var endOffset: Int64 = 1
    @Published var playing: Bool = false
    @Published var currentSample: Int = 0
    @Published var currentSampleRange: Range<Int> = 0..<1
    
    init(fileName: String, fileExtension: String, soundEngine: AVAudioEngine, useEffects: Bool = true) throws{
        let fullUrl = try SoundFileManager.getFilePath(fileName: fileName, fileExtension: fileExtension)
        sampleRate = 0
        audioDuration = CMTime()
        audioDurationSeconds = CMTimeGetSeconds(audioDuration);
        self.engine = soundEngine
        mixerNode = engine.mainMixerNode
        
        do {
            try audioFile = AVAudioFile(forReading: fullUrl)
            endOffset = audioFile!.length
        }
        
        catch let error {
            print("Error opening audio file: \(error.localizedDescription)")
        }
        
        routeEffects()

        //engine.connect(reverb, to: mixerNode!, format:  mixerNode!.outputFormat(forBus: 0))
        
        
        // Initialize any async tasks
        Task{
            await initialize(fullUrl: fullUrl)
        }
        
    }
    
    private var validEffects: [AVAudioUnit]{
        let effects = [speed, eq, pitch, distortion, delay, reverb]
        let validEffects = effects.filter(){value in
            return value != nil
        }
        return validEffects.map { $0! }
    }
    
    func routeEffects(){
        self.bypass(enable: true)
        let validEffects = validEffects
        
        engine.detach(playerNode)
        for effect in validEffects{
            engine.detach(effect)
        }
        
        engine.attach(playerNode)
        for effect in validEffects{
            engine.attach(effect)
        }
        if validEffects.count == 0{
            engine.connect(playerNode, to: mixerNode!, format: nil)
        }
        else{
            for idx in 0..<validEffects.count{
                if idx == validEffects.count - 1{
                    engine.connect(validEffects[idx], to: mixerNode!, format: nil)
                }
                else{
                    engine.connect(validEffects[idx], to: validEffects[idx + 1], format: nil)
                }
            }
            engine.connect(playerNode, to: validEffects[0], format: nil)
        }

    }
    
    deinit {
        destroy()
    }
    
    private func initialize(fullUrl: URL) async {
        do{
            let asset = AVAsset(url: fullUrl)
            let track = try await asset.load(.tracks)[0]
            let desc = try await track.load(.formatDescriptions)[0]
            let basic = CMAudioFormatDescriptionGetStreamBasicDescription(desc)
            sampleRate = basic?.pointee.mSampleRate
            audioDuration = try await asset.load(.duration)
            audioDurationSeconds = CMTimeGetSeconds(audioDuration);
            initialized = true
        }
        catch{
            print("Exception while extracting track data")
        }
    }
    
    func reloadAudio(fileName: String, fileExtension: String) throws{
        let fullUrl = try SoundFileManager.getFilePath(fileName: fileName, fileExtension: fileExtension)
        do {
            try audioFile = AVAudioFile(forReading: fullUrl)
        }
        
        catch let error {
            print("Error opening audio file: \(error.localizedDescription)")
        }
    }
    
    func bypass(enable: Bool){
        // This should be done synchronously to prevent issues while destructing
        // Maybe in the future we can use locks to performantly do this in the background to speed up touch->Play response
        // IDK what the performance timing of this even is, maybe not an issue
            if self.delay != nil{
                self.delay?.bypass = enable
            }
            if self.distortion != nil{
                self.distortion?.bypass = enable
            }
            if self.reverb != nil{
                self.reverb?.bypass = enable
            }
            if self.eq != nil{
                self.eq?.bypass = enable
            }
            if self.pitch != nil{
                self.pitch?.bypass = enable
            }
            if self.speed != nil{
                self.speed?.bypass = enable
            }
    }
    
    func setRange(range: Range<Int>){
        setStartOffset(startOffset: Int64(range.first!))
        setEndOffset(endOffset: Int64(range.last!))
    }
    
    func setStartOffset(startOffset: Int64){
        self.startOffset = max(0, startOffset)
        self.startOffset = min(self.endOffset - 1, self.startOffset)
    }
    
    func setEndOffset(endOffset: Int64){
        if endOffset <= 0{
            return
        }
        self.endOffset = max(self.startOffset + 1, endOffset)
    }
    
    func enableReverb(enable: Bool){
        if enable{
            if reverb == nil{
                reverb = AVAudioUnitReverb()
                routeEffects()
            }
        }
        else{
            if reverb != nil{
                engine.detach(reverb!)
                reverb = nil
                routeEffects()
            }
        }
        
    }
    
    func enableDelay(enable: Bool){
        if enable{
            if delay == nil{
                delay = AVAudioUnitDelay()
                routeEffects()
            }
        }
        else{
            if delay != nil{
                engine.detach(delay!)
                delay = nil
                routeEffects()
            }
        }
        
    }
    
    func enableDistortion(enable: Bool){
        if enable{
            if distortion == nil{
                distortion = AVAudioUnitDistortion()
                routeEffects()
            }
        }
        else{
            if distortion != nil{
                engine.detach(distortion!)
                distortion = nil
                routeEffects()
            }
        }
        
    }
    
    func enablePitch(enable: Bool){
        if enable{
            if pitch == nil{
                pitch = AVAudioUnitTimePitch()
                routeEffects()
            }
        }
        else{
            if pitch != nil{
                engine.detach(pitch!)
                pitch = nil
                routeEffects()
            }
        }
        
    }
    
    func enableSpeed(enable: Bool){
        if enable{
            if speed == nil{
                speed = AVAudioUnitVarispeed()
                routeEffects()
            }
        }
        else{
            if speed != nil{
                engine.detach(speed!)
                speed = nil
                routeEffects()
            }
        }
        
    }
    
    func play() {
        DispatchQueue.global().async {
            guard self.engine.isRunning else {return}
            self.bypass(enable: false)
            self.playerNode.scheduleSegment(self.audioFile!, startingFrame: self.startOffset, frameCount: AVAudioFrameCount(self.endOffset - self.startOffset), at: nil)
            self.sampleStart = self.playerNode.lastRenderTime!.sampleTime
            self.playerNode.play()
            DispatchQueue.main.async {
                self.playing = true
            }
            Task{
                // 120 fps is 0.008, set to half to prevent aliasing
                let seconds = 0.004
                let duration = UInt64(seconds * 1_000_000_000)
                let current = min(Int(self.playerNode.lastRenderTime!.sampleTime - self.sampleStart + self.startOffset), Int(self.endOffset))
                let currentRange = Int(self.startOffset)..<current
                DispatchQueue.main.async {
                    self.currentSample = current
                    self.currentSampleRange = currentRange
                }
                while self.engine.isRunning && self.currentSample < self.endOffset && self.playerNode.isPlaying{
                    try? await Task.sleep(nanoseconds: duration)
                    if self.playerNode.lastRenderTime == nil{
                        break
                    }
                    let current = min(Int(self.playerNode.lastRenderTime!.sampleTime - self.sampleStart + self.startOffset), Int(self.endOffset))
                    let currentRange = Int(self.startOffset)..<current
                    DispatchQueue.main.async {
                        self.currentSample = current
                        self.currentSampleRange = currentRange
                    }
                   
                }
                self.stop(bypass: false)
            }
            
        }
    }
    func stop(bypass: Bool = true){
        DispatchQueue.global().async {
            self.stopBlocking(bypass: bypass)
        }
    }
    
    func stopBlocking(bypass: Bool = true){
        if bypass{
            self.bypass(enable: true)
        }
        if self.engine.isRunning{
            if self.playing{
                self.playerNode.stop()
                self.playerNode.reset()
                DispatchQueue.main.async {
                    self.playing = false
                    self.currentSample = Int(self.startOffset)
                }
            }
        }
    }
    
    func destroy(){
        self.stopBlocking()
        engine.detach(playerNode)
        for effect in validEffects{
            engine.detach(effect)
        }
}
    
    func pause(){
        
    }
    
    func isPlaying() -> Bool{
        return self.playerNode.isPlaying
    }
    
    public var remainingTime: TimeInterval {
        guard let nodeTime = playerNode.lastRenderTime,
            let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
                return 0
        }
        let time = (Double(playerTime.sampleTime) / playerTime.sampleRate)
            .truncatingRemainder(dividingBy: Double(audioFile!.length) / Double(playerTime.sampleRate))
        return time
    }
    
}
