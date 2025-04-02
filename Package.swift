// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "menu_bar_stock_info",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "menu_bar_stock_info",
            targets: ["menu_bar_stock_info"]),
    ],
    dependencies: [
        .package(url: "https://github.com/AlexRoar/SwiftYFinance", from: "1.4.1"),
    ],
    targets: [
        .target(
            name: "menu_bar_stock_info",
            dependencies: [
                .product(name: "SwiftYFinance", package: "SwiftYFinance"),
            ],
            path: "menu_bar_stock_info"),
    ]
) 