import AppKit

/// Centered toolbar address field. Default mode shows the page title; on click
/// switches to URL mode (selectable for copy). Press ESC or click outside to revert.
final class AddressBar: NSView {
    private let field = NSTextField()
    private var clickMonitor: Any?

    var pageTitle: String = "" {
        didSet { if !isShowingURL { field.stringValue = pageTitle } }
    }
    var pageURL: String = "" {
        didSet { if isShowingURL { field.stringValue = pageURL } }
    }
    private var isShowingURL = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.focusRingType = .none
        field.alignment = .center
        field.isEditable = false
        field.isSelectable = false
        field.font = .systemFont(ofSize: 12.5, weight: .medium)
        field.textColor = .labelColor
        field.lineBreakMode = .byTruncatingTail
        field.usesSingleLineMode = true
        field.translatesAutoresizingMaskIntoConstraints = false
        field.cell?.usesSingleLineMode = true
        addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            field.centerYAnchor.constraint(equalTo: centerYAnchor),
            field.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        showURLMode()
    }

    private func showURLMode() {
        guard !isShowingURL else { return }
        isShowingURL = true
        field.isSelectable = true
        field.stringValue = pageURL
        DispatchQueue.main.async { [weak self] in
            self?.field.selectText(nil)
        }
        installOutsideClickMonitor()
    }

    private func revert() {
        guard isShowingURL else { return }
        isShowingURL = false
        field.isSelectable = false
        field.stringValue = pageTitle
        removeOutsideClickMonitor()
        // Drop first-responder
        window?.makeFirstResponder(nil)
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            // Convert click to this view's coordinate space
            let pointInWindow = event.locationInWindow
            let pointInSelf = self.convert(pointInWindow, from: nil)
            if !self.bounds.contains(pointInSelf) {
                self.revert()
            }
            return event
        }
    }

    private func removeOutsideClickMonitor() {
        if let m = clickMonitor {
            NSEvent.removeMonitor(m)
            clickMonitor = nil
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // ESC
            revert()
        } else {
            super.keyDown(with: event)
        }
    }

    deinit {
        if let m = clickMonitor { NSEvent.removeMonitor(m) }
    }
}
