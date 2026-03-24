// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CheerComCalculatorApp",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "CheerComCalculatorApp",
            targets: ["CheerComCalculatorApp"])
    ],
    dependencies: [
        .package(path: "../../ModelRigKit"),
    ],
    targets: [
        .target(
            name: "CheerComCalculatorApp",
            dependencies: ["ModelRigKit"],
            path: "CheerComCaluculatorApp"
        ),
        .testTarget(
            name: "CheerComCalculatorAppTests",
            dependencies: ["CheerComCalculatorApp"],
            path: "CheerComCalculatorAppTests"
        )
    ]
)
