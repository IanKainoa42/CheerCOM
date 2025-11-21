import SceneKit
import UIKit

class VisualizationsManager {
    var comMarker: SCNNode!
    var comTrailNode: SCNNode!
    var gravityLineNode: SCNNode!
    var bosNode: SCNNode!
    var gridNode: SCNNode!

    var showAdvancedVisualizations = false
    var trailPositions: [SCNVector3] = []
    let maxTrailPoints = 50

    weak var sceneManager: CheerCOMSceneManager?

    init(scene: SCNScene, sceneManager: CheerCOMSceneManager) {
        self.sceneManager = sceneManager
        setupVisuals(in: scene)
    }

    private func setupVisuals(in scene: SCNScene) {
        setupCOMMarker(in: scene)
        setupCOMTrail(in: scene)
        setupVisualAids(in: scene)
    }

    private func setupCOMMarker(in scene: SCNScene) {
        let sphere = SCNSphere(radius: 8)
        sphere.firstMaterial?.diffuse.contents = UIColor.green
        sphere.firstMaterial?.emission.contents = UIColor.green.withAlphaComponent(0.5)
        sphere.firstMaterial?.lightingModel = .constant

        comMarker = SCNNode(geometry: sphere)
        scene.rootNode.addChildNode(comMarker)

        print("🔴 COM marker created")
    }

    private func setupCOMTrail(in scene: SCNScene) {
        comTrailNode = SCNNode()
        scene.rootNode.addChildNode(comTrailNode)
        print("🔵 COM trail initialized")
    }

    private func setupVisualAids(in scene: SCNScene) {
        // Gravity Line
        let line = SCNCylinder(radius: 0.5, height: 1.0)
        line.firstMaterial?.diffuse.contents = UIColor.white
        gravityLineNode = SCNNode(geometry: line)
        gravityLineNode.isHidden = true
        scene.rootNode.addChildNode(gravityLineNode)

        // Base of Support
        bosNode = SCNNode()
        bosNode.isHidden = true
        scene.rootNode.addChildNode(bosNode)

        // Grid
        gridNode = SCNNode()
        let plane1 = SCNPlane(width: 300, height: 300)
        plane1.firstMaterial?.diffuse.contents = UIColor.purple.withAlphaComponent(0.3)
        plane1.firstMaterial?.isDoubleSided = true
        let planeNode1 = SCNNode(geometry: plane1)

        let plane2 = SCNPlane(width: 300, height: 300)
        plane2.firstMaterial?.diffuse.contents = UIColor.purple.withAlphaComponent(0.3)
        plane2.firstMaterial?.isDoubleSided = true
        let planeNode2 = SCNNode(geometry: plane2)
        planeNode2.eulerAngles.y = .pi / 2

        gridNode.addChildNode(planeNode1)
        gridNode.addChildNode(planeNode2)
        gridNode.isHidden = true
        scene.rootNode.addChildNode(gridNode)
    }

    func updateCOM(position: SCNVector3) {
        comMarker.position = position

        // Update trail
        trailPositions.append(position)
        if trailPositions.count > maxTrailPoints {
            trailPositions.removeFirst()
        }
        updateTrailVisualizationOptimized()

        // Update advanced visualizations if needed
        if showAdvancedVisualizations {
            updateGravityLine()
            gridNode.position = SCNVector3(comMarker.position.x, 150, comMarker.position.z)

            // Stability Analysis
            let (margin, isStable) = calculateStabilityMargin(com: position)
            updateStabilityVisuals(margin: margin, isStable: isStable)

            if !isStable {
                highlightUnstableSegments(com: position)
            } else {
                resetSegmentHighlights()
            }
        }
    }

    func toggleVisualizations() {
        showAdvancedVisualizations.toggle()

        gravityLineNode.isHidden = !showAdvancedVisualizations
        bosNode.isHidden = !showAdvancedVisualizations
        gridNode.isHidden = !showAdvancedVisualizations

        // Update visualizations if turning on
        if showAdvancedVisualizations {
            updateGravityLine()
            updateBOS()
        } else {
            resetSegmentHighlights()
        }
    }

    private func updateGravityLine() {
        let comPosition = comMarker.position

        guard let cylinder = gravityLineNode.geometry as? SCNCylinder else { return }
        cylinder.height = CGFloat(comPosition.y)

        gravityLineNode.position = SCNVector3(comPosition.x, comPosition.y / 2, comPosition.z)
    }

    func updateBOS() {
        bosNode.childNodes.forEach { $0.removeFromParentNode() }

        guard let points = getBOSPoints() else { return }

        let path = UIBezierPath()
        path.move(to: points[0])
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        path.close()

        let shape = SCNShape(path: path, extrusionDepth: 0)
        shape.firstMaterial?.diffuse.contents = UIColor.green.withAlphaComponent(0.3)
        shape.firstMaterial?.isDoubleSided = true

        let node = SCNNode(geometry: shape)
        node.eulerAngles.x = -.pi / 2

        // Add outline
        let outline = SCNNode(geometry: shape)
        outline.geometry?.firstMaterial?.fillMode = .lines
        outline.geometry?.firstMaterial?.diffuse.contents = UIColor.white
        outline.position.y = 0.1  // Slightly above to avoid z-fighting
        node.addChildNode(outline)

        bosNode.addChildNode(node)
    }

    private func getBOSPoints() -> [CGPoint]? {
        guard let sceneManager = sceneManager,
            let leftFoot = sceneManager.findBone(named: "mixamorig_LeftFoot"),
            let rightFoot = sceneManager.findBone(named: "mixamorig_RightFoot"),
            let leftToe = sceneManager.findBone(named: "mixamorig_LeftToeBase"),
            let rightToe = sceneManager.findBone(named: "mixamorig_RightToeBase")
        else {
            return nil
        }

        let lf = CGPoint(x: CGFloat(leftFoot.worldPosition.x), y: CGFloat(leftFoot.worldPosition.z))
        let rf = CGPoint(
            x: CGFloat(rightFoot.worldPosition.x), y: CGFloat(rightFoot.worldPosition.z))
        let lt = CGPoint(x: CGFloat(leftToe.worldPosition.x), y: CGFloat(leftToe.worldPosition.z))
        let rt = CGPoint(x: CGFloat(rightToe.worldPosition.x), y: CGFloat(rightToe.worldPosition.z))

        // Order points to form a convex hull (simplified for feet)
        // Assuming standard stance: LF -> RF -> RT -> LT
        return [lf, rf, rt, lt]
    }

    private func updateTrailVisualizationOptimized() {
        let currentNodes = comTrailNode.childNodes
        let needed = trailPositions.count
        let existing = currentNodes.count

        // Add new nodes if we need more
        if existing < needed {
            for _ in existing..<needed {
                let sphere = SCNSphere(radius: 2)
                sphere.firstMaterial?.diffuse.contents = UIColor.cyan
                sphere.firstMaterial?.lightingModel = .constant
                let node = SCNNode(geometry: sphere)
                comTrailNode.addChildNode(node)
            }
        }
        // Remove excess nodes if we have too many
        else if existing > needed {
            for i in (needed..<existing).reversed() {
                currentNodes[i].removeFromParentNode()
            }
        }

        // Update positions and alpha for all nodes
        for (i, pos) in trailPositions.enumerated() {
            let node = comTrailNode.childNodes[i]
            node.position = pos

            // Update alpha
            let alpha = Float(i + 1) / Float(trailPositions.count)
            if let material = node.geometry?.firstMaterial {
                material.diffuse.contents = UIColor.cyan.withAlphaComponent(CGFloat(alpha))
            }
        }
    }

    // MARK: - Stability Analysis

    /// Calculates the margin of stability (distance from COM to nearest BOS edge)
    /// Returns: (margin: Float, isStable: Bool)
    func calculateStabilityMargin(com: SCNVector3) -> (Float, Bool) {
        guard let points = getBOSPoints() else { return (0, false) }

        let comPoint = CGPoint(x: CGFloat(com.x), y: CGFloat(com.z))

        // Check if inside polygon
        var isInside = false
        var j = points.count - 1
        for i in 0..<points.count {
            if (points[i].y > comPoint.y) != (points[j].y > comPoint.y)
                && (comPoint.x < (points[j].x - points[i].x) * (comPoint.y - points[i].y)
                    / (points[j].y - points[i].y) + points[i].x)
            {
                isInside = !isInside
            }
            j = i
        }

        // Calculate distance to nearest edge
        var minDistance: CGFloat = .greatestFiniteMagnitude

        for i in 0..<points.count {
            let p1 = points[i]
            let p2 = points[(i + 1) % points.count]

            let distance = distanceToSegment(p: comPoint, v: p1, w: p2)
            if distance < minDistance {
                minDistance = distance
            }
        }

        return (Float(minDistance), isInside)
    }

    private func distanceToSegment(p: CGPoint, v: CGPoint, w: CGPoint) -> CGFloat {
        let l2 = pow(v.x - w.x, 2) + pow(v.y - w.y, 2)
        if l2 == 0 { return hypot(p.x - v.x, p.y - v.y) }

        var t = ((p.x - v.x) * (w.x - v.x) + (p.y - v.y) * (w.y - v.y)) / l2
        t = max(0, min(1, t))

        let projection = CGPoint(x: v.x + t * (w.x - v.x), y: v.y + t * (w.y - v.y))
        return hypot(p.x - projection.x, p.y - projection.y)
    }

    private func updateStabilityVisuals(margin: Float, isStable: Bool) {
        guard let material = comMarker.geometry?.firstMaterial else { return }

        if !isStable {
            material.diffuse.contents = UIColor.red
            material.emission.contents = UIColor.red
        } else if margin < 10.0 {  // Warning threshold
            material.diffuse.contents = UIColor.yellow
            material.emission.contents = UIColor.yellow
        } else {
            material.diffuse.contents = UIColor.green
            material.emission.contents = UIColor.green
        }

        // Update gravity line color
        if let lineMat = gravityLineNode.geometry?.firstMaterial {
            lineMat.diffuse.contents = material.diffuse.contents
        }
    }

    // MARK: - Segment Analysis

    func highlightUnstableSegments(com: SCNVector3) {
        guard let sceneManager = sceneManager else { return }

        // Calculate direction of instability (COM relative to BOS center)
        guard let points = getBOSPoints() else { return }
        let bosCenter = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        let center = CGPoint(
            x: bosCenter.x / CGFloat(points.count), y: bosCenter.y / CGFloat(points.count))

        let comPoint = CGPoint(x: CGFloat(com.x), y: CGFloat(com.z))
        let instabilityVector = CGPoint(x: comPoint.x - center.x, y: comPoint.y - center.y)

        // Find segments that are furthest in the direction of instability
        var maxDotProduct: Float = -Float.greatestFiniteMagnitude
        var mostUnstableNode: SCNNode?

        for (name, node) in sceneManager.cachedBoneNodes {
            // Skip feet as they are the base
            if name.contains("Foot") || name.contains("Toe") { continue }

            let nodePos = CGPoint(
                x: CGFloat(node.worldPosition.x), y: CGFloat(node.worldPosition.z))
            let nodeVector = CGPoint(x: nodePos.x - center.x, y: nodePos.y - center.y)

            // Dot product to find alignment with instability
            let dot = Float(nodeVector.x * instabilityVector.x + nodeVector.y * instabilityVector.y)

            if dot > maxDotProduct {
                maxDotProduct = dot
                mostUnstableNode = node
            }
        }

        // Highlight the most unstable node and its parent (limb)
        if let node = mostUnstableNode {
            highlightNode(node, color: .red)
            if let parent = node.parent, parent.name?.contains("mixamorig") == true {
                highlightNode(parent, color: .red)
            }
        }
    }

    private func highlightNode(_ node: SCNNode, color: UIColor) {
        node.geometry?.firstMaterial?.emission.contents = color
    }

    func resetSegmentHighlights() {
        guard let sceneManager = sceneManager else { return }

        for (_, node) in sceneManager.cachedBoneNodes {
            node.geometry?.firstMaterial?.emission.contents = UIColor.black
        }
    }
}
