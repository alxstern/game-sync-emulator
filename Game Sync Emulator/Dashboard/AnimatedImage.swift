import SwiftUI
import AppKit

// SwiftUI's Image only ever shows a GIF's first frame. NSImageView animates multi-frame
// images natively, so this just wraps one for use in SwiftUI.
//
// Each source sprite is cropped to its own tight bounding box rather than a shared canvas
// (Bulbasaur is 37x38px, Venusaur is 86x71px) — that size difference IS correct relative
// scale, not padding to normalize away.
struct AnimatedImage: NSViewRepresentable {
    enum Sizing {
        // native size × factor, applied identically to every sprite — use this wherever
        // multiple sprites appear together, so relative size stays correct (a Lugia row is
        // legitimately taller than a Bulbasaur row).
        case scale(CGFloat)
        // independently fit to a fixed box, aspect ratio preserved — use this for a single
        // isolated avatar where a consistent footprint matters more than relative size.
        case fit(CGSize)
    }

    // Shared by every screen that uses .scale sizing, so a given species renders at the same
    // relative size everywhere in the app (and the same size across launches/rebuilds).
    static let standardSpriteScale: CGFloat = 0.7

    let image: NSImage
    var sizing: Sizing = .scale(1)

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.animates = true
        view.imageScaling = .scaleProportionallyUpOrDown
        view.wantsLayer = true
        view.layer?.magnificationFilter = .nearest // keep pixel art crisp when scaled up
        view.image = image
        return view
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        if nsView.image !== image {
            nsView.image = image
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSImageView, context: Context) -> CGSize? {
        let native = image.size
        switch sizing {
        case .scale(let factor):
            return CGSize(width: native.width * factor, height: native.height * factor)
        case .fit(let box):
            guard native.width > 0, native.height > 0 else { return box }
            let ratio = min(box.width / native.width, box.height / native.height)
            return CGSize(width: native.width * ratio, height: native.height * ratio)
        }
    }
}
