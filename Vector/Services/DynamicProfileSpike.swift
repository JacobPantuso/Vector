// DynamicProfileSpike.swift
// Throwaway compile spike for iOS 27 FoundationModels.LanguageModelSession.DynamicProfile API
// This file tests which parts of the new API actually compile.
// DELIVERABLE: Honest report of successes and failures, with all experiments included (failures marked with FAILED: comments).

#if DEBUG

import FoundationModels
import Foundation

@available(iOS 27.0, *)
enum DynamicProfileSpike {

    // MARK: - Experiment 1: Minimal profile with Instructions + session creation
    /// Tests basic Profile initialization and session usage.
    static func experiment1_minimalProfile() {
        let profile = LanguageModelSession.Profile {
            Instructions("You are a test.")
        }
        let session = LanguageModelSession(profile: profile)
        // Session created successfully
    }

    // MARK: - Experiment 2: Profile with .reasoningLevel(.light) and .maximumResponseTokens(200)
    /// Tests profile builder modifiers: reasoningLevel and maximumResponseTokens.
    /// Modifiers chain on the Profile/DynamicProfile, not on Instructions.
    static func experiment2_profileWithModifiers() {
        let profile = LanguageModelSession.Profile {
            Instructions("You are a test.")
        }
        .reasoningLevel(.light)
        .maximumResponseTokens(200)
        let session = LanguageModelSession(profile: profile)
        // Session created with modifiers
    }

    // MARK: - Experiment 3: Conditional instructions (if/else, tests buildEither)
    /// Tests buildEither via if/else branching inside the builder.
    static func experiment3_conditionalInstructions() {
        let someBoolean = true
        let profile = LanguageModelSession.Profile {
            if someBoolean {
                Instructions("Branch A")
            } else {
                Instructions("Branch B")
            }
        }
        let session = LanguageModelSession(profile: profile)
        // Conditional instructions work
    }

    // MARK: - Experiment 4: Tool in builder (GetWorkoutHistoryTool from AdvisorTools)
    /// Tests whether real tools compose into instructions.
    /// This is the single most important experiment — it tests whether tools work inside profiles.
    static func experiment4_toolInBuilder() {
        let profile = LanguageModelSession.Profile {
            Instructions("You are a fitness advisor.")
            GetWorkoutHistoryTool()
        }
        let session = LanguageModelSession(profile: profile)
        // Tool added to profile builder
    }

    // MARK: - Experiment 5: DynamicInstructions.ForEach over array of strings
    /// Tests ForEach builder — iterates over an array and emits instructions per element.
    static func experiment5_forEachInstructions() {
        let exercises = ["Push-ups", "Squats", "Bench Press"]
        let profile = LanguageModelSession.Profile {
            Instructions("You are a trainer. Know these exercises:")
            DynamicInstructions.ForEach(exercises, id: \.self) { exercise in
                Instructions("- \(exercise)")
            }
        }
        let session = LanguageModelSession(profile: profile)
        // ForEach instructions added
    }

    // MARK: - Experiment 6: .historyTransform modifier on DynamicProfile
    /// Tests the historyTransform modifier: filters history to last 12 entries.
    /// This modifier is on DynamicProfile, not on Instructions.
    static func experiment6_historyTransform() {
        let profile = LanguageModelSession.Profile {
            Instructions("You are a test.")
        }
        .historyTransform { entries in
            Array(entries.suffix(12))
        }
        let session = LanguageModelSession(profile: profile)
        // historyTransform modifier applied
    }

    // MARK: - Experiment 7a: Custom DynamicProfile drives a session (no wrapper)
    /// Tests that a custom struct conforming to DynamicProfile can drive a session directly.
    /// Tests the `sending some DynamicProfile` parameter in LanguageModelSession.init.
    @available(iOS 27.0, *)
    struct CustomProfile: LanguageModelSession.DynamicProfile {
        var body: some LanguageModelSession.DynamicProfile {
            LanguageModelSession.Profile {
                Instructions("Custom profile instructions.")
            }
            .reasoningLevel(.moderate)
        }
    }

    static func experiment7a_customDynamicProfileDrivesSession() {
        // Critical test: pass custom profile directly via `sending some DynamicProfile`
        let profile = CustomProfile()
        let session = LanguageModelSession(profile: profile)
        // If this compiles, custom DynamicProfile successfully drives the session
    }

    // MARK: - Experiment 7b: Custom DynamicProfile with history parameter
    /// Tests that custom DynamicProfile works with the history parameter.
    static func experiment7b_customDynamicProfileWithHistory() {
        let profile = CustomProfile()
        let history: [Transcript.Entry] = []  // Empty array confirms type
        let session = LanguageModelSession(profile: profile, history: history)
        // If this compiles, history parameter typechecks with custom DynamicProfile
    }

    // MARK: - Experiment 7c: @SessionPropertyEntry macro in SessionPropertyValues extension
    /// The macro must be applied to a var in an extension of SessionPropertyValues.
    /// This is analogous to SwiftUI's @Entry macro.
}

@available(iOS 27.0, *)
extension SessionPropertyValues {
    @SessionPropertyEntry var vectorRecoveryScore: Int = 0
}

@available(iOS 27.0, *)
extension DynamicProfileSpike {
    // MARK: - Experiment 7d: SessionProperty property wrapper
    /// Tests reading a SessionProperty-wrapped keypath inside a custom DynamicProfile.
    struct CustomProfileWithSessionProperty: LanguageModelSession.DynamicProfile {
        @LanguageModelSession.SessionProperty(\.vectorRecoveryScore) var recovery: Int

        var body: some LanguageModelSession.DynamicProfile {
            LanguageModelSession.Profile {
                Instructions("Profile with session property: recovery score \(recovery)")
            }
        }
    }

    static func experiment7d_sessionPropertyComposesInProfile() {
        // Test: SessionProperty wrapper composes inside custom DynamicProfile
        let profile = CustomProfileWithSessionProperty()
        let session = LanguageModelSession(profile: profile)
        // If this compiles, SessionProperty successfully reads and composes
    }
}

#endif
