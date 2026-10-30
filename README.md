# TypeIt(贴贴)

把**剪贴板里的文字,模拟成键盘逐字敲进当前焦点输入框**的 macOS 小工具。

适用于那些屏蔽了 ⌘V 粘贴、只认"真实键盘输入"的输入框(网页表单、考试系统、部分聊天客户端等)。

包含三个组件:

| 文件 | 说明 |
|---|---|
| `typeit.c` | 命令行版:`pbpaste \| ./typeit [每字符ms] [倒计时秒]`,倒计时内切到目标输入框即可 |
| `typeitd.swift` | 常驻守护进程版:后台运行,按 `⌃⌥V` 把剪贴板逐字敲进焦点输入框 |
| `typeitapp.swift` | 菜单栏 App 版:图标常驻菜单栏,支持暂停快捷键、立即输入、三档速度(3/15/40 ms 每字符) |

## 编译

```sh
# 命令行版
cc -O2 -framework CoreGraphics -framework CoreFoundation typeit.c -o typeit

# 守护进程版 / 菜单栏版
swiftc -O typeitd.swift -o typeitd
swiftc -O typeitapp.swift -o typeitapp
```

## 使用

1. 编译并运行对应程序。
2. **系统设置 → 隐私与安全性 → 辅助功能**,给运行它的程序(终端 App 或 `typeitapp`)勾选权限,否则无法注入键盘事件。
3. 复制文字到剪贴板,切到目标输入框,触发即可(`pbpaste | ./typeit` / `⌃⌥V` / 菜单栏"立即输入")。

## 说明

- 换行符会转成回车键,目标框里会真正换行。
- emoji 等代理对字符按整字发送,不会拆坏。
- 菜单栏版会等你松开 Ctrl/Option 再开始打字,避免开头字符被修饰键吃掉。

## 许可

MIT
