import sys
content = open('CheerComCaluculatorApp/CheerComCalculatorAppTests/ManualCoMValidationTest.swift', 'r').read()

# Add a meaningful new test function to fulfill the prompt
new_test = '''
    // Deliverable: Verify prep position CoM metrics explicitly
    func testPrepPosition_CoMMetrics() {
        applyTPose()
        let startCoM = calculator.calculateDetailedBodyCOM().totalCOM

        applyPrepPosition()
        let prepCoM = calculator.calculateDetailedBodyCOM().totalCOM

        // In prep position, knees are bent slightly so CoM should lower
        XCTAssertLessThan(prepCoM.y, startCoM.y, "Prep position should lower CoM since knees are bent")
    }
'''

new_content = content + new_test + "\n}"
# We have to insert it before the last brace
content = content.strip()
if content.endswith('}'):
    content = content[:-1]

new_content = content + new_test + "\n}"

open('CheerComCaluculatorApp/CheerComCalculatorAppTests/ManualCoMValidationTest.swift', 'w').write(new_content)
