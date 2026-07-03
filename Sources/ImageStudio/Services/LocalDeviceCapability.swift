import Foundation

struct LocalRuntimeProfile: Equatable, Sendable {
    let title: String
    let detail: String
    let defaultStepCount: Int
    let maxStepCount: Int
    let defaultGuidanceScale: Float
}

struct LocalDeviceCapability: Equatable, Sendable {
    let modelIdentifier: String
    let physicalMemoryBytes: Int64
    let estimatedChipRank: Int?
    let isSimulator: Bool

    static func current() -> LocalDeviceCapability {
        let identifier = currentModelIdentifier()
        return LocalDeviceCapability(
            modelIdentifier: identifier,
            physicalMemoryBytes: Int64(ProcessInfo.processInfo.physicalMemory),
            estimatedChipRank: estimatedChipRank(for: identifier),
            isSimulator: isRunningInSimulator
        )
    }

    func unsupportedReason(for entry: LocalModelEntry) -> String? {
        if isSimulator {
            return "The iOS simulator cannot run the on-device SDXL pipeline. Use a physical iPhone or iPad."
        }

        if let minimumRAMBytes = entry.minimumRAMBytes, physicalMemoryBytes < minimumRAMBytes {
            return "This device has \(formatBytes(physicalMemoryBytes)) RAM. \(formatBytes(minimumRAMBytes)) is required for local SDXL."
        }

        if let minimumChip = entry.minimumChip,
           let estimatedChipRank,
           estimatedChipRank < minimumChip.rank {
            return "This device is below the minimum \(minimumChip.displayName) chip requirement for local SDXL."
        }

        return nil
    }

    var runtimeProfile: LocalRuntimeProfile {
        switch physicalMemoryBytes {
        case ..<7_500_000_000:
            return LocalRuntimeProfile(
                title: "Conservative",
                detail: "Lower memory footprint for 6 GB class devices.",
                defaultStepCount: 18,
                maxStepCount: 28,
                defaultGuidanceScale: 7.0
            )
        case ..<11_000_000_000:
            return LocalRuntimeProfile(
                title: "Balanced",
                detail: "Good default tradeoff for most supported devices.",
                defaultStepCount: 24,
                maxStepCount: 38,
                defaultGuidanceScale: 7.5
            )
        default:
            return LocalRuntimeProfile(
                title: "High Quality",
                detail: "Higher default fidelity for memory-rich devices.",
                defaultStepCount: 30,
                maxStepCount: 50,
                defaultGuidanceScale: 8.0
            )
        }
    }

    var memoryDescription: String {
        formatBytes(physicalMemoryBytes)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
    }

    private static var isRunningInSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    private static func currentModelIdentifier() -> String {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Simulator"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { result, child in
            guard let value = child.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
        #endif
    }

    private static func estimatedChipRank(for identifier: String) -> Int? {
        if identifier.hasPrefix("iPhone"),
           let major = deviceMajorVersion(for: identifier) {
            switch major {
            case ..<13: return 0
            case 13: return LocalModelChipTier.a14.rank
            case 14: return LocalModelChipTier.a15.rank
            case 15: return LocalModelChipTier.a16.rank
            default: return LocalModelChipTier.a17.rank
            }
        }

        if identifier.hasPrefix("iPad"),
           let major = deviceMajorVersion(for: identifier) {
            switch major {
            case ..<13: return 0
            case 13: return LocalModelChipTier.a14.rank
            default: return LocalModelChipTier.m1.rank
            }
        }

        return nil
    }

    private static func deviceMajorVersion(for identifier: String) -> Int? {
        let digits = identifier
            .split(separator: ",")
            .first?
            .filter(\.isNumber) ?? ""
        return Int(digits)
    }
}

private extension LocalModelChipTier {
    var rank: Int {
        switch self {
        case .a14: return 1
        case .a15: return 2
        case .a16: return 3
        case .a17: return 4
        case .m1: return 5
        }
    }

    var displayName: String {
        switch self {
        case .a14: return "A14"
        case .a15: return "A15"
        case .a16: return "A16"
        case .a17: return "A17"
        case .m1: return "M1"
        }
    }
}
