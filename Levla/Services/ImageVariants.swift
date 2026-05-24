import Foundation
import SwiftUI

/// Turn a Supabase public storage URL into a render-image URL with a target
/// pixel width — much smaller payloads than loading the full 1024px source
/// at every render site.
///
/// `/storage/v1/object/public/...`  →  `/storage/v1/render/image/public/...`
/// with `?width=N&quality=Q&resize=cover` appended.
enum ImageVariants {
    static func resized(_ url: URL?, targetPoints: CGFloat) -> URL? {
        guard var comps = url.flatMap({ URLComponents(url: $0, resolvingAgainstBaseURL: false) }) else {
            return url
        }

        // Only rewrite our own Supabase storage URLs; leave others alone.
        guard comps.path.contains("/storage/v1/object/public/") else { return url }

        comps.path = comps.path.replacingOccurrences(
            of: "/storage/v1/object/public/",
            with: "/storage/v1/render/image/public/"
        )

        // Bake the device's native scale into the requested pixel width
        // so a 80pt tile on a 3x screen asks for ~240px, not ~80px.
        let scale = UIScreen.main.scale
        let pixels = max(80, min(1024, Int((targetPoints * scale).rounded())))

        var items = comps.queryItems ?? []
        items.append(.init(name: "width", value: String(pixels)))
        items.append(.init(name: "height", value: String(pixels)))
        items.append(.init(name: "resize", value: "cover"))
        items.append(.init(name: "quality", value: pixels <= 256 ? "70" : "82"))
        comps.queryItems = items

        return comps.url
    }
}
