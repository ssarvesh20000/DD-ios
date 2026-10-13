import CoreGraphics
import UIKit

/// Letterbox geometry matching ultralytics' `LetterBox` (the preprocessing the
/// detector was trained and evaluated with): scale so the longer side equals
/// `targetSide`, keep the aspect ratio, center the image, and pad the rest of
/// the square with gray (114, 114, 114).
///
/// All box math here is pure so it can be unit tested. Boxes are normalized
/// 0..1 with a top-left origin unless stated otherwise.
nonisolated struct LetterboxGeometry: Equatable {
    /// Oriented size of the source image (pixels).
    let sourceSize: CGSize
    /// Side of the square model input (pixels).
    let targetSide: CGFloat
    /// Source → target scale factor.
    let scale: CGFloat
    /// Size of the resized image inside the square (pixels, rounded like ultralytics).
    let scaledSize: CGSize
    /// Left / top padding (pixels, rounded like ultralytics).
    let padding: CGPoint

    init(sourceSize: CGSize, targetSide: CGFloat = 640) {
        self.sourceSize = sourceSize
        self.targetSide = targetSide
        let r = min(targetSide / sourceSize.width, targetSide / sourceSize.height)
        scale = r
        let newW = (sourceSize.width * r).rounded()
        let newH = (sourceSize.height * r).rounded()
        scaledSize = CGSize(width: newW, height: newH)
        // ultralytics: left = round(dw - 0.1), top = round(dh - 0.1)
        let dw = (targetSide - newW) / 2
        let dh = (targetSide - newH) / 2
        padding = CGPoint(x: (dw - 0.1).rounded(), y: (dh - 0.1).rounded())
    }

    /// Where the resized image is drawn inside the square (pixels, top-left origin).
    var contentRect: CGRect {
        CGRect(origin: padding, size: scaledSize)
    }

    /// Map a box normalized to the letterboxed square back to the source image
    /// (both normalized, top-left origin). Parts of the box that fall in the
    /// padding are clipped. Returns nil if nothing of the box is left.
    func unletterbox(_ box: CGRect) -> CGRect? {
        let x0 = (box.minX * targetSide - padding.x) / scaledSize.width
        let y0 = (box.minY * targetSide - padding.y) / scaledSize.height
        let x1 = (box.maxX * targetSide - padding.x) / scaledSize.width
        let y1 = (box.maxY * targetSide - padding.y) / scaledSize.height
        let cx0 = min(max(x0, 0), 1), cy0 = min(max(y0, 0), 1)
        let cx1 = min(max(x1, 0), 1), cy1 = min(max(y1, 0), 1)
        guard cx1 > cx0, cy1 > cy0 else { return nil }
        return CGRect(x: cx0, y: cy0, width: cx1 - cx0, height: cy1 - cy0)
    }

    /// Inverse of `unletterbox` (no clipping): source-normalized → square-normalized.
    func letterbox(_ box: CGRect) -> CGRect {
        CGRect(
            x: (box.minX * scaledSize.width + padding.x) / targetSide,
            y: (box.minY * scaledSize.height + padding.y) / targetSide,
            width: box.width * scaledSize.width / targetSide,
            height: box.height * scaledSize.height / targetSide
        )
    }
}

nonisolated enum Letterbox {
    /// Pad color used by ultralytics (114 / 255 gray).
    static let padGray: CGFloat = 114.0 / 255.0

    /// Vision returns boxes with a bottom-left origin; flip to top-left.
    static func topLeftFromVision(_ box: CGRect) -> CGRect {
        CGRect(x: box.minX, y: 1.0 - box.minY - box.height, width: box.width, height: box.height)
    }

    /// Oriented pixel size of a UIImage (what the user sees).
    static func pixelSize(of image: UIImage) -> CGSize {
        CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    }

    /// Draw `image` letterboxed into a `geometry.targetSide` square, 8-bit sRGB.
    /// `UIImage.draw(in:)` applies `imageOrientation`, so camera photos come out upright.
    @MainActor
    static func render(_ image: UIImage, geometry: LetterboxGeometry) -> CGImage? {
        let side = geometry.targetSide
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let rendered = renderer.image { ctx in
            UIColor(red: padGray, green: padGray, blue: padGray, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
            ctx.cgContext.interpolationQuality = .high
            image.draw(in: geometry.contentRect)
        }
        return rendered.cgImage
    }
}
