//
//  CustomFontsScene.ViewModel.swift
//  WDBFontOverwrite
//
//  Created by Noah Little (@ginsudev) on 3/1/2023.
//

import SwiftUI
import UniformTypeIdentifiers

class WDBImportCustomFontPickerViewControllerDelegate: NSObject, UIDocumentPickerDelegate {
    let importType: CustomFontType
    let ttcRepackMode: TTCRepackMode
    
    init(importType: CustomFontType, ttcRepackMode: TTCRepackMode) {
        self.importType = importType
        self.ttcRepackMode = ttcRepackMode
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        Task {
            await importSelectedFonts(atURLs: urls)
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        ProgressManager.shared.message = "取消"
    }
    
    private func importSelectedFonts(atURLs urls: [URL]) async {
        let documentDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        
        var successfullyImportedCount = 0
        
        // Import selected font files into the documents directory, one by one.
        for url in urls {
            if importType == .emoji {
                let emojiFont = FontMap.emojiCustomFont
                let targetURL = documentDirectory.appendingPathComponent(emojiFont.localPath)
                let success = await importFont(withFileURL: url, targetURL: targetURL)
                successfullyImportedCount += success
            } else {
                let key = FontMap.key(forFont: url.lastPathComponent)
                if let customFont = FontMap.fontMap[key] {
                    let targetURL = documentDirectory.appendingPathComponent(customFont.localPath)
                    let success = await importFont(withFileURL: url, targetURL: targetURL)
                    successfullyImportedCount += success
                }
            }
        }

        ProgressManager.shared.message = String(
            format: "成功导入 %d/%d 文件.%@",
            successfullyImportedCount,
            urls.count,
            successfullyImportedCount == urls.count ? "" : " 跳过了某些文件，因为您的设备没有这些字体，或者因为它们不支持您的iOS设备。"
        )
    }
    
    private func importFont(withFileURL fileURL: URL, targetURL: URL) async -> Int {
        let success = await importCustomFontImpl(
            fileURL: fileURL,
            targetURL: targetURL,
            ttcRepackMode: self.ttcRepackMode
        )
        if success == nil {
            return 1
        } else {
            return 0
        }
    }
}

// https://capps.tech/blog/read-files-with-documentpicker-in-swiftui
struct DocumentPicker: UIViewControllerRepresentable {
    var importType: CustomFontType
    var ttcRepackMode: TTCRepackMode
    
    func makeCoordinator() -> WDBImportCustomFontPickerViewControllerDelegate {
        return WDBImportCustomFontPickerViewControllerDelegate(
            importType: importType,
            ttcRepackMode: ttcRepackMode
        )
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<DocumentPicker>) -> UIDocumentPickerViewController {
        let pickerViewController = UIDocumentPickerViewController(
            forOpeningContentTypes: [
                UTType(
                    filenameExtension: "ttf",
                    conformingTo: .font
                )!,
                UTType(
                    filenameExtension: "ttc",
                    conformingTo: .font
                )!,
                UTType(
                    filenameExtension: "woff2",
                    conformingTo: .font
                )!,
            ],
            asCopy: true
        )
        
        pickerViewController.allowsMultipleSelection = importType == .font
        pickerViewController.delegate = context.coordinator
        return pickerViewController
    }
    
    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController,
        context: UIViewControllerRepresentableContext<DocumentPicker>
    ) {}
}
