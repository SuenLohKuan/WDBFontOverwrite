//
//  FileEditorView.swift
//  WDBFontOverwrite
//
//  Created by Noah Little on 4/1/2023.
//

import SwiftUI

struct FileEditorView: View {
    @StateObject private var viewModel = ViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.files, id: \.self) { file in
                HStack {
                    Text(file)
                    Spacer()
                    Button {
                        viewModel.remove(file: file)
                        Task {
                            await viewModel.populateFiles()
                        }
                    } label: {
                        Image(systemName: "清空")
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.isVisibleRemoveAllAlert = true
                    } label: {
                        Image(systemName: "清空")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("导入的字体 (\(viewModel.files.count))")
        }
        .alert(isPresented: $viewModel.isVisibleRemoveAllAlert) {
            Alert(
                title: Text("全部删除"),
                message: Text("您确定要移除所有导入的字体文件吗？"),
                primaryButton: .destructive(Text("全部删除")) {
                    viewModel.removeAllFiles()
                    Task {
                        await viewModel.populateFiles()
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            Task {
                await viewModel.populateFiles()
            }
        }
    }
}

struct FileEditorView_Previews: PreviewProvider {
    static var previews: some View {
        FileEditorView()
    }
}
