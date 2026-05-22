# 灵镜 (WebWrap)

> 把任意网页打包成独立的 macOS 原生 App —— 极致轻量、性能优先、零 Electron 依赖。

![platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![swift](https://img.shields.io/badge/swift-5.9%2B-orange)
![size](https://img.shields.io/badge/runtime-%E2%89%88138KB-brightgreen)
![license](https://img.shields.io/badge/license-MIT-lightgrey)

灵镜让你在几秒内把 ChatGPT、Linear、Notion、Pinterest 这类网站变成 macOS 上独立的 `.app`：有自己的 Dock 图标、独立的窗口、独立的登录态，可以单独 Cmd+Tab 切换。

---

## ✨ 特性

- 🪶 **极致轻量** —— 单个 wrapper 仅 **~170 KB**（含 runtime），冷启动 **< 250ms**
- 🍎 **macOS 原生** —— 纯 Swift + AppKit + WKWebView，**不含 Electron / Chromium**，跟随系统 Safari 引擎自动升级
- 🔒 **登录态隔离** —— 每个 wrapper 独立 cookie/storage，天然支持多账号（同一个网站可以生成两个 wrapper 用不同账号）
- 🎨 **智能图标** —— 自动抓取站点 `apple-touch-icon` / favicon / manifest，套用 macOS Squircle 风格生成 `.icns`；也可手动拖入自定义图
- 🌐 **地址栏可读** —— 顶部居中显示页面标题，点击切换为 URL 全文可复制
- 🚀 **静默自升级** —— Runtime 升级后所有已生成的 wrapper 启动时自动同步，**登录态保留**
- 🌏 **中 / 英 双语界面** —— 默认跟随系统，可在偏好设置切换
- 📦 **独立可分发** —— 生成的 wrapper 不依赖灵镜本身存在，可单独拷给别人用

---

## 📸 截图

> _截图待补：Generator 三栏布局、Wrapper 顶部地址栏、偏好设置语言切换_

---

## 🆚 为什么不用 WebCatalog / Coherence / Tauri？

| | **灵镜** | Electron 类（WebCatalog 等） |
|---|---|---|
| 单 wrapper 体积 | **~170 KB** | 150+ MB |
| 冷启动 | **< 250 ms** | 1–3 s |
| 内存常驻 | ~100 MB | 300+ MB |
| 浏览器引擎 | 系统 WebKit（随 macOS 安全更新） | 内嵌 Chromium（需各 App 自己升级） |
| 价格 | 免费、开源 | 多数收费 |
| 平台 | macOS Only | 跨平台 |

只做 macOS、只用系统能力，所以才能做到这个体积和启动速度。

---

## 📥 安装

需要 macOS 13+ 和 Xcode 命令行工具：

```bash
xcode-select --install   # 如果还没装
git clone https://github.com/<your-name>/webwrap.git
cd webwrap
make install
```

`make install` 会：
1. Release 模式编译（约 5 秒）
2. 打包成 `灵镜.app`
3. 安装到 `~/Applications/灵镜.app`
4. 刷新 LaunchServices 并自动启动

> 首次双击 灵镜本身或新生成的 wrapper 时，macOS Gatekeeper 可能拦截（因为是 ad-hoc 本地签名）。在 Finder **右键 → 打开** → 弹窗点 **打开** 即可，每个 App 只需一次。

---

## 🚀 使用

1. 启动**灵镜** → 窗口右上角点 **+ 新建**
2. 输入名称（如 `ChatGPT`）和网址（如 `https://chat.openai.com`）
3. 图标默认从网站自动抓取；也可点 **选择…** 拖入自己的 PNG/JPG/ICNS
4. 点 **创建** → 1–3 秒后 wrapper 出现在 `~/Applications/`、Launchpad、Spotlight
5. 双击运行：独立窗口、独立登录、独立 Dock 图标

### Wrapper 顶部工具栏

```
● ● ●  [ < | > ]      [    页面标题（点击可看 URL）    ]      ↻  │  🧭
       后退 / 前进                                            刷新   在浏览器打开
```

| 操作 | 快捷键 |
|---|---|
| 后退 | ⌘[ |
| 前进 | ⌘] |
| 刷新 | ⌘R |
| 在默认浏览器打开当前页 | ⇧⌘O |
| 关窗 | ⌘W |
| 退出 | ⌘Q |

---

## 🏗 架构

```
┌──────────────────────┐         ┌───────────────────────────────────┐
│   灵镜 (Generator)   │         │       生成的 Wrapper.app          │
│   SwiftUI 三栏 GUI   │         │                                   │
│                      │         │  Contents/                        │
│  ├─ AppBuilder       │  生成   │  ├─ MacOS/WebWrapRuntime (~140KB) │
│  ├─ IconFetcher      │ ──────▶ │  ├─ Resources/                    │
│  ├─ IconRenderer     │         │  │  ├─ AppIcon.icns               │
│  ├─ BundleWriter     │         │  │  └─ config.json                │
│  └─ Codesigner       │         │  └─ Info.plist                    │
└──────────────────────┘         └───────────────────────────────────┘
                                       ↓ 启动时
                              ┌────────────────────────────┐
                              │  AppKit + WKWebView 窗口   │
                              │  独立 WKWebsiteDataStore   │
                              │  （按 bundle id 自动隔离）  │
                              └────────────────────────────┘
```

**两个 SwiftPM target，共享一套代码：**

| Target | 产物 | 角色 |
|---|---|---|
| `WebWrap` | `灵镜.app` (SwiftUI GUI) | 生成器；管理 wrappers 列表；调用核心模块组装新 app |
| `WebWrapRuntime` | 单可执行二进制 (~138KB) | 复制进每个生成的 wrapper；启动时读 `config.json` 加载对应站点 |

---

## ⚡ 性能实测（M1，macOS 14）

| 指标 | 目标 | 实测 |
|---|---|---|
| Runtime release 二进制 | ≤ 2.5 MB | **138 KB** ✅ |
| 单 wrapper bundle 体积 | ≤ 3 MB | **168 KB** ✅ |
| Wrapper 冷启动到首帧 | ≤ 250 ms | **< 250 ms** ✅ |
| Wrapper 运行时内存 | ≤ 150 MB | **~100 MB** ✅ |
| Generator 启动 | ≤ 500 ms | **< 500 ms** ✅ |
| 单元测试 | 全绿 | **18/18 ✅** |

---

## 🛠 开发

```bash
make build            # swift build (debug)
make test             # swift test
make bundle           # debug 打包到 build/灵镜.app
make bundle-release   # release 打包
make install          # release 打包 + 安装到 ~/Applications + 刷新 LaunchServices
make patch-wrappers   # 把所有已生成的 wrapper 内的 runtime 升级到当前编译版本
make clean
```

### 项目结构

```
.
├── Package.swift
├── Makefile
├── Scripts/bundle-webwrap.sh
├── Sources/
│   ├── WebWrap/                         # Generator
│   │   ├── WebWrapApp.swift             # @main
│   │   ├── AppState.swift
│   │   ├── Localization.swift
│   │   ├── Core/
│   │   │   ├── GeneratorConfig.swift
│   │   │   ├── BundleWriter.swift
│   │   │   ├── Codesigner.swift
│   │   │   ├── AppBuilder.swift
│   │   │   ├── IconFetcher.swift
│   │   │   └── IconRenderer.swift
│   │   └── Views/
│   │       ├── SidebarView.swift
│   │       ├── DetailView.swift
│   │       ├── CreateSheet.swift
│   │       └── PreferencesSheet.swift
│   └── WebWrapRuntime/                  # 每个 wrapper 里跑的二进制
│       ├── main.swift
│       ├── AppDelegate.swift
│       ├── BrowserWindow.swift
│       ├── AddressBar.swift
│       ├── MenuBar.swift
│       ├── WebViewDelegate.swift
│       └── Config.swift
├── Tests/WebWrapTests/                  # 18 个单元测试
└── docs/superpowers/
    ├── specs/2026-05-22-web2app-design.md
    └── plans/2026-05-22-web2app.md
```

### 技术栈

- **Swift 5.9+** / SwiftPM
- **AppKit + WKWebView**（runtime；不用 SwiftUI 是为了极致冷启动）
- **SwiftUI**（generator GUI）
- **Core Image** + `sips` + `iconutil`（图标管线）
- **CryptoKit**（runtime 升级时 SHA-256 比对）
- **SwiftSoup**（仅 generator，用于解析 HTML 提取 icon link）
- **macOS 13+**（Ventura）

---

## ❓ FAQ

**Q: 升级灵镜，已生成的 App 会丢吗？**
不会。灵镜自身无状态，所有 wrapper 真相在 `~/Applications/*.app/Contents/Resources/config.json`。升级灵镜只替换 `~/Applications/灵镜.app`，其他 wrapper 原地不动。

**Q: 升级灵镜后，已生成 wrapper 里的 runtime 会跟着升级吗？**
会，**自动且静默**。灵镜启动时通过 SHA-256 对比每个 wrapper 内嵌的 runtime 与当前 runtime，不同则后台替换 + 重新签名，登录态保留。

**Q: 同一个网站可以生成多个 wrapper 吗（多账号）？**
可以，**只要名字不同**。例如生成 `Gmail-Work` 和 `Gmail-Personal`，bundle id 不同 → WebKit 数据完全隔离 → 两边可以同时登录不同账号。

**Q: 删除某个 wrapper 后登录态会清掉吗？**
**不会**。WebKit 数据存在 `~/Library/WebKit/<bundle-id>/` 和 `~/Library/Cookies/<bundle-id>.binarycookies`，删除 .app 不会动这些目录。重新创建同名 wrapper（同 bundle id）登录态会恢复。如要彻底清掉，手动删除上述目录。

**Q: 能用 Developer ID 签名给别人分发吗？**
当前只支持 ad-hoc 本地签名（自用足够）。如要分发，在 `Scripts/bundle-webwrap.sh` 和 `Sources/WebWrap/Core/Codesigner.swift` 里把 `--sign -` 改成你的 Developer ID 即可，配合 `notarytool` 上 notarize。

**Q: 支持 Windows / Linux 吗？**
不支持也不计划支持，这是个**只做 macOS 一件事**的工具。

---

## 📝 License

MIT — 用法不限，包括商用、二次分发、改造。

---

## 🙏 致谢

灵感来自 [WebCatalog](https://webcatalog.io)，但用纯 macOS 原生栈重做，体积和启动速度大幅优于 Electron 方案。

设计文档与实现计划完整保留在 [`docs/superpowers/`](docs/superpowers/)。
