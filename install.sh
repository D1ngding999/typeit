#!/usr/bin/env bash
# TypeIt 一行安装:
#   curl -fsSL https://raw.githubusercontent.com/D1ngding999/typeit/main/install.sh | bash
set -euo pipefail

REPO="D1ngding999/typeit"
ASSET="typeit-macos-universal.zip"
DEST="${TYPEIT_HOME:-$HOME/.local/bin}"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "TypeIt 仅支持 macOS" >&2; exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo ">> 下载最新版二进制(arm64 + Intel 通用)…"
curl -fsSL "https://github.com/$REPO/releases/latest/download/$ASSET" -o "$TMP/pkg.zip"

echo ">> 安装到 $DEST …"
mkdir -p "$DEST"
unzip -oq "$TMP/pkg.zip" -d "$DEST"
chmod +x "$DEST/typeit" "$DEST/typeitd" "$DEST/typeitapp"
xattr -d com.apple.quarantine "$DEST/typeit" "$DEST/typeitd" "$DEST/typeitapp" 2>/dev/null || true

cat <<EOF

✅ 安装完成:
  $DEST/typeit      命令行版:pbpaste | typeit [每字符ms] [倒计时秒]
  $DEST/typeitd     快捷键守护:启动后按 ⌃⌥V 输入剪贴板
  $DEST/typeitapp   菜单栏 App:键盘图标常驻,可选速度

EOF

if [[ ":$PATH:" != *":$DEST:"* ]]; then
  cat <<EOF
⚠️  $DEST 不在 PATH 里,加一下(用 zsh 的话):
    echo 'export PATH="\$HOME/.local/bin:\$PATH"' >> ~/.zshrc && source ~/.zshrc

EOF
fi

echo "📌 首次使用:系统设置 → 隐私与安全性 → 辅助功能,勾选运行它的终端 App(或 typeitapp),否则无法注入键盘事件。"
