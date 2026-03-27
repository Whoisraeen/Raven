// MARK: - Image

/// Displays an image loaded from a file path.
/// The image is loaded into a Vulkan texture and rendered as a textured quad.
///
/// Usage:
/// ```swift
/// Image("assets/logo.png")
///     .frame(width: 200, height: 150)
/// ```
public struct Image: View {
    public typealias Body = Never
    public var body: Never { fatalError("Image is a primitive view") }

    /// The file path to the image (PNG, JPG, BMP, etc.)
    public let source: String

    /// Optional explicit size — if nil, uses the image's natural size
    public internal(set) var displayWidth: Float? = nil
    public internal(set) var displayHeight: Float? = nil

    /// Opacity (0.0–1.0)
    public internal(set) var opacity: Float = 1.0

    public init(_ source: String) {
        self.source = source
    }

    /// Set the display size of the image.
    public func size(width: Float, height: Float) -> Image {
        var copy = self
        copy.displayWidth = width
        copy.displayHeight = height
        return copy
    }
}
