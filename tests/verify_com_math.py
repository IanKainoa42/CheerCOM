# Tests/VerifyCOMMath.py
# This script simulates the COM calculation logic to verify correctness without SceneKit runtime.

import math

class Vector3:
    def __init__(self, x, y, z):
        self.x = x
        self.y = y
        self.z = z

    def __add__(self, other):
        return Vector3(self.x + other.x, self.y + other.y, self.z + other.z)

    def __sub__(self, other):
        return Vector3(self.x - other.x, self.y - other.y, self.z - other.z)

    def __mul__(self, scalar):
        return Vector3(self.x * scalar, self.y * scalar, self.z * scalar)

    def __str__(self):
        return f"({self.x:.3f}, {self.y:.3f}, {self.z:.3f})"

class Node:
    def __init__(self, name, position):
        self.name = name
        self.position = position  # This represents worldPosition

class SegmentResult:
    def __init__(self, name, position, mass):
        self.name = name
        self.position = position
        self.mass = mass

class CalculationResult:
    def __init__(self, totalCOM, segmentCOMs):
        self.totalCOM = totalCOM
        self.segmentCOMs = segmentCOMs

class COMCalculator:
    def __init__(self, body_mass):
        self.body_mass = body_mass

        # Segments Definition (Matches COMCalculator.swift)
        # (name, prox, dist, mass, com)
        self.segments = [
            # Trunk
            ("Pelvis", "mixamorig_Hips", "mixamorig_Spine", 0.146, 0.50),
            ("Abdomen Lower", "mixamorig_Spine", "mixamorig_Spine1", 0.0855, 0.50),
            ("Abdomen Upper", "mixamorig_Spine1", "mixamorig_Spine2", 0.0855, 0.50),
            ("Thorax", "mixamorig_Spine2", "mixamorig_Neck", 0.180, 0.50),
            # Head
            ("Head", "mixamorig_Neck", "mixamorig_Head", 0.081, 0.50),
            # Upper Limbs
            ("R Upper Arm", "mixamorig_RightArm", "mixamorig_RightForeArm", 0.028, 0.44),
            ("R Forearm", "mixamorig_RightForeArm", "mixamorig_RightHand", 0.016, 0.43),
            ("R Hand", "mixamorig_RightHand", "mixamorig_RightHandMiddle1", 0.006, 0.50),
            ("L Upper Arm", "mixamorig_LeftArm", "mixamorig_LeftForeArm", 0.028, 0.44),
            ("L Forearm", "mixamorig_LeftForeArm", "mixamorig_LeftHand", 0.016, 0.43),
            ("L Hand", "mixamorig_LeftHand", "mixamorig_LeftHandMiddle1", 0.006, 0.50),
            # Lower Limbs
            ("R Thigh", "mixamorig_RightUpLeg", "mixamorig_RightLeg", 0.100, 0.43),
            ("R Shank", "mixamorig_RightLeg", "mixamorig_RightFoot", 0.0465, 0.43),
            ("R Foot", "mixamorig_RightFoot", "mixamorig_RightToeBase", 0.0145, 0.50),
            ("L Thigh", "mixamorig_LeftUpLeg", "mixamorig_LeftLeg", 0.100, 0.43),
            ("L Shank", "mixamorig_LeftLeg", "mixamorig_LeftFoot", 0.0465, 0.43),
            ("L Foot", "mixamorig_LeftFoot", "mixamorig_LeftToeBase", 0.0145, 0.50),
        ]

        self.bound_segments = []

    def bind(self, joint_nodes):
        self.bound_segments = []

        for name, prox_name, dist_name, mass, com in self.segments:
            prox_node = joint_nodes.get(prox_name)
            if not prox_node:
                print(f"⚠️ Missing proximal joint: {prox_name}")
                continue

            dist_node = joint_nodes.get(dist_name)
            if not dist_node:
                # Fallback logic for Hand
                if "Hand" in name:
                    print(f"⚠️ Hand distal {dist_name} missing, using proximal as fallback (CoM at wrist)")
                    dist_node = prox_node
                else:
                    print(f"⚠️ Missing distal joint: {dist_name}")
                    continue

            self.bound_segments.append({
                "name": name,
                "prox": prox_node,
                "dist": dist_node,
                "mass_ratio": mass,
                "com_ratio": com
            })

    def calculate_detailed_body_com(self):
        total_weighted = Vector3(0, 0, 0)
        total_mass = 0.0
        segment_results = []

        for segment in self.bound_segments:
            prox_pos = segment["prox"].position
            dist_pos = segment["dist"].position

            # COM = prox + (dist - prox) * com_ratio
            vec = dist_pos - prox_pos
            seg_com = prox_pos + (vec * segment["com_ratio"])
            seg_mass = self.body_mass * segment["mass_ratio"]

            total_weighted = total_weighted + (seg_com * seg_mass)
            total_mass += seg_mass

            segment_results.append(SegmentResult(segment["name"], seg_com, seg_mass))

        if total_mass > 0:
            total_com = total_weighted * (1.0 / total_mass)
        else:
            total_com = Vector3(0, 0, 0)

        return CalculationResult(total_com, segment_results)

def run_verification():
    print("🧪 Running Python CoM Verification...")

    calculator = COMCalculator(body_mass=70.0)
    nodes = {}

    # Setup mock nodes (T-Poseish)
    # Right Arm extending along X axis
    nodes["mixamorig_RightArm"] = Node("RightArm", Vector3(20, 150, 0))
    nodes["mixamorig_RightForeArm"] = Node("RightForeArm", Vector3(50, 150, 0))
    nodes["mixamorig_RightHand"] = Node("RightHand", Vector3(80, 150, 0))
    # Note: mixamorig_RightHandMiddle1 is MISSING to test fallback

    # Bind
    print("\n--- Binding Nodes ---")
    calculator.bind(nodes)

    # Calculate
    print("\n--- Calculating CoM ---")
    result = calculator.calculate_detailed_body_com()

    # Verify Hand Fallback
    hand_seg = next((s for s in result.segmentCOMs if s.name == "R Hand"), None)
    if hand_seg:
        print(f"✅ Hand Segment: {hand_seg.name}")
        print(f"   Position: {hand_seg.position}")
        expected_x = 80.0
        print(f"   Expected X: {expected_x} (Fallback to Wrist)")

        if abs(hand_seg.position.x - expected_x) < 0.001:
            print("   Result: PASS")
        else:
            print("   Result: FAIL")
    else:
        print("❌ R Hand segment missing!")

    # Verify Upper Arm
    # Prox: (20, 150, 0), Dist: (50, 150, 0), Ratio: 0.44
    # COM = 20 + (30 * 0.44) = 20 + 13.2 = 33.2
    arm_seg = next((s for s in result.segmentCOMs if s.name == "R Upper Arm"), None)
    if arm_seg:
        print(f"\n✅ Upper Arm Segment: {arm_seg.name}")
        print(f"   Position X: {arm_seg.position.x:.3f}")
        expected_x = 33.2
        print(f"   Expected X: {expected_x}")

        if abs(arm_seg.position.x - expected_x) < 0.001:
            print("   Result: PASS")
        else:
            print("   Result: FAIL")
            print(f"   Diff: {abs(arm_seg.position.x - expected_x)}")
    else:
        print("❌ R Upper Arm segment missing!")

    print("\n✅ Verification Complete")

if __name__ == "__main__":
    run_verification()
