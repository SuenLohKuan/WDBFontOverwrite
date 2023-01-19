//
//  PresetFontsScene.swift
//  WDBFontOverwrite
//
//  Created by Noah Little on 6/1/2023.
//

import SwiftUI

struct PresetFontsScene: View {
    private let viewModel = ViewModel()

    var body: some View {
        NavigationView {
            Form {
                Section {
                    ExplanationView(
                        systemImage: "textformat",
                        description: "从预设字体中进行选择。",
                        canShowProgress: true
                    )
                }
                .listRowBackground(Color(UIColor(red: 0.44, green: 0.69, blue: 0.67, alpha: 1.00)))
                fontsSection
                actionSection
            }
            .navigationTitle("Presets")
        }
        .navigationViewStyle(.stack)
    }
}

private extension PresetFontsScene {
    var fontsSection: some View {
        Section {
            ForEach(viewModel.fonts, id: \.name) { font in
                Button {
                    Task {
                        await MainActor.run {
                            ProgressManager.shared.message = "运行中"
                        }
                        await overwriteWithFont(name: font.repackedPath)
                    }
                } label: {
                    Text(font.name)
                        .font(.custom(
                            font.postScriptName,
                            size: 18)
                        )
                }
            }
        } header: {
            Text("字体")
        }
    }
    
    private var actionSection: some View {
        Section {
            RespringButton()
        } header: {
            Text("开始")
        } footer: {
            Text("最初创建者 [@zhuowei](https://twitter.com/zhuowei). 更新和维护者 [@GinsuDev](https://twitter.com/GinsuDev).汉化[@SuenLohKuan](https://twitter.com/SuenLohKuan).")
        }
    }
}

struct PresetsScene_Previews: PreviewProvider {
    static var previews: some View {
        PresetFontsScene()
    }
}
