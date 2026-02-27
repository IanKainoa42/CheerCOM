# tests/verify_com_math.py
# This script simulates the COM calculation logic to verify correctness without SceneKit runtime.
# It replicates the logic of COMCalculator.swift.

import math

class SCNVector3:
    def __init__(self, x=0.0, y=0.0, z=0.0):
        self.x = float(x)
        self.y = float(y)
        self.z = float(z)

    def __add__(self, other):
        return SCNVector3(self.x + other.x, self.y + other.y, self.z + other.z)

    def __sub__(self, other):
        return SCNVector3(self.x - other.x, self.y - other.y, self.z - other.z)

    def __mul__(self, other):
        if isinstance(other, (int, float)):
            return SCNVector3(self.x * other, self.y * other, self.z * other)
        raise TypeError("Multiplication only supported with scalar")

    def __repr__(self):
        return f"SCNVector3({self.x:.3f}, {self.y:.3f}, {self.z:.3f})"

class SCNNode:
    def __init__(self, name=None, position=None):
        self.name = name
        self.position = position if position else SCNVector3()
        # In this mock, worldPosition is just position since we don't have a hierarchy
        self.worldPosition = self.position

class COMCalculatorMock:
    def __init__(self, body_mass):
        self.body_mass = body_mass

        # 17 body segments with (name, proximal_joint, distal_joint, mass_%, com_%)
        # Based on COMCalculator.swift
        self.segments = [
            # Trunk subdivision (Total 49.7%)
            ("Pelvis", "mixamorig_Hips", "mixamorig_Spine", 0.146, 0.50),
            ("Abdomen Lower", "mixamorig_Spine", "mixamorig_Spine1", 0.0855, 0.50),
            ("Abdomen Upper", "mixamorig_Spine1", "mixamorig_Spine2", 0.0855, 0.50),
            ("Thorax", "mixamorig_Spine2", "mixamorig_Neck", 0.180, 0.50),

            # Head (Total 8.1%) - Modeled as Neck segment (approx)
            ("Head", "mixamorig_Neck", "mixamorig_Head", 0.081, 0.50),

            # Upper Limbs (Total 10.0%)
            # RightArm = Humerus (Shoulder to Elbow)
            ("R Upper Arm", "mixamorig_RightArm", "mixamorig_RightForeArm", 0.028, 0.44),
            # RightForeArm = Radius/Ulna (Elbow to Wrist)
            ("R Forearm", "mixamorig_RightForeArm", "mixamorig_RightHand", 0.016, 0.43),
            # RightHand = Hand (Wrist to Knuckles)
            ("R Hand", "mixamorig_RightHand", "mixamorig_RightHandMiddle1", 0.006, 0.50),

            ("L Upper Arm", "mixamorig_LeftArm", "mixamorig_LeftForeArm", 0.028, 0.44),
            ("L Forearm", "mixamorig_LeftForeArm", "mixamorig_LeftHand", 0.016, 0.43),
            ("L Hand", "mixamorig_LeftHand", "mixamorig_LeftHandMiddle1", 0.006, 0.50),
            ("R Thigh", "mixamorig_RightUpLeg", "mixamorig_RightLeg", 0.100, 0.43),
            ("R Shank", "mixamorig_RightLeg", "mixamorig_RightFoot", 0.0465, 0.43),
            ("R Foot", "mixamorig_RightFoot", "mixamorig_RightToeBase", 0.0145, 0.50),
            ("L Thigh", "mixamorig_LeftUpLeg", "mixamorig_LeftLeg", 0.100, 0.43),
            ("L Shank", "mixamorig_LeftLeg", "mixamorig_LeftFoot", 0.0465, 0.43),
            ("L Foot", "mixamorig_LeftFoot", "mixamorig_LeftToeBase", 0.0145, 0.50)
        ]

        self.bound_segments = []

    def bind(self, joint_nodes):
        self.bound_segments = []
        missing_count = 0

        for name, prox_name, dist_name, mass_ratio, com_ratio in self.segments:
            prox_node = joint_nodes.get(prox_name)
            if not prox_node:
                print(f"⚠️ Missing proximal joint for binding: {prox_name}")
                missing_count += 1
                continue

            dist_node = joint_nodes.get(dist_name)
            if not dist_node:
                # Special handling for Hand tips
                if "Hand" in name:
                    print(f"⚠️ Hand distal {dist_name} missing, using proximal as fallback (CoM at wrist)")
                    dist_node = prox_node
                else:
                    print(f"⚠️ Missing distal joint for binding: {dist_name}")
                    missing_count += 1
                    continue

            self.bound_segments.append({
                "name": name,
                "prox": prox_node,
                "dist": dist_node,
                "mass_ratio": mass_ratio,
                "com_ratio": com_ratio
            })

        if missing_count == 0:
            print(f"✅ COMCalculator bound to {len(self.bound_segments)} segments")

    def calculate_detailed_body_com(self):
        if not self.bound_segments:
            print("⚠️ COMCalculator: No segments bound. Did you call bind(jointNodes:)?")
            return SCNVector3(), []

        total_weighted = SCNVector3()
        total_mass = 0.0
        segment_results = []

        for segment in self.bound_segments:
            prox_pos = segment["prox"].worldPosition
            dist_pos = segment["dist"].worldPosition

            # COM = proximal + (distal - proximal) * %
            seg_com = prox_pos + ((dist_pos - prox_pos) * segment["com_ratio"])
            seg_mass = self.body_mass * segment["mass_ratio"]

            total_weighted = total_weighted + (seg_com * seg_mass)
            total_mass += seg_mass

            segment_results.append({
                "name": segment["name"],
                "position": seg_com,
                "mass": seg_mass
            })

        total_com = (total_weighted * (1.0 / total_mass)) if total_mass > 0 else SCNVector3()
        return total_com, segment_results

def run_verification():
    print("🧪 Running CoM Verification (Python)...")

    calculator = COMCalculatorMock(body_mass=70.0)

    # Verify Mass Ratios
    total_ratio = sum(s[3] for s in calculator.segments)
    print(f"Total Mass Ratio: {total_ratio:.4f}")
    if abs(total_ratio - 1.0) > 0.001:
        print(f"❌ FAIL: Mass ratios do not sum to 1.0 (Diff: {total_ratio - 1.0:.4f})")
    else:
        print("✅ PASS: Mass ratios sum to approx 1.0")

    def create_base_nodes():
        nodes = {}
        # Trunk
        nodes["mixamorig_Hips"] = SCNNode("Hips", SCNVector3(0, 100, 0))
        nodes["mixamorig_Spine"] = SCNNode("Spine", SCNVector3(0, 110, 0))
        nodes["mixamorig_Spine1"] = SCNNode("Spine1", SCNVector3(0, 120, 0))
        nodes["mixamorig_Spine2"] = SCNNode("Spine2", SCNVector3(0, 130, 0))
        nodes["mixamorig_Neck"] = SCNNode("Neck", SCNVector3(0, 140, 0))
        nodes["mixamorig_Head"] = SCNNode("Head", SCNVector3(0, 150, 0))

        # Right Arm (T-Poseish)
        nodes["mixamorig_RightArm"] = SCNNode("RArm", SCNVector3(20, 130, 0))
        nodes["mixamorig_RightForeArm"] = SCNNode("RForeArm", SCNVector3(50, 130, 0))
        nodes["mixamorig_RightHand"] = SCNNode("RHand", SCNVector3(80, 130, 0))
        # Missing Hand Tip to test fallback

        # Left Arm
        nodes["mixamorig_LeftArm"] = SCNNode("LArm", SCNVector3(-20, 130, 0))
        nodes["mixamorig_LeftForeArm"] = SCNNode("LForeArm", SCNVector3(-50, 130, 0))
        nodes["mixamorig_LeftHand"] = SCNNode("LHand", SCNVector3(-80, 130, 0))
        nodes["mixamorig_LeftHandMiddle1"] = SCNNode("LHandTip", SCNVector3(-90, 130, 0))

        # Legs (simplified)
        nodes["mixamorig_RightUpLeg"] = SCNNode("RUpLeg", SCNVector3(10, 100, 0))
        nodes["mixamorig_RightLeg"] = SCNNode("RLeg", SCNVector3(10, 50, 0))
        nodes["mixamorig_RightFoot"] = SCNNode("RFoot", SCNVector3(10, 10, 0))
        nodes["mixamorig_RightToeBase"] = SCNNode("RToe", SCNVector3(10, 0, 10))

        nodes["mixamorig_LeftUpLeg"] = SCNNode("LUpLeg", SCNVector3(-10, 100, 0))
        nodes["mixamorig_LeftLeg"] = SCNNode("LLeg", SCNVector3(-10, 50, 0))
        nodes["mixamorig_LeftFoot"] = SCNNode("LFoot", SCNVector3(-10, 10, 0))
        nodes["mixamorig_LeftToeBase"] = SCNNode("LToe", SCNVector3(-10, 0, 10))
        return nodes

    def print_pose_report(pose_name, total_com, segments):
        print(f"\n--- {pose_name} ---")
        print(f"Total CoM: {total_com}")
        print("Segments:")
        for s in segments:
            print(f"  {s['name'].ljust(15)} Mass: {s['mass']:<6.3f} CoM: {s['position']}")

    # 1. T-Pose Baseline
    nodes = create_base_nodes()
    print("\n--- Binding Nodes ---")
    calculator.bind(nodes)

    total_com_tpose, segments_tpose = calculator.calculate_detailed_body_com()
    print_pose_report("T-Pose (Baseline)", total_com_tpose, segments_tpose)

    # Verify Hand Fallback
    r_hand = next((s for s in segments_tpose if s["name"] == "R Hand"), None)
    if r_hand:
        print(f"\n✅ R Hand (Fallback): {r_hand['position']}")
        expected = SCNVector3(80, 130, 0)
        if abs(r_hand['position'].x - expected.x) < 0.001:
            print("   PASS: Correctly used proximal position")
        else:
            print(f"   FAIL: Expected {expected}, got {r_hand['position']}")

    l_hand = next((s for s in segments_tpose if s["name"] == "L Hand"), None)
    if l_hand:
        print(f"✅ L Hand (Normal): {l_hand['position']}")
        expected_x = -85.0
        if abs(l_hand['position'].x - expected_x) < 0.001:
            print("   PASS: Correctly calculated midpoint")
        else:
            print(f"   FAIL: Expected X={expected_x}, got {l_hand['position'].x}")

    # 2. Touchdown (Arms up)
    nodes_td = create_base_nodes()
    for name in ["mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
                 "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand", "mixamorig_LeftHandMiddle1"]:
        if name in nodes_td:
            nodes_td[name].position.y += 50
    calculator.bind(nodes_td)
    total_com_td, segments_td = calculator.calculate_detailed_body_com()
    print_pose_report("Touchdown (Arms Up)", total_com_td, segments_td)
    print(f"Y Difference from T-Pose: {total_com_td.y - total_com_tpose.y:.3f} (Expected > 0)")

    # 3. Squat (Hips down)
    nodes_sq = create_base_nodes()
    upper_body = ["mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2", "mixamorig_Neck", "mixamorig_Head",
                  "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
                  "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand", "mixamorig_LeftHandMiddle1",
                  "mixamorig_RightUpLeg", "mixamorig_LeftUpLeg"]
    for name in upper_body:
        if name in nodes_sq:
            nodes_sq[name].position.y -= 40
    calculator.bind(nodes_sq)
    total_com_sq, segments_sq = calculator.calculate_detailed_body_com()
    print_pose_report("Squat", total_com_sq, segments_sq)
    print(f"Y Difference from T-Pose: {total_com_sq.y - total_com_tpose.y:.3f} (Expected < 0)")

    # 4. Pike (Legs forward)
    nodes_pk = create_base_nodes()
    legs_fwd = ["mixamorig_RightLeg", "mixamorig_RightFoot", "mixamorig_RightToeBase",
                "mixamorig_LeftLeg", "mixamorig_LeftFoot", "mixamorig_LeftToeBase"]
    for name in legs_fwd:
        if name in nodes_pk:
            nodes_pk[name].position.z += 50
    calculator.bind(nodes_pk)
    total_com_pk, segments_pk = calculator.calculate_detailed_body_com()
    print_pose_report("Pike", total_com_pk, segments_pk)
    print(f"Z Difference from T-Pose: {total_com_pk.z - total_com_tpose.z:.3f} (Expected > 0)")

    # 5. Layout (Straight body) - In this mock, Layout is similar to Touchdown
    # as the baseline mock nodes are already upright like a standing position.
    nodes_ly = create_base_nodes()
    for name in ["mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
                 "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand", "mixamorig_LeftHandMiddle1"]:
        if name in nodes_ly:
            nodes_ly[name].position.y += 50
    calculator.bind(nodes_ly)
    total_com_ly, segments_ly = calculator.calculate_detailed_body_com()
    print_pose_report("Layout", total_com_ly, segments_ly)
    print(f"Y Difference from T-Pose: {total_com_ly.y - total_com_tpose.y:.3f} (Expected > 0)")

if __name__ == "__main__":
    run_verification()
