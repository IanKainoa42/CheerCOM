import Foundation

/// A single virtual camera sample for exporting one animation from one viewpoint.
public struct CameraSample: Equatable {
    public let azimuthDeg: Double
    public let elevationDeg: Double
    public let distanceM: Double
    public let focalLengthMm: Double
    public let imageWidthPx: Int
    public let imageHeightPx: Int

    public init(
        azimuthDeg: Double,
        elevationDeg: Double,
        distanceM: Double,
        focalLengthMm: Double = 35.0,
        imageWidthPx: Int = 1920,
        imageHeightPx: Int = 1080
    ) {
        self.azimuthDeg = azimuthDeg
        self.elevationDeg = elevationDeg
        self.distanceM = distanceM
        self.focalLengthMm = focalLengthMm
        self.imageWidthPx = imageWidthPx
        self.imageHeightPx = imageHeightPx
    }
}

/// Generates the systematic 24×4 = 96 camera sample grid described in the
/// tumbling skill classification design spec.
public enum OrbitalCameraSampler {

    public static let azimuthStepDeg: Double = 15.0
    public static let elevationAnglesDeg: [Double] = [-10.0, 0.0, 10.0, 20.0]
    public static let baseDistanceM: Double = 5.0
    public static let distanceJitterRatio: Double = 0.10

    /// Generate the full 96-sample grid. Deterministic given the seed.
    public static func standardGrid(seed: UInt64 = 0) -> [CameraSample] {
        var samples: [CameraSample] = []
        var rng = SeededRandom(seed: seed)

        var azimuth = 0.0
        while azimuth < 360.0 {
            for elevation in elevationAnglesDeg {
                let jitter = rng.nextDouble(in: -distanceJitterRatio...distanceJitterRatio)
                let distance = baseDistanceM * (1.0 + jitter)
                samples.append(CameraSample(
                    azimuthDeg: azimuth,
                    elevationDeg: elevation,
                    distanceM: distance
                ))
            }
            azimuth += azimuthStepDeg
        }

        return samples
    }
}

/// Minimal seeded PRNG (xorshift) for reproducible jitter.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEADBEEFCAFEBABE : seed
    }

    mutating func nextUInt64() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        let normalized = Double(nextUInt64() & 0xFFFFFFFF) / Double(UInt32.max)
        return range.lowerBound + normalized * (range.upperBound - range.lowerBound)
    }
}
