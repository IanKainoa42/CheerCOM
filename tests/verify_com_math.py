#!/usr/bin/env python3
import math

class Vector3:
    def __init__(self, x=0.0, y=0.0, z=0.0):
        self.x = x
        self.y = y
        self.z = z

    def __add__(self, other):
        return Vector3(self.x + other.x, self.y + other.y, self.z + other.z)

    def __sub__(self, other):
        return Vector3(self.x - other.x, self.y - other.y, self.z - other.z)

    def __mul__(self, scalar):
        return Vector3(self.x * scalar, self.y * scalar, self.z * scalar)

    def __repr__(self):
        return f"({self.x:.2f}, {self.y:.2f}, {self.z:.2f})"

class Node:
    def __init__(self, name, position):
        self.name = name
        self.worldPosition = position

class SegmentResult:
    def __init__(self, name, position, mass):
        self.name = name
        self.position = position
        self.mass = mass

class CalculationResult:
    def __init__(self, total_com, segment_coms):
        self.totalCOM = total_com
        self.segmentCOMs = segment_coms

class COMCalculator:
    def __init__(self, body_mass):
        self.body_mass = body_mass
        # 17 segments (name, prox, dist, mass%, com%)
        self.segments = [
            ("Pelvis", "mixamorig_Hips", "mixamorig_Spine", 0.146, 0.50),
            ("Abdomen Lower", "mixamorig_Spine", "mixamorig_Spine1", 0.0855, 0.50),
            ("Abdomen Upper", "mixamorig_Spine1", "mixamorig_Spine2", 0.0855, 0.50),
            ("Thorax", "mixamorig_Spine2", "mixamorig_Neck", 0.180, 0.50),
            ("Head", "mixamorig_Neck", "mixamorig_Head", 0.081, 0.50),
            ("R Upper Arm", "mixamorig_RightArm", "mixamorig_RightForeArm", 0.028, 0.44),
            ("R Forearm", "mixamorig_RightForeArm", "mixamorig_RightHand", 0.016, 0.43),
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

    def calculate_detailed_body_com(self):
        if not self.bound_segments:
            print("⚠️ COMCalculator: No segments bound.")
            return CalculationResult(Vector3(), [])

        total_weighted = Vector3()
        total_mass = 0.0
        segment_results = []

        for seg in self.bound_segments:
            prox_pos = seg["prox"].worldPosition
            dist_pos = seg["dist"].worldPosition

            # COM = proximal + (distal - proximal) * %
            diff = dist_pos - prox_pos
            seg_com = prox_pos + (diff * seg["com_ratio"])
            seg_mass = self.body_mass * seg["mass_ratio"]

            total_weighted = total_weighted + (seg_com * seg_mass)
            total_mass += seg_mass

            segment_results.append(SegmentResult(seg["name"], seg_com, seg_mass))

        if total_mass > 0:
            final_com = total_weighted * (1.0 / total_mass)
        else:
            final_com = Vector3()

        return CalculationResult(final_com, segment_results)

def run_tests():
    print("🧪 Starting Python CoM Verification...")

    # 1. Setup Mock Calculator
    body_mass = 70.0
    calc = COMCalculator(body_mass)

    # 2. Setup Mock Nodes (T-Pose like)
    nodes = {}
    # Spine (Vertical)
    nodes["mixamorig_Hips"] = Node("Hips", Vector3(0, 100, 0))
    nodes["mixamorig_Spine"] = Node("Spine", Vector3(0, 110, 0))
    nodes["mixamorig_Spine1"] = Node("Spine1", Vector3(0, 120, 0))
    nodes["mixamorig_Spine2"] = Node("Spine2", Vector3(0, 130, 0))
    nodes["mixamorig_Neck"] = Node("Neck", Vector3(0, 140, 0))
    nodes["mixamorig_Head"] = Node("Head", Vector3(0, 150, 0))

    # Right Arm (Extending Right +X)
    nodes["mixamorig_RightArm"] = Node("RightArm", Vector3(10, 135, 0)) # Shoulder
    nodes["mixamorig_RightForeArm"] = Node("RightForeArm", Vector3(40, 135, 0)) # Elbow
    nodes["mixamorig_RightHand"] = Node("RightHand", Vector3(70, 135, 0)) # Wrist
    # Missing Hand Tip to test fallback

    # Left Arm (Extending Left -X)
    nodes["mixamorig_LeftArm"] = Node("LeftArm", Vector3(-10, 135, 0))
    nodes["mixamorig_LeftForeArm"] = Node("LeftForeArm", Vector3(-40, 135, 0))
    nodes["mixamorig_LeftHand"] = Node("LeftHand", Vector3(-70, 135, 0))
    nodes["mixamorig_LeftHandMiddle1"] = Node("LeftHandTip", Vector3(-80, 135, 0))

    # Legs (Vertical Down)
    nodes["mixamorig_RightUpLeg"] = Node("RightUpLeg", Vector3(10, 100, 0))
    nodes["mixamorig_RightLeg"] = Node("RightLeg", Vector3(10, 50, 0))
    nodes["mixamorig_RightFoot"] = Node("RightFoot", Vector3(10, 10, 0))
    nodes["mixamorig_RightToeBase"] = Node("RightToeBase", Vector3(10, 0, 10)) # Feet forward +Z

    nodes["mixamorig_LeftUpLeg"] = Node("LeftUpLeg", Vector3(-10, 100, 0))
    nodes["mixamorig_LeftLeg"] = Node("LeftLeg", Vector3(-10, 50, 0))
    nodes["mixamorig_LeftFoot"] = Node("LeftFoot", Vector3(-10, 10, 0))
    nodes["mixamorig_LeftToeBase"] = Node("LeftToeBase", Vector3(-10, 0, 10))

    # 3. Bind
    print("Binding Nodes...")
    calc.bind(nodes)

    # 4. Calculate
    result = calc.calculate_detailed_body_com()

    # 5. Verify Total Mass
    total_segment_mass = sum(s.mass for s in result.segmentCOMs)
    print(f"Total Calculated Mass: {total_segment_mass:.2f} (Expected: {body_mass:.2f})")
    assert abs(total_segment_mass - body_mass) < 0.01, "Total mass mismatch!"

    # 6. Verify Right Hand Fallback
    r_hand = next(s for s in result.segmentCOMs if s.name == "R Hand")
    print(f"R Hand CoM: {r_hand.position} (Expected: (70.00, 135.00, 0.00))")
    # Should be exactly at Wrist (70, 135, 0) because tip is missing
    assert abs(r_hand.position.x - 70.0) < 0.001, "R Hand fallback failed"

    # 7. Verify R Upper Arm Midpoint
    # Shoulder (10, 135, 0) -> Elbow (40, 135, 0). Length 30.
    # CoM at 0.44 * 30 = 13.2 from proximal.
    # Proximal X = 10. Expected X = 23.2.
    r_upper = next(s for s in result.segmentCOMs if s.name == "R Upper Arm")
    print(f"R Upper Arm CoM X: {r_upper.position.x:.2f} (Expected: 23.20)")
    assert abs(r_upper.position.x - 23.2) < 0.001, "R Upper Arm calculation incorrect"

    # 8. Verify Symmetry (approximate)
    # Since right hand uses fallback (shorter lever arm) and left hand uses full length,
    # the CoM should shift slightly to the left (-X).
    print(f"Total CoM: {result.totalCOM}")
    assert result.totalCOM.x < 0, "CoM should be slightly left due to missing R Hand tip"

    print("✅ All Python verification tests passed!")

if __name__ == "__main__":
    run_tests()
