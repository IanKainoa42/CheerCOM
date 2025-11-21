// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CheerComCalculatorApp",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "CheerComCalculatorApp",
            targets: ["CheerComCalculatorApp"])
    ],
    targets: [
        .target(
            name: "CheerComCalculatorApp",
            path: "CheerComCalculatorApp"
        )
    ]
)
