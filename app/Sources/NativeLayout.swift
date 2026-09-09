import AppKit

/// Shared AppKit layout primitives. Semantic colors follow appearance and contrast settings.
enum NativeLayout {
    static func label(_ text: String, size: CGFloat = 13, weight: NSFont.Weight = .regular, secondary: Bool = false) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = secondary ? .secondaryLabelColor : .labelColor
        label.maximumNumberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    static func stack(_ views: [NSView], spacing: CGFloat = 12) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        for view in views {
            view.translatesAutoresizingMaskIntoConstraints = false
            if !(view is NSButton) || view is NSPopUpButton {
                view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            } else {
                view.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor).isActive = true
            }
        }
        return stack
    }

    static func pin(_ view: NSView, in parent: NSView, inset: CGFloat = 0) {
        view.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: inset),
            view.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -inset),
            view.topAnchor.constraint(equalTo: parent.topAnchor, constant: inset),
            view.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -inset)
        ])
    }

    static func heading(_ title: String, subtitle: String) -> NSView {
        stack([label(title, size: 26, weight: .bold), label(subtitle, secondary: true)], spacing: 6)
    }

    static func field(_ title: String, _ control: NSView) -> NSStackView {
        stack([label(title, size: 12, weight: .medium, secondary: true), control], spacing: 6)
    }

    static func separator() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }

    static func card(_ title: String, symbol: String, views: [NSView]) -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.fillColor = .controlBackgroundColor
        box.borderColor = .separatorColor
        box.borderWidth = 0.5
        box.cornerRadius = 10
        box.contentViewMargins = .zero
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil)!)
        icon.contentTintColor = .secondaryLabelColor
        icon.widthAnchor.constraint(equalToConstant: 16).isActive = true
        let titleRow = NSStackView(views: [icon, label(title, size: 11, weight: .semibold, secondary: true)])
        titleRow.spacing = 7
        let body = stack([titleRow] + views)
        pin(body, in: box.contentView!, inset: 18)
        return box
    }

    static func scroll(_ body: NSView, inset: CGFloat = 26) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        pin(body, in: document, inset: inset)
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        return scroll
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
