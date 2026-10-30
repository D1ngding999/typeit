// typeitd — 常驻快捷键守护:按下 ⌃⌥V 就把剪贴板文字逐字敲进当前焦点输入框
// 快捷键可在下面 HOTKEY_* 常量改
import AppKit
import Carbon
import CoreGraphics

let HOTKEY_MODS: UInt32 = UInt32(controlKey | optionKey)           // ⌃⌥
let HOTKEY_KEY:  UInt32 = UInt32(kVK_ANSI_V)                       // V
let CHAR_DELAY_US: UInt32 = 3000                                   // 每字符 3ms

func postText(_ s: [UniChar]) {
    guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
          let up   = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else { return }
    s.withUnsafeBufferPointer { p in
        if let base = p.baseAddress {
            down.keyboardSetUnicodeString(stringLength: p.count, unicodeString: base)
            up.keyboardSetUnicodeString(stringLength: p.count, unicodeString: base)
        }
    }
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
}

func postReturn() {
    guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true),
          let up   = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: false) else { return }
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
}

func typeClipboard() {
    DispatchQueue.global(qos: .userInitiated).async {
        usleep(80_000)  // 稍等,避免快捷键按键的尾音干扰
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            NSSound.beep(); return
        }
        let units = Array(text.utf16)
        var i = 0
        while i < units.count {
            let c = units[i]
            var len = 1
            if c >= 0xD800 && c <= 0xDBFF && i + 1 < units.count { len = 2 }  // emoji 代理对
            if c == 0x0A { postReturn() } else { postText(Array(units[i..<(i + len)])) }
            i += len
            usleep(CHAR_DELAY_US)
        }
    }
}

func hotkeyCb(_ call: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    typeClipboard()
    return noErr
}

let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
let trusted = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
FileHandle.standardError.write(Data("[typeitd] accessibility trusted = \(trusted)\n".utf8))

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                              eventKind: UInt32(kEventHotKeyPressed))
InstallEventHandler(GetApplicationEventTarget(), hotkeyCb, 1, &eventType, nil, nil)
var hotKeyRef: EventHotKeyRef?
let hkID = EventHotKeyID(signature: OSType(0x54595044), id: 1) // 'TYPD'
let st = RegisterEventHotKey(HOTKEY_KEY, HOTKEY_MODS, hkID, GetApplicationEventTarget(), 0, &hotKeyRef)
guard st == noErr else { fatalError("RegisterEventHotKey failed: \(st)") }

app.run()
