//
//  SoundboardApp.swift
//  Shared
//
//  Created by Tim Barber on 10/8/21.
//

import SwiftUI

@main
struct SoundboardApp: App {
    let persistenceController = PersistenceController.shared
    var body: some Scene {
        WindowGroup {
            MainView(preview: false)
            }
        }
    }
