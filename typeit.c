// typeit — 把 stdin 的文字模拟键盘敲进当前焦点窗口
// 用法:  pbpaste | ./typeit [每字符延迟ms] [倒计时秒]
// 需要给"运行它的终端 App"授予 系统设置→隐私与安全性→辅助功能 权限
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void post_string(const UniChar *s, CFIndex len) {
    CGEventRef down = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)0, true);
    CGEventRef up   = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)0, false);
    CGEventKeyboardSetUnicodeString(down, (unsigned int)len, s);
    CGEventKeyboardSetUnicodeString(up,   (unsigned int)len, s);
    CGEventPost(kCGHIDEventTap, down);
    CGEventPost(kCGHIDEventTap, up);
    CFRelease(down);
    CFRelease(up);
}

int main(int argc, char **argv) {
    long delay_us = argc > 1 ? atol(argv[1]) * 1000 : 3000;  /* 默认 3ms/字符 */
    int countdown = argc > 2 ? atoi(argv[2]) : 3;
    if (delay_us < 0) delay_us = 0;

    /* 读全部 stdin */
    size_t cap = 65536, len = 0;
    char *buf = malloc(cap);
    size_t n;
    while ((n = fread(buf + len, 1, cap - len, stdin)) > 0) {
        len += n;
        if (len == cap) { cap *= 2; buf = realloc(buf, cap); }
    }

    CFStringRef str = CFStringCreateWithBytes(NULL, (const UInt8 *)buf, (CFIndex)len,
                                              kCFStringEncodingUTF8, false);
    if (!str) { fprintf(stderr, "输入不是 UTF-8 文本\n"); return 1; }

    CFIndex units = CFStringGetLength(str);      /* UTF-16 单元数 */
    UniChar *u = malloc((units + 1) * sizeof(UniChar));
    CFStringGetCharacters(str, CFRangeMake(0, units), u);

    fprintf(stderr, "%d 秒后开始输入 %ld 个字符(每字符约 %ld ms),请切到目标输入框...\n",
            countdown, (long)units, delay_us / 1000);
    for (int i = countdown; i > 0; i--) { fprintf(stderr, "  %d\n", i); sleep(1); }

    /* 逐个字符发,代理对(emoji 等)合成一个事件发 */
    for (CFIndex i = 0; i < units; ) {
        UniChar c = u[i];
        CFIndex chunk = 1;
        if (c >= 0xD800 && c <= 0xDBFF && i + 1 < units &&
            u[i + 1] >= 0xDC00 && u[i + 1] <= 0xDFFF) { chunk = 2; i++; }
        /* 换行转成回车键,让目标框换行 */
        if (u[i] == '\n') {
            CGEventRef kd = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)36, true);
            CGEventRef ku = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)36, false);
            CGEventPost(kCGHIDEventTap, kd); CGEventPost(kCGHIDEventTap, ku);
            CFRelease(kd); CFRelease(ku);
        } else {
            post_string(&u[i], chunk);
        }
        i++;
        if (delay_us) usleep((useconds_t)delay_us);
    }
    fprintf(stderr, "完成。\n");
    return 0;
}
