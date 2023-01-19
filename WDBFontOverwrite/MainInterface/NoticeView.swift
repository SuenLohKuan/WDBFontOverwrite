//
//  NoticeView.swift
//  WDBFontOverwrite
//
//  Created by Noah Little on 3/1/2023.
//

import SwiftUI

enum Notice: String {
    /// iOS not supported msg.
    case iosVersion = "不支持的iOS版本。不要要求我们支持新版本，因为所使用的漏洞根本不支持新的iOS版本"
    
    /// Custom font pre-usage info.
    case beforeUse = "自定字体需要为iOS移植的字体文件。详情见 https://github.com/ginsudev/WDBFontOverwrite for details."
    
    /// Keyboard cache issue msg.
    case keyboard = "由于iOS缓存问题，键盘字体可能不会立即应用。如果可能，删除该文件夹 /var/mobile/Library/Caches/com.apple.keyboards/ if you wish for changes to take effect immediately."
}

struct NoticeView: View {
    let notice: Notice
    
    var body: some View {
        HStack {
            Image(systemName: "info.circle")
            Text(LocalizedStringKey(notice.rawValue))
        }
    }
}

struct NoticeView_Previews: PreviewProvider {
    static var previews: some View {
        NoticeView(notice: .keyboard)
    }
}
