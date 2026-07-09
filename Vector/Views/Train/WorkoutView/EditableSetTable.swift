import SwiftUI

// MARK: - Editable Set Table Component

struct EditableSetTable: View {
    let session: ActiveWorkoutSession
    let exercise: ManualExerciseEntry

    private enum Field: Hashable {
        case weight(Int)
        case reps(Int)
    }

    @FocusState private var focusedField: Field?

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<exercise.sets, id: \.self) { setIndex in
                SwipeToDelete(onDelete: {
                    withAnimation(.spring(duration: 0.25)) {
                        session.removeSet(from: exercise.id, setIndex: setIndex)
                    }
                }) {
                    setRow(setIndex)
                }
            }

            // Add Set button
            Button {
                withAnimation(.spring(duration: 0.25)) {
                    session.addSet(to: exercise.id)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption2)
                    Text("Add Set")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.cyan)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
        .font(.caption)
        .toolbar {
            if focusedField != nil {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Row

    private func setRow(_ setIndex: Int) -> some View {
        HStack(spacing: 8) {
            Text("Set \(setIndex + 1)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
            Spacer()

                HStack(spacing: 2) {
                    TextField("BW", text: weightText(setIndex))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .focused($focusedField, equals: .weight(setIndex))
                        .frame(width: 38)
                    if weightValue(setIndex) > 0 {
                        Text("lbs")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            // Reps control
                TextField("0", text: repsText(setIndex))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .focused($focusedField, equals: .reps(setIndex))
                    .frame(width: 26)
            Text("reps")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            // Done toggle
            Button {
                session.toggleSetDone(for: exercise.id, setIndex: setIndex)
            } label: {
                Image(systemName: session.isSetDone(exercise.id, setIndex) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(session.isSetDone(exercise.id, setIndex) ? .green : .gray.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
    }

    // MARK: - Stepper wrapper

    @ViewBuilder
    private func stepper<FieldContent: View>(
        minus: @escaping () -> Void,
        plus: @escaping () -> Void,
        @ViewBuilder field: () -> FieldContent
    ) -> some View {
        HStack(spacing: 4) {
            Button(action: minus) {
                Text("−")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 20, height: 18)
            }
            .buttonStyle(.glass)

            field()

            Button(action: plus) {
                Text("+")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 20, height: 18)
            }
            .buttonStyle(.glass)
        }
    }

    // MARK: - Bindings & helpers

    private func weightValue(_ setIndex: Int) -> Double {
        let weights = session.loggedSetWeights[exercise.id] ?? []
        return setIndex < weights.count ? weights[setIndex] : 0
    }

    private func repsValue(_ setIndex: Int) -> Int {
        let reps = session.loggedSetReps[exercise.id] ?? []
        return setIndex < reps.count ? reps[setIndex] : exercise.reps
    }

    private func weightText(_ setIndex: Int) -> Binding<String> {
        Binding(
            get: {
                let w = weightValue(setIndex)
                return w == 0 ? "" : String(format: "%.0f", w)
            },
            set: { newValue in
                let digits = newValue.filter { $0.isNumber }
                session.setWeight(for: exercise.id, setIndex: setIndex, to: max(0, Double(digits) ?? 0))
            }
        )
    }

    private func repsText(_ setIndex: Int) -> Binding<String> {
        Binding(
            get: { "\(repsValue(setIndex))" },
            set: { newValue in
                let digits = newValue.filter { $0.isNumber }
                session.setReps(for: exercise.id, setIndex: setIndex, to: max(0, Int(digits) ?? 0))
            }
        )
    }
}

// MARK: - Swipe to Delete

private struct SwipeToDelete<Content: View>: View {
    let onDelete: () -> Void
    let content: Content

    init(onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onDelete = onDelete
        self.content = content()
    }

    @State private var offset: CGFloat = 0
    private let actionWidth: CGFloat = 56

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red)
                .frame(width: actionWidth + 10)
                .overlay(alignment: .center) {
                    Image(systemName: "trash.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.trailing, 6)
                }
                .opacity(offset < -2 ? 1 : 0)
                .onTapGesture { onDelete() }

            content
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 14)
                        .onChanged { value in
                            let dx = value.translation.width
                            if dx < 0 {
                                offset = max(dx, -actionWidth)
                            } else {
                                offset = min(0, -actionWidth + dx)
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(duration: 0.25)) {
                                offset = value.translation.width < -actionWidth * 0.5 ? -actionWidth : 0
                            }
                        }
                )
        }
    }
}
