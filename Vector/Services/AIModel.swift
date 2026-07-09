import FoundationModels

/// Central gate for Apple's Private Cloud Compute (PCC) model.
///
/// PCC requires the restricted `com.apple.developer.private-cloud-compute`
/// entitlement. Without it, ANY use of `PrivateCloudComputeLanguageModel` — even
/// reading `.availability` — triggers a non-catchable `Fatal error`. So PCC is
/// opt-in and OFF by default. Flip `isPCCEnabled` to `true` ONLY in a build that
/// is actually signed with the entitlement.
enum AIModel {
    /// Set to `true` only once the app is signed with the PCC entitlement.
    static let isPCCEnabled = false

    /// Safe to evaluate anywhere: Swift `&&` short-circuits, so the cloud model is
    /// never constructed or queried unless PCC is enabled.
    static var isCloudAvailable: Bool {
        guard #available(iOS 27, *) else { return false }
        return isPCCEnabled && PrivateCloudComputeLanguageModel().availability == .available
    }
}
