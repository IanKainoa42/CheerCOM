import sys
content = open('CheerComCaluculatorApp/CheerComCalculatorAppTests/ManualCoMValidationTest.swift', 'r').read()
new_content = content.replace(
'''    // Deliverable: Add test for Liberty Pose CoM metrics explicitly
    func testLibertyPose_CoMMetrics() {
        print("Liberty Pose CoM Metrics running")
        applyTPose()''',
'''    // Deliverable: Add test for Liberty Pose CoM metrics explicitly
    func testLibertyPose_CoMMetrics() {
        applyTPose()''')

open('CheerComCaluculatorApp/CheerComCalculatorAppTests/ManualCoMValidationTest.swift', 'w').write(new_content)
