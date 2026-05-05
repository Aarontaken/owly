# Owly 🌙

> Tiny menu-bar app for macOS that keeps your Mac awake while letting the screen sleep.
>
> 一个极简的 macOS 菜单栏防睡眠工具：屏幕该熄熄、CPU 该跑跑、合盖也能不睡。

[![Platform](https://img.shields.io/badge/platform-macOS%2012%2B-blue)](https://www.apple.com/macos/)
[![Language](https://img.shields.io/badge/Swift-5-orange)](https://www.swift.org/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Release](https://img.shields.io/github/v/release/Aarontaken/owly)](https://github.com/Aarontaken/owly/releases)

---

## ✨ 它能做什么

跑长时间任务（编译、AI agent、下载、训练）时不希望 Mac 自动睡眠中断任务，但又不想屏幕一直亮着耗电？Owly 就是为这个场景做的。

**三档单选**，住在菜单栏里点一下切：

| 模式            | 屏幕自动熄 | 系统空闲睡 | 合盖睡 | 适用场景                                     |
| --------------- | ---------- | ---------- | ------ | -------------------------------------------- |
| 🌙 关闭         | 熄         | 睡         | 睡     | 默认状态                                     |
| ☕ 熄屏不睡     | **熄**     | **不睡**   | 睡     | 跑长任务，屏幕该熄省电、CPU 继续干活        |
| ⚡ 强力模式     | 熄         | 不睡       | **不睡** | 合盖塞包带去会议室，任务还在跑              |

**关键概念**：屏幕熄灭 ≠ 系统睡眠。屏幕熄了 CPU 还在跑、任务还继续；只有系统睡眠才会冻结进程。

## 🎯 为什么选 Owly

**比 `caffeinate -i` 命令好用**：菜单栏可视化状态、永久持有断电不掉、可视化诊断。

**比 Amphetamine 简单**：三档够用、没有触发器/定时/会话这些复杂概念、~200KB 单二进制。

**比商业工具便宜透明**：免费、开源、~700 行 Swift 全在这里、`pmset` 授权严格限定为两条精确命令。

## 📦 安装

### 方式 A：下载现成的（推荐）

1. 去 [Releases](https://github.com/Aarontaken/owly/releases) 下载最新的 `Owly-vX.X.X.zip`
2. 解压，把 **Owly.app** 拖到「应用程序」文件夹
3. **第一次启动**：右键 Owly.app → 选「打开」→ 弹窗里再点「打开」（绕过 Gatekeeper 的一次性确认）
4. 菜单栏出现月亮图标，点开就能用

> ⚠️ **关于 Gatekeeper**：本项目用 ad-hoc 签名（没付 $99/年的 Apple 开发者证书），所以首次打开会被系统提示"无法验证开发者"。这是 ad-hoc 签名应用的正常行为；你可以审计本仓库源码（~700 行 Swift）确认安全性后再打开。

### 方式 B：从源码编译

需要 macOS 12+ 和 Xcode Command Line Tools（`xcode-select --install`）。**不需要 Xcode 完整版**，用系统自带的 `swiftc` 即可。

```bash
git clone https://github.com/Aarontaken/owly.git
cd owly
./scripts/build.sh      # swiftc 编译 + 打包成 .app
./scripts/install.sh    # 复制到 /Applications + 注册 LaunchAgent
```

## 🚀 使用

启动后菜单栏会出现一个图标，点开是这样：

```
当前：关闭
────────
✓ 关闭                          ⌘0
  熄屏不睡（屏幕照常熄）         ⌘1
  强力模式（合盖也不睡）         ⌘2
────────
✓ 开机自启                      ← 点击切换，无需密码
撤销强力模式授权…               ← 仅在已授权时显示
关于 / 状态详情…
诊断信息…
────────
退出                            ⌘Q
```

**「强力模式」第一次点会弹 macOS 原生管理员授权对话框**，输一次密码后永久免密。授权范围**严格限制**为以下两条精确命令：

```
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -a disablesleep 1
```

不会获得其他任何 root 权限。可在仓库 [`resources/sudoers.template`](resources/sudoers.template) 看到完整模板。

## 🧠 实现原理

| 模式       | 底层机制                                                        |
| ---------- | --------------------------------------------------------------- |
| 熄屏不睡   | IOKit `IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleSystemSleep)` —— 等价于 `caffeinate -i`，进程绑定，进程退出 assertion 自动释放 |
| 强力模式   | `pmset -a disablesleep 1`，系统级 `SleepDisabled` 硬开关，需要 root 权限。Owly 通过预装 sudoers 规则换取菜单栏免密切换 |

合盖睡眠走的是 macOS 内核级路径，普通 `caffeinate` / IOKit assertion **顶不住**，只能靠 `pmset disablesleep`。

App 退出时会自动复位 `disablesleep=0`，并在每次启动时检测崩溃残留状态，避免遗留。

## 🛡️ 安全性

- **只读 ~700 行 Swift 单文件**：[`src/main.swift`](src/main.swift)
- **ad-hoc 代码签名**：`codesign --force --sign -`，可以本地验证
- **sudoers 授权范围最小化**：只两条精确命令，不允许通配符 / 其他 pmset 子命令 / 其他二进制
- **进程退出自动清理**：IOKit assertion 随进程释放、`disablesleep` 在 `applicationWillTerminate` 复位
- **崩溃容错**：App 启动时如果发现 `SleepDisabled=1` 但当前不在强力模式，会主动复位
- **无网络访问**：可以放心断网用，无任何遥测

如果你不放心 sudoers，可以选择不启用强力模式 —— 「熄屏不睡」完全不需要任何权限。

## 🛠️ 项目结构

```
owly/
├── README.md                    
├── LICENSE                       # MIT
├── src/main.swift                # 整个 App（菜单栏 + IOKit + SwiftUI 弹窗 + sudoers 管理）
├── resources/
│   ├── Info.plist
│   └── sudoers.template          # __USER__ 占位符的 sudoers 模板
├── scripts/
│   ├── build.sh                  # swiftc 编译 + 打包 .app
│   ├── install.sh                # 复制到 /Applications + LaunchAgent
│   ├── uninstall.sh              # 完全卸载 + 复位
│   ├── enable-lid-lock.sh        # 命令行启用强力模式（菜单栏的 GUI 替代）
│   ├── disable-lid-lock.sh       # 命令行撤销强力模式授权
│   ├── distribute.sh             # 打 dist/Owly-vX.X.X.zip 分发包
│   └── generate-icon.swift       # 用 SF Symbol 渲染 AppIcon.icns
└── build/                        # 编译产物（gitignore）
```

## 🤝 给同事分发

如果你想自己改名/打包发给同事：

```bash
./scripts/distribute.sh 1.1.3   # 在 dist/ 下生成 Owly-v1.1.3.zip（不传参时默认即此版本）
```

zip 内含 `Owly.app` + 一份给同事的中文 README。同事拿到只需：解压 → 拖到「应用程序」 → 右键打开。

## 🐛 诊断

菜单 →「诊断信息…」一目了然显示：
- 当前模式（内存状态）
- IOKit assertion 是否激活
- `pmset disablesleep` 当前值
- 强力模式 sudoers 是否生效（带具体的 stderr 报错文本）
- 进程 PID 和 bundle 路径

如果遇到问题，截图这个窗口提 issue 就好。

## 📜 License

[MIT](LICENSE) — 拿去随便用、改、商用、分发。如果觉得有用，给个 star ⭐ 就好。

## 🙏 致谢

灵感来自 macOS 自带的 `caffeinate` 命令、[Amphetamine](https://apps.apple.com/app/amphetamine/id937984704)、[KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake)。Owly 的差异点是更轻量、更聚焦"屏幕睡 / 系统不睡"这一个最常用的场景。
