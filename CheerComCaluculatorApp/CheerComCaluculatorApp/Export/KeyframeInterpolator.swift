import Foundation
import SceneKit
import simd


/// Interpolates joint euler angles between skill keyframes using SLERP on quaternions.
public struct KeyframeInterpolator {

    public struct ResolvedKeyframe {
        public let frameIndex: Int
        public let jointAngles: [String: SCNVector3]

        public init(frameIndex: Int, jointAngles: [String: SCNVector3]) {
            self.frameIndex = frameIndex
            self.jointAngles = jointAngles
        }
    }

    public let keyframes: [ResolvedKeyframe]
    public let numFrames: Int

    public init(keyframes: [ResolvedKeyframe], numFrames: Int) {
        self.keyframes = keyframes.sorted { $0.frameIndex < $1.frameIndex }
        self.numFrames = numFrames
    }

    /// Returns interpolated joint angles at a given frame index.
    public func angles(atFrame frame: Int) -> [String: SCNVector3] {
        guard !keyframes.isEmpty else { return [:] }

        if frame <= keyframes.first!.frameIndex {
            return keyframes.first!.jointAngles
        }
        if frame >= keyframes.last!.frameIndex {
            return keyframes.last!.jointAngles
        }

        var prev = keyframes.first!
        var next = keyframes.last!
        for i in 0..<(keyframes.count - 1) {
            if keyframes[i].frameIndex <= frame && frame <= keyframes[i + 1].frameIndex {
                prev = keyframes[i]
                next = keyframes[i + 1]
                break
            }
        }

        let span = Double(next.frameIndex - prev.frameIndex)
        let t = span > 0 ? Double(frame - prev.frameIndex) / span : 0.0

        return interpolate(from: prev.jointAngles, to: next.jointAngles, t: t)
    }

    private func interpolate(
        from: [String: SCNVector3],
        to: [String: SCNVector3],
        t: Double
    ) -> [String: SCNVector3] {
        var result: [String: SCNVector3] = [:]
        let allKeys = Set(from.keys).union(to.keys)
        for key in allKeys {
            if let a = from[key], let b = to[key] {
                result[key] = slerpEulerAngles(a, b, t: Float(t))
            } else if let a = from[key] {
                result[key] = a
            } else if let b = to[key] {
                result[key] = b
            }
        }
        return result
    }

    private func slerpEulerAngles(
        _ a: SCNVector3,
        _ b: SCNVector3,
        t: Float
    ) -> SCNVector3 {
        let qa = quaternionFromEuler(a)
        let qb = quaternionFromEuler(b)
        let qslerp = simd_slerp(qa, qb, t)
        return eulerFromQuaternion(qslerp)
    }

    // MARK: - Quaternion helpers

    private func quaternionFromEuler(_ euler: SCNVector3) -> simd_quatf {
        let x = Float(euler.x)
        let y = Float(euler.y)
        let z = Float(euler.z)

        let qx = simd_quatf(angle: x, axis: SIMD3<Float>(1, 0, 0))
        let qy = simd_quatf(angle: y, axis: SIMD3<Float>(0, 1, 0))
        let qz = simd_quatf(angle: z, axis: SIMD3<Float>(0, 0, 1))
        return qy * qx * qz  // YXZ order, matches SceneKit's default euler convention
    }

    private func eulerFromQuaternion(_ q: simd_quatf) -> SCNVector3 {
        let ysqr = q.imag.y * q.imag.y
        let t0 = 2.0 * (q.real * q.imag.x + q.imag.y * q.imag.z)
        let t1 = 1.0 - 2.0 * (q.imag.x * q.imag.x + ysqr)
        let x = atan2(t0, t1)

        var t2 = 2.0 * (q.real * q.imag.y - q.imag.z * q.imag.x)
        t2 = max(-1.0, min(1.0, t2))
        let y = asin(t2)

        let t3 = 2.0 * (q.real * q.imag.z + q.imag.x * q.imag.y)
        let t4 = 1.0 - 2.0 * (ysqr + q.imag.z * q.imag.z)
        let z = atan2(t3, t4)

        #if os(macOS)
        return SCNVector3(CGFloat(x), CGFloat(y), CGFloat(z))
        #else
        return SCNVector3(x, y, z)
        #endif
    }
}
