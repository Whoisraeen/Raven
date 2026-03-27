import CSTBTrueType
import CVulkan

// MARK: - FontManager

/// Manages font loading and SDF glyph atlas generation using stb_truetype.
/// Supports loading TTF fonts, generating SDF glyphs on demand,
/// and maintaining a dynamic texture atlas.
public class FontManager: @unchecked Sendable {
    /// Singleton instance
    public static let shared = FontManager()

    // Font info from stb_truetype
    private var fontInfo = stbtt_fontinfo()
    private var fontData: [UInt8] = []  // kept alive for stb_truetype
    private var fontLoaded = false

    // Atlas configuration
    private var atlasWidth: Int = 512
    private var atlasHeight: Int = 512
    private var atlasData: [UInt8] = []
    private var atlasDirty = false

    // Glyph cache
    private var glyphCache: [GlyphKey: GlyphInfo] = [:]

    // Atlas packing cursor
    private var packCursorX: Int = 0
    private var packCursorY: Int = 0
    private var packRowHeight: Int = 0

    // SDF parameters
    private let sdfPadding: Int32 = 5
    private let sdfOnEdge: UInt8 = 180
    private let sdfPixelDistScale: Float = 36.0

    private init() {
        atlasData = [UInt8](repeating: 0, count: atlasWidth * atlasHeight)
    }

    // MARK: - Font Loading

    /// Load a TTF font from file path.
    public func loadFont(path: String) -> Bool {
        guard let data = readFileBytes(atPath: path) else {
            print("FontManager: Failed to read font file at \(path)")
            return false
        }
        return loadFont(data: data)
    }

    /// Load a TTF font from raw bytes.
    public func loadFont(data: [UInt8]) -> Bool {
        self.fontData = data
        let result = fontData.withUnsafeBufferPointer { buffer in
            stbtt_InitFont(&fontInfo, buffer.baseAddress, 0)
        }
        if result == 0 {
            print("FontManager: stbtt_InitFont failed")
            return false
        }
        fontLoaded = true
        glyphCache.removeAll()
        packCursorX = 0
        packCursorY = 0
        packRowHeight = 0
        atlasData = [UInt8](repeating: 0, count: atlasWidth * atlasHeight)
        atlasDirty = true
        print("FontManager: Font loaded successfully")
        return true
    }

    /// Load the bundled default font (Inter).
    public func loadDefaultFont() -> Bool {
        let execDir = parentDirectory(of: CommandLine.arguments[0])
        let rendererDir = parentDirectory(of: #filePath)  // Renderer
        let ravenDir = parentDirectory(of: rendererDir)    // Raven
        let sourcesDir = parentDirectory(of: ravenDir)     // Sources

        let searchPaths = [
            // Relative to executable
            joinPath(execDir, "Inter.ttf"),
            // Relative to source
            joinPath(ravenDir, "Resources/Inter.ttf"),
            // Relative to package root
            joinPath(sourcesDir, "Sources/Raven/Resources/Inter.ttf"),
        ]

        for path in searchPaths {
            if fileExists(atPath: path) {
                return loadFont(path: path)
            }
        }

        print("FontManager: Default font not found, using embedded bitmap fallback")
        return false
    }

    // MARK: - Glyph Retrieval

    /// Get glyph info for a character at a given pixel size.
    /// Generates the SDF glyph and packs into atlas on first request.
    public func getGlyph(codepoint: UInt32, fontSize: Float) -> GlyphInfo? {
        let key = GlyphKey(codepoint: codepoint, fontSize: fontSize)
        if let cached = glyphCache[key] {
            return cached
        }

        guard fontLoaded else { return nil }

        // Generate SDF glyph
        let scale = stbtt_ScaleForPixelHeight(&fontInfo, fontSize)
        let glyphIndex = stbtt_FindGlyphIndex(&fontInfo, Int32(codepoint))
        if glyphIndex == 0 && codepoint != 0 { return nil }

        var glyphW: Int32 = 0, glyphH: Int32 = 0
        var xoff: Int32 = 0, yoff: Int32 = 0

        guard let sdfBitmap = stbtt_GetGlyphSDF(
            &fontInfo, scale,
            glyphIndex, Int32(sdfPadding),
            sdfOnEdge, sdfPixelDistScale,
            &glyphW, &glyphH, &xoff, &yoff
        ) else {
            // Space or empty glyph — still need advance width
            var advanceWidth: Int32 = 0
            var leftSideBearing: Int32 = 0
            stbtt_GetGlyphHMetrics(&fontInfo, glyphIndex, &advanceWidth, &leftSideBearing)

            let info = GlyphInfo(
                u0: 0, v0: 0, u1: 0, v1: 0,
                width: 0, height: 0,
                xOffset: 0, yOffset: 0,
                advance: Float(advanceWidth) * scale,
                fontSize: fontSize
            )
            glyphCache[key] = info
            return info
        }
        defer { stbtt_FreeSDF(sdfBitmap, nil) }

        let w = Int(glyphW)
        let h = Int(glyphH)

        // Pack into atlas
        if !packGlyph(width: w, height: h) {
            // Atlas is full — grow it
            growAtlas()
            if !packGlyph(width: w, height: h) {
                print("FontManager: Atlas still full after growth, glyph too large")
                return nil
            }
        }

        let destX = packCursorX - w
        let destY = packCursorY

        // Copy SDF data into atlas
        for row in 0..<h {
            for col in 0..<w {
                let srcIdx = row * w + col
                let dstIdx = (destY + row) * atlasWidth + (destX + col)
                atlasData[dstIdx] = sdfBitmap[srcIdx]
            }
        }
        atlasDirty = true

        // Metrics
        var advanceWidth: Int32 = 0
        var leftSideBearing: Int32 = 0
        stbtt_GetGlyphHMetrics(&fontInfo, glyphIndex, &advanceWidth, &leftSideBearing)

        let info = GlyphInfo(
            u0: Float(destX) / Float(atlasWidth),
            v0: Float(destY) / Float(atlasHeight),
            u1: Float(destX + w) / Float(atlasWidth),
            v1: Float(destY + h) / Float(atlasHeight),
            width: Float(w),
            height: Float(h),
            xOffset: Float(xoff),
            yOffset: Float(yoff),
            advance: Float(advanceWidth) * scale,
            fontSize: fontSize
        )
        glyphCache[key] = info
        return info
    }

    /// Get kerning advance between two codepoints.
    public func getKerning(cp1: UInt32, cp2: UInt32, fontSize: Float) -> Float {
        guard fontLoaded else { return 0 }
        let scale = stbtt_ScaleForPixelHeight(&fontInfo, fontSize)
        let g1 = stbtt_FindGlyphIndex(&fontInfo, Int32(cp1))
        let g2 = stbtt_FindGlyphIndex(&fontInfo, Int32(cp2))
        let kern = stbtt_GetGlyphKernAdvance(&fontInfo, g1, g2)
        return Float(kern) * scale
    }

    /// Get font vertical metrics for a given size.
    public func getMetrics(fontSize: Float) -> FontMetrics {
        guard fontLoaded else {
            return FontMetrics(ascent: fontSize * 0.8, descent: fontSize * 0.2, lineGap: fontSize * 0.1)
        }
        let scale = stbtt_ScaleForPixelHeight(&fontInfo, fontSize)
        var ascent: Int32 = 0, descent: Int32 = 0, lineGap: Int32 = 0
        stbtt_GetFontVMetrics(&fontInfo, &ascent, &descent, &lineGap)
        return FontMetrics(
            ascent: Float(ascent) * scale,
            descent: Float(-descent) * scale,
            lineGap: Float(lineGap) * scale
        )
    }

    /// Measure the width and height of a string at a given font size.
    public func measureText(_ text: String, fontSize: Float) -> (width: Float, height: Float) {
        let metrics = getMetrics(fontSize: fontSize)
        let height = metrics.lineHeight

        guard fontLoaded else {
            // Fallback to monospace 8px-based approximation for the fallback font
            return (width: Float(text.count) * (fontSize / 2.0), height: height)
        }

        var width: Float = 0
        var prevCodepoint: UInt32 = 0

        for char in text {
            let cp = char.unicodeScalars.first.map { UInt32($0.value) } ?? 32
            
            if prevCodepoint != 0 {
                width += getKerning(cp1: prevCodepoint, cp2: cp, fontSize: fontSize)
            }
            
            // Just get advance, avoid generating SDF if not needed
            let scale = stbtt_ScaleForPixelHeight(&fontInfo, fontSize)
            let glyphIndex = stbtt_FindGlyphIndex(&fontInfo, Int32(cp))
            var advanceWidth: Int32 = 0
            var leftSideBearing: Int32 = 0
            stbtt_GetGlyphHMetrics(&fontInfo, glyphIndex, &advanceWidth, &leftSideBearing)
            width += Float(advanceWidth) * scale
            
            prevCodepoint = cp
        }

        return (width: width, height: height)
    }

    // MARK: - Atlas Access

    /// Whether the atlas texture needs re-uploading.
    public var isAtlasDirty: Bool { atlasDirty }

    /// Mark the atlas as uploaded.
    public func markAtlasClean() { atlasDirty = false }

    /// Get the current atlas pixel data.
    public var currentAtlasData: [UInt8] { atlasData }

    /// Current atlas dimensions.
    public var currentAtlasWidth: Int { atlasWidth }
    public var currentAtlasHeight: Int { atlasHeight }

    /// Whether stb_truetype font is loaded (vs. bitmap fallback).
    public var isFontLoaded: Bool { fontLoaded }

    // MARK: - Atlas Packing

    private func packGlyph(width: Int, height: Int) -> Bool {
        guard width > 0 && height > 0 else { return true }

        // Check if glyph fits in current row
        if packCursorX + width > atlasWidth {
            // Move to next row
            packCursorY += packRowHeight + 1
            packCursorX = 0
            packRowHeight = 0
        }

        // Check if glyph fits vertically
        if packCursorY + height > atlasHeight {
            return false
        }

        packCursorX += width + 1
        packRowHeight = max(packRowHeight, height)
        return true
    }

    private func growAtlas() {
        let newWidth = atlasWidth * 2
        let newHeight = atlasHeight * 2
        var newData = [UInt8](repeating: 0, count: newWidth * newHeight)

        // Copy old data
        for row in 0..<atlasHeight {
            for col in 0..<atlasWidth {
                newData[row * newWidth + col] = atlasData[row * atlasWidth + col]
            }
        }

        atlasWidth = newWidth
        atlasHeight = newHeight
        atlasData = newData
        atlasDirty = true

        // Invalidate UV cache since atlas size changed
        let fontSize = glyphCache.values.first?.fontSize ?? 16
        for (key, var info) in glyphCache {
            info.u0 = info.u0 * Float(atlasWidth / 2) / Float(atlasWidth)
            info.v0 = info.v0 * Float(atlasHeight / 2) / Float(atlasHeight)
            info.u1 = info.u1 * Float(atlasWidth / 2) / Float(atlasWidth)
            info.v1 = info.v1 * Float(atlasHeight / 2) / Float(atlasHeight)
            glyphCache[key] = info
        }

        print("FontManager: Atlas grown to \(newWidth)×\(newHeight)")
    }
}

// MARK: - Supporting Types

public struct GlyphKey: Hashable {
    public let codepoint: UInt32
    public let fontSize: Float

    // Hash Float with 1-decimal precision to avoid FP issues
    public func hash(into hasher: inout Hasher) {
        hasher.combine(codepoint)
        hasher.combine(Int(fontSize * 10))
    }

    public static func == (lhs: GlyphKey, rhs: GlyphKey) -> Bool {
        lhs.codepoint == rhs.codepoint && Int(lhs.fontSize * 10) == Int(rhs.fontSize * 10)
    }
}

public struct GlyphInfo {
    /// UV coordinates in the atlas texture
    public var u0, v0, u1, v1: Float
    /// Pixel dimensions of the glyph SDF
    public var width, height: Float
    /// Offset from cursor to top-left of glyph
    public var xOffset, yOffset: Float
    /// Horizontal advance to next character
    public var advance: Float
    /// Font size this glyph was generated for
    public var fontSize: Float
}

public struct FontMetrics {
    public var ascent: Float
    public var descent: Float
    public var lineGap: Float
    public var lineHeight: Float { ascent + descent + lineGap }
}
