import AppKit

/// Developer aid: `KEYLUME_SNAPSHOT=/path/prefix` makes the app write a PNG of its own
/// window and a text dump of the view tree, then quit. Does nothing otherwise.
enum DebugSnapshot {
    static func runIfRequested() {
        guard let prefix = ProcessInfo.processInfo.environment["KEYLUME_SNAPSHOT"] else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            guard let window = NSApp.windows.first(where: { $0.isVisible }), let root = window.contentView?.superview else {
                exit(2)
            }
            var lines: [String] = []
            func walk(_ v: NSView, _ depth: Int) {
                lines.append(String(repeating: "  ", count: depth)
                             + "\(type(of: v)) \(Int(v.frame.minX)),\(Int(v.frame.minY)) \(Int(v.frame.width))x\(Int(v.frame.height))"
                             + (v.isHidden ? " HIDDEN" : "") + (v.alphaValue < 1 ? " alpha=\(v.alphaValue)" : ""))
                if depth < 14 { v.subviews.forEach { walk($0, depth + 1) } }
            }
            walk(root, 0)
            try? lines.joined(separator: "\n").write(toFile: prefix + ".txt", atomically: true, encoding: .utf8)
            if let rep = root.bitmapImageRepForCachingDisplay(in: root.bounds) {
                root.cacheDisplay(in: root.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: prefix + ".png"))
            }
            exit(0)
        }
    }
}
