import SceneKit
import UIKit
import ModelRigKit


class VisualizationsManager {
    struct CircularVector3Buffer: RandomAccessCollection {
        private var buffer: [SCNVector3]
        private var head: Int = 0
        let capacity: Int

        init(capacity: Int) {
            self.capacity = capacity
            self.buffer = []
            self.buffer.reserveCapacity(capacity)
        }

        var startIndex: Int { 0 }
        var endIndex: Int { buffer.count }

        var count: Int {
            return buffer.count
        }

        mutating func append(_ element: SCNVector3) {
            if buffer.count < capacity {
                buffer.append(element)
            } else {
                buffer[head] = element
                head = (head + 1) % capacity
            }
        }

        subscript(index: Int) -> SCNVector3 {
            if buffer.count < capacity {
                return buffer[index]
            }
            return buffer[(head + index) % capacity]
        }

        func index(after i: Int) -> Int {
            return i + 1
        }

        func index(before i: Int) -> Int {
            return i - 1
        }
    }

    var comMarker: SCNNode!
    var comTrailNode: SCNNode!
    var gravityLineNode: SCNNode!
    var bosNode: SCNNode!
    var gridNode: SCNNode!
    var axesNode: SCNNode!
    var segmentCOMNodes: SCNNode!

    // Caches to avoid accessing sceneKit's childNodes property, which reallocates an array every time
    private var cachedSegmentNodes: [SCNNode] = []
    private var cachedTrailNodes: [SCNNode] = []
    private var cachedBosNodes: [SCNNode] = []

    var showAdvancedVisualizations = false {
        didSet {
            // Update visibility of nodes when property changes
            gravityLineNode.isHidden = !showAdvancedVisualizations
            bosNode.isHidden = !showAdvancedVisualizations
            gridNode.isHidden = !showAdvancedVisualizations
            axesNode.isHidden = !showAdvancedVisualizations
            segmentCOMNodes.isHidden = !showAdvancedVisualizations

            if showAdvancedVisualizations {
                updateGravityLine()
                updateBOS()
            } else {
                resetSegmentHighlights()
            }
        }
    }
    static let maxTrailPoints = 50
    var trailPositions = CircularVector3Buffer(capacity: VisualizationsManager.maxTrailPoints)

    weak var sceneManager: CheerCOMSceneManager?

    // Cache for BOS nodes to avoid repeated lookups
    private var leftFootNode: SCNNode?
    private var rightFootNode: SCNNode?
    private var leftToeNode: SCNNode?
    private var rightToeNode: SCNNode?

    init(scene: SCNScene, sceneManager: CheerCOMSceneManager) {
        self.sceneManager = sceneManager
        setupVisuals(in: scene)
    }

    private func setupVisuals(in scene: SCNScene) {
        setupCOMMarker(in: scene)
        setupSegmentMarkers(in: scene)
        setupCOMTrail(in: scene)
        setupVisualAids(in: scene)
        setupAxes(in: scene)
    }

    private func setupAxes(in scene: SCNScene) {
        axesNode = SCNNode()

        // X Axis (Red)
        let xGeo = SCNCylinder(radius: 0.2, height: 50)
        xGeo.firstMaterial?.diffuse.contents = UIColor.red
        let xNode = SCNNode(geometry: xGeo)
        xNode.position = SCNVector3(25, 0, 0)
        xNode.eulerAngles.z = -.pi / 2
        axesNode.addChildNode(xNode)

        // Y Axis (Green)
        let yGeo = SCNCylinder(radius: 0.2, height: 50)
        yGeo.firstMaterial?.diffuse.contents = UIColor.green
        let yNode = SCNNode(geometry: yGeo)
        yNode.position = SCNVector3(0, 25, 0)
        axesNode.addChildNode(yNode)

        // Z Axis (Blue)
        let zGeo = SCNCylinder(radius: 0.2, height: 50)
        zGeo.firstMaterial?.diffuse.contents = UIColor.blue
        let zNode = SCNNode(geometry: zGeo)
        zNode.position = SCNVector3(0, 0, 25)
        zNode.eulerAngles.x = .pi / 2
        axesNode.addChildNode(zNode)

        axesNode.isHidden = true
        scene.rootNode.addChildNode(axesNode)
    }

    private func setupCOMMarker(in scene: SCNScene) {
        // Visible CoM marker
        let sphere = SCNSphere(radius: 10) // Slightly larger to make it very prominent
        sphere.firstMaterial?.diffuse.contents = UIColor.green
        sphere.firstMaterial?.emission.contents = UIColor.green.withAlphaComponent(0.6)
        sphere.firstMaterial?.lightingModel = .constant

        comMarker = SCNNode(geometry: sphere)
        scene.rootNode.addChildNode(comMarker)

        print("🔴 Visible COM marker created")
    }

    private func setupSegmentMarkers(in scene: SCNScene) {
        segmentCOMNodes = SCNNode()
        scene.rootNode.addChildNode(segmentCOMNodes)
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

        // Axes Indicator
        axesNode = SCNNode()
        axesNode.isHidden = true
        scene.rootNode.addChildNode(axesNode)

        // X Axis (Red)
        let xBox = SCNBox(width: 50, height: 1, length: 1, chamferRadius: 0)
        xBox.firstMaterial?.diffuse.contents = UIColor.red
        let xNode = SCNNode(geometry: xBox)
        xNode.position = SCNVector3(25, 0, 0)
        axesNode.addChildNode(xNode)

        // Y Axis (Green)
        let yBox = SCNBox(width: 1, height: 50, length: 1, chamferRadius: 0)
        yBox.firstMaterial?.diffuse.contents = UIColor.green
        let yNode = SCNNode(geometry: yBox)
        yNode.position = SCNVector3(0, 25, 0)
        axesNode.addChildNode(yNode)

        // Z Axis (Blue)
        let zBox = SCNBox(width: 1, height: 1, length: 50, chamferRadius: 0)
        zBox.firstMaterial?.diffuse.contents = UIColor.blue
        let zNode = SCNNode(geometry: zBox)
        zNode.position = SCNVector3(0, 0, 25)
        axesNode.addChildNode(zNode)
    }

    func updateCOM(result: CalculationResult) {
        let position = result.totalCOM
        comMarker.position = position

        // Update Segment COMs
        updateSegmentVisuals(segmentResults: result.segmentCOMs)

        // Update trail
        trailPositions.append(position)
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

    private func updateSegmentVisuals(segmentResults: [SegmentResult]) {
        // Clear existing nodes if count mismatch (simple approach) or update them
        // For performance, we should reuse nodes.

        // Ensure we have enough nodes
        if cachedSegmentNodes.count < segmentResults.count {
            for _ in cachedSegmentNodes.count..<segmentResults.count {
                let sphere = SCNSphere(radius: 3) // Smaller than main COM
                sphere.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(0.8)
                sphere.firstMaterial?.lightingModel = .constant
                let node = SCNNode(geometry: sphere)
                segmentCOMNodes.addChildNode(node)
                cachedSegmentNodes.append(node)
            }
        }

        // Update positions
        for (index, result) in segmentResults.enumerated() {
            if index < cachedSegmentNodes.count {
                // Use cached currentNodes to avoid repeated childNodes array creation
                let node = cachedSegmentNodes[index]
                node.position = result.position
                node.isHidden = !showAdvancedVisualizations // Only show in advanced mode?
            }
        }

        // Hide extra nodes if any
        if cachedSegmentNodes.count > segmentResults.count {
            for index in segmentResults.count..<cachedSegmentNodes.count {
                cachedSegmentNodes[index].isHidden = true
            }
        }
    }

    func toggleVisualizations() {
        showAdvancedVisualizations.toggle()
    }

    private func updateGravityLine() {
        let comPosition = comMarker.position

        guard let cylinder = gravityLineNode.geometry as? SCNCylinder else { return }
        cylinder.height = CGFloat(comPosition.y)

        gravityLineNode.position = SCNVector3(comPosition.x, comPosition.y / 2, comPosition.z)
    }

    func updateBOS() {
        for node in cachedBosNodes {
            node.removeFromParentNode()
        }
        cachedBosNodes.removeAll()

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
        cachedBosNodes.append(node)
    }

    private func getBOSPoints() -> [CGPoint]? {
        // Initialize cache if needed
        if leftFootNode == nil {
            guard let sceneManager = sceneManager else { return nil }
            leftFootNode = sceneManager.findBone(.leftFoot)
            rightFootNode = sceneManager.findBone(.rightFoot)
            leftToeNode = sceneManager.findBone(.leftToeBase)
            rightToeNode = sceneManager.findBone(.rightToeBase)
        }

        guard let leftFoot = leftFootNode,
            let rightFoot = rightFootNode,
            let leftToe = leftToeNode,
            let rightToe = rightToeNode
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
        let needed = trailPositions.count
        let existing = cachedTrailNodes.count

        // Add new nodes if we need more
        if existing < needed {
            for _ in existing..<needed {
                let sphere = SCNSphere(radius: 2)
                sphere.firstMaterial?.diffuse.contents = UIColor.cyan
                sphere.firstMaterial?.lightingModel = .constant
                let node = SCNNode(geometry: sphere)
                comTrailNode.addChildNode(node)
                cachedTrailNodes.append(node)
            }
        }
        // Remove excess nodes if we have too many
        else if existing > needed {
            for i in (needed..<existing).reversed() {
                cachedTrailNodes[i].removeFromParentNode()
                cachedTrailNodes.remove(at: i)
            }
        }

        // Update positions and alpha for all nodes
        for (i, pos) in trailPositions.enumerated() {
            // Use cached currentNodes to avoid repeated childNodes array creation
            let node = cachedTrailNodes[i]
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
        var minDistanceSq: CGFloat = .greatestFiniteMagnitude

        for i in 0..<points.count {
            let p1 = points[i]
            let p2 = points[(i + 1) % points.count]

            let distSq = distanceSquaredToSegment(p: comPoint, v: p1, w: p2)
            if distSq < minDistanceSq {
                minDistanceSq = distSq
            }
        }

        return (Float(sqrt(minDistanceSq)), isInside)
    }

    private func distanceSquaredToSegment(p: CGPoint, v: CGPoint, w: CGPoint) -> CGFloat {
        let dvx = v.x - w.x
        let dvy = v.y - w.y
        let l2 = dvx * dvx + dvy * dvy
        if l2 == 0 {
            let dpx = p.x - v.x
            let dpy = p.y - v.y
            return dpx * dpx + dpy * dpy
        }

        var t = ((p.x - v.x) * (w.x - v.x) + (p.y - v.y) * (w.y - v.y)) / l2
        t = max(0, min(1, t))

        let projX = v.x + t * (w.x - v.x)
        let projY = v.y + t * (w.y - v.y)
        let dpx = p.x - projX
        let dpy = p.y - projY
        return dpx * dpx + dpy * dpy
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

        for (_, node) in sceneManager.cachedBoneNodes {
            if sceneManager.feetAndToes.contains(node) { continue }

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
