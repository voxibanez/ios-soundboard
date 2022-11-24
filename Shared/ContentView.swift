//
//  ContentView.swift
//  Shared
//
//  Created by Tim Barber on 10/8/21.
//

import SwiftUI
import CoreData
import Combine
import AVFoundation
import Introspect


struct BoundsAnchorsPreferenceKey: PreferenceKey {
    typealias Value = [String: Anchor<CGRect>]
    static var defaultValue: Value = [:]

    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = value.merging(nextValue()) { (_, new) in new }
    }
}

struct BoundsPreferenceKey: PreferenceKey {
    typealias Value = [String:  CGRect]
    static var defaultValue: Value = [:]

    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = value.merging(nextValue()) { (_, new) in new }
    }
}
extension CGRect: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin.x)
        hasher.combine(origin.y)
        hasher.combine(size.width)
        hasher.combine(size.height)
    }
}

struct SoundButtonView : View{
    @ObservedObject var viewModel: SoundButton
    @ObservedObject var sound: AudioSample
    @Binding var scalar: Float
    @State private var angle: Double = 0.0
    @State private var playColor: Color = Color.accentColor
    @State private var backgroundColor: Color = Color.gray
    
    private func onClick(){
        return
    }
    
    func getWidth() -> CGFloat{
        return 100 * viewModel.scale * CGFloat(scalar)
    }
    
    func getHeight() -> CGFloat{
        return 100 * viewModel.scale * CGFloat(scalar)
    }
    
    func getCenter() -> CGPoint{
        return CGPoint(x: CGFloat(getWidth() / 2.0), y: CGFloat(getHeight() / 2.0))
    }

    
    var body: some View {
        if (viewModel.attributes.name == nil){
            Text("Error")
        }
        else{
            Button(action: onClick){
                ZStack{
                    (viewModel.buttonPressed ? sound.playing ? playColor : playColor.opacity(0.3) : playColor.opacity(0.0))
                        .animation(.easeInOut(duration: 0.1), value: viewModel.buttonPressed)
                        .animation(.easeInOut(duration: 0.5), value: sound.playing)
                        
                    Text(viewModel.attributes.name!).foregroundColor(.white)
                    
                }
            }
            .sheet(isPresented: $viewModel.editing, onDismiss: {viewModel.onSettingsUpdate()}) {
                SoundSettingsView(attributes: self.viewModel.attributes, audioSample: self.viewModel.sound, updateSettings: viewModel.syncSettings)
            }.frame(alignment: .top)
                .frame(width: getWidth(), height: getHeight())
                .background(Color.gray)
                .cornerRadius(15)
                .padding()
                .rotationEffect(.degrees(angle))
                .onAppear(){
                    if viewModel.editMode{
                        //print("Editing")
                        withAnimation(Animation.easeInOut(duration: 0.1 * Double.random(in: 0.9...1.1)).repeatForever(autoreverses: true)) {
                            angle = 3.0 * (Bool.random() ? 1 : -1)
                        }
                    }
                    else{
                        //print("Editing done")
                        withAnimation(Animation.easeInOut(duration: 0.5)){
                            angle = 0.0
                        }
                    }
                    
                }
                .onChange(of: viewModel.editMode){value in
                    if value{
                        //print("Editing")
                        withAnimation(Animation.easeInOut(duration: 0.1 * Double.random(in: 0.9...1.1)).repeatForever(autoreverses: true)) {
                            angle = 3.0 * (Bool.random() ? 1 : -1)
                        }
                    }
                    else{
                        //print("Editing done")
                        withAnimation(Animation.easeInOut(duration: 0.5)){
                            angle = 0.0
                        }
                    }
                }
        }        }
}


class SoundButton: Hashable, ObservableObject {
    var attributes: SoundAttributes
    var onSoundPlayStart: () -> ()
    var onSoundPlayEnd: () -> ()
    var removeSound: (SoundButton) -> ()
    var editSound: (SoundButton) -> ()
    var onSettingsUpdate: () -> ()
    var soundEngine: AVAudioEngine
    @ObservedObject var sound: AudioSample
    var volume: Int = 1
    var editMasterValue: Bool? = nil
    @Published var scale: CGFloat = 1.0
    @Published var buttonPressed: Bool = false
    @Published var editMode: Bool = false
    @Published var editing: Bool = false
    @Published var holding: Bool = false
    @Published var holdingComplete: Bool = true
    @Published var holdingCord: CGPoint = CGPoint(x: 0, y: 0)
    @Published var holdingCordGlobal: CGPoint = CGPoint(x: 0, y: 0)
    private var uuid = UUID().uuidString
    var touchEvents: [TouchEvent] = []
    var holdEvents: [TouchEvent] = []
    init(attributes: SoundAttributes, soundEngine: AVAudioEngine, onSoundPlayStart: @escaping () -> Void, onSoundPlayEnd: @escaping () -> Void, removeSound: @escaping (SoundButton) -> Void, editSound: @escaping (SoundButton) -> Void, editMasterValue: Bool?, onSettingsUpdate: @escaping () -> Void) throws{
        self.onSoundPlayStart = onSoundPlayStart
        self.onSoundPlayEnd = onSoundPlayEnd
        self.removeSound = removeSound
        self.editSound = editSound
        self.attributes = attributes
        self.soundEngine = soundEngine
        self.sound = try AudioSample(fileName: attributes.fileName!, fileExtension: attributes.fileExtension!, soundEngine: self.soundEngine)
        self.editMasterValue = editMasterValue
        self.onSettingsUpdate = onSettingsUpdate
        self.syncSettings()
        
    }

    func markHoldingComplete(){
        holdingComplete = true
    }
    
    func reloadAudio(fileName: String, fileExtension: String) throws{
        try self.sound.reloadAudio(fileName: fileName, fileExtension: fileExtension)
    }
    
    func syncSettings(){
        // Sync settings with audio
        self.sound.enableReverb(enable: attributes.reverbEnabled)
        self.sound.enableDelay(enable: attributes.delayEnabled)
        self.sound.enableDistortion(enable: attributes.distortionEnabled)
        self.sound.enablePitch(enable: attributes.pitchEnabled)
        self.sound.enableSpeed(enable: attributes.speedEnabled)
        
        self.sound.reverb?.wetDryMix = attributes.reverbWet
        self.sound.delay?.wetDryMix = attributes.delayWet
        self.sound.distortion?.wetDryMix = attributes.distortionWet
        self.sound.pitch?.pitch = attributes.pitchLevel
        self.sound.pitch?.rate = attributes.pitchRate
        self.sound.pitch?.overlap = attributes.pitchOverlap
        self.sound.speed?.rate = attributes.speedLevel
        
        self.sound.setStartOffset(startOffset: attributes.sampleStartOffset)
        self.sound.setEndOffset(endOffset: attributes.sampleEndOffset)
    }
    
    func triggerEditingSync(){
        if editMasterValue != nil{
            onEditModeChange(editMode: editMasterValue!)
            editMasterValue = nil
        }
    }
    
    func onEditModeChange(editMode: Bool){
        self.editMode = editMode
        if self.editMode{
            stopSound()
        }
        else{
            holding = false
            holdingComplete = true
        }
    }
    
    func stopSound(){
        touchEvents.removeAll()
        sound.stop()
        if buttonPressed{
            buttonPressed = false
        }
    }
    
    func onPress(touches: [TouchEvent]){
        // If in edit mode, skip press
        if self.editMode{
            return
        }
        self.touchEvents.append(contentsOf: touches)
        if self.touchEvents.count == 1{
            if !buttonPressed{
                buttonPressed = true
            }
            sound.play()
            onSoundPlayStart()
        }
    }
    func onRelease(touches: [TouchEvent]){
        for touch in touches{
            let indexToDelete = touchEvents.firstIndex(of: touch)
            if indexToDelete != nil && indexToDelete! >= 0{
                touchEvents.remove(at: indexToDelete!)
            }
        }
        
        // If in edit mode, open the editing screen
        if self.editMode && !self.holding{
            self.editing = true
        }
        
        if touchEvents.count == 0{
            if buttonPressed{
                buttonPressed = false
            }
            sound.stop()
            onSoundPlayEnd()
        }
    }
    func onUpdate(touches: [TouchEvent]){
        //sound.changePitch(pitch: Float(touches[0].currentLocation.y) - Float(touches[0].startLocation.x))
    }
    
    func onHoldStart(touches: [TouchEvent]){
        if (!editMode || touches.count < 1){
            return
        }
        holdingCord.x = touches[0].currentLocation.x
        holdingCord.y = touches[0].currentLocation.y
        holdingCordGlobal.x = touches[0].currentLocationGlobal.x
        holdingCordGlobal.y = touches[0].currentLocationGlobal.y
        holding = true
        holdingComplete = false
    }
    
    func onHoldUpdate(touches: [TouchEvent]){
        
        if (!editMode || !holding || touches.count < 1){
            return
        }
        print(touches.count)
        holdingCord.x = touches[0].currentLocation.x
        holdingCord.y = touches[0].currentLocation.y
        holdingCordGlobal.x = touches[0].currentLocationGlobal.x
        holdingCordGlobal.y = touches[0].currentLocationGlobal.y
    }
    
    
    func onHoldEnd(touches: [TouchEvent]){
        if (!editMode){
            return
        }
        holding = false
        holdingCord.x = 0
        holdingCord.y = 0
        holdingCordGlobal.x = 0
        holdingCordGlobal.y = 0
    }
    
    func onRemove(){
        removeSound(self)
    }
    
    static func == (lhs: SoundButton, rhs: SoundButton) -> Bool {
        return lhs.uuid == rhs.uuid
        }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.uuid)
        }
}

struct SoundGridView: View {
    @ObservedObject var viewModel: SoundGridManager
    @Binding var soundButtonSize: Float
    @Binding var editing: Bool
    @State private var offset: CGFloat = .zero
    @State private var paddingNeeded: CGFloat = .zero
    @State private var totalPages = 0
    @State private var currentPage = 0
    @State private var soundButtonViewRep: CGPoint = CGPoint(x: 0, y: 0)
    @State private var soundButtonHoldingIndex: Int = -1
    @State private var soundButtonBoundsDictAdjusted: [SoundButton: CGRect] = [:]
    @State private var soundButtonBoundsDict: [SoundButton: CGRect] = [:]
    @State private var gridSwapTime: Double = 0.2

    
    private let orientationPublisher = NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
    
    let columns = [
        GridItem(.adaptive(minimum: 80), spacing: 20)
    ]
    
    func test(){
    }
    
    var body: some View {
                GeometryReader { geometry in
                        ScrollViewReader { reader in
                            ScrollView(viewModel.isSoundPlaying ? [] : .horizontal
                                       , showsIndicators: true) {
                                ZStack(alignment: .topLeading){
                                    ZStack(alignment: .topLeading){
                                        self.generateContent(in: geometry)
                                    
                                    }.fixedSize(horizontal: false, vertical: true).background(GeometryReader {gp -> Color in
                                        DispatchQueue.main.async {
                                            var numPages: Double = gp.size.width / UIScreen.main.bounds.size.width
                                            numPages.round(.up)
                                            var padding = (UIScreen.main.bounds.size.width * numPages) - gp.size.width
                                            padding = max(padding, 0)
                                            // update on next cycle with calculated height of ZStack !!!
                                            self.totalPages = Int(numPages)
                                        }
                                        return Color.clear
                                    })
                                    getPadding()
                                    Color.clear
                                }.fixedSize(horizontal: false, vertical: false)
                            }.introspectScrollView(){ scrollview in
                                scrollview.isPagingEnabled = true
                                scrollview.showsHorizontalScrollIndicator = true
                                scrollview.horizontalScrollIndicatorInsets = .zero
                                scrollview.alwaysBounceHorizontal = true
                            }
                            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                                //Orient scrollview to nearest page
                                print("Setting to closest page in orientation")
                                reader.scrollTo(0, anchor: .leading)
                            }
                        }
                        

        }
        //.frame(height: totalHeight)// << variant for ScrollView/List
                .frame(alignment: .topLeading) // << variant for VStack

    }
    
    private func getPadding() -> some View{
        return HStack(){
            ForEach(0..<self.totalPages, id: \.self){ i in
                ZStack(){}.frame(width: UIScreen.main.bounds.size.width, height: 1).id(i)
            }
        }
    }
    
    @State private var totalHeight
        //  = CGFloat.zero       // << variant for ScrollView/List
        = CGFloat.infinity   // << variant for VStack
    
    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        var tabIndex = 0
        return ForEach(self.viewModel.sounds, id: \.self) { soundButton in
                ZStack{
                    self.item(for: soundButton)
                        .padding([.horizontal, .vertical], 0)
                        .alignmentGuide(.leading, computeValue: { d in
                            
                            if (abs(width - d.width) > g.size.width)
                            {
                                width = 0
                                height -= d.height
                            }
                            
                            if (abs(height - d.height) > g.size.height){
                                tabIndex -= 1
                                height = 0
                                width = 0
                            }
                            let result = width + g.size.width * CGFloat(tabIndex)
                            if soundButton == self.viewModel.sounds.last! {
                                width = 0 //last item
                                tabIndex = 0
                                
                                
                            } else {
                                width -= d.width
                            }
                            return result
                        })
                        .alignmentGuide(.top, computeValue: {d in
                            let result = height
                            if soundButton == self.viewModel.sounds.last! {
                                height = 0 // last item
                                tabIndex = 0
                            }
                            return result
                        })
                        .background(GeometryReader {gp -> Color in
                            DispatchQueue.main.async {
                                let ratio = CGFloat(1.0)
                                let adjustedX = gp.frame(in: .global).midX - (gp.size.width / 2.0 * ratio)
                                let adjustedY = gp.frame(in: .global).midY - (gp.size.height / 2.0 * ratio)
                                let adjustedWidth = gp.size.width * ratio
                                let adjustedHeight = gp.size.height * ratio
                                soundButtonBoundsDictAdjusted[soundButton] = CGRect(x: adjustedX, y: adjustedY, width: adjustedWidth, height: adjustedHeight)
                                soundButtonBoundsDict[soundButton] = CGRect(x: adjustedX, y: adjustedY, width: adjustedWidth, height: adjustedHeight)

                                
                            }
                            return Color.clear
                        })
                    
                }.overlay(createOverlay(for: soundButton, soundButtonBoundsDict: soundButtonBoundsDict), alignment: .trailing)
        }
                
    }
    
    func onIntersect(point: CGPoint, soundButton: SoundButton){
        print(point)
        for (key, value) in soundButtonBoundsDictAdjusted {
            if CGRectContainsPoint(value, point){
                //print("Intersect!")
                if (soundButton != key){
                    //print("Soundbutton1: " + soundButton.attributes.name! + " Soundbutton2: " + key.attributes.name!)
                    //print("Key X: " + String(format: "%.3f", Double(value.minX)) + " Key Y: " + String(format: "%.3f", Double(value.minY)))
                    withAnimation(.easeIn(duration: gridSwapTime)) {
                        viewModel.swapButtons(button1: soundButton, button2: key)
                    }
                }
            }
        }
    }
    
    private func createOverlay(for soundButton: SoundButton, soundButtonBoundsDict: [SoundButton: CGRect] ) -> some View{
        self.movableItem(for: soundButton)
            .modifier(SoundButtonMovableModifier(soundButton: soundButton, onIntersect: onIntersect, soundButtonBoundsDict: $soundButtonBoundsDict, gridSwapTime: gridSwapTime))
           
            
    }
    
    private func createTab(for soundButtons: [AnyView]) -> some View {
            ZStack{
                ForEach(soundButtons.indices, id: \.self) { ind in
                    soundButtons[ind]
            }
        }
    }
    
    private func onOverlayHideDone(soundbutton: SoundButton){
        
    }
    
    private func item(for soundButton: SoundButton) -> some View {
        ZStack{
            SoundButtonView(viewModel: soundButton, sound: soundButton.sound, scalar: $soundButtonSize).modifier(ButtonModifier(editing: $editing, soundButton: soundButton))
            Image(systemName: "minus.circle.fill")
                .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
                .foregroundColor(Color(.red))
                .offset(x: -50 * soundButton.scale * CGFloat(soundButtonSize), y: -50 * soundButton.scale * CGFloat(soundButtonSize))
                .onTapGesture {
                    if soundButton.editMode || (soundButton.editMasterValue != nil && soundButton.editMasterValue!) {
                        soundButton.onRemove()
                    }
                }
                .modifier(RemoveHidingModifier(soundButton: soundButton))
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
                .foregroundColor(Color(.blue))
                .offset(x: 50 * soundButton.scale * CGFloat(soundButtonSize), y: -50 * soundButton.scale * CGFloat(soundButtonSize))
                .onTapGesture {
                    if soundButton.editMode || (soundButton.editMasterValue != nil && soundButton.editMasterValue!) {
                        //soundButton.onDuplicate()
                    }
                }
                .modifier(RemoveHidingModifier(soundButton: soundButton))
            
        }.onAppear(){
            soundButton.triggerEditingSync()
        }
        .modifier(SoundButtonHidingModifier(soundButton: soundButton))
    
    }
    
    private func movableItem(for soundButton: SoundButton) -> some View {
        
            ZStack{
                SoundButtonView(viewModel: soundButton, sound: soundButton.sound, scalar: $soundButtonSize)
            
                Image(systemName: "minus.circle.fill")
                    .font(.title)
                    .foregroundColor(Color(.red))
                    .offset(x: -50 * soundButton.scale * CGFloat(soundButtonSize), y: -50 * soundButton.scale * CGFloat(soundButtonSize))
            }
    }
    
    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)
            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
    
}

struct ButtonModifier : ViewModifier {
    @Binding var editing: Bool
    @ObservedObject var soundButton: SoundButton
    
    @ViewBuilder func body(content: Content) -> some View {
        if editing {
            content.overlay(TouchesHandler(didBeginPan: { touches in
                //print("Touchdown")
                soundButton.onPress(touches: touches)
            }, didUpdatePan: { touches in
                soundButton.onUpdate(touches: touches)
            }, didEndPan: { touches in
                //print("Touchup")
                soundButton.onRelease(touches: touches)
            },didLongPressBegin: {touches in
                //print("Long hold start")
                soundButton.onHoldStart(touches: touches)
            },didLongPressUpdate: {touches in
                soundButton.onHoldUpdate(touches: touches)
            },didLongPressEnd: {touches in
                //print("Long hold end")
                soundButton.onHoldEnd(touches: touches)
            }))
        } else {
            content.overlay(TouchesHandler(didBeginPan: { touches in
                //print("Touchdown")
                soundButton.onPress(touches: touches)
            }, didUpdatePan: { touches in
                soundButton.onUpdate(touches: touches)
            }, didEndPan: { touches in
                //print("Touchup")
                soundButton.onRelease(touches: touches)
            }))
        }
    }
}

struct SoundButtonHidingModifier : ViewModifier {
    @ObservedObject var soundButton: SoundButton
    
    @ViewBuilder func body(content: Content) -> some View {
        content.opacity(soundButton.holding || !soundButton.holdingComplete ? 0 : 1)
    }
}

struct RemoveHidingModifier : ViewModifier {
    @ObservedObject var soundButton: SoundButton
    
    @ViewBuilder func body(content: Content) -> some View {
            content.opacity(soundButton.editMode || (soundButton.editMasterValue != nil && soundButton.editMasterValue!) ? 1 : 0)
    }
}

struct SoundButtonMovableModifier : ViewModifier {
    @ObservedObject var soundButton: SoundButton
    var onIntersect: ((CGPoint, SoundButton)->Void)?
    @Binding var soundButtonBoundsDict: [SoundButton: CGRect]
    var gridSwapTime: Double
    @State private var scale = 1.0
    @State private var localPos = CGPoint()
    @State private var localPosAnimate = CGPoint()
    @State private var initialPosComplete = false
    @State private var serialQueue = DispatchQueue(label: "queuename")
    @State private var globalOffset = CGPoint()
    @State private var show = false
    
    
    func getOffset() -> CGPoint{
        let bounds = soundButtonBoundsDict[soundButton]
        if bounds != nil{
            return soundButtonBoundsDict[soundButton]!.origin
        }
        return CGPoint()
    }
    
    @ViewBuilder func body(content: Content) -> some View {
            content.opacity(show ? 1 : 0)
                .scaleEffect(scale, anchor: .center)
                //.animation(.easeIn(duration: 0.1), value: scale)
                .position(x: localPos.x + globalOffset.x, y: localPos.y + globalOffset.y)
                .onChange(of: soundButton.holdingCordGlobal){ value in
                    DispatchQueue.main.async {
                        onIntersect?(value, soundButton)
                    }
                }
                .onChange(of: soundButton.holdingCordGlobal){value in
                    if value.x != 0 || value.y != 0{
                        withAnimation(.easeIn(duration: 0.1)) {
                            localPos = value
                        }
                    }
                }
                .onChange(of: soundButton.holding){value in
                    withAnimation(.easeIn(duration: 0.1)) {
                        scale = value ? 1.2 : 1.0
                    }
                    if value{
                        show = true
                    }
                    else{
                        serialQueue.sync{
                            let bounds = soundButtonBoundsDict[soundButton]
                            if bounds != nil{
                                let currentOffset = getOffset()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    localPos.x = currentOffset.x + bounds!.width / 2.0
                                    localPos.y = currentOffset.y + bounds!.height / 2.0
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    show = false
                                    soundButton.markHoldingComplete()
                                }
                                    
                            }
                        }
                    }
                }
                .onChange(of: soundButtonBoundsDict) {value in
                    serialQueue.sync{
                        let bounds = soundButtonBoundsDict[soundButton]
                        if bounds != nil{
                            let currentOffset = getOffset()
                            if globalOffset != currentOffset{
                                withAnimation(.easeIn(duration: gridSwapTime)) {
                                    globalOffset.x = -currentOffset.x
                                    globalOffset.y = -currentOffset.y
                                }
                            }
                            
                            if !initialPosComplete{
                                localPos.x = currentOffset.x + bounds!.width / 2.0
                                localPos.y = currentOffset.y + bounds!.height / 2.0
                                initialPosComplete = true
                            }
                            
                            if !soundButton.holding{
                                localPos.x = currentOffset.x + bounds!.width / 2.0
                                localPos.y = currentOffset.y + bounds!.height / 2.0
                            }
                        }
                    }
                    
        }

        
        
    }
}

class SoundGridManager: ObservableObject{
    @Published var sounds: [SoundButton] = []
    @Published var isSoundPlaying = false
    @Published var editing = false
    @State var soundButtonSize: Float = 1.0
    private var soundsQueue: DispatchQueue = DispatchQueue(label: "thread-safe-obj", attributes: .concurrent)
    var soundEngine: AVAudioEngine
    private var soundsPlaying = 0
    private var soundSettingsContext: NSManagedObjectContext
    static var dbVer = "0.03"
    private var cancellables = Set<AnyCancellable>()
    
    init(view: Bool)
    {
        let audioSession = AVAudioSession.sharedInstance()
        let ioBufferDuration = 128.0 / 44100.0
        self.soundEngine = AVAudioEngine()
        UITextField.appearance().clearButtonMode = .whileEditing
        do {
            try audioSession.setPreferredIOBufferDuration(ioBufferDuration)
            try audioSession.setCategory(AVAudioSession.Category.playback, options: .mixWithOthers)
        }
        
        catch let error {
            print("Error starting sound engine: \(error.localizedDescription)")
        }
        
        if view{
            self.soundSettingsContext = PersistenceController.preview.container.viewContext
        }
        else{
            self.soundSettingsContext = PersistenceController.shared.container.viewContext
        }
        self.loadSettings()

    }
    
    func swapButtons(button1: SoundButton, button2: SoundButton){
        let i1 = sounds.firstIndex(where: {$0 == button1})
        if i1 == nil{
            print("i1 does not exist")
            return
        }
        let i2 = sounds.firstIndex(where: {$0 == button2})
        if i2 == nil{
            print("i2 does not exist")
            return
        }
        
        sounds.move(from: i1!, to: i2!)
        
        for i in 0..<sounds.count {
            sounds[i].attributes.idx = Int64(i)
        }
        
        do {
            try soundSettingsContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error adding new sound \(nsError), \(nsError.userInfo)")
        }
    }
    
    func saveSettings(){
        do {
            try soundSettingsContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error saving settings: \(nsError), \(nsError.userInfo)")
        }
    }
    
    func onEdit(editing: Bool){
        soundsQueue.sync(flags: .barrier) {
            self.editing = editing
            for sound in self.sounds{
                sound.onEditModeChange(editMode: self.editing)
                sound.syncSettings()
            }
        }


    }
    
    func stopAllSounds(){
        soundsQueue.sync(flags: .barrier) {
            for sound in self.sounds{
                sound.stopSound()
            }
        }
    }
    
    private func onSoundPlayStart(){
        /// For some reason, this is the only way to get updates from the subviews
        isSoundPlaying.toggle()
    }
    
    private func onSoundPlayEnd(){
        /// For some reason, this is the only way to get updates from the subviews
        isSoundPlaying.toggle()
    }
    
    func loadSettings(){
        let fetchRequest:NSFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SoundAttributes")
        print("Loading stored data")
        do {
            var fetchedSoundAttributes = try soundSettingsContext.fetch(fetchRequest) as! [SoundAttributes]
            if (fetchedSoundAttributes.count > 1) {
                fetchedSoundAttributes = fetchedSoundAttributes.sorted {
                    $0.idx < $1.idx
                }
            }
            for soundAttr in fetchedSoundAttributes{
                do{
                    try self.addToSoundArray(sound: SoundButton(attributes: soundAttr, soundEngine: self.soundEngine, onSoundPlayStart: onSoundPlayStart, onSoundPlayEnd: onSoundPlayEnd, removeSound: removeSound, editSound: editSound, editMasterValue: self.editing, onSettingsUpdate: saveSettings))
                }
                catch SoundFileManager.SoundFileManagerError.fileNotFound(let fileName){
                    print("Error while loading sound: Invalid file name (" + fileName + ")")
                }
                catch SoundFileManager.SoundFileManagerError.invalidExtension(let extName){
                    print("Error while loading sound: Extension invalid (" + extName + ")")
                }
                catch{
                    print("Uknown error occured while loading sound")
                }
            }
        } catch {
            fatalError("Failed to fetch data: \(error)")
        }
          }

    private func addToSoundArray(sound: SoundButton){
        soundsQueue.sync(flags: .barrier) {
            self.sounds.append(sound)
        }
        if (!self.soundEngine.isRunning){
            do{
               try self.soundEngine.start()
            }
            catch let error {
                print("Error starting sound engine: \(error.localizedDescription)")
            }
        }
    }
    
    func removeSound(sound: SoundButton){
        withAnimation {
            soundsQueue.sync(flags: .barrier) {
                self.sounds.removeAll { value in
                    return value == sound
                }
                
                self.soundSettingsContext.delete(sound.attributes)
                
                for i in 0..<sounds.count {
                    sounds[i].attributes.idx = Int64(i)
                }
                
                do {
                    try self.soundSettingsContext.save()
                } catch {
                    // Replace this implementation with code to handle the error appropriately.
                    // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    let nsError = error as NSError
                    fatalError("Unresolved error removing sound \(nsError), \(nsError.userInfo)")
                }
            }
    }
    }
    
    func editSound(sound: SoundButton){
        print("Editing sound")
    }
    
    func renameSound(oldFileName: String, oldFileExtension: String, newFileName: String, newFileExtension: String){
        for sound in sounds{
            if sound.attributes.fileName == oldFileName && sound.attributes.fileExtension == oldFileExtension{
                sound.attributes.fileName = newFileName
                sound.attributes.fileExtension = newFileExtension
                do{
                    try sound.reloadAudio(fileName: newFileName, fileExtension: newFileExtension)
                }
                catch{
                    print("Sound failed to load audio with new sound file (" + newFileName + ") extension (" + newFileExtension + ") Old sound file: (" + oldFileName + ") extension (" + oldFileExtension + ")")
                }
                // Even if we throw an exception, save the settings because we did do the rename, sound will dissapear if it still can't load on next start.
                sound.syncSettings()
            }
        }
        
        saveSettings()
    }
    
    func removeSound(fileName: String, fileExtension: String){
        withAnimation {
            soundsQueue.sync(flags: .barrier) {
                let soundsToRemove = self.sounds.filter(){ value in
                    return value.attributes.fileName == fileName && value.attributes.fileExtension == fileExtension
                }
                for sound in soundsToRemove{
                    self.soundSettingsContext.delete(sound.attributes)
                }
                
                self.sounds.removeAll { value in
                    return value.attributes.fileName == fileName && value.attributes.fileExtension == fileExtension
                }
                
                
                
                for i in 0..<sounds.count {
                    sounds[i].attributes.idx = Int64(i)
                }
                
                do {
                    try self.soundSettingsContext.save()
                } catch {
                    // Replace this implementation with code to handle the error appropriately.
                    // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    let nsError = error as NSError
                    fatalError("Unresolved error removing sound \(nsError), \(nsError.userInfo)")
                }
            }
    }
    }
    
    func addSound(fileName: String, fileExtension: String) {
        withAnimation {
            let newSound = SoundAttributes(context: soundSettingsContext)
            newSound.uid = UUID()
            newSound.fileName = fileName
            newSound.fileExtension = fileExtension
            newSound.name = fileName
            newSound.dbVer = SoundGridManager.dbVer
            newSound.idx = Int64(sounds.count)

            do {
                try soundSettingsContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error adding new sound \(nsError), \(nsError.userInfo)")
            }
            do{
                try self.addToSoundArray(sound: SoundButton(attributes: newSound, soundEngine: self.soundEngine, onSoundPlayStart: onSoundPlayStart, onSoundPlayEnd: onSoundPlayEnd, removeSound: removeSound, editSound: editSound, editMasterValue: self.editing, onSettingsUpdate: saveSettings))

            }
            catch SoundFileManager.SoundFileManagerError.fileNotFound(let fileName){
                print("Error while adding sound: Invalid file name (" + fileName + ")")
            }
            catch SoundFileManager.SoundFileManagerError.invalidExtension(let extName){
                print("Error while adding sound: Extension invalid (" + extName + ")")
            }
            catch{
                print("Uknown error occured while adding sound")
            }
        }
    }
    
}


struct MainView: View {
    @State var bounds: [String: CGRect] = [:]
    @State var editing: Bool = false
    @State var soundButtonSize: Float = 1.0
    var preview: Bool
    @ObservedObject var soundManager: SoundGridManager = SoundGridManager(view: false)

    func updateSize()
    {
    }
    
    var body: some View {
        NavigationView{
            ZStack{
                SoundLibraryView(soundManager: soundManager, soundButtonSize: $soundButtonSize, editing: $editing)
                if (editing){
                    VStack(){
                        Spacer()
                        VStack(){
                            TextSlider(text: "Size", defaultValue: 1.0, range: 0.2...5.0, value: $soundButtonSize, updateSettings: updateSize)
                        }.transition(.move(edge: .bottom)).background(.ultraThinMaterial, in:
                                                                        RoundedRectangle (cornerRadius: 20.0))
                    }.frame(alignment: .bottom)
                       
                }
            }
            .frame(maxHeight: .infinity)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarTitle("Sound Library").font(.title2)
            .navigationBarItems(leading:
                                  HStack{
                Button(action: {
                    editing.toggle()
                    soundManager.onEdit(editing: editing)
                }) {
                    Text(editing ? "Done" : "Edit").font(.title3)
                }
                
            },
                                trailing:
                                    HStack{
                SoundImportView(soundManager: soundManager)
            }
            )
        }.navigationViewStyle(StackNavigationViewStyle())


            .backgroundPreferenceValue(BoundsAnchorsPreferenceKey.self) { anchors in
                        // Get bounds relative to VStack:
                        GeometryReader { proxy in
                            let localBoundss = anchors.mapValues { anchor in
                                CGRect(origin: proxy[anchor].origin, size: proxy[anchor].size)
                            }
                            Color.clear.border(Color.clear, width: 1)
                                .preference(key: BoundsPreferenceKey.self, value: localBoundss)
                        }
                    }
                    .onPreferenceChange(BoundsPreferenceKey.self) { bounds in
                        // Store bounds into the state variable:
                        self.bounds = bounds
                    }

    }
}

struct SoundImportView: View{
    @ObservedObject var soundManager: SoundGridManager
    @State private var showImport = false
    
    var items: [GridItem] {
      Array(repeating: .init(.adaptive(minimum: 120)), count: 2)
    }
    func onAdd(fileName: String, fileExtension: String){
        print("Adding: " + fileName)
        soundManager.addSound(fileName: fileName, fileExtension: fileExtension)
    }
    func onRename(oldFileName: String, oldFileExtension: String, newFileName: String, newFileExtension: String){
        soundManager.renameSound(oldFileName: oldFileName, oldFileExtension: oldFileExtension, newFileName: newFileName, newFileExtension: newFileExtension)
    }
    
    func onRemove(fileName: String, fileExtension: String){
        soundManager.removeSound(fileName: fileName, fileExtension: fileExtension)
    }
    
    func promptRemove(fileName: String, fileExtension: String) -> Bool{
        for sound in soundManager.sounds{
            if sound.attributes.fileName == fileName && sound.attributes.fileExtension == fileExtension{
                return true
            }
        }
        return false
    }
    
    var body: some View {
        Button(action: {
            self.showImport.toggle()
        }) {
            Text("+").font(.largeTitle).animation(.none)
            /*Text("Sound Library").foregroundColor(.white)
                .frame(width: 200, height: 40)
                .background(Color.green)
                .cornerRadius(15)
                .padding()
             */
        }.sheet(isPresented: $showImport) {
            FileOpenView(onAdd: onAdd, onRename: onRename, promptRemove: promptRemove, onRemove: onRemove, soundEngine: self.soundManager.soundEngine)
        }.frame(alignment: .top)
    }
}

struct SoundLibraryView: View {
    @ObservedObject var soundManager: SoundGridManager
    @Binding var soundButtonSize: Float
    @Binding var editing: Bool
    @State private var selectedTab = 0

    var body: some View {
            if soundManager.sounds.count > 0{
                SoundGridView(viewModel: soundManager, soundButtonSize: $soundButtonSize, editing: $editing)
            }else{
                Text("No sounds yet")
            }
        }
}

extension String
{
    func encodeUrl() -> String?
    {
        return self.addingPercentEncoding( withAllowedCharacters: NSCharacterSet.urlQueryAllowed)
    }
    func decodeUrl() -> String?
    {
        return self.removingPercentEncoding
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(preview: true)
    }
}

extension Float {
  var f: CGFloat { return CGFloat(self) }
}

    extension Array where Element: Equatable
    {
        mutating func move(_ element: Element, to newIndex: Index) {
            if let oldIndex: Int = self.firstIndex(of: element) { self.move(from: oldIndex, to: newIndex) }
        }
    }

    extension Array
    {
        mutating func move(from oldIndex: Index, to newIndex: Index) {
            // Don't work for free and use swap when indices are next to each other - this
            // won't rebuild array and will be super efficient.
            if oldIndex == newIndex { return }
            if abs(newIndex - oldIndex) == 1 { return self.swapAt(oldIndex, newIndex) }
            self.insert(self.remove(at: oldIndex), at: newIndex)
        }
    }
