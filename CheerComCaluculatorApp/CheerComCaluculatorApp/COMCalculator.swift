import SceneKit

struct SegmentResult {
    let name: String
    let position: SCNVector3
    let mass: Double
    let proxPosition: SCNVector3
    let distPosition: SCNVector3
}

struct CalculationResult {
    let totalCOM: SCNVector3
    let segmentCOMs: [SegmentResult]
}

class COMCalculator {
    var bodyMass: Double  // kg

    // 17 body segments with (name, proximal_joint, distal_joint, mass_%, com_%)
    // Based on anthropometric data from Winter (2009) and de Leva (1996)
    // Updated for Mixamo skeleton with mixamorig_ prefix
    // Note: Clavicle mass is assumed to be integrated into Thorax.
    let segments: [SegmentData] = SegmentData.standard

    // MARK: - Optimization
    private struct BoundSegment {
        let name: String
        let prox: SCNNode
        let dist: SCNNode
        let baseMassRatio: Double
        var currentMassRatio: Double
        let comRatio: Double
    }

    private var boundSegments: [BoundSegment] = []
    private var currentPreset: BodyPreset = .averageNeutral

    init(bodyMass: Double) {
        self.bodyMass = bodyMass
    }

    /// Binds the calculator to the specific SCNNodes for direct access.
    /// Call this once during setup or when the character model changes.
    func bind(jointNodes: [String: SCNNode]) {
        boundSegments.removeAll()
        var missingCount = 0

        for segment in segments {
            guard let proxNode = jointNodes[segment.proximalJoint.rawValue] else {
                print("⚠️ Missing proximal joint for binding: \(segment.proximalJoint.rawValue)")
                missingCount += 1
                continue
            }

            var distNode = jointNodes[segment.distalJoint.rawValue]
            if distNode == nil {
                // Special handling for Hand tips: use proximal if distal is missing (CoM at wrist)
                if segment.name.contains("Hand") {
                    print("⚠️ Hand distal \(segment.distalJoint.rawValue) missing, using proximal as fallback (CoM at wrist)")
                    distNode = proxNode
                } else {
                    print("⚠️ Missing distal joint for binding: \(segment.distalJoint.rawValue)")
                    missingCount += 1
                    continue
                }
            }

            boundSegments.append(BoundSegment(
                name: segment.name, // Use descriptive segment name
                prox: proxNode,
                dist: distNode!,
                baseMassRatio: segment.massRatio,
                currentMassRatio: segment.massRatio,
                comRatio: segment.comRatio
            ))
        }

        applyPresetMultipliers()

        if missingCount == 0 {
            print("✅ COMCalculator bound to \(boundSegments.count) segments")
        }
    }

    /// Sets the active body preset, which adjusts segment masses (anthropometric multipliers)
    func setPreset(_ preset: BodyPreset) {
        currentPreset = preset
        applyPresetMultipliers()
    }

    private func applyPresetMultipliers() {
        guard !boundSegments.isEmpty else { return }

        let trunkMultiplier: Double
        let upperMultiplier: Double
        let lowerMultiplier: Double

        switch currentPreset {
        case .averageNeutral:
            trunkMultiplier = 1.0
            upperMultiplier = 1.0
            lowerMultiplier = 1.0
        case .athleticFemale:
            trunkMultiplier = 0.95
            upperMultiplier = 0.95
            lowerMultiplier = 1.08
        case .athleticMale:
            trunkMultiplier = 1.05
            upperMultiplier = 1.15
            lowerMultiplier = 0.95
        }

        var totalMassRatio: Double = 0

        for i in 0..<boundSegments.count {
            let name = boundSegments[i].name
            var multiplier = 1.0

            if name.contains("Pelvis") || name.contains("Abdomen") || name.contains("Thorax") || name.contains("Head") {
                multiplier = trunkMultiplier
            } else if name.contains("Arm") || name.contains("Forearm") || name.contains("Hand") {
                multiplier = upperMultiplier
            } else if name.contains("Thigh") || name.contains("Shank") || name.contains("Foot") {
                multiplier = lowerMultiplier
            }

            boundSegments[i].currentMassRatio = boundSegments[i].baseMassRatio * multiplier
            totalMassRatio += boundSegments[i].currentMassRatio
        }

        // Normalize so they sum to exactly 1.0
        if totalMassRatio > 0 {
            for i in 0..<boundSegments.count {
                boundSegments[i].currentMassRatio /= totalMassRatio
            }
        }
    }

    /// Optimized calculation using bound nodes directly.
    func calculateBodyCOM() -> SCNVector3 {
        return calculateDetailedBodyCOM(detailed: false).totalCOM
    }

    /// Detailed calculation returning segment data.
    /// CoM Formula: Σ(segmentMass * segmentCOMWorld) / Σ(segmentMass)
    /// - Parameter detailed: If false, segmentCOMs will be empty to save allocations.
    func calculateDetailedBodyCOM(detailed: Bool = true) -> CalculationResult {
        // Fallback or warning if not bound?
        if boundSegments.isEmpty {
             print("⚠️ COMCalculator: No segments bound. Did you call bind(jointNodes:)?")
             return CalculationResult(totalCOM: SCNVector3Zero, segmentCOMs: [])
        }

        var totalWeighted = SCNVector3Zero
        var totalMass: Double = 0

        // Only allocate array if detailed results are requested
        var segmentResults: [SegmentResult] = []
        if detailed {
            segmentResults.reserveCapacity(boundSegments.count)
        }

        for segment in boundSegments {
            // Direct property access is faster than dictionary lookup
            let proxPos = segment.prox.presentation.worldPosition
            let distPos = segment.dist.presentation.worldPosition

            // COM = proximal + (distal - proximal) * %
            let segCOM = proxPos + ((distPos - proxPos) * Float(segment.comRatio))
            let segMass = bodyMass * segment.currentMassRatio

            totalWeighted = totalWeighted + (segCOM * Float(segMass))
            totalMass += segMass

            if detailed {
                segmentResults.append(SegmentResult(
                    name: segment.name,
                    position: segCOM,
                    mass: segMass,
                    proxPosition: proxPos,
                    distPosition: distPos
                ))
            }
        }

        // CoM Calculation: Sum(segMass * segCOM) / TotalMass
        let totalCOM = totalMass > 0 ? (totalWeighted * Float(1.0 / totalMass)) : SCNVector3Zero
        return CalculationResult(totalCOM: totalCOM, segmentCOMs: segmentResults)
    }
}

// MARK: - SCNVector3 Extensions

extension SCNVector3 {
    static func + (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
        return SCNVector3(l.x + r.x, l.y + r.y, l.z + r.z)
    }

    static func - (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
        return SCNVector3(l.x - r.x, l.y - r.y, l.z - r.z)
    }

    static func * (v: SCNVector3, s: Float) -> SCNVector3 {
        return SCNVector3(v.x * s, v.y * s, v.z * s)
    }
}
// Baseline audit verified: COMCalculator uses 17-segment anthropometric model
