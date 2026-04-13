import ProjectDescription

extension Project {
    public static func app(
        name: String,
        destinations: Destinations,
        deploymentTarget: String
    ) -> Project {
        Project(
            name: name,
            options: .options(
                defaultKnownRegions: ["zh-Hant", "en"],
                developmentRegion: "zh-Hant"
            ),
            packages: [
                .local(path: "Packages/Util"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                    "DEVELOPMENT_TEAM": "7T6Y9LETK9",
                ],
                defaultSettings: .recommended
            ),
            targets: [
                .target(
                    name: name,
                    destinations: destinations,
                    product: .app,
                    bundleId: "com.lova.\(name.lowercased())",
                    deploymentTargets: .macOS(deploymentTarget),
                    infoPlist: .extendingDefault(with: [
                        "LSUIElement": .boolean(true),
                        "CFBundleDisplayName": "\(name)",
                    ]),
                    buildableFolders: [
                        .folder("\(name)/Sources"),
                        .folder("\(name)/Resources"),
                    ],
                    dependencies: [
                        .package(product: "Util", type: .runtime),
                    ]
                ),
                .target(
                    name: "\(name)Tests",
                    destinations: destinations,
                    product: .unitTests,
                    bundleId: "com.lova.\(name.lowercased()).tests",
                    deploymentTargets: .macOS(deploymentTarget),
                    buildableFolders: [
                        .folder("Tests/Sources"),
                    ],
                    dependencies: [
                        .target(name: name),
                    ]
                ),
            ]
        )
    }
}
