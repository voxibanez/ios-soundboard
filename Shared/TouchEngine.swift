//
//  TapEngine.swift
//  Soundboard
//
//  Created by Tim Barber on 10/12/21.
//
import SwiftUI
import UIKit

class PanGesture: UIPanGestureRecognizer{
    var didBeginTouch: (([TouchEvent])->Void)?
    var didEndTouch: (([TouchEvent])->Void)?
    var didUpdateTouch: (([TouchEvent])->Void)?
    private var activeTouchEvents: [TouchEvent] = []

    init(target: Any?, action: Selector?, didBeginTouch: (([TouchEvent])->Void)? = nil, didUpdateTouch: (([TouchEvent])->Void)? = nil, didEndTouch: (([TouchEvent])->Void)? = nil) {
        super.init(target: target, action: action)
        self.didBeginTouch = didBeginTouch
        self.didUpdateTouch = didUpdateTouch
        self.didEndTouch = didEndTouch
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        var touchEvents: [TouchEvent] = []
        for touch in touches{
            // Get start location
            let currentLocation = touch.location(in: self.view)
            let currentLocationGlobal = touch.location(in: .none)
            for touchEvent in activeTouchEvents{
                if touch == touchEvent  {
                    touchEvent.currentLocation = currentLocation
                    touchEvent.currentLocationGlobal = currentLocationGlobal
                    touchEvents.append(contentsOf: [touchEvent])
                    break
                }
            }
        }
        self.didUpdateTouch?(touchEvents)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        var touchEvents: [TouchEvent] = []
        for touch in touches{
            // Get start location
            let startLocation = touch.location(in: self.view)
            let startLocationGlobal = touch.location(in: .none)
            touchEvents.append(contentsOf: [TouchEvent(startLocation: startLocation, startLocationGlobal: startLocationGlobal, touchObject: touch)])
        }
        activeTouchEvents.append(contentsOf: touchEvents)
        self.didBeginTouch?(touchEvents)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        var touchEvents: [TouchEvent] = []
        for touch in touches{
            // Get start location
            let currentLocation = touch.location(in: self.view)
            for touchEvent in activeTouchEvents{
                if touch == touchEvent  {
                    touchEvent.currentLocation = currentLocation
                    touchEvents.append(contentsOf: [touchEvent])
                    let indexToDelete = activeTouchEvents.firstIndex(of: touchEvent)
                    // TODO: Make sure this doesn't tank the for loop
                    activeTouchEvents.remove(at: indexToDelete!)
                    break
                }
            }
        }
        self.didEndTouch?(touchEvents)
    }
        
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        var touchEvents: [TouchEvent] = []
        for touch in touches{
            // Get start location
            let currentLocation = touch.location(in: self.view)
            for touchEvent in activeTouchEvents{
                if touch == touchEvent {
                    touchEvent.currentLocation = currentLocation
                    touchEvents.append(contentsOf: [touchEvent])
                    let indexToDelete = activeTouchEvents.firstIndex(of: touchEvent)
                    // TODO: Make sure this doesn't tank the for loop
                    activeTouchEvents.remove(at: indexToDelete!)
                    break
                }
            }
        }
        self.didEndTouch?(touchEvents)
    }
}

class LongPressGesture: UILongPressGestureRecognizer{
    var didBeginTouch: (([TouchEvent])->Void)?
    var didEndTouch: (([TouchEvent])->Void)?
    var didUpdateTouch: (([TouchEvent])->Void)?
    private var useLocalLocation: Bool = false
    private var activeTouchEvents: [TouchEvent] = []

    init(target: Any?, action: Selector?, didBeginTouch: (([TouchEvent])->Void)? = nil, didUpdateTouch: (([TouchEvent])->Void)? = nil, didEndTouch: (([TouchEvent])->Void)? = nil, useLocalLocation: Bool = false) {
        super.init(target: target, action: action)
        self.didBeginTouch = didBeginTouch
        self.didUpdateTouch = didUpdateTouch
        self.didEndTouch = didEndTouch
        self.useLocalLocation = useLocalLocation
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        var touchEvents: [TouchEvent] = []
        for touch in touches{
            // Get start location
            let currentLocation = touch.location(in: self.view)
            let currentLocationGlobal = touch.location(in: .none)
            for touchEvent in activeTouchEvents{
                if touch == touchEvent  {
                    touchEvent.currentLocation = currentLocation
                    touchEvent.currentLocationGlobal = currentLocationGlobal
                    touchEvents.append(contentsOf: [touchEvent])
                    break
                }
            }
        }
        
        self.didUpdateTouch?(touchEvents)
    }
    
    func longTouchUpdate(){
        if (self.state == .began){
            self.didBeginTouch?(activeTouchEvents)
        }
        else if (self.state == .changed){
            // This is handled properly by touchesMoved
            //self.didUpdateTouch?(activeTouchEvents)
        }
        else if (self.state == .cancelled){
            self.didEndTouch?(activeTouchEvents)
        }
        else if (self.state == .ended){
            self.didEndTouch?(activeTouchEvents)
        }
        else if (self.state == .failed){
            self.didEndTouch?(activeTouchEvents)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        var touchEvents: [TouchEvent] = []
        for touch in touches{
            // Get start location
            let startLocation = touch.location(in: self.view)
            let startLocationGlobal = touch.location(in: .none)
            touchEvents.append(contentsOf: [TouchEvent(startLocation: startLocation, startLocationGlobal: startLocationGlobal, touchObject: touch)])
        }
        print("Touch begin")
        activeTouchEvents.append(contentsOf: touchEvents)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        var touchEvents: [TouchEvent] = []
        for touch in touches{
            // Get start location
            let currentLocation = touch.location(in: self.view)
            for touchEvent in activeTouchEvents{
                if touch == touchEvent  {
                    touchEvent.currentLocation = currentLocation
                    touchEvents.append(contentsOf: [touchEvent])
                    let indexToDelete = activeTouchEvents.firstIndex(of: touchEvent)
                    // TODO: Make sure this doesn't tank the for loop
                    activeTouchEvents.remove(at: indexToDelete!)
                    break
                }
            }
        }
        //self.didEndTouch?(touchEvents)
    }
        
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        var touchEvents: [TouchEvent] = []
        for touch in touches{
            // Get start location
            let currentLocation = touch.location(in: self.view)
            for touchEvent in activeTouchEvents{
                if touch == touchEvent {
                    touchEvent.currentLocation = currentLocation
                    touchEvents.append(contentsOf: [touchEvent])
                    let indexToDelete = activeTouchEvents.firstIndex(of: touchEvent)
                    // TODO: Make sure this doesn't tank the for loop
                    activeTouchEvents.remove(at: indexToDelete!)
                    break
                }
            }
        }
        //self.didEndTouch?(touchEvents)
    }
}

class TapGesture : UITapGestureRecognizer {

    var didBeginTouch: (([TouchEvent])->Void)?
    var didEndTouch: (([TouchEvent])->Void)?
    private var activeTouchEvents: [TouchEvent] = []

    init(target: Any?, action: Selector?, didBeginTouch: (([TouchEvent])->Void)? = nil, didEndTouch: (([TouchEvent])->Void)? = nil) {
        super.init(target: target, action: action)
        self.didBeginTouch = didBeginTouch
        self.didEndTouch = didEndTouch
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        var touchEvents: [TouchEvent] = []
        for touch in touches{
            let startLocation = touch.location(in: self.view)
            let startLocationGlobal = touch.location(in: .none)
            touchEvents.append(contentsOf: [TouchEvent(startLocation: startLocation, startLocationGlobal: startLocationGlobal, touchObject: touch)])
        }
        activeTouchEvents.append(contentsOf: touchEvents)
        self.didBeginTouch?(touchEvents)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        var touchEvents: [TouchEvent] = []
        for touch in touches{
            let currentLocation = touch.location(in: self.view)
            for touchEvent in activeTouchEvents{
                if touch == touchEvent {
                    touchEvent.currentLocation = currentLocation
                    touchEvents.append(contentsOf: [touchEvent])
                    let indexToDelete = activeTouchEvents.firstIndex(of: touchEvent)
                    // TODO: Make sure this doesn't tank the for loop
                    activeTouchEvents.remove(at: indexToDelete!)
                    break
                }
            }
        }
        self.didEndTouch?(touchEvents)
    }
}

class TouchEvent: Hashable{
    var currentLocation: CGPoint
    var currentLocationGlobal: CGPoint
    var startLocation: CGPoint
    var touchObject: UITouch
    init(startLocation: CGPoint, startLocationGlobal: CGPoint, touchObject: UITouch){
        self.startLocation = startLocation
        self.touchObject = touchObject
        self.currentLocation = startLocation
        self.currentLocationGlobal = startLocationGlobal
    }
    func intersectsView(view: UIView) -> Bool{
        return view.frame.contains(currentLocation)
    }
    static func == (lhs: TouchEvent, rhs: TouchEvent) -> Bool {
        return lhs.touchObject == rhs.touchObject
        }
    
    static func == (lhs: UITouch, rhs: TouchEvent) -> Bool {
        return lhs == rhs.touchObject
        }
    
    static func == (lhs: TouchEvent, rhs: UITouch) -> Bool {
        return lhs.touchObject == rhs
        }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.touchObject)
        }
}

struct TouchesHandler: UIViewRepresentable {
    var didBeginTap: (([TouchEvent])->Void)?
    var didEndTap: (([TouchEvent])->Void)?
    var didBeginPan: (([TouchEvent])->Void)?
    var didUpdatePan: (([TouchEvent])->Void)?
    var didEndPan: (([TouchEvent])->Void)?
    var didLongPressBegin: (([TouchEvent])->Void)?
    var didLongPressUpdate: (([TouchEvent])->Void)?
    var didLongPressEnd: (([TouchEvent])->Void)?

    func makeUIView(context: UIViewRepresentableContext<TouchesHandler>) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = true
        if (didBeginTap != nil || didEndTap != nil){
            view.addGestureRecognizer(context.coordinator.makeTapGesture(didBegin: didBeginTap, didEnd: didEndTap))
        }
        if (didBeginPan != nil || didUpdatePan != nil || didEndPan != nil){
            view.addGestureRecognizer(context.coordinator.makePanGesture(didBegin: didBeginPan, didUpdate: didUpdatePan, didEnd: didEndPan))
        }
        if (didLongPressBegin != nil || didLongPressUpdate != nil || didLongPressEnd != nil){
            view.addGestureRecognizer(context.coordinator.makeLongPressGesture(didBegin: didLongPressBegin, didUpdate: didLongPressUpdate, didEnd: didLongPressEnd))
        }
        return view;
    }
    
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<TouchesHandler>) {

    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    class Coordinator: NSObject {
        @objc
        func action(_ sender: Any?) {
        }
        
        @objc
        func longPressAction(_ sender: LongPressGesture) {
            sender.longTouchUpdate()
        }

        func makeTapGesture(didBegin: (([TouchEvent])->Void)?, didEnd: (([TouchEvent])->Void)?) -> TapGesture {
            let gesture = TapGesture(target: self, action: #selector(self.action(_:)), didBeginTouch: didBegin, didEndTouch: didEnd)
            gesture.cancelsTouchesInView = false
            return gesture
        }
        
        func makeLongPressGesture(didBegin: (([TouchEvent])->Void)?, didUpdate: (([TouchEvent])->Void)?, didEnd: (([TouchEvent])->Void)?) -> LongPressGesture{
            let gesture = LongPressGesture(target: self, action: #selector(self.longPressAction(_:)), didBeginTouch: didBegin, didUpdateTouch: didUpdate ,didEndTouch: didEnd)
            gesture.cancelsTouchesInView = false
            gesture.minimumPressDuration = 0.3
            return gesture
        }
        
        func makePanGesture(didBegin: (([TouchEvent])->Void)?, didUpdate: (([TouchEvent])->Void)?, didEnd: (([TouchEvent])->Void)?) -> PanGesture {
            let gesture = PanGesture(target: self, action: #selector(self.action(_:)), didBeginTouch: didBegin, didUpdateTouch: didUpdate, didEndTouch: didEnd)
            gesture.cancelsTouchesInView = false
            return gesture
        }
    typealias UIViewType = UIView
}
}

struct TestCustomTapGesture: View {
    var body: some View {
        Text("Hello, World!")
            .padding()
            .background(Color.yellow)
            .overlay(TouchesHandler(didBeginTap: { touches in
                print(">> did begin tap")
            }, didEndTap: { touches in
                print("<< did end tap")
            }, didBeginPan: { touches in
                print("<< did start pan")
            }, didUpdatePan: { touches in
                print("<< did update pan")
            }, didEndPan: { touches in
                print("<< did end pan")
            }))
    }
}

struct TestCustomTapGesture_Previews: PreviewProvider {
    static var previews: some View {
        TestCustomTapGesture()
    }
}
