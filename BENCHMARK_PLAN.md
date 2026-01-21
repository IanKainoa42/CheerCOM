# Performance Benchmark Plan: COM Calculator Optimization

## Analysis
The current implementation of `calculateBodyCOM` and its usage in `SceneViewController` introduces unnecessary overhead in a hot loop (running at ~30 FPS).

### Current Overhead
1.  **Allocation**: Every frame, `SceneViewController` allocates a new `[String: SCNVector3]` dictionary.
2.  **Iteration**: It iterates over all cached bone nodes (potentially more than needed) to populate this dictionary.
3.  **Lookup**: `COMCalculator` iterates over 14 segments. For each segment, it performs two dictionary lookups using String keys (`prox` and `dist`).
    *   String hashing and equality checks are relatively expensive compared to direct memory access.
    *   Dictionary lookups are O(1) on average but have constant factor overhead.

### Proposed Optimization
1.  **Pre-resolution**: Resolve `SCNNode` references once (at startup) and store them in a list of `BoundSegment` structs.
2.  **Direct Access**: In the render loop, iterate the list of `BoundSegment`s and access `node.worldPosition` directly.
    *   Eliminates dictionary allocation per frame.
    *   Eliminates string hashing and dictionary lookups per segment.
    *   Reduces memory churn (GC pressure).

## Theoretical Benchmark
Since we cannot compile Swift code in the current environment to run a live benchmark, we describe the benchmark methodology that would verify this improvement.

### Methodology
We would create an `XCTestCase` with two performance tests using `measure {}` block.

#### 1. Baseline Benchmark
Simulates the current behavior:
```swift
func testBaselinePerformance() {
    let calculator = COMCalculator(bodyMass: 70.0)
    let nodes = createMockNodes() // Dictionary of [String: SCNNode]

    measure {
        // Simulate what SceneViewController does
        var jointPositions: [String: SCNVector3] = [:]
        for (name, node) in nodes {
            jointPositions[name] = node.worldPosition
        }
        _ = calculator.calculateBodyCOM(jointPositions: jointPositions)
    }
}
```

#### 2. Optimized Benchmark
Simulates the new behavior:
```swift
func testOptimizedPerformance() {
    let calculator = COMCalculator(bodyMass: 70.0)
    let nodes = createMockNodes()
    calculator.bind(jointNodes: nodes) // One-time setup

    measure {
        _ = calculator.calculateBodyCOM()
    }
}
```

### Expected Results
*   **Baseline**: Higher CPU time due to dictionary allocation and hashing.
*   **Optimized**: Significantly lower CPU time (approaching the cost of just the vector math + `worldPosition` access).
*   **Memory**: Reduced transient allocations (no dictionary created per frame).

## Conclusion
This optimization removes O(N) allocations and lookups from the hot path, replacing them with O(1) direct accesses. This is strictly better for both CPU and Memory usage.
