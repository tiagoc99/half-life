// Half-Life app entry point.
// RxApp is the SwiftUI App type marked @main, so the system starts the process here.
// body builds one WindowGroup whose root view is ContentView. That view owns the Sources, Calculator, and Settings tabs.
// This file does not calculate decay, store sources, or contact the App Store.

//
//  RxApp.swift
//  Rx
//
//  Created by Tiago Costa on 08/10/2025.
//

import SwiftUI

@main
// The scene is a single window. ContentView creates the source list and the purchase manager.
struct RxApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
