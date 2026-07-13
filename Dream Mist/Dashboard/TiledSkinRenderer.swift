import AppKit

// Decodes C-Gear and Pokédex skins — the DS's tile-based image format used for the top
// screen background. Each 8x8 tile stores 4-bit palette indices (2 pixels/byte); a 16-color
// foreground palette and, for Pokédex skins, an extra 64-color background palette follow.
// Ported from the reference Java implementation's TiledImageUtility (read-only direction —
// this project doesn't support encoding a custom image into a skin).
enum TiledSkinRenderer {
    private static let tileWidth = 8
    private static let tileHeight = 8
    private static let tileSize = tileWidth * tileHeight // 64
    private static let colorPaletteSize = 16
    private static let screenWidth = 256
    private static let screenHeight = 192
    private static let screenSize = screenWidth * screenHeight
    private static let screenTileCount = screenSize / tileSize // 768

    private static let cache = NSCache<NSString, NSImage>()

    // C-Gear skins only use 255 of the 768 possible tile slots, so the file also stores explicit
    // tile-mapping data (which tile goes where, plus flip flags) for every screen position.
    // normalizeIndices is true for original Black & White skins, which use a non-linear
    // in-memory tile index scheme; false for Black 2 / White 2.
    static func cgearSkin(path: URL, normalizeIndices: Bool) -> NSImage? {
        let key = "cgear:\(path.path):\(normalizeIndices)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = try? Data(contentsOf: path),
              let image = readTiledImage(
                data: data, tileCount: 255, backgroundColorCount: 0,
                backgroundColorIndices: nil, backgroundOverrides: nil, normalizeIndices: normalizeIndices
              ) else {
            log("TiledSkinRenderer: failed to decode C-Gear skin at \(path.path)")
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }

    // Pokédex skins fill all 768 tiles (no mapping data needed — they're placed in order), and
    // pixels using foreground palette index 0 fall back to a fixed per-pixel background color
    // (loaded from zukan.bin) unless overridden, so the skin can be a partial overlay.
    static func dexSkin(path: URL) -> NSImage? {
        let key = "dex:\(path.path)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = try? Data(contentsOf: path),
              let image = readTiledImage(
                data: data, tileCount: 768, backgroundColorCount: 64,
                backgroundColorIndices: dexBackgroundColorIndices, backgroundOverrides: dexBackgroundOverrides,
                normalizeIndices: false
              ) else {
            log("TiledSkinRenderer: failed to decode Pokédex skin at \(path.path)")
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }

    private static func readTiledImage(
        data: Data, tileCount: Int, backgroundColorCount: Int,
        backgroundColorIndices: [UInt8]?, backgroundOverrides: [Bool]?, normalizeIndices: Bool
    ) -> NSImage? {
        // Tile data (tileCount * 32 bytes) + foreground palette (32 bytes) + background
        // palette, if any (backgroundColorCount * 2 bytes). C-Gear skins additionally need
        // tile-mapping data (screenTileCount * 2 bytes) since they don't fill every tile slot.
        let tileMappingBytes = tileCount < screenTileCount ? screenTileCount * 2 : 0
        let minimumSize = tileCount * (tileSize / 2) + colorPaletteSize * 2 + backgroundColorCount * 2 + tileMappingBytes
        guard data.count >= minimumSize else {
            log("TiledSkinRenderer: file too short (\(data.count) bytes, need \(minimumSize))")
            return nil
        }

        var reader = LittleEndianReader(data)
        var tileData = [Int](repeating: 0, count: tileCount * tileSize) // palette indices, 0-15
        var tileIndices = [Int](repeating: 0, count: tileCount) // in-memory index lookup table

        for i in 0..<tileCount {
            let rawTileData = reader.readBytes(tileSize / 2)
            for j in 0..<rawTileData.count {
                let paletteIndices = Int(rawTileData[j])
                tileData[i * tileSize + j * 2] = paletteIndices & (colorPaletteSize - 1)
                tileData[i * tileSize + j * 2 + 1] = (paletteIndices >> 4) & (colorPaletteSize - 1)
            }
            tileIndices[i] = normalizeIndices ? (i + i / 17 * 15 + 0xA0A0) : i
        }

        var colorPalette = [Int](repeating: 0, count: colorPaletteSize)
        for i in 0..<colorPaletteSize {
            let raw = Int(UInt16(bitPattern: reader.readShort()))
            // The game always shows the background (or black) in place of the first foreground
            // color, so zero it out here for an accurate preview.
            colorPalette[i] = i == 0 ? 0 : BGR555.toRGB888(raw)
        }

        var backgroundColorPalette = [Int](repeating: 0, count: backgroundColorCount)
        for i in 0..<backgroundColorCount {
            backgroundColorPalette[i] = BGR555.toRGB888(Int(UInt16(bitPattern: reader.readShort())))
        }

        var pixels = [UInt32](repeating: 0, count: screenSize)

        // backgroundColorIndices/backgroundOverrides are only ever both-nil (C-Gear) or
        // both-present (Pokédex with background applied) at the call sites below.
        func resolveColor(paletteIndex: Int, pixelIndex: Int) -> Int {
            guard let backgroundColorIndices, let backgroundOverrides else {
                return colorPalette[paletteIndex]
            }
            if paletteIndex > 0 && !backgroundOverrides[pixelIndex] {
                return colorPalette[paletteIndex]
            }
            return backgroundColorPalette[Int(backgroundColorIndices[pixelIndex])]
        }

        if tileCount < screenTileCount {
            for i in 0..<screenTileCount {
                let x = (i * tileWidth) % screenWidth
                let y = (i * tileWidth / screenWidth) * tileHeight
                let leftBits = Int(reader.readByte())
                let rightBits = Int(reader.readByte())
                let memoryIndex = leftBits | ((rightBits & ~12) << 8)
                let flipBits = rightBits & 12

                guard let tileIndex = tileIndices.firstIndex(of: memoryIndex) else { continue }

                for j in 0..<tileSize {
                    let tilePixelIndex: Int
                    switch flipBits {
                    case 4:  tilePixelIndex = (tileWidth * (j / tileWidth) + tileWidth) - j % tileWidth - 1
                    case 8:  tilePixelIndex = tileSize - (tileWidth * (j / tileWidth) + tileWidth) + j % tileWidth
                    case 12: tilePixelIndex = tileSize - j - 1
                    default: tilePixelIndex = j
                    }
                    let pixelX = x + j % tileWidth
                    let pixelY = y + j / tileWidth
                    let pixelIndex = pixelY * screenWidth + pixelX
                    let paletteIndex = tileData[tileIndex * tileSize + tilePixelIndex]
                    pixels[pixelIndex] = UInt32(resolveColor(paletteIndex: paletteIndex, pixelIndex: pixelIndex))
                }
            }
        } else {
            for i in 0..<screenTileCount {
                let x = (i * tileWidth) % screenWidth
                let y = (i * tileWidth / screenWidth) * tileWidth
                for j in 0..<tileSize {
                    let pixelX = x + j % tileWidth
                    let pixelY = y + j / tileWidth
                    let pixelIndex = pixelY * screenWidth + pixelX
                    let paletteIndex = tileData[i * tileSize + j]
                    pixels[pixelIndex] = UInt32(resolveColor(paletteIndex: paletteIndex, pixelIndex: pixelIndex))
                }
            }
        }

        return makeImage(pixels: pixels, width: screenWidth, height: screenHeight)
    }

    private static func makeImage(pixels: [UInt32], width: Int, height: Int) -> NSImage? {
        var rgba = [UInt8](repeating: 255, count: width * height * 4)
        for i in 0..<pixels.count {
            let color = pixels[i]
            rgba[i * 4]     = UInt8((color >> 16) & 0xFF)
            rgba[i * 4 + 1] = UInt8((color >> 8) & 0xFF)
            rgba[i * 4 + 2] = UInt8(color & 0xFF)
            rgba[i * 4 + 3] = 255
        }

        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let cgImage = CGImage(
                width: width, height: height,
                bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              ) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    // Pokédex skin background data: a per-pixel color-index array and override-bit array,
    // both run-length encoded. See zukan.bin / Resources/NOTICE.md.
    private static let (dexBackgroundColorIndices, dexBackgroundOverrides): ([UInt8], [Bool]) = {
        guard let url = BundleResource.find("zukan.bin"), let data = try? Data(contentsOf: url) else {
            log("TiledSkinRenderer: failed to load zukan.bin")
            return ([UInt8](repeating: 0, count: screenSize), [Bool](repeating: false, count: screenSize))
        }

        var reader = LittleEndianReader(data)
        var colorIndices = [UInt8](repeating: 0, count: screenSize)
        var overrides = [Bool](repeating: false, count: screenSize)

        var index = 0
        var pairs = Int(UInt16(bitPattern: reader.readShort()))
        for _ in 0..<pairs where index < screenSize {
            let amount = Int(reader.readByte())
            let value = reader.readByte()
            for _ in 0..<amount where index < screenSize {
                colorIndices[index] = value & 63
                index += 1
            }
        }

        index = 0
        pairs = Int(UInt16(bitPattern: reader.readShort()))
        for _ in 0..<pairs where index < screenSize {
            let amount = Int(UInt16(bitPattern: reader.readShort()))
            let value = reader.readByte()
            for _ in 0..<amount where index < screenSize {
                for k in 0..<8 where index < screenSize {
                    overrides[index] = (value & (1 << k)) != 0
                    index += 1
                }
            }
        }

        return (colorIndices, overrides)
    }()
}
