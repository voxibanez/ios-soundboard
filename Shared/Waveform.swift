import Foundation
import SwiftUI
import CoreData
import FDWaveformView
 

struct WaveformEditor : View{
    @State var attributes: SoundAttributes
    @State var audioSample: AudioSample
    @State private var newName = ""
    @State private var playing = false
    @State private var customWaveformView = CustomFdWaveformView()
    @State private var cropperLeft = Cropper(cropperType: .Right, lineThickness: 3, lineColor: .red)
    @State private var cropperRight = Cropper(cropperType: .Left, lineThickness: 3, lineColor: .red)
    var animator: UIViewPropertyAnimator!
    var body: some View {
            VStack{
                CropperView(cropper: cropperLeft)
                CropperView(cropper: cropperRight)
                WaveForm(audioURL: try! SoundFileManager.getFilePath(fileName: attributes.fileName!, fileExtension: attributes.fileExtension!), waveform: customWaveformView.waveform).frame(width: 300, height: 100, alignment: .center)
                
                // Button for playing sound
                Button(action:{
                    if !audioSample.isPlaying(){
                        self.customWaveformView.waveform.doesAllowScrubbing = false
                        customWaveformView.start()
                        audioSample.play()
                        playing = true
                    }else{
                        audioSample.stop()
                        playing = false
                        customWaveformView.stop()
                        customWaveformView.reset()
                        self.customWaveformView.waveform.highlightedSamples = 0..<1
                        self.customWaveformView.waveform.doesAllowScrubbing = true

                    }
                }){
                    Image(systemName: playing ? "stop.circle" : "play.circle")
                }.buttonStyle(BorderlessButtonStyle()).frame(
                    alignment: Alignment.center)
            }
    }
    }

class CustomFdWaveformView{
    var animator: UIViewPropertyAnimator!
    var animatorReset: UIViewPropertyAnimator!
    var waveform = FDWaveformView()
    
    init(){
        
        //animator = UIViewPropertyAnimator(duration: 2, curve: .linear) { [unowned self, waveform] in
        animator = UIViewPropertyAnimator(duration: 2, curve: .linear) { [waveform] in
            waveform.highlightedSamples = 0..<waveform.totalSamples
        }
        //animatorReset = UIViewPropertyAnimator(duration: 0.0, curve: .linear) { [unowned self, waveform] in
        animatorReset = UIViewPropertyAnimator(duration: 0.0, curve: .linear) { [waveform] in
            waveform.highlightedSamples = 0..<1
        }
        
    }
    func start(){
        animator.startAnimation()
    }
    func stop(){
        animator.stopAnimation(true)
    }
    func reset(){
        animatorReset.startAnimation()
    }
}

struct WaveForm : UIViewRepresentable{
    var audioURL: URL
    var waveform: FDWaveformView

    func makeUIView(context: Context) -> FDWaveformView {
        self.waveform.audioURL = self.audioURL
        self.waveform.doesAllowScrubbing = true
        self.waveform.doesAllowStretch = true
        self.waveform.doesAllowScroll = true
        return self.waveform
    }
    
    func updateUIView(_ uiView: FDWaveformView, context: Context) {
    }
}

struct CropperView: UIViewRepresentable{
    var cropper: Cropper

    func makeUIView(context: Context) -> Cropper {
        return self.cropper
    }
    
    func updateUIView(_ uiView: Cropper, context: Context) {
    }
}

internal enum CropperType {
    case Left
    case Right
}

public class Cropper: UIView {
    public var cropTime: CGFloat = 0 {
        willSet {
            if newValue > 0 {
                var second = (Int((newValue.truncatingRemainder(dividingBy: 3600)).truncatingRemainder(dividingBy: 60)))
                let minute = (Int((newValue.truncatingRemainder(dividingBy: 3600)) / 60))
                let hour = (Int(newValue / 3600))
                var milisec: CGFloat = newValue - CGFloat(hour * 3600) - CGFloat(minute * 60) - CGFloat(second)
                let rounded = Int(round(milisec))
                second += rounded
                milisec = (rounded == 1) ? 0 : milisec
                let miliSecStr = Double(milisec).stripDecimalZeroAsString() ?? ""
                if hour == 0 {
                    self.timeLabel.text = "\(minute.addLeadingZeroAsString()):\(second.addLeadingZeroAsString())\(miliSecStr)"
                } else {
                    self.timeLabel.text = "\(hour.addLeadingZeroAsString()):\(minute.addLeadingZeroAsString()):\(second.addLeadingZeroAsString())\(miliSecStr)"
                }
            } else {
                self.timeLabel.text = "00:00"
            }
            setNeedsDisplay()
        }
    }
    
    var verticalLine: UIView = UIView()
    var horizontalLine: UIView = UIView()
    var lineColor: UIColor = .red
    var lineThickness: CGFloat = 2
    var height: CGFloat = 90.0
    var width: CGFloat = 30.0
    var cropperType: CropperType = .Left
    let timeLabel: UILabel = UILabel()
    let labelHeight: CGFloat = 20
    
    init(cropperType: CropperType, lineThickness: CGFloat = 2, lineColor: UIColor = .red) {
        self.cropperType = cropperType
        self.lineThickness = lineThickness
        self.lineColor = lineColor
        super.init(frame: CGRectNull)
        setupUI()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupUI()
    }
    
    //override func touchesBegan(touches: Set<UITouch>, with event: UIEvent) {
    //    let touch = touches.first
    //    let p = (touch?.locationInView(self))!
    //    print("coord: \(p.x), \(p.y)")
    //}
    
    private func setupUI() {
        self.cropTime = 0
        timeLabel.text = "00:00"
        timeLabel.textColor = self.lineColor
        timeLabel.font = UIFont(name: "San Francisco", size: 12)
        timeLabel.adjustsFontSizeToFitWidth = true
    }
    
    func setTimeLabel(timeText time: String?) {
        self.timeLabel.text = time
    }
    /*
    override public func drawRect(rect: CGRect) {
        print("drawRect, rect bounds: \(rect.width), \(rect.height)")
    }
    */
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        self.backgroundColor = .clear
        positionViews()
    }
    
    func positionViews() {
        // left Verticalline and Horizontal line as default
        timeLabel.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: labelHeight)
        verticalLine = UIView(frame: CGRect(x: 0, y: labelHeight, width: lineThickness, height: self.bounds.height - lineThickness - labelHeight))
        verticalLine.backgroundColor = lineColor
        horizontalLine = UIView(frame: CGRect(x: 0, y: self.bounds.height-lineThickness, width: self.bounds.width, height: lineThickness))
        horizontalLine.backgroundColor = lineColor
        
        switch self.cropperType {
        case .Right:
            timeLabel.frame = CGRect(x: 0, y: self.bounds.height-labelHeight, width: width, height: labelHeight)
            let maxX = self.bounds.width - lineThickness
            verticalLine.frame = CGRect(x: maxX, y: 0, width: lineThickness, height: self.bounds.height - labelHeight)
            horizontalLine.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: lineThickness)
            
        default:
            print("using Left cropper as default")
        }
        
        self.addSubview(timeLabel)
        self.addSubview(verticalLine)
        self.addSubview(horizontalLine)
    }

}

extension Int {
    func addLeadingZeroAsString() -> String {
        return String(format: "%02d", self)  // add leading zero to single digit
    }
}

extension Double {
    
    func stripDecimalZeroAsString() -> String? {
        if self >= 1 || self == 0 {
            return nil
        }
        let formatter = NumberFormatter()
        formatter.positiveFormat = ".###" // decimal without decimal 0
        
        return formatter.string(from: NSNumber(value: self)) // 0.333454 becomes ".333"
    }
}
