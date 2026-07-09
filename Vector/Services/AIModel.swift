import FoundationModels

/// Central gate for Apple's Private Cloud Compute (PCC) model.
///
/// PCC requires the restricted `com.apple.developer.private-cloud-compute`
/// entitlement, and `PrivateCloudComputeLanguageModel` isn't declared until the
/// iOS 27 SDK — referencing it while building against iOS 26 (as TestFlight
/// builds do) is a compile error, not just a runtime unavailability. So the type
/// itself isn't referenced anywhere in this codebase right now. Reintroduce it
/// here once the app is signed with the entitlement and building against the
/// iOS 27 SDK.
enum AIModel {
    static let isPCCEnabled = false

    static var isCloudAvailable: Bool {
        false
    }
}
