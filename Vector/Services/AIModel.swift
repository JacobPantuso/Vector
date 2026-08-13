import FoundationModels

/// Central gate for Apple's Private Cloud Compute (PCC) model.
///
/// `PrivateCloudComputeLanguageModel` is available on iOS 27+ and watchOS 27+.
/// However, PCC still requires the restricted `com.apple.developer.private-cloud-compute`
/// entitlement to function. Vector lacks this entitlement, so PCC is disabled
/// and the type is not referenced anywhere in this codebase. Reintroduce it
/// once the app is signed with the entitlement.
enum AIModel {
    static let isPCCEnabled = false

    static var isCloudAvailable: Bool {
        false
    }

    /// The on-device system model does not support reasoning; `.reasoningLevel` throws
    /// `LanguageModelError.unsupportedCapability` if applied anyway. Feature-detect rather than assume.
    static var supportsReasoning: Bool {
        SystemLanguageModel.default.capabilities.contains(.reasoning)
    }
}
