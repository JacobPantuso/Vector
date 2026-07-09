import Foundation

/// Centralized feature flags for toggling app features without deleting code.
enum FeatureFlags {
    /// Nutrition is temporarily disabled. Flip to `true` to restore the tab and AI tools.
    static let nutritionEnabled = false
}
