# Mac lock

一键暂停 Mac 的键盘输入，清洁桌面时更省心。采用原生 SwiftUI Liquid Glass，提供中文界面、菜单栏开关和 Dock 图标。

## 下载

从 [GitHub Releases](https://github.com/yiz965689-max/Mac-lock/releases/latest) 下载 `Mac-lock-2.1.0-macOS.zip`。

**系统要求：macOS 26 或更高版本，Apple Silicon（M 系列芯片）。目前不提供 Intel 版本。**

## 安装与授权

1. 解压，将 `Mac lock.app` 拖到“应用程序”。
2. 打开应用。当前发行包为本地临时签名，未经 Apple 公证；若 macOS 阻止启动，只通过系统提供的“隐私与安全性 → 仍要打开”手动确认。不要关闭 Gatekeeper 或删除隔离属性。
3. 在“系统设置 → 隐私与安全性 → 辅助功能”和“输入监控”中，分别添加并开启 Mac lock。
4. 退出并重新打开应用。更新后如权限不识别，移除旧条目，再添加当前应用。

可使用 Release 中的 `SHA256SUMS.txt` 核对下载文件。

## 使用

- **仅锁键盘**：保留触控板操作。
- **全锁**：暂停键盘、指针、点击与滚动。没有倒计时；在两秒内独立按三次 **Esc** 恢复输入，长按不计作三次。
- 菜单栏开关：点一次锁定，再点一次解锁。绿色表示锁定，灰色表示解锁。
- 关闭主窗口后继续运行。点击 Dock 图标可重新打开；窗口右上角电源按钮、应用菜单或 Dock 右键菜单可以退出。
- 登录后自动启动可在界面中关闭。每次启动默认解锁、默认仅锁键盘。
- 睡眠、唤醒、切换用户会话、正常退出时主动解除锁定；系统停用事件拦截器时也会解除锁定。

**设备范围限制：当前使用会话级事件拦截，不能可靠区分内置与外接设备。外接键盘和鼠标也可能受到影响。**

应用不保存或上传按键内容，不包含联网、账户或遥测功能。输入权限由用户在 macOS 系统设置中手动授予。

## 构建

需要支持 macOS 26 SDK 的 Apple Command Line Tools 或 Xcode，无第三方包依赖：

```sh
./build.sh
```

脚本会输出生成的 `.app` 路径，并进行本地临时签名及签名验证。请以 `.app` 方式启动，不直接运行裸可执行文件。

验证 Esc 手势及事件范围逻辑：

```sh
swiftc -parse-as-library InputGate.swift Tests/InputGateChecks.swift -o /tmp/mac-lock-checks
/tmp/mac-lock-checks
```

## 验证范围

v2.1.0 已完成编译、签名验证、Esc 手势和事件范围逻辑测试，以及本机界面启动、退出和登录项注册检查。当前发行版本的物理键盘/触控板锁定恢复、不同硬件和重启登录行为尚未完成全面验证。首次使用请先测试仅锁键盘，并确认 Esc 恢复方式后再使用全锁。

## 实现说明

使用 Apple 的 SwiftUI、AppKit、CoreGraphics 和 ServiceManagement 原生框架。源码及图标在独立重写过程中生成，没有随此版本分发旧项目的源文件或素材。开发过程曾查看 KeepClean 的源码，不属于严格的净室开发；不作完全原创或商用无侵权保证。

- [CoreGraphics CGEvent](https://developer.apple.com/documentation/coregraphics/cgevent)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [SwiftUI Liquid Glass](https://developer.apple.com/documentation/swiftui/glasseffectcontainer)
