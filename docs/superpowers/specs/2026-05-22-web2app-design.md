# Web2App — macOS 网页打包工具设计文档

**日期**: 2026-05-22
**目标平台**: macOS 13 Ventura+
**核心目标**: 将任意网页打包为独立的 macOS 原生 .app，性能最优，自用为主。

---

## 1. 范围（Scope）

实现"标准版"功能集：

- 选 URL + 图标 → 一键生成独立 .app
- 每个 wrapper 拥有独立 cookie/localStorage（账号隔离）
- 自定义 User-Agent
- Dock 角标（识别站点 title 中的未读数）
- 基础快捷键：前进 / 后退 / 刷新 / 关窗 / 退出
- 自动抓取站点图标 + 用户手动覆盖

**明确不做**：多账号 workspace、广告拦截、JS 注入、内置 catalog、Developer ID 签名/公证、Windows/Linux 版本。

---

## 2. 整体架构

两个 Xcode target，共享同一 codebase：

| Target | 产物 | 角色 |
|---|---|---|
| **WebWrap** (GUI) | `WebWrap.app` | 生成器；管理 wrappers；调用 `AppBuilder` 组装新 app |
| **WebWrapRuntime** | `WebWrapRuntime` 单可执行文件 (~1.5MB) | 复制进每个生成的 .app；启动时读 `Resources/config.json` 渲染对应网站 |

### 2.1 生成的 wrapper bundle 结构

```
MySite.app/Contents/
├── Info.plist            # CFBundleIdentifier=com.webwrap.<slug>, CFBundleName, ...
├── MacOS/
│   └── WebWrapRuntime    # 与所有其他 wrapper 完全相同的二进制
├── Resources/
│   ├── AppIcon.icns      # 由 IconRenderer 生成
│   └── config.json       # { url, name, userAgent, bundleId, host, ... }
└── _CodeSignature/       # ad-hoc 签名（codesign -s -）
```

### 2.2 关键设计决策

| 决策 | 选择 | 理由 |
|---|---|---|
| Wrapper 与 runtime 关系 | **完全独立**（runtime 二进制复制进每个 .app） | 启动最快、无依赖、语义清晰；升级 wrapper 时由 Generator 提供"全部重生成"按钮 |
| 代码签名 | **Ad-hoc**（`codesign -s -`） | 自用为主，无需付费开发者账号；首次启动右键打开绕过 Gatekeeper |
| 安装位置 | **`~/Applications/`** | 不需要管理员密码，Launchpad/Spotlight 仍可识别 |
| 数据隔离 | **依赖系统默认**（每个 bundle id 独立的 `WKWebsiteDataStore.default()`） | 零代码成本，OS 保证 |
| Runtime UI 框架 | **AppKit + WKWebView**（不用 SwiftUI） | SwiftUI 启动有 ~80ms 额外开销，runtime 追求极致冷启动 |
| Generator UI 框架 | **SwiftUI** | 开发效率高，启动开销可接受 |
| 持久化数据库 | **无**（真相在 wrapper bundle 自身） | YAGNI；启动时扫描 `~/Applications` 重建列表 |

---

## 3. Runtime（被复制进每个 wrapper 的二进制）

职责单一：读 config → 开窗 → 加载 URL → 处理交互。约 400-600 行 Swift。

### 3.1 模块

```
WebWrapRuntime/
├── main.swift              # NSApplication 入口
├── AppDelegate.swift       # 启动流程、菜单栏构建
├── Config.swift            # struct Config: Codable
├── BrowserWindow.swift     # NSWindow + WKWebView + NSToolbar
└── WebViewDelegate.swift   # 导航策略
```

### 3.2 行为表

| 交互 | 实现 |
|---|---|
| 启动 | `Bundle.main.url(forResource: "config", withExtension: "json")` → 同步反序列化 → 立即建窗 + `loadRequest` |
| 工具栏 | `NSToolbar` 三按钮：Back / Forward / Reload（用 SF Symbols，零图片资源） |
| 快捷键 | Cmd+[ Back, Cmd+] Forward, Cmd+R Reload, Cmd+W 关窗（不退出），Cmd+Q 退出 |
| 站外链接 | `decidePolicyFor navigationAction`：目标 host 不是 `config.host` 或其子域时调用 `NSWorkspace.shared.open(url)`；mailto:/tel: 等非 http(s) scheme 也走系统打开 |
| Dock 角标 | KVO 监听 `WKWebView.title`，正则匹配 `\((\d+)\)` → `NSApp.dockTile.badgeLabel` |
| UA 覆盖 | `webView.customUserAgent = config.userAgent`（nil 时走 Safari UA） |
| 通知 | WebKit 默认 `Notification` API + `UNUserNotificationCenter` 桥接 |
| 暗色模式 | 不处理，跟随站点 |

### 3.3 性能预算

- 冷启动到首帧：**≤ 250ms**（M1）
- 内存常驻：**≤ 150MB**（与原生 Safari 单 tab 相当）
- 二进制体积：**~1.5MB**（Release + LTO + strip + `DEAD_CODE_STRIPPING=YES`）

---

## 4. Generator GUI（WebWrap.app）

SwiftUI 单窗口，三栏布局（Sidebar + List + Detail）。

### 4.1 模块

```
WebWrap/
├── App.swift                 # @main, WindowGroup
├── AppState.swift            # ObservableObject, @Published wrappers: [WrapperApp]
├── WrapperApp.swift          # 内存模型
├── Views/
│   ├── SidebarView.swift
│   ├── DetailView.swift
│   └── CreateSheet.swift
└── Core/                     # 纯逻辑层，可单测
    ├── AppBuilder.swift      # build(config) -> URL
    ├── IconFetcher.swift     # URL -> best icon Data
    ├── IconRenderer.swift    # Data -> .icns（macOS 风格化）
    ├── BundleWriter.swift    # 写 Info.plist / config.json / 复制 runtime
    └── Codesigner.swift      # Process("/usr/bin/codesign", ...)
```

### 4.2 创建 wrapper 流程

`CreateWrapper(url, name, iconOverride?)`：

0. 生成 `slug`：name 转小写、ASCII 化、非字母数字替换为 `-`，作为 `com.webwrap.<slug>` 的 bundle id 后缀；重名则追加 `-2`、`-3`
1. `IconFetcher.fetch(url)` — 并行探测各候选源（详见 §5）
2. `IconRenderer.render(data)` — Core Image 流水线生成 1024×1024 PNG，再通过 `sips` + `iconutil` 生成 `.icns`
3. `BundleWriter.write(config)` — 临时目录组装 `.app`，复制 runtime，写 Info.plist 与 config.json
4. `Codesigner.adhocSign(bundleURL)` — `codesign --force --deep --sign - <bundle>`
5. `FileManager.moveItem` → `~/Applications/<Name>.app`（原子操作）
6. 通知 `AppState` 刷新

### 4.3 列表来源

启动时扫描 `~/Applications`，过滤 `CFBundleIdentifier` 前缀为 `com.webwrap.` 的 bundle，读各自的 `config.json` 重建内存模型。**不维护额外数据库**，真相在 bundle 自身。

### 4.4 编辑与重生成

修改字段后 = 重建一次 .app 替换原位置（一次原子 move）。简单可靠，避免增量修改的边角问题。

---

## 5. 图标管线

### 5.1 抓取优先级

取第一个 ≥ 256px 的，否则取最大者，最后 fallback 到首字母方块：

1. `<link rel="apple-touch-icon" sizes="...">`（通常 180×180，质量最高）
2. `<link rel="icon" sizes="...">` 中 size 最大者
3. Web App Manifest（`<link rel="manifest">` → `icons[]`）中 size 最大者
4. `/apple-touch-icon.png` 和 `/apple-touch-icon-precomposed.png` 直链探测
5. `/favicon.ico`（解析多帧 ICO 取最大帧）
6. 兜底：站点首字母 + 主题色生成纯色方块图

HTML 解析使用 `SwiftSoup`（Generator 唯一外部依赖，Runtime 不引入）。

### 5.2 macOS 风格化（Core Image 流水线）

```
原图 1024×1024
  ↓ aspectFit 到 824×824（macOS 标准内容区，留 100px padding）
  ↓ 应用 squircle mask（Apple 连续曲率圆角，预制 SVG → CGPath）
  ↓ 加底色（透明 PNG 取主色调或纯白）
  ↓ drop shadow（offset y=2, blur=8, opacity=0.25）
  ↓ 输出 1024×1024 PNG
```

### 5.3 生成 .icns

通过 `Process` 调用系统工具：

```bash
mkdir AppIcon.iconset
sips -z 16 16     in.png --out AppIcon.iconset/icon_16x16.png
sips -z 32 32     in.png --out AppIcon.iconset/icon_16x16@2x.png
sips -z 32 32     in.png --out AppIcon.iconset/icon_32x32.png
sips -z 64 64     in.png --out AppIcon.iconset/icon_32x32@2x.png
sips -z 128 128   in.png --out AppIcon.iconset/icon_128x128.png
sips -z 256 256   in.png --out AppIcon.iconset/icon_128x128@2x.png
sips -z 256 256   in.png --out AppIcon.iconset/icon_256x256.png
sips -z 512 512   in.png --out AppIcon.iconset/icon_256x256@2x.png
sips -z 512 512   in.png --out AppIcon.iconset/icon_512x512.png
cp in.png         AppIcon.iconset/icon_512x512@2x.png
iconutil -c icns AppIcon.iconset
```

整套约 200ms。

### 5.4 手动覆盖分支

- 用户拖入 PNG/JPG：跳过抓取，进风格化流水线
- 用户拖入 `.icns`：跳过整个管线，直接复制

---

## 6. 技术栈

| 项 | 选择 | 理由 |
|---|---|---|
| 语言 | Swift 5.9+ | 系统原生，无运行时依赖 |
| Generator UI | SwiftUI | 开发效率 |
| Runtime UI | AppKit + WKWebView | 极致冷启动 |
| 部署目标 | macOS 13 Ventura+ | 覆盖 95%+ 用户 |
| 项目管理 | Xcode workspace，2 个 target | 简单直接 |
| 外部依赖 | 仅 Generator 使用 `SwiftSoup` | Runtime 零依赖 |
| 构建配置 | Release: `-O`, LTO, strip, `DEAD_CODE_STRIPPING=YES` | 二进制 ~1.5MB |

---

## 7. 性能基线（验收指标）

| 指标 | 目标 |
|---|---|
| Runtime 冷启动到首帧 | ≤ 250ms (M1) |
| 单 wrapper 磁盘体积 | ≤ 3MB（含图标） |
| 生成一个 wrapper 全流程 | ≤ 1s（不含图标下载网络耗时） |
| Wrapper 运行时常驻内存 | ≤ 150MB |
| Generator 启动 | ≤ 500ms |

---

## 8. 实施路线图

每阶段完成后都是可工作的产物，可中途暂停。

| 阶段 | 产出 | 验证方式 |
|---|---|---|
| **P1. Runtime 最小可用** | WebWrapRuntime 二进制，硬编码 URL 也能开窗显示网页 | 命令行直接跑二进制能看到 google.com |
| **P2. Runtime 完整** | 读 config.json、工具栏、快捷键、站外链接路由、Dock 角标、UA 注入 | 手工塞 config.json + 复制二进制成 .app，双击表现正确 |
| **P3. AppBuilder 核心** | `BundleWriter` + `Codesigner` 纯函数模块，给定 config 生成可启动 .app | 命令行调用，产物可双击运行、Launchpad 显示、`~/Applications` 出现 |
| **P4. 图标管线** | `IconFetcher` + `IconRenderer`，端到端 URL → .icns | 单测 + 跑 10 个站点目测图标质量 |
| **P5. Generator GUI** | SwiftUI 三栏，串联 P3+P4，列表/创建/编辑/删除/重生成 | 用户测试：从 0 到生成 5 个常用 app < 3 分钟 |

---

## 9. 已知限制与未来扩展

- **首次启动需右键打开**绕过 Gatekeeper（ad-hoc 签名固有限制）
- **不支持分发**给其他用户（如需，未来扩展 Developer ID + 公证模式）
- **不支持多账号同站**（如需，未来扩展 workspace 概念，为同一 URL 创建多个不同 bundle id 的 wrapper）
- **不内置 catalog**（如需，未来加一个预置常用站点的 JSON 清单）
