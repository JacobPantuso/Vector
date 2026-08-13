import SwiftUI

struct EquipmentSetupSheet: View {
    @Binding var hasCompletedEquipmentSetup: Bool
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            EquipmentSetupContent()
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Skip") {
                            hasCompletedEquipmentSetup = true
                        }
                        .font(.subheadline.weight(.semibold))
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            hasCompletedEquipmentSetup = true
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
                .interactiveDismissDisabled()
        }
    }
}
