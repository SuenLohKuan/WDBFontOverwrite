//
//  OverwriteFontImpl.swift
//  WDBFontOverwrite
//
//  Created by Zhuowei Zhang on 2022-12-25.
//

import UIKit
import UniformTypeIdentifiers

func overwriteWithFont(name: String) async {
    let fontURL = Bundle.main.url(
        forResource: name,
        withExtension: nil,
        subdirectory: "RepackedFonts"
    )!
    
    await overwriteWithFont(
        fontURL: fontURL,
        pathToTargetFont: "/System/Library/Fonts/CoreUI/SFUI.ttf"
    )
}

func overwriteWithFont(
    fontURL: URL,
    pathToTargetFont: String
) async {
    let succeeded = overwriteWithFontImpl(
        fontURL: fontURL,
        pathToTargetFont: pathToTargetFont
    )
    
    await MainActor.run {
        ProgressManager.shared.message = succeeded ? "成功:强制关闭应用程序以查看结果" : "失败"
    }
}

/// Overwrite the system font with the given font using CVE-2022-46689.
/// The font must be specially prepared so that it skips past the last byte in every 16KB page.
/// See BrotliPadding.swift for an implementation that adds this padding to WOFF2 fonts.
func overwriteWithFontImpl(
    fontURL: URL,
    pathToTargetFont: String
) -> Bool {
    var fontData: Data = try! Data(contentsOf: fontURL)
#if false
    let documentDirectory = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    )[0].path
    
    let pathToTargetFont = documentDirectory + "/SFUI.ttf"
    let pathToRealTargetFont = "/System/Library/Fonts/CoreUI/SFUI.ttf"
    let origData = try! Data(contentsOf: URL(fileURLWithPath: pathToRealTargetFont))
    try! origData.write(to: URL(fileURLWithPath: pathToTargetFont))
#endif
    
    // open and map original font
    let fd = open(pathToTargetFont, O_RDONLY | O_CLOEXEC)
    if fd == -1 {
        print("不能打开字体?!")
        return false
    }
    defer { close(fd) }
    // check size of font
    let originalFontSize = lseek(fd, 0, SEEK_END)
    guard originalFontSize >= fontData.count else {
        print("字体太大了!")
        return false
    }
    lseek(fd, 0, SEEK_SET)
    
    if fontData[0..<4] == Data([0x77, 0x4f, 0x46, 0x32]) {
        // if this is a woff2 (and not a ttc)
        // patch our font with the padding
        // https://www.w3.org/TR/WOFF2/#woff20Header
        // length
        withUnsafeBytes(of: UInt32(originalFontSize).bigEndian) {
            fontData.replaceSubrange(0x8..<0x8 + 4, with: $0)
        }
        // privOffset
        withUnsafeBytes(of: UInt32(fontData.count).bigEndian) {
            fontData.replaceSubrange(0x28..<0x28 + 4, with: $0)
        }
        // privLength
        withUnsafeBytes(of: UInt32(Int(originalFontSize) - fontData.count).bigEndian) {
            fontData.replaceSubrange(0x2c..<0x2c + 4, with: $0)
        }
    }
    
    // Map the font we want to overwrite so we can mlock it
    let fontMap = mmap(nil, fontData.count, PROT_READ, MAP_SHARED, fd, 0)
    if fontMap == MAP_FAILED {
        print("映射失败")
        return false
    }
    // mlock so the file gets cached in memory
    guard mlock(fontMap, fontData.count) == 0 else {
        print("不能锁定内存")
        return false
    }
    
    DispatchQueue.main.async {
        ProgressManager.shared.totalProgress = Double(fontData.count)
    }

    // for every 16k chunk, rewrite
    print(Date())
    for chunkOff in stride(from: 0, to: fontData.count, by: 0x4000) {
        print(String(format: "%lx", chunkOff))
        if chunkOff % 0x40000 == 0 {
            DispatchQueue.main.async {
                ProgressManager.shared.completedProgress = Double(chunkOff)
            }
        }
        // we only rewrite 16383 bytes out of every 16384 bytes.
        let dataChunk = fontData[chunkOff..<min(fontData.count, chunkOff + 0x3fff)]
        var overwroteOne = false
        for _ in 0..<2 {
            let overwriteSucceeded = dataChunk.withUnsafeBytes { dataChunkBytes in
                return unaligned_copy_switch_race(
                    fd, Int64(chunkOff), dataChunkBytes.baseAddress, dataChunkBytes.count)
            }
            if overwriteSucceeded {
                overwroteOne = true
                break
            }
            print("再试一次?!")
        }
        guard overwroteOne else {
            print("不能覆盖")
            return false
        }
    }
    DispatchQueue.main.async {
        ProgressManager.shared.completedProgress = Double(fontData.count)
    }
    print(Date())
    print("成功覆盖所有字体")
    return true
}

func dumpCurrentFont() {
    let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[
        0
    ].path
    let pathToTargetFont = documentDirectory + "/SFUI_dump.ttf"
    let pathToRealTargetFont = "/System/Library/Fonts/CoreUI/SFUI.ttf"
    let origData = try! Data(contentsOf: URL(fileURLWithPath: pathToRealTargetFont))
    try! origData.write(to: URL(fileURLWithPath: pathToTargetFont))
}

func overwriteWithCustomFont(
    name: String,
    targetPath: PathType?
) async {
    let documentDirectory = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    )[0]
    
    let fontURL = documentDirectory.appendingPathComponent(name)
    guard FileManager.default.fileExists(atPath: fontURL.path) else {
        await MainActor.run {
            ProgressManager.shared.message = "没有导入自定义字体"
        }
        return
    }
    
    switch targetPath {
    case .single(let path):
        await overwriteWithFont(
            fontURL: fontURL,
            pathToTargetFont: path
        )
    case .many(let paths):
        for path in paths {
            if (access(path, F_OK) == 0) {
                await overwriteWithFont(
                    fontURL: fontURL,
                    pathToTargetFont: path
                )
            }
        }
    default:
        await MainActor.run {
            ProgressManager.shared.message = "必须提供targetName或targetNames"
        }
    }
}

enum TTCRepackMode {
    case woff2
    case ttcpad
    case firstFontOnly
}

func importCustomFontImpl(
    fileURL: URL,
    targetURL: URL,
    ttcRepackMode: TTCRepackMode = .woff2
) async -> String? {
    // read first 16k of font
    let fileHandle = try! FileHandle(forReadingFrom: fileURL)
    defer { fileHandle.closeFile() }
    let first16k = try! fileHandle.read(upToCount: 0x4000)!
    if first16k.count == 0x4000 && first16k[0..<4] == Data([0x77, 0x4f, 0x46, 0x32])
        && first16k[0x3fff] == 0x41
    {
        print("已填充 WOFF2")
        try? FileManager.default.removeItem(at: targetURL)
        try! FileManager.default.copyItem(at: fileURL, to: targetURL)
        return nil
    }
    try! fileHandle.seek(toOffset: 0)
    let fileData = try! fileHandle.readToEnd()!
    var repackedData: Data? = nil
    if first16k.count >= 4 && first16k[0..<4] == Data([0x74, 0x74, 0x63, 0x66]) {
        // ttcf
        if ttcRepackMode == .woff2 {
            repackedData = repackTrueTypeFontAsPaddedWoff2(input: fileData)
        } else if ttcRepackMode == .ttcpad {
            repackedData = repack_ttc(
                fileData, /*delete_noncritical=*/ false, /*allow_corrupt_loca=*/ true)
        } else if ttcRepackMode == .firstFontOnly {
            let documentDirectory = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask)[0]
            let tempDirectoryURL = documentDirectory.appendingPathComponent("ttc_convert")
            try? FileManager.default.removeItem(at: tempDirectoryURL)
            try! FileManager.default.createDirectory(
                at: tempDirectoryURL, withIntermediateDirectories: false)
            let tempTTCURL = tempDirectoryURL.appendingPathComponent("font.ttc")
            try! FileManager.default.copyItem(at: fileURL, to: tempTTCURL)
            if stripttc_handlefile(tempTTCURL.path) == 0 {
                let ttfData = try! Data(contentsOf: tempDirectoryURL.appendingPathComponent("font_00.ttf"))
                try! FileManager.default.removeItem(at: tempDirectoryURL)
                repackedData = repackTrueTypeFontAsPaddedWoff2(input: ttfData)
            }
        }
    } else {
        repackedData = repackTrueTypeFontAsPaddedWoff2(input: fileData)
    }
    guard let repackedData = repackedData else {
        return "Failed to repack"
    }
    try! repackedData.write(to: targetURL)
    return nil
}

func repackTrueTypeFontAsPaddedWoff2(input: Data) -> Data? {
    var outputBuffer = [UInt8](repeating: 0, count: input.count + 1024)
    var outputLength = outputBuffer.count
    let woff2Result = outputBuffer.withUnsafeMutableBytes {
        WOFF2WrapperConvertTTFToWOFF2([UInt8](input), input.count, $0.baseAddress, &outputLength)
    }
    guard woff2Result else {
        print("woff2 转换失败")
        return nil
    }
    let woff2Data = Data(bytes: outputBuffer, count: outputLength)
    do {
        return try repackWoff2Font(input: woff2Data)
    } catch {
        print("错误: \(error).")
        return nil
    }
}

// Hack: fake Brotli compress method that just returns the original uncompressed data.'
// (We're recompressing it anyways in a second!)
@_cdecl("BrotliEncoderCompress")
func fakeBrotliEncoderCompress(
    quality: Int,
    lgwin: Int,
    mode: Int,
    inputSize: size_t,
    inputBuffer: UnsafePointer<UInt8>,
    encodedSize: UnsafeMutablePointer<size_t>,
    encodedBuffer: UnsafeMutablePointer<UInt8>
) -> Int {
    let encodedSizeIn = encodedSize.pointee
    if inputSize > encodedSizeIn {
        return 0
    }
    UnsafeBufferPointer(
        start: inputBuffer,
        count: inputSize).copyBytes(
            to: UnsafeMutableRawBufferPointer(
                start: encodedBuffer,
                count: encodedSizeIn
            )
        )
    encodedSize[0] = inputSize
    return 1
}
