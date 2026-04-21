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

    @property
    def presentation(self):
        # Mock presentation node returning self so we can call presentation.worldPosition
        return self

class COMCalculatorMock:
    def __init__(self, body_mass, preset="averageNeutral"):
        self.body_mass = body_mass
        self.preset = preset

        # 17 body segments with (name, proximal_joint, distal_joint, mass_%, com_%)
        # Based on COMCalculator.swift
        self.segments = [
            # Trunk subdivision (Total 49.7%)
            ("Pelvis", "mixamorig_Hips", "mixamorig_Spine", 0.146, 0.50),
            ("Abdomen Lower", "mixamorig_Spine", "mixamorig_Spine1", 0.0855, 0.50),
            ("Abdomen Upper", "mixamorig_Spine1", "mixamorig_Spine2", 0.0855, 0.50),
            ("Thorax", "mixamorig_Spine2", "mixamorig_Neck", 0.180, 0.50),

            # Head (Total 8.1%)
            ("Head", "mixamorig_Head", "mixamorig_HeadTop_End", 0.081, 0.50),

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

    def get_multipliers(self):
        if self.preset == "averageNeutral":
            return {"trunk": 1.0, "upper": 1.0, "lower": 1.0}
        elif self.preset == "athleticFemale":
            return {"trunk": 0.95, "upper": 0.95, "lower": 1.08}
        elif self.preset == "athleticMale":
            return {"trunk": 1.05, "upper": 1.15, "lower": 0.95}
        return {"trunk": 1.0, "upper": 1.0, "lower": 1.0}

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
                "base_mass_ratio": mass_ratio,
                "com_ratio": com_ratio,
                "current_mass_ratio": mass_ratio
            })

        self.apply_preset()

    def apply_preset(self):
        if not self.bound_segments:
            return

        multipliers = self.get_multipliers()
        total_mass_ratio = 0.0

        for segment in self.bound_segments:
            multiplier = 1.0
            if "Arm" in segment["name"] or "Forearm" in segment["name"] or "Hand" in segment["name"]:
                multiplier = multipliers["upper"]
            elif "Thigh" in segment["name"] or "Shank" in segment["name"] or "Foot" in segment["name"]:
                multiplier = multipliers["lower"]
            else:
                multiplier = multipliers["trunk"]

            segment["current_mass_ratio"] = segment["base_mass_ratio"] * multiplier
            total_mass_ratio += segment["current_mass_ratio"]

        for segment in self.bound_segments:
            segment["current_mass_ratio"] /= total_mass_ratio

    def set_preset(self, preset):
        self.preset = preset
        self.apply_preset()

    def calculate_detailed_body_com(self):
        if not self.bound_segments:
            print("⚠️ COMCalculator: No segments bound. Did you call bind(jointNodes:)?")
            return SCNVector3(), []

        total_weighted = SCNVector3()
        total_mass = 0.0
        segment_results = []

        for segment in self.bound_segments:
            prox_pos = segment["prox"].presentation.worldPosition
            dist_pos = segment["dist"].presentation.worldPosition

            # COM = proximal + (distal - proximal) * %
            seg_com = prox_pos + ((dist_pos - prox_pos) * segment["com_ratio"])
            seg_mass = self.body_mass * segment["current_mass_ratio"]

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
    nodes["mixamorig_HeadTop_End"] = SCNNode("HeadTop", SCNVector3(0, 160, 0))

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
    # Total ratio on unbound baseline segments
    total_ratio = sum(s[3] for s in calculator.segments)
    if abs(total_ratio - 1.0) > 0.001:
        print(f"❌ FAIL: Mass ratios sum to {total_ratio:.4f}")
        return False
    print(f"✅ PASS: Base mass ratios sum to {total_ratio:.4f}")
    return True

def test_body_presets():
    print("\nTest: Body Presets Mass Normalization")
    calculator = COMCalculatorMock(body_mass=70.0)
    nodes = create_t_pose_nodes()

    # Test averageNeutral
    calculator.set_preset("averageNeutral")
    calculator.bind(nodes)
    total_ratio_neutral = sum(s["current_mass_ratio"] for s in calculator.bound_segments)
    if abs(total_ratio_neutral - 1.0) > 0.001:
        print(f"❌ FAIL: Neutral preset mass ratio sum is {total_ratio_neutral:.4f}")
        return False

    neutral_lower_mass = sum(s["current_mass_ratio"] for s in calculator.bound_segments if "Thigh" in s["name"])

    # Test athleticFemale
    calculator.set_preset("athleticFemale")
    total_ratio_female = sum(s["current_mass_ratio"] for s in calculator.bound_segments)
    if abs(total_ratio_female - 1.0) > 0.001:
        print(f"❌ FAIL: Athletic Female preset mass ratio sum is {total_ratio_female:.4f}")
        return False

    female_lower_mass = sum(s["current_mass_ratio"] for s in calculator.bound_segments if "Thigh" in s["name"])
    if female_lower_mass <= neutral_lower_mass:
        print(f"❌ FAIL: Athletic Female lower body mass should be greater than neutral. ({female_lower_mass:.4f} <= {neutral_lower_mass:.4f})")
        return False

    # Test athleticMale
    calculator.set_preset("athleticMale")
    total_ratio_male = sum(s["current_mass_ratio"] for s in calculator.bound_segments)
    if abs(total_ratio_male - 1.0) > 0.001:
        print(f"❌ FAIL: Athletic Male preset mass ratio sum is {total_ratio_male:.4f}")
        return False

    male_lower_mass = sum(s["current_mass_ratio"] for s in calculator.bound_segments if "Thigh" in s["name"])
    if male_lower_mass >= neutral_lower_mass:
        print(f"❌ FAIL: Athletic Male lower body mass should be less than neutral. ({male_lower_mass:.4f} >= {neutral_lower_mass:.4f})")
        return False

    print("✅ PASS: All body presets apply multipliers correctly and normalize to 1.0")

    # Reset back to neutral for the rest of tests
    calculator.set_preset("averageNeutral")
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

def test_high_v(calculator, t_pose_com):
    print("\nTest: High V Pose (Arms Diagonally Up)")
    nodes = create_t_pose_nodes()

    # Raise Arms in High V (diagonally up)
    # Right Arm High V
    nodes["mixamorig_RightArm"].position = SCNVector3(20, 130, 0)
    nodes["mixamorig_RightForeArm"].position = SCNVector3(35, 150, 0)
    nodes["mixamorig_RightHand"].position = SCNVector3(50, 170, 0)
    # Right hand is missing the distal tip in create_t_pose_nodes to test the fallback,
    # so we don't need to position mixamorig_RightHandMiddle1 here.

    # Left Arm High V
    nodes["mixamorig_LeftArm"].position = SCNVector3(-20, 130, 0)
    nodes["mixamorig_LeftForeArm"].position = SCNVector3(-35, 150, 0)
    nodes["mixamorig_LeftHand"].position = SCNVector3(-50, 170, 0)
    nodes["mixamorig_LeftHandMiddle1"].position = SCNVector3(-55, 175, 0)

    calculator.bind(nodes)
    highv_com, _ = calculator.calculate_detailed_body_com()

    print(f"   High V CoM: {highv_com}")

    diff = highv_com.y - t_pose_com.y
    print(f"   Rise from T-Pose: {diff:.2f}")

    if diff > 0.5:
        print("✅ PASS: CoM rose")
        return True
    else:
        print("❌ FAIL: CoM did not rise")
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

def test_lunge(calculator, t_pose_com):
    print("\nTest: Lunge Pose (Asymmetric Stance, Lower Hips)")
    nodes = create_t_pose_nodes()

    # Lower hips
    drop = 15.0
    for key in nodes:
        nodes[key].position.y -= drop

    # Keep feet on ground, but spread them
    nodes["mixamorig_RightFoot"].position = SCNVector3(10, 10, 20)
    nodes["mixamorig_RightToeBase"].position = SCNVector3(10, 0, 30)

    nodes["mixamorig_LeftFoot"].position = SCNVector3(-10, 10, -20)
    nodes["mixamorig_LeftToeBase"].position = SCNVector3(-10, 0, -10)

    # Adjust knees
    nodes["mixamorig_RightLeg"].position = SCNVector3(10, 50, 20)
    nodes["mixamorig_LeftLeg"].position = SCNVector3(-10, 50, -20)

    calculator.bind(nodes)
    lunge_com, _ = calculator.calculate_detailed_body_com()

    print(f"   Lunge CoM: {lunge_com}")

    diff = t_pose_com.y - lunge_com.y
    print(f"   Drop from T-Pose: {diff:.2f}")

    if diff > 5.0:
        print("✅ PASS: CoM lowered significantly in lunge")
        return True
    else:
        print("❌ FAIL: CoM did not lower significantly in lunge")
        return False

def test_liberty(calculator, t_pose_com):
    print("\nTest: Liberty Pose (Single Leg, Arms High V)")
    nodes = create_t_pose_nodes()

    # Raise arms to High V (same as High V test)
    nodes["mixamorig_RightForeArm"].position = SCNVector3(-30, 150, 0)
    nodes["mixamorig_RightHand"].position = SCNVector3(-50, 170, 0)
    # RightHandMiddle1 omitted to test fallback

    nodes["mixamorig_LeftForeArm"].position = SCNVector3(30, 150, 0)
    nodes["mixamorig_LeftHand"].position = SCNVector3(50, 170, 0)
    nodes["mixamorig_LeftHandMiddle1"].position = SCNVector3(60, 180, 0)

    # Raise Right Leg (flex hip and knee)
    # Right thigh: UpLeg -> Leg
    nodes["mixamorig_RightLeg"].position = SCNVector3(10, 90, 30) # Knee goes up and forward
    # Right Shank: Leg -> Foot
    nodes["mixamorig_RightFoot"].position = SCNVector3(10, 50, 30) # Ankle below knee
    # Right Foot: Foot -> ToeBase
    nodes["mixamorig_RightToeBase"].position = SCNVector3(10, 40, 30)

    calculator.bind(nodes)
    liberty_com, _ = calculator.calculate_detailed_body_com()

    print(f"   Liberty CoM: {liberty_com}")

    rise = liberty_com.y - t_pose_com.y
    x_shift = abs(liberty_com.x - t_pose_com.x)
    print(f"   Rise from T-Pose: {rise:.2f}")
    print(f"   Lateral Shift (X): {x_shift:.2f}")

    if rise > 1.0:
        print("✅ PASS: CoM rose significantly in Liberty")
        return True
    else:
        print("❌ FAIL: CoM did not rise significantly in Liberty")
        return False

def test_arabesque(calculator, t_pose_com):
    print("\nTest: Arabesque Pose (Right leg extended back, arms out)")
    nodes = create_t_pose_nodes()

    # Move right leg backwards (-Z) and up
    nodes["mixamorig_RightLeg"].position = SCNVector3(10, 80, -30)
    nodes["mixamorig_RightFoot"].position = SCNVector3(10, 60, -50)
    nodes["mixamorig_RightToeBase"].position = SCNVector3(10, 50, -60)

    # Move arms to the side (simulating arabesque arm positions)
    nodes["mixamorig_RightHand"].position = SCNVector3(60, 130, 0)
    nodes["mixamorig_LeftHand"].position = SCNVector3(-60, 130, 0)

    calculator.bind(nodes)
    arabesque_com, _ = calculator.calculate_detailed_body_com()

    print(f"   Arabesque CoM: {arabesque_com}")

    z_shift = abs(arabesque_com.z - t_pose_com.z)
    print(f"   Z Shift from T-Pose: {z_shift:.2f}")

    if z_shift > 1.0:
        print("✅ PASS: CoM shifted significantly in Z for Arabesque")
        return True
    else:
        print("❌ FAIL: CoM Z shift not significant for Arabesque")
        return False

def test_bridge(calculator, t_pose_com):
    print("\nTest: Bridge Pose (Backbend)")
    nodes = create_t_pose_nodes()

    # Drop hips and spine significantly
    nodes["mixamorig_Hips"].position = SCNVector3(0, 50, 0)
    nodes["mixamorig_Spine"].position = SCNVector3(0, 55, -10)
    nodes["mixamorig_Spine1"].position = SCNVector3(0, 60, -20)
    nodes["mixamorig_Spine2"].position = SCNVector3(0, 55, -30)
    nodes["mixamorig_Neck"].position = SCNVector3(0, 45, -40)
    nodes["mixamorig_Head"].position = SCNVector3(0, 40, -45)
    nodes["mixamorig_HeadTop_End"].position = SCNVector3(0, 30, -50)

    # Move arms to the floor behind the head
    nodes["mixamorig_RightArm"].position = SCNVector3(15, 30, -35)
    nodes["mixamorig_RightForeArm"].position = SCNVector3(20, 15, -40)
    nodes["mixamorig_RightHand"].position = SCNVector3(20, 0, -40)
    nodes["mixamorig_LeftArm"].position = SCNVector3(-15, 30, -35)
    nodes["mixamorig_LeftForeArm"].position = SCNVector3(-20, 15, -40)
    nodes["mixamorig_LeftHand"].position = SCNVector3(-20, 0, -40)

    calculator.bind(nodes)
    bridge_com, _ = calculator.calculate_detailed_body_com()

    print(f"   Bridge CoM: {bridge_com}")
    drop = t_pose_com.y - bridge_com.y
    z_shift = bridge_com.z - t_pose_com.z

    print(f"   Drop from T-Pose: {drop:.2f}")
    print(f"   Z Shift from T-Pose: {z_shift:.2f}")

    if drop > 10.0 and z_shift < -2.0:
        print("✅ PASS: CoM dropped and shifted backward significantly for Bridge")
        return True
    else:
        print("❌ FAIL: CoM shift not as expected for Bridge")
        return False

def test_scale(calculator, t_pose_com):
    print("\nTest: Scale Pose (Leg extended to side/up)")
    nodes = create_t_pose_nodes()

    # Move left leg out and up
    nodes["mixamorig_LeftLeg"].position = SCNVector3(-40, 80, 0)
    nodes["mixamorig_LeftFoot"].position = SCNVector3(-60, 90, 0)
    nodes["mixamorig_LeftToeBase"].position = SCNVector3(-70, 95, 0)

    calculator.bind(nodes)
    scale_com, _ = calculator.calculate_detailed_body_com()

    print(f"   Scale CoM: {scale_com}")

    lateral_shift = abs(scale_com.x - t_pose_com.x)
    print(f"   Lateral Shift (X): {lateral_shift:.2f}")

    if lateral_shift > 1.0:
        print("✅ PASS: CoM shifted laterally for Scale")
        return True
    else:
        print("❌ FAIL: CoM did not shift laterally for Scale")
        return False

def test_prep_position(calculator, t_pose_com):
    print("\nTest: Prep Position (Slight Squat, Hands at Chest)")
    nodes = create_t_pose_nodes()

    # Slight drop in hips and knees
    nodes["mixamorig_Hips"].position = SCNVector3(0, 95, 0)
    nodes["mixamorig_Spine"].position = SCNVector3(0, 100, 0)
    nodes["mixamorig_RightUpLeg"].position = SCNVector3(10, 95, 0)
    nodes["mixamorig_LeftUpLeg"].position = SCNVector3(-10, 95, 0)
    nodes["mixamorig_RightLeg"].position = SCNVector3(10, 48, 10)
    nodes["mixamorig_LeftLeg"].position = SCNVector3(-10, 48, 10)

    # Hands near chest (Y ~ 110-120)
    nodes["mixamorig_RightForeArm"].position = SCNVector3(15, 120, 10)
    nodes["mixamorig_RightHand"].position = SCNVector3(5, 120, 15)
    # RightHandMiddle1 is missing by design for fallback testing
    nodes["mixamorig_LeftForeArm"].position = SCNVector3(-15, 120, 10)
    nodes["mixamorig_LeftHand"].position = SCNVector3(-5, 120, 15)
    nodes["mixamorig_LeftHandMiddle1"].position = SCNVector3(-5, 120, 20)

    calculator.bind(nodes)
    prep_com, _ = calculator.calculate_detailed_body_com()

    print(f"   Prep Position CoM: {prep_com}")

    drop = t_pose_com.y - prep_com.y
    print(f"   Drop from T-Pose: {drop:.2f}")

    if drop > 1.0 and drop < 10.0:
        print("✅ PASS: CoM dropped slightly in Prep Position")
        return True
    else:
        print("❌ FAIL: CoM drop not in expected range for Prep Position")
        return False

class JointLimitsMock:
    limits = {
        "mixamorig_RightLeg": {"min": SCNVector3(-160, -360, -360), "max": SCNVector3(0, 360, 360)},
        "mixamorig_LeftLeg": {"min": SCNVector3(-160, -360, -360), "max": SCNVector3(0, 360, 360)},
        "mixamorig_RightForeArm": {"min": SCNVector3(-360, -360, 0), "max": SCNVector3(360, 360, 160)},
        "mixamorig_LeftForeArm": {"min": SCNVector3(-360, -360, -160), "max": SCNVector3(360, 360, 0)},
        "mixamorig_RightArm": {"min": SCNVector3(-180, -90, -180), "max": SCNVector3(90, 90, 0)},
        "mixamorig_LeftArm": {"min": SCNVector3(-180, -90, 0), "max": SCNVector3(90, 90, 180)},
        "mixamorig_Spine": {"min": SCNVector3(-45, -45, -45), "max": SCNVector3(45, 45, 45)},
        "mixamorig_Spine1": {"min": SCNVector3(-45, -45, -45), "max": SCNVector3(45, 45, 45)},
        "mixamorig_Spine2": {"min": SCNVector3(-45, -45, -45), "max": SCNVector3(45, 45, 45)},
        "mixamorig_Neck": {"min": SCNVector3(-60, -80, -45), "max": SCNVector3(60, 80, 45)},
        "mixamorig_Head": {"min": SCNVector3(-60, -80, -45), "max": SCNVector3(60, 80, 45)},
        "mixamorig_RightUpLeg": {"min": SCNVector3(-180, -90, -180), "max": SCNVector3(90, 90, 180)},
        "mixamorig_LeftUpLeg": {"min": SCNVector3(-180, -90, -180), "max": SCNVector3(90, 90, 180)},
        "mixamorig_RightHand": {"min": SCNVector3(-90, -45, -45), "max": SCNVector3(90, 45, 45)},
        "mixamorig_LeftHand": {"min": SCNVector3(-90, -45, -45), "max": SCNVector3(90, 45, 45)},
        "mixamorig_RightFoot": {"min": SCNVector3(-45, -30, -30), "max": SCNVector3(45, 30, 30)},
        "mixamorig_LeftFoot": {"min": SCNVector3(-45, -30, -30), "max": SCNVector3(45, 30, 30)}
    }

    @staticmethod
    def clamp_angles(joint_name, angles):
        if joint_name not in JointLimitsMock.limits:
            return angles

        limit = JointLimitsMock.limits[joint_name]

        # We need to convert the limits to radians for the clamping,
        # but the inputs here in the mock are usually manipulated in degrees for testing,
        # or we assume they are passed in radians. Let's do radians.
        min_rad = SCNVector3(math.radians(limit["min"].x), math.radians(limit["min"].y), math.radians(limit["min"].z))
        max_rad = SCNVector3(math.radians(limit["max"].x), math.radians(limit["max"].y), math.radians(limit["max"].z))

        clamped_x = max(min_rad.x, min(max_rad.x, angles.x))
        clamped_y = max(min_rad.y, min(max_rad.y, angles.y))
        clamped_z = max(min_rad.z, min(max_rad.z, angles.z))

        if clamped_x != angles.x or clamped_y != angles.y or clamped_z != angles.z:
            deg_x = math.degrees(angles.x)
            deg_y = math.degrees(angles.y)
            deg_z = math.degrees(angles.z)
            c_x = math.degrees(clamped_x)
            c_y = math.degrees(clamped_y)
            c_z = math.degrees(clamped_z)
            print(f"⚠️ POSE VALIDATOR WARNING: Out-of-range angle clamped on {joint_name}. Attempted: ({deg_x:.1f}°, {deg_y:.1f}°, {deg_z:.1f}°) -> Clamped: ({c_x:.1f}°, {c_y:.1f}°, {c_z:.1f}°)")

        return SCNVector3(clamped_x, clamped_y, clamped_z)

def test_joint_limits():
    print("\nTest: Joint Limits")

    # Test Knee limits [-160, 0]
    knee_angle = SCNVector3(math.radians(-180), 0, 0)
    clamped_knee = JointLimitsMock.clamp_angles("mixamorig_RightLeg", knee_angle)
    if abs(clamped_knee.x - math.radians(-160)) < 0.001:
        print("✅ PASS: Knee X clamped to -160 degrees")
    else:
        print(f"❌ FAIL: Knee X not clamped. Got {math.degrees(clamped_knee.x)}")
        return False

    knee_angle_pos = SCNVector3(math.radians(20), 0, 0)
    clamped_knee_pos = JointLimitsMock.clamp_angles("mixamorig_RightLeg", knee_angle_pos)
    if abs(clamped_knee_pos.x - 0) < 0.001:
        print("✅ PASS: Knee X clamped to 0 degrees")
    else:
        print(f"❌ FAIL: Knee X not clamped to 0. Got {math.degrees(clamped_knee_pos.x)}")
        return False

    # Test Elbow limits
    r_elbow = SCNVector3(0, 0, math.radians(180))
    clamped_r_elbow = JointLimitsMock.clamp_angles("mixamorig_RightForeArm", r_elbow)
    if abs(clamped_r_elbow.z - math.radians(160)) < 0.001:
        print("✅ PASS: Right Elbow Z clamped to 160 degrees")
    else:
        print(f"❌ FAIL: Right Elbow Z not clamped. Got {math.degrees(clamped_r_elbow.z)}")
        return False

    l_elbow = SCNVector3(0, 0, math.radians(-180))
    clamped_l_elbow = JointLimitsMock.clamp_angles("mixamorig_LeftForeArm", l_elbow)
    if abs(clamped_l_elbow.z - math.radians(-160)) < 0.001:
        print("✅ PASS: Left Elbow Z clamped to -160 degrees")
    else:
        print(f"❌ FAIL: Left Elbow Z not clamped. Got {math.degrees(clamped_l_elbow.z)}")
        return False

    # Test Shoulder limits
    r_shoulder = SCNVector3(math.radians(-200), 0, math.radians(10))
    clamped_r_shoulder = JointLimitsMock.clamp_angles("mixamorig_RightArm", r_shoulder)
    if abs(clamped_r_shoulder.x - math.radians(-180)) < 0.001 and abs(clamped_r_shoulder.z - 0) < 0.001:
        print("✅ PASS: Right Shoulder clamped properly")
    else:
        print(f"❌ FAIL: Right Shoulder not clamped. Got X: {math.degrees(clamped_r_shoulder.x)}, Z: {math.degrees(clamped_r_shoulder.z)}")
        return False

    l_shoulder = SCNVector3(math.radians(-200), 0, math.radians(-10))
    clamped_l_shoulder = JointLimitsMock.clamp_angles("mixamorig_LeftArm", l_shoulder)
    if abs(clamped_l_shoulder.x - math.radians(-180)) < 0.001 and abs(clamped_l_shoulder.z - 0) < 0.001:
        print("✅ PASS: Left Shoulder clamped properly")
    else:
        print(f"❌ FAIL: Left Shoulder not clamped. Got X: {math.degrees(clamped_l_shoulder.x)}, Z: {math.degrees(clamped_l_shoulder.z)}")
        return False

    # Test Spine limits
    spine_angle = SCNVector3(math.radians(-50), math.radians(60), 0)
    clamped_spine = JointLimitsMock.clamp_angles("mixamorig_Spine", spine_angle)
    if abs(clamped_spine.x - math.radians(-45)) < 0.001 and abs(clamped_spine.y - math.radians(45)) < 0.001:
        print("✅ PASS: Spine clamped properly")
    else:
        print(f"❌ FAIL: Spine not clamped. Got X: {math.degrees(clamped_spine.x)}, Y: {math.degrees(clamped_spine.y)}")
        return False

    # Test Neck limits
    neck_angle = SCNVector3(math.radians(-70), math.radians(90), 0)
    clamped_neck = JointLimitsMock.clamp_angles("mixamorig_Neck", neck_angle)
    if abs(clamped_neck.x - math.radians(-60)) < 0.001 and abs(clamped_neck.y - math.radians(80)) < 0.001:
        print("✅ PASS: Neck clamped properly")
    else:
        print(f"❌ FAIL: Neck not clamped. Got X: {math.degrees(clamped_neck.x)}, Y: {math.degrees(clamped_neck.y)}")
        return False

    # Test Hip limits
    r_hip = SCNVector3(math.radians(-200), math.radians(100), 0)
    clamped_r_hip = JointLimitsMock.clamp_angles("mixamorig_RightUpLeg", r_hip)
    if abs(clamped_r_hip.x - math.radians(-180)) < 0.001 and abs(clamped_r_hip.y - math.radians(90)) < 0.001:
        print("✅ PASS: Right Hip clamped properly")
    else:
        print(f"❌ FAIL: Right Hip not clamped. Got X: {math.degrees(clamped_r_hip.x)}, Y: {math.degrees(clamped_r_hip.y)}")
        return False

    # Test Hand (Wrist) limits
    r_hand = SCNVector3(math.radians(120), math.radians(60), math.radians(-60))
    clamped_r_hand = JointLimitsMock.clamp_angles("mixamorig_RightHand", r_hand)
    if abs(clamped_r_hand.x - math.radians(90)) < 0.001 and abs(clamped_r_hand.y - math.radians(45)) < 0.001 and abs(clamped_r_hand.z - math.radians(-45)) < 0.001:
        print("✅ PASS: Right Hand (Wrist) clamped properly")
    else:
        print(f"❌ FAIL: Right Hand not clamped. Got X: {math.degrees(clamped_r_hand.x)}, Y: {math.degrees(clamped_r_hand.y)}, Z: {math.degrees(clamped_r_hand.z)}")
        return False

    # Test Foot (Ankle) limits
    r_foot = SCNVector3(math.radians(-60), math.radians(-50), math.radians(40))
    clamped_r_foot = JointLimitsMock.clamp_angles("mixamorig_RightFoot", r_foot)
    if abs(clamped_r_foot.x - math.radians(-45)) < 0.001 and abs(clamped_r_foot.y - math.radians(-30)) < 0.001 and abs(clamped_r_foot.z - math.radians(30)) < 0.001:
        print("✅ PASS: Right Foot (Ankle) clamped properly")
    else:
        print(f"❌ FAIL: Right Foot not clamped. Got X: {math.degrees(clamped_r_foot.x)}, Y: {math.degrees(clamped_r_foot.y)}, Z: {math.degrees(clamped_r_foot.z)}")
        return False

    return True

def run_verification():
    print("🧪 Running CoM Verification Harness (Python)\n")

    calculator = COMCalculatorMock(body_mass=70.0)

    if not test_mass_ratios():
        sys.exit(1)

    if not test_body_presets():
        sys.exit(1)

    t_pose_com = test_t_pose(calculator)

    if not test_high_v(calculator, t_pose_com):
        sys.exit(1)

    if not test_touchdown(calculator, t_pose_com):
        sys.exit(1)

    if not test_squat(calculator, t_pose_com):
        sys.exit(1)

    if not test_pike(calculator, t_pose_com):
        sys.exit(1)

    if not test_lunge(calculator, t_pose_com):
        sys.exit(1)

    if not test_liberty(calculator, t_pose_com):
        sys.exit(1)

    if not test_prep_position(calculator, t_pose_com):
        sys.exit(1)

    if not test_arabesque(calculator, t_pose_com):
        sys.exit(1)

    if not test_scale(calculator, t_pose_com):
        sys.exit(1)

    if not test_bridge(calculator, t_pose_com):
        sys.exit(1)

    if not test_joint_limits():
        sys.exit(1)

    print("\n✅ All CoM Logic Tests Passed")

if __name__ == "__main__":
    run_verification()
