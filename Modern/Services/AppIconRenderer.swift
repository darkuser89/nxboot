import CoreImage
import ImageIO

/// Recolors only the colored controller shells; the neutral tile, controls and bolt stay intact.
/// Rendering lives off the UI executor and creates no persistent icon variants.
actor AppIconRenderer {
    private let source: CGImage?
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private let context = CIContext(options: [.workingColorSpace: NSNull(), .cacheIntermediates: false])

    init(iconURL: URL?) {
        source = iconURL.flatMap(Self.loadLargestImage)
    }

    func render(_ accent: JoyConAccent) -> CGImage? {
        guard let source else { return nil }
        let dimension = 32
        let (targetR, targetG, targetB) = accent.rgb
        var cube = [Float]()
        cube.reserveCapacity(dimension * dimension * dimension * 4)
        for blue in 0..<dimension {
            let b = Double(blue) / Double(dimension - 1)
            for green in 0..<dimension {
                let g = Double(green) / Double(dimension - 1)
                for red in 0..<dimension {
                    let r = Double(red) / Double(dimension - 1)
                    let value = max(r, max(g, b))
                    let minimum = min(r, min(g, b))
                    let saturation = value == 0 ? 0 : (value - minimum) / value
                    // Neutral pixels and dark controls must not acquire a color cast.
                    let mask = Self.smoothstep(0.18, 0.48, saturation) * Self.smoothstep(0.16, 0.30, value)
                    cube.append(Float(r + (targetR * value - r) * mask))
                    cube.append(Float(g + (targetG * value - g) * mask))
                    cube.append(Float(b + (targetB * value - b) * mask))
                    cube.append(1)
                }
            }
        }
        let data = cube.withUnsafeBytes { Data($0) }
        let input = CIImage(cgImage: source)
        guard let filter = CIFilter(name: "CIColorCube", parameters: [
            kCIInputImageKey: input,
            "inputCubeDimension": dimension,
            "inputCubeData": data
        ]), let output = filter.outputImage else { return nil }
        return context.createCGImage(output, from: input.extent, format: .RGBA8, colorSpace: colorSpace)
    }

    private nonisolated static func smoothstep(_ lower: Double, _ upper: Double, _ value: Double) -> Double {
        let t = min(max((value - lower) / (upper - lower), 0), 1)
        return t * t * (3 - 2 * t)
    }

    private nonisolated static func loadLargestImage(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }
        let index = (0..<count).max { left, right in
            func width(_ index: Int) -> Int {
                let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
                return (props?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
            }
            return width(left) < width(right)
        } ?? 0
        return CGImageSourceCreateImageAtIndex(source, index, nil)
    }
}
