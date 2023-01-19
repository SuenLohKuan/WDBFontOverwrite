//
//  CustomFontsScene.swift
//  WDBFontOverwrite
//
//  Created by Noah Little on 6/1/2023.
//

import SwiftUI
import UniformTypeIdentifiers

struct CustomFontsScene: View {
    @StateObject private var viewModel = ViewModel()
    @EnvironmentObject var progressManager: ProgressManager
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                Form {
                    Section {
                        ExplanationView(
                            systemImage: "textformat",
                            description: "导入和管理已移植到iOS的自定义字体。",
                            canShowProgress: true
                        )
                    }
                    .listRowBackground(Color(UIColor(red: 0.44, green: 0.69, blue: 0.67, alpha: 1.00)))
                    fontsList
                    actionSection
                }
            }
            .navigationTitle("Custom")
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $viewModel.importPresented) {
            DocumentPicker(
                importType: viewModel.selectedCustomFontType,
                ttcRepackMode: viewModel.importTTCRepackMode
            )
        }
        .sheet(isPresented: $viewModel.isPresentedFileEditor) {
            FileEditorView()
        }
        .onAppear {
            Task(priority: .background) {
                do {
                    try await FontMap.populateFontMap()
                } catch {
                    progressManager.message = "错误:无法填充字体映射。"
                }
            }
        }
    }
    
    @ViewBuilder
    private var fontsList: some View {
        Section {
            Picker("Custom fonts", selection: $viewModel.customFontPickerSelection) {
                Text("自定义字体")
                    .tag(0)
                Text("自定义Emoji表情")
                    .tag(1)
            }
            .pickerStyle(.segmented)
            
            Button {
                progressManager.message = "导入中..."
                viewModel.importTTCRepackMode = .woff2
                viewModel.importPresented = true
            } label: {
                AlignedRowContentView(
                    imageName: "square.and.arrow.down",
                    text: "导入自定义 \(viewModel.selectedCustomFontType.rawValue)"
                )
            }
            if viewModel.selectedCustomFontType == .font {
                Button {
                    progressManager.message = "导入中..."
                    viewModel.importTTCRepackMode = .ttcpad
                    viewModel.importPresented = true
                } label: {
                    AlignedRowContentView(
                        imageName: "square.and.arrow.down",
                        text: "导入自定义 \(viewModel.selectedCustomFontType.rawValue) with fix for .ttc"
                    )
                }
            }
            Button {
                progressManager.isBusy = true
                progressManager.message = "运行中"
                Task {
                    await viewModel.batchOverwriteFonts()
                }
            } label: {
                AlignedRowContentView(
                    imageName: "checkmark.circle",
                    text: "应用 \(viewModel.selectedCustomFontType.rawValue)"
                )
            }
        } header: {
            Text("字体")
        }
    }
    
    private var actionSection: some View {
        Section {
            Button {
                viewModel.isPresentedFileEditor = true
            } label: {
                AlignedRowContentView(
                    imageName: "doc.badge.gearshape",
                    text: "管理导入的字体"
                )
            }
            RespringButton()
        } header: {
            Text("开始")
        } footer: {
            Text("最初创建者 [@zhuowei](https://twitter.com/zhuowei). 更新和维护者 [@GinsuDev](https://twitter.com/GinsuDev).汉化[@SuenLohKuan](https://twitter.com/SuenLohKuan).")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        CustomFontsScene()
    }
}
