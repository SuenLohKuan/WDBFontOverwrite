//
//  WDBFontOverwriteApp.swift
//  WDBFontOverwrite
//
//  Created by Zhuowei Zhang on 2022-12-25.
//

import SwiftUI

@main
struct WDBFontOverwriteApp: App {
    @StateObject private var progressManager = ProgressManager.shared

    var body: some Scene {
        WindowGroup {
            TabView {
                PresetFontsScene()
                    .tabItem {
                        Label("预设", systemImage: "list.dash")
                    }
                CustomFontsScene()
                    .tabItem {
                        Label("自定义", systemImage: "plus")
                    }
                FontDiscoveryScene()
                    .tabItem {
                        Label("发现", systemImage: "star")
                    }
            }
            .environmentObject(progressManager)
        }
    }
}
