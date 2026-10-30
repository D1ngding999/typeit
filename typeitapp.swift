// TypeIt.app — 菜单栏小程序:开启后按 ⌃⌥V 把剪贴板文字逐字敲进当前焦点输入框
import AppKit
import Carbon
import CoreGraphics

let HOTKEY_MODS: UInt32 = UInt32(controlKey | optionKey)  // ⌃⌥
let HOTKEY_KEY:  UInt32 = UInt32(kVK_ANSI_V)
var charDelayUs: UInt32 = 15_000                         // 默认每字符 15ms

var hotkeyEnabled = true

/// 等 Ctrl/Option 物理松开再开始打字,否则开头几个字符会被修饰键吃掉
func waitModifiersReleased() {
    let keys: [CGKeyCode] = [58, 59, 61, 62]  // 左/右 Option,左/右 Control
    let deadline = Date().addingTimeInterval(1.2)
    while Date() < deadline {
        if !keys.contains(where: { CGEventSource.keyState(.combinedSessionState, key: $0) }) { break }
        usleep(30_000)
    }
    usleep(120_000)
}

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
        waitModifiersReleased()
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            NSSound.beep(); return
        }
        let units = Array(text.utf16)
        var i = 0
        while i < units.count {
            let c = units[i]
            var len = 1
            if c >= 0xD800 && c <= 0xDBFF && i + 1 < units.count { len = 2 }
            if c == 0x0A { postReturn() } else { postText(Array(units[i..<(i + len)])) }
            i += len
            usleep(charDelayUs)
        }
    }
}

func hotkeyCb(_ call: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    if hotkeyEnabled { typeClipboard() }
    return noErr
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var toggleItem: NSMenuItem!
    var speedItems: [NSMenuItem] = []
    var pollTimer: Timer?

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "keyboard",
                                           accessibilityDescription: "TypeIt")
        let menu = NSMenu()
        toggleItem = NSMenuItem(title: "暂停快捷键", action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        let now = NSMenuItem(title: "立即输入剪贴板", action: #selector(typeNow), keyEquivalent: "")
        now.target = self
        menu.addItem(now)
        let speedParent = NSMenuItem(title: "输入速度", action: nil, keyEquivalent: "")
        let speedMenu = NSMenu()
        for (title, us) in [("快(3ms/字)", 3_000), ("中(15ms/字)", 15_000), ("慢(40ms/字)", 40_000)] {
            let it = NSMenuItem(title: title, action: #selector(setSpeed(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = NSNumber(value: us)
            it.state = (UInt32(us) == charDelayUs) ? .on : .off
            speedItems.append(it)
            speedMenu.addItem(it)
        }
        speedParent.submenu = speedMenu
        menu.addItem(speedParent)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 TypeIt", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        refreshIcon()
        if !AXIsProcessTrusted() {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
            pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] t in
                if AXIsProcessTrusted() {
                    t.invalidate()
                    self?.refreshIcon()
                    NSSound.beep()  // 一声提示:已可用
                }
            }
        }
    }

    func refreshIcon() {
        let trusted = AXIsProcessTrusted()
        let name = trusted && hotkeyEnabled ? "keyboard" : (trusted ? "keyboard.badge.ellipsis" : "questionmark.circle")
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "TypeIt")
        toggleItem.title = hotkeyEnabled ? "暂停快捷键" : "启用快捷键"
        if !trusted { toggleItem.isEnabled = false }
    }

    @objc func toggle() { hotkeyEnabled.toggle(); refreshIcon() }
    @objc func typeNow() { typeClipboard() }
    @objc func setSpeed(_ sender: NSMenuItem) {
        guard let n = sender.representedObject as? NSNumber else { return }
        charDelayUs = UInt32(n.uint32Value)
        for it in speedItems { it.state = (it === sender) ? .on : .off }
    }
}

// 安装全局快捷键
var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                              eventKind: UInt32(kEventHotKeyPressed))
InstallEventHandler(GetApplicationEventTarget(), hotkeyCb, 1, &eventType, nil, nil)
var hotKeyRef: EventHotKeyRef?
let hkID = EventHotKeyID(signature: OSType(0x54595044), id: 1)
let st = RegisterEventHotKey(HOTKEY_KEY, HOTKEY_MODS, hkID, GetApplicationEventTarget(), 0, &hotKeyRef)
guard st == noErr else { fatalError("RegisterEventHotKey failed: \(st)") }

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
