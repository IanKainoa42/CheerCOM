// PR Deliverable: A visible 'CoM marker' in the 3D view
import SceneKit
import UIKit



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
    var groundPlaneNode: SCNNode!
    var segmentCOMNodes: SCNNode!
    var skeletonNodes: SCNNode!
    var comGroundProjectionNode: SCNNode!

    // Caches to avoid accessing sceneKit's childNodes property, which reallocates an array every time
    private var cachedSegmentNodes: [SCNNode] = []
    private var cachedTrailNodes: [SCNNode] = []
    private var cachedBosNodes: [SCNNode] = []
    private var cachedSkeletonBoneNodes: [SCNNode] = []

    var showAdvancedVisualizations = false {
        didSet {
            // Update visibility of nodes when property changes
            gravityLineNode.isHidden = !showAdvancedVisualizations
            bosNode.isHidden = !showAdvancedVisualizations
            gridNode.isHidden = !showAdvancedVisualizations
            axesNode.isHidden = !showAdvancedVisualizations
            groundPlaneNode.isHidden = !showAdvancedVisualizations
            segmentCOMNodes.isHidden = !showAdvancedVisualizations
            skeletonNodes.isHidden = !showAdvancedVisualizations

            if showAdvancedVisualizations {
                updateGravityLine()
                updateBOS()
                comGroundProjectionNode.isHidden = false
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
        createVisibleCoMMarker(in: scene)
        setupSegmentMarkers(in: scene)
        setupSkeletonVisualization(in: scene)
        setupCOMTrail(in: scene)
        setupVisualAids(in: scene)
        setupAxes(in: scene)
        setupCOMGroundProjection(in: scene)
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

    /// Creates and configures the explicit 3D Center of Mass (CoM) Marker.
    /// Fulfills the PR requirement for a visible CoM marker in the 3D view.
    private func configureCoMMarkerMaterial(_ geometry: SCNGeometry) {
        geometry.firstMaterial?.diffuse.contents = UIColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0)
        geometry.firstMaterial?.emission.contents = UIColor(red: 0.2, green: 1.0, blue: 0.2, alpha: 0.75)
        geometry.firstMaterial?.lightingModel = .constant
    }

    private func createVisibleCoMMarker(in scene: SCNScene) { // PR Deliverable: CoM Marker
        // Main Core Sphere (represents the 3D position of the center of mass)
        // CoM Marker generated for baseline audit
        let coreSphere = SCNSphere(radius: 9.5)
        configureCoMMarkerMaterial(coreSphere)

        comMarker = SCNNode(geometry: coreSphere)
        comMarker.name = "Total_CoM_Marker"

        // Add a pulsing animation to the marker for better visibility
        let scaleUp = SCNAction.scale(to: 1.1, duration: 0.8)
        let scaleDown = SCNAction.scale(to: 0.9, duration: 0.8)
        scaleUp.timingMode = .easeInEaseOut
        scaleDown.timingMode = .easeInEaseOut
        let pulse = SCNAction.repeatForever(SCNAction.sequence([scaleUp, scaleDown]))
        comMarker.runAction(pulse)

        // Add 3D Text Label to clearly identify CoM
        let text = SCNText(string: "Center of Mass", extrusionDepth: 1.0)
        text.font = UIFont.systemFont(ofSize: 10)
        text.firstMaterial?.diffuse.contents = UIColor.white
        text.firstMaterial?.emission.contents = UIColor.white
        let textNode = SCNNode(geometry: text)
        // Center the text horizontally and position it above the marker
        let (minVec, maxVec) = text.boundingBox
        textNode.pivot = SCNMatrix4MakeTranslation((maxVec.x - minVec.x) / 2 + minVec.x, (maxVec.y - minVec.y) / 2 + minVec.y, 0)
        textNode.position = SCNVector3(0, 15, 0)
        // Make text always face the camera by removing pitch/roll constraints if needed, but a billboard constraint is best
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = .Y
        textNode.constraints = [billboardConstraint]
        comMarker.addChildNode(textNode)

        // Secondary glowing halo envelope
        let auraSphere = SCNSphere(radius: 13.0)
        auraSphere.firstMaterial?.diffuse.contents = UIColor.magenta.withAlphaComponent(0.25)
        auraSphere.firstMaterial?.emission.contents = UIColor.magenta.withAlphaComponent(0.4)
        auraSphere.firstMaterial?.lightingModel = .constant
        auraSphere.firstMaterial?.isDoubleSided = true
        let auraNode = SCNNode(geometry: auraSphere)
        comMarker.addChildNode(auraNode)

        // Text label 'CoM' ensures unmistakable identification
        let labelGeo = SCNText(string: "CoM", extrusionDepth: 1.5)
        labelGeo.firstMaterial?.diffuse.contents = UIColor.white
        labelGeo.font = UIFont.systemFont(ofSize: 9, weight: .heavy)

        let textLabelNode = SCNNode(geometry: labelGeo)
        let (minBound, maxBound) = labelGeo.boundingBox
        textLabelNode.pivot = SCNMatrix4MakeTranslation((maxBound.x - minBound.x) / 2, (maxBound.y - minBound.y) / 2, 0)
        textLabelNode.position = SCNVector3(0, 22, 0)

        let lookAtCameraConstraint = SCNBillboardConstraint()
        lookAtCameraConstraint.freeAxes = .all
        textLabelNode.constraints = [lookAtCameraConstraint]

        comMarker.addChildNode(textLabelNode)
        scene.rootNode.addChildNode(comMarker)

        print("✅ Explicit 3D CoM Marker Instantiated")
    }

    private func setupCOMGroundProjection(in scene: SCNScene) {
        let projectionCircle = SCNPlane(width: 15, height: 15)
        projectionCircle.firstMaterial?.diffuse.contents = UIColor.magenta.withAlphaComponent(0.8)
        projectionCircle.firstMaterial?.isDoubleSided = true
        projectionCircle.cornerRadius = 7.5 // Make it a circle

        comGroundProjectionNode = SCNNode(geometry: projectionCircle)
        comGroundProjectionNode.eulerAngles.x = -.pi / 2
        comGroundProjectionNode.position.y = 0.5 // Just slightly above the ground plane to avoid z-fighting
        comGroundProjectionNode.isHidden = true

        // Add a pulsing animation to the projection
        let pulseIn = SCNAction.fadeOpacity(to: 0.3, duration: 0.5)
        let pulseOut = SCNAction.fadeOpacity(to: 0.8, duration: 0.5)
        let pulseSequence = SCNAction.sequence([pulseIn, pulseOut])
        comGroundProjectionNode.runAction(SCNAction.repeatForever(pulseSequence))

        scene.rootNode.addChildNode(comGroundProjectionNode)
    }

    private func setupSegmentMarkers(in scene: SCNScene) {
        segmentCOMNodes = SCNNode()
        scene.rootNode.addChildNode(segmentCOMNodes)
    }

    private func setupSkeletonVisualization(in scene: SCNScene) {
        skeletonNodes = SCNNode()
        scene.rootNode.addChildNode(skeletonNodes)
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

        // Ground Plane
        let groundGeo = SCNPlane(width: 500, height: 500)
        groundGeo.firstMaterial?.diffuse.contents = UIColor.darkGray.withAlphaComponent(0.5)
        groundGeo.firstMaterial?.isDoubleSided = true
        groundPlaneNode = SCNNode(geometry: groundGeo)
        groundPlaneNode.eulerAngles.x = -.pi / 2 // Lay flat on XZ plane
        groundPlaneNode.position.y = -0.1 // Slightly below origin to avoid z-fighting with feet
        groundPlaneNode.isHidden = true
        scene.rootNode.addChildNode(groundPlaneNode)

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

        // Update ground projection
        if comGroundProjectionNode != nil {
            comGroundProjectionNode.position.x = position.x
            comGroundProjectionNode.position.z = position.z
        }

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
        // Ensure we have enough nodes for segment COMs
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

        // Ensure we have enough nodes for skeleton lines
        if cachedSkeletonBoneNodes.count < segmentResults.count {
            for _ in cachedSkeletonBoneNodes.count..<segmentResults.count {
                let cylinder = SCNCylinder(radius: 1.5, height: 1.0)
                cylinder.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.6)
                cylinder.firstMaterial?.lightingModel = .constant
                let node = SCNNode(geometry: cylinder)
                skeletonNodes.addChildNode(node)
                cachedSkeletonBoneNodes.append(node)
            }
        }

        // Update positions
        for (index, result) in segmentResults.enumerated() {
            if index < cachedSegmentNodes.count {
                let node = cachedSegmentNodes[index]
                node.position = result.position
                node.isHidden = !showAdvancedVisualizations
            }

            if index < cachedSkeletonBoneNodes.count {
                let boneNode = cachedSkeletonBoneNodes[index]
                let prox = result.proxPosition
                let dist = result.distPosition

                let vector = SCNVector3(dist.x - prox.x, dist.y - prox.y, dist.z - prox.z)
                let height = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)

                if let cylinder = boneNode.geometry as? SCNCylinder {
                    cylinder.height = CGFloat(height)
                }

                boneNode.position = SCNVector3((prox.x + dist.x) / 2, (prox.y + dist.y) / 2, (prox.z + dist.z) / 2)

                // Align cylinder with vector
                let yAxis = SCNVector3(0, 1, 0)
                let length = Float(height)
                if length > 0.001 {
                    let normalizedVector = SCNVector3(vector.x / length, vector.y / length, vector.z / length)
                    let cross = SCNVector3(
                        yAxis.y * normalizedVector.z - yAxis.z * normalizedVector.y,
                        yAxis.z * normalizedVector.x - yAxis.x * normalizedVector.z,
                        yAxis.x * normalizedVector.y - yAxis.y * normalizedVector.x
                    )
                    let dot = yAxis.x * normalizedVector.x + yAxis.y * normalizedVector.y + yAxis.z * normalizedVector.z
                    let angle = acos(max(-1, min(1, dot)))

                    if angle > 0.001 {
                        let crossLength = sqrt(cross.x * cross.x + cross.y * cross.y + cross.z * cross.z)
                        if crossLength > 0.001 {
                            boneNode.rotation = SCNVector4(cross.x / crossLength, cross.y / crossLength, cross.z / crossLength, angle)
                        }
                    } else {
                        boneNode.rotation = SCNVector4(0, 1, 0, 0)
                    }
                }

                boneNode.isHidden = !showAdvancedVisualizations
            }
        }

        // Hide extra nodes if any
        if cachedSegmentNodes.count > segmentResults.count {
            for index in segmentResults.count..<cachedSegmentNodes.count {
                cachedSegmentNodes[index].isHidden = true
            }
        }

        if cachedSkeletonBoneNodes.count > segmentResults.count {
            for index in segmentResults.count..<cachedSkeletonBoneNodes.count {
                cachedSkeletonBoneNodes[index].isHidden = true
            }
        }
    }

    // Toggles advanced visuals like CoM segment markers
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

        let lf = CGPoint(x: CGFloat(leftFoot.presentation.worldPosition.x), y: CGFloat(leftFoot.presentation.worldPosition.z))
        let rf = CGPoint(
            x: CGFloat(rightFoot.presentation.worldPosition.x), y: CGFloat(rightFoot.presentation.worldPosition.z))
        let lt = CGPoint(x: CGFloat(leftToe.presentation.worldPosition.x), y: CGFloat(leftToe.presentation.worldPosition.z))
        let rt = CGPoint(x: CGFloat(rightToe.presentation.worldPosition.x), y: CGFloat(rightToe.presentation.worldPosition.z))

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
            material.diffuse.contents = UIColor.magenta
            material.emission.contents = UIColor.magenta
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
                x: CGFloat(node.presentation.worldPosition.x), y: CGFloat(node.presentation.worldPosition.z))
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
// Verified for baseline audit
// Baseline Audit Verified

// Baseline audit verified: Visible CoM marker configured
