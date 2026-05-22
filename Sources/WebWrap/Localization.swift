import Foundation
import SwiftUI

@MainActor
final class Localization: ObservableObject {
    enum Language: String, CaseIterable, Identifiable {
        case system, zh, en
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .system: return "跟随系统 / Follow System"
            case .zh: return "中文"
            case .en: return "English"
            }
        }
    }

    @Published var preferred: Language {
        didSet {
            UserDefaults.standard.set(preferred.rawValue, forKey: "preferredLanguage")
        }
    }

    var effective: Language {
        if preferred == .system {
            let code = Locale.current.language.languageCode?.identifier ?? "en"
            return code.hasPrefix("zh") ? .zh : .en
        }
        return preferred
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "preferredLanguage") ?? "system"
        self.preferred = Language(rawValue: raw) ?? .system
    }

    func t(_ key: LocalizedKey) -> String {
        switch effective {
        case .zh: return key.zh
        case .en, .system: return key.en
        }
    }
}

enum LocalizedKey {
    case appName
    case newWrapper, newWrapperMenu, refresh, preferences
    case noWrappersTitle, noWrappersDescription
    case settings, name, url, userAgent, icon, autoFetched, choose
    case create, cancel, done
    case launch, revealInFinder, regenerate, delete
    case language
    case updateAllApps, updateAllDescription, updateAllSuccess, updating
    case createFailedPrefix, deleteFailedPrefix
    case windowTitle

    var zh: String {
        switch self {
        case .appName: return "灵镜"
        case .newWrapper: return "新建"
        case .newWrapperMenu: return "新建 App…"
        case .refresh: return "刷新"
        case .preferences: return "偏好设置"
        case .noWrappersTitle: return "还没有创建任何应用"
        case .noWrappersDescription: return "点击侧栏 + 创建你的第一个 App"
        case .settings: return "设置"
        case .name: return "名称"
        case .url: return "网址"
        case .userAgent: return "User-Agent（可选）"
        case .icon: return "图标"
        case .autoFetched: return "从网站自动抓取"
        case .choose: return "选择…"
        case .create: return "创建"
        case .cancel: return "取消"
        case .done: return "完成"
        case .launch: return "启动"
        case .revealInFinder: return "在 Finder 中显示"
        case .regenerate: return "重新生成"
        case .delete: return "删除"
        case .language: return "语言"
        case .updateAllApps: return "更新所有 App"
        case .updateAllDescription: return "把所有已生成的 App 升级到当前 Runtime。登录态会保留。"
        case .updateAllSuccess: return "已更新 %d 个 App"
        case .updating: return "正在更新…"
        case .createFailedPrefix: return "创建失败"
        case .deleteFailedPrefix: return "删除失败"
        case .windowTitle: return "灵镜"
        }
    }

    var en: String {
        switch self {
        case .appName: return "WebWrap"
        case .newWrapper: return "New"
        case .newWrapperMenu: return "New Wrapper…"
        case .refresh: return "Refresh"
        case .preferences: return "Preferences"
        case .noWrappersTitle: return "No wrappers yet"
        case .noWrappersDescription: return "Click + in the sidebar to create your first one."
        case .settings: return "Settings"
        case .name: return "Name"
        case .url: return "URL"
        case .userAgent: return "User-Agent (optional)"
        case .icon: return "Icon"
        case .autoFetched: return "Auto-fetched from site"
        case .choose: return "Choose…"
        case .create: return "Create"
        case .cancel: return "Cancel"
        case .done: return "Done"
        case .launch: return "Launch"
        case .revealInFinder: return "Reveal in Finder"
        case .regenerate: return "Regenerate"
        case .delete: return "Delete"
        case .language: return "Language"
        case .updateAllApps: return "Update All Apps"
        case .updateAllDescription: return "Upgrade all generated apps to the current runtime. Login state is preserved."
        case .updateAllSuccess: return "Updated %d app(s)"
        case .updating: return "Updating…"
        case .createFailedPrefix: return "Create failed"
        case .deleteFailedPrefix: return "Delete failed"
        case .windowTitle: return "WebWrap"
        }
    }
}
