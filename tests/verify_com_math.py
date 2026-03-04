# tests/verify_com_math.py
# This script simulates the COM calculation logic to verify correctness without SceneKit runtime.
# It replicates the logic of COMCalculator.swift.

import math
import sys

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

    @property
    def worldPosition(self):
        return self.position

    @worldPosition.setter
    def worldPosition(self, value):
        self.position = value

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
                # print(f"⚠️ Missing proximal joint for binding: {prox_name}")
                missing_count += 1
                continue

            dist_node = joint_nodes.get(dist_name)
            if not dist_node:
                # Special handling for Hand tips
                if "Hand" in name:
                    # print(f"⚠️ Hand distal {dist_name} missing, using proximal as fallback (CoM at wrist)")
                    dist_node = prox_node
                else:
                    # print(f"⚠️ Missing distal joint for binding: {dist_name}")
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

# Helper to create T-Pose Nodes
def create_t_pose_nodes():
    nodes = {}
    # Trunk (Y-axis vertical)
    nodes["mixamorig_Hips"] = SCNNode("Hips", SCNVector3(0, 100, 0))
    nodes["mixamorig_Spine"] = SCNNode("Spine", SCNVector3(0, 110, 0))
    nodes["mixamorig_Spine1"] = SCNNode("Spine1", SCNVector3(0, 120, 0))
    nodes["mixamorig_Spine2"] = SCNNode("Spine2", SCNVector3(0, 130, 0))
    nodes["mixamorig_Neck"] = SCNNode("Neck", SCNVector3(0, 140, 0))
    nodes["mixamorig_Head"] = SCNNode("Head", SCNVector3(0, 150, 0))

    # Right Arm (X-axis lateral)
    nodes["mixamorig_RightArm"] = SCNNode("RArm", SCNVector3(20, 130, 0))
    nodes["mixamorig_RightForeArm"] = SCNNode("RForeArm", SCNVector3(50, 130, 0))
    nodes["mixamorig_RightHand"] = SCNNode("RHand", SCNVector3(80, 130, 0))
    # Missing Hand Tip to test fallback for Right Hand

    # Left Arm
    nodes["mixamorig_LeftArm"] = SCNNode("LArm", SCNVector3(-20, 130, 0))
    nodes["mixamorig_LeftForeArm"] = SCNNode("LForeArm", SCNVector3(-50, 130, 0))
    nodes["mixamorig_LeftHand"] = SCNNode("LHand", SCNVector3(-80, 130, 0))
    nodes["mixamorig_LeftHandMiddle1"] = SCNNode("LHandTip", SCNVector3(-90, 130, 0))

    # Legs
    nodes["mixamorig_RightUpLeg"] = SCNNode("RUpLeg", SCNVector3(10, 100, 0))
    nodes["mixamorig_RightLeg"] = SCNNode("RLeg", SCNVector3(10, 50, 0))
    nodes["mixamorig_RightFoot"] = SCNNode("RFoot", SCNVector3(10, 10, 0))
    nodes["mixamorig_RightToeBase"] = SCNNode("RToe", SCNVector3(10, 0, 10))

    nodes["mixamorig_LeftUpLeg"] = SCNNode("LUpLeg", SCNVector3(-10, 100, 0))
    nodes["mixamorig_LeftLeg"] = SCNNode("LLeg", SCNVector3(-10, 50, 0))
    nodes["mixamorig_LeftFoot"] = SCNNode("LFoot", SCNVector3(-10, 10, 0))
    nodes["mixamorig_LeftToeBase"] = SCNNode("LToe", SCNVector3(-10, 0, 10))

    return nodes

def test_mass_ratios():
    print("Test: Mass Ratios Sum to 1.0")
    calculator = COMCalculatorMock(body_mass=70.0)
    total_ratio = sum(s[3] for s in calculator.segments)
    if abs(total_ratio - 1.0) > 0.001:
        print(f"❌ FAIL: Mass ratios sum to {total_ratio:.4f}")
        return False
    print(f"✅ PASS: Mass ratios sum to {total_ratio:.4f}")
    return True

def test_t_pose(calculator):
    print("\nTest: T-Pose Baseline")
    nodes = create_t_pose_nodes()
    calculator.bind(nodes)

    total_com, segments = calculator.calculate_detailed_body_com()
    print(f"   T-Pose CoM: {total_com}")

    # Check Hand Fallback logic (Right Hand missing tip)
    r_hand = next((s for s in segments if s["name"] == "R Hand"), None)
    if r_hand and abs(r_hand['position'].x - 80.0) < 0.001:
        print("✅ PASS: R Hand Fallback correct (used proximal)")
    else:
        print(f"❌ FAIL: R Hand Fallback incorrect. Got {r_hand['position']}")

    # Check Normal Hand logic (Left Hand has tip)
    l_hand = next((s for s in segments if s["name"] == "L Hand"), None)
    if l_hand and abs(l_hand['position'].x - (-85.0)) < 0.001:
        print("✅ PASS: L Hand Normal correct (midpoint)")
    else:
        print(f"❌ FAIL: L Hand Normal incorrect. Got {l_hand['position']}")

    return total_com

def test_touchdown(calculator, t_pose_com):
    print("\nTest: Touchdown Pose (Arms Up)")
    nodes = create_t_pose_nodes()

    # Raise Arms: Rotate 180 deg around shoulder to point UP
    # Shoulder height is 130
    # Arm length approx 30 (20->50), Forearm 30 (50->80)

    # Right Arm UP
    nodes["mixamorig_RightArm"].position = SCNVector3(20, 130, 0)
    nodes["mixamorig_RightForeArm"].position = SCNVector3(20, 160, 0) # +30 Y
    nodes["mixamorig_RightHand"].position = SCNVector3(20, 190, 0) # +30 Y

    # Left Arm UP
    nodes["mixamorig_LeftArm"].position = SCNVector3(-20, 130, 0)
    nodes["mixamorig_LeftForeArm"].position = SCNVector3(-20, 160, 0)
    nodes["mixamorig_LeftHand"].position = SCNVector3(-20, 190, 0)
    nodes["mixamorig_LeftHandMiddle1"].position = SCNVector3(-20, 200, 0)

    calculator.bind(nodes)
    touchdown_com, _ = calculator.calculate_detailed_body_com()

    print(f"   Touchdown CoM: {touchdown_com}")

    diff = touchdown_com.y - t_pose_com.y
    print(f"   Rise from T-Pose: {diff:.2f}")

    if diff > 2.0:
        print("✅ PASS: CoM rose significantly")
        return True
    else:
        print("❌ FAIL: CoM did not rise significantly")
        return False

def test_squat(calculator, t_pose_com):
    print("\nTest: Squat Pose (Hips Lowered)")
    nodes = create_t_pose_nodes()

    # Lower everything by 20 units
    drop = 20.0
    for key in nodes:
        nodes[key].position.y -= drop

    # In a real squat, legs bend, but simply lowering the whole upper body
    # and adjusting knees outward/forward is enough to test "lowering CoM" logic

    # Keep feet on ground
    nodes["mixamorig_RightFoot"].position.y = 10
    nodes["mixamorig_RightToeBase"].position.y = 0
    nodes["mixamorig_LeftFoot"].position.y = 10
    nodes["mixamorig_LeftToeBase"].position.y = 0

    # Knees bend forward/out
    nodes["mixamorig_RightLeg"].position = SCNVector3(15, 50, 20)
    nodes["mixamorig_LeftLeg"].position = SCNVector3(-15, 50, 20)

    calculator.bind(nodes)
    squat_com, _ = calculator.calculate_detailed_body_com()

    print(f"   Squat CoM: {squat_com}")

    diff = t_pose_com.y - squat_com.y
    print(f"   Drop from T-Pose: {diff:.2f}")

    if diff > 10.0:
        print("✅ PASS: CoM lowered significantly")
        return True
    else:
        print("❌ FAIL: CoM did not lower significantly")
        return False

def test_pike(calculator, t_pose_com):
    print("\nTest: Pike Pose (Legs Forward)")
    nodes = create_t_pose_nodes()

    # Pike: Hips flexed 90 deg, legs extended straight forward (Z+)
    # Hips remain roughly at same height or slightly lower, but legs move deep into Z+

    # Upper legs extend forward from Hips (0, 100, 0) -> Z+
    # Length approx 50. End at (0, 100, 50)
    nodes["mixamorig_RightUpLeg"].position = SCNVector3(10, 100, 0) # Proximal
    nodes["mixamorig_RightLeg"].position = SCNVector3(10, 100, 50) # Distal/Knee

    nodes["mixamorig_LeftUpLeg"].position = SCNVector3(-10, 100, 0)
    nodes["mixamorig_LeftLeg"].position = SCNVector3(-10, 100, 50)

    # Lower legs continue forward
    # Length approx 40. End at (0, 100, 90)
    nodes["mixamorig_RightFoot"].position = SCNVector3(10, 100, 90) # Ankle
    nodes["mixamorig_RightToeBase"].position = SCNVector3(10, 110, 90) # Toes point up

    nodes["mixamorig_LeftFoot"].position = SCNVector3(-10, 100, 90)
    nodes["mixamorig_LeftToeBase"].position = SCNVector3(-10, 110, 90)

    calculator.bind(nodes)
    pike_com, _ = calculator.calculate_detailed_body_com()

    print(f"   Pike CoM: {pike_com}")

    # Check Z-shift
    # T-Pose Z is approx 0. Pike Z should be positive (legs are heavy)
    diff = pike_com.z - t_pose_com.z
    print(f"   Forward Shift (Z) from T-Pose: {diff:.2f}")

    if diff > 10.0:
        print("✅ PASS: CoM shifted forward significantly")
        return True
    else:
        print("❌ FAIL: CoM did not shift forward significantly")
        return False

class JointLimit:
    def __init__(self, minX=None, maxX=None, minY=None, maxY=None, minZ=None, maxZ=None):
        self.minX = minX
        self.maxX = maxX
        self.minY = minY
        self.maxY = maxY
        self.minZ = minZ
        self.maxZ = maxZ

    def clamp(self, vector):
        result = SCNVector3(vector.x, vector.y, vector.z)
        if self.minX is not None and self.maxX is not None: result.x = min(max(result.x, self.minX), self.maxX)
        elif self.minX is not None: result.x = max(result.x, self.minX)
        elif self.maxX is not None: result.x = min(result.x, self.maxX)

        if self.minY is not None and self.maxY is not None: result.y = min(max(result.y, self.minY), self.maxY)
        elif self.minY is not None: result.y = max(result.y, self.minY)
        elif self.maxY is not None: result.y = min(result.y, self.maxY)

        if self.minZ is not None and self.maxZ is not None: result.z = min(max(result.z, self.minZ), self.maxZ)
        elif self.minZ is not None: result.z = max(result.z, self.minZ)
        elif self.maxZ is not None: result.z = min(result.z, self.maxZ)
        return result

class JointLimits:
    def __init__(self):
        def deg(degrees):
            return degrees * math.pi / 180.0

        self.limits = {
            "mixamorig_RightLeg": JointLimit(minX=deg(-160), maxX=deg(0)),
            "mixamorig_LeftLeg": JointLimit(minX=deg(-160), maxX=deg(0)),
            "mixamorig_RightForeArm": JointLimit(minZ=deg(0), maxZ=deg(160)),
            "mixamorig_LeftForeArm": JointLimit(minZ=deg(-160), maxZ=deg(0))
        }

    def clamp_angles(self, angles, joint_name):
        if joint_name in self.limits:
            return self.limits[joint_name].clamp(angles)
        return angles

def test_joint_limits():
    print("\nTest: Joint Limits")
    limits = JointLimits()

    def deg(degrees):
        return degrees * math.pi / 180.0

    # Test Knee limits ([-160, 0] degrees on X)
    # Attempt to bend knee forward (positive X) -> should clamp to 0
    invalid_knee = SCNVector3(deg(45), 0, 0)
    clamped_knee = limits.clamp_angles(invalid_knee, "mixamorig_RightLeg")
    if abs(clamped_knee.x - 0.0) < 0.001:
        print("✅ PASS: Knee forward bend correctly clamped to 0")
    else:
        print(f"❌ FAIL: Knee forward bend not clamped. Got {clamped_knee.x}")
        return False

    # Attempt to over-bend knee backward (e.g. -180 degrees) -> should clamp to -160
    overbend_knee = SCNVector3(deg(-180), 0, 0)
    clamped_knee = limits.clamp_angles(overbend_knee, "mixamorig_RightLeg")
    if abs(clamped_knee.x - deg(-160)) < 0.001:
        print("✅ PASS: Knee overbend correctly clamped to -160")
    else:
        print(f"❌ FAIL: Knee overbend not clamped. Got {clamped_knee.x}")
        return False

    # Test Elbow limits (Right elbow Z: [0, 160], Left elbow Z: [-160, 0])
    # Attempt to bend right elbow backward (negative Z) -> should clamp to 0
    invalid_r_elbow = SCNVector3(0, 0, deg(-45))
    clamped_r_elbow = limits.clamp_angles(invalid_r_elbow, "mixamorig_RightForeArm")
    if abs(clamped_r_elbow.z - 0.0) < 0.001:
        print("✅ PASS: Right elbow backward bend correctly clamped to 0")
    else:
        print(f"❌ FAIL: Right elbow backward bend not clamped. Got {clamped_r_elbow.z}")
        return False

    # Attempt to bend left elbow backward (positive Z) -> should clamp to 0
    invalid_l_elbow = SCNVector3(0, 0, deg(45))
    clamped_l_elbow = limits.clamp_angles(invalid_l_elbow, "mixamorig_LeftForeArm")
    if abs(clamped_l_elbow.z - 0.0) < 0.001:
        print("✅ PASS: Left elbow backward bend correctly clamped to 0")
    else:
        print(f"❌ FAIL: Left elbow backward bend not clamped. Got {clamped_l_elbow.z}")
        return False

    return True

def run_verification():
    print("🧪 Running CoM Verification Harness (Python)\n")

    calculator = COMCalculatorMock(body_mass=70.0)

    if not test_mass_ratios():
        sys.exit(1)

    if not test_joint_limits():
        sys.exit(1)

    t_pose_com = test_t_pose(calculator)

    if not test_touchdown(calculator, t_pose_com):
        sys.exit(1)

    if not test_squat(calculator, t_pose_com):
        sys.exit(1)

    if not test_pike(calculator, t_pose_com):
        sys.exit(1)

    print("\n✅ All CoM Logic Tests Passed")

if __name__ == "__main__":
    run_verification()
