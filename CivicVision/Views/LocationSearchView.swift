import SwiftUI

/// Debounced ZIP / place search that sets the app's manual location.
struct LocationSearchView: View {
    @Environment(ExposureStore.self) private var store
    @State private var query = ""
    @State private var results: [GeoSuggestion] = []
    @State private var loading = false
    @State private var error: String?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                TextField("Enter ZIP or place (10001, Brooklyn, 94110)", text: $query)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($focused)
                    .foregroundStyle(Theme.text)
                if loading {
                    ProgressView().scaleEffect(0.7)
                } else if !query.isEmpty {
                    Button {
                        clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textTertiary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))

            if focused, !results.isEmpty || error != nil {
                resultsList
            }
        }
        .onChange(of: query) { _, newValue in scheduleSearch(newValue) }
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(results.enumerated()), id: \.element.id) { index, s in
                Button {
                    pick(s)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.label).font(.subheadline.weight(.medium)).foregroundStyle(Theme.text)
                        if let sub = s.sublabel {
                            Text(sub).font(.caption).foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < results.count - 1 {
                    Divider().overlay(Theme.border)
                }
            }
            if results.isEmpty, let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }

    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 2 {
            results = []
            error = nil
            loading = false
            return
        }
        loading = true
        error = nil
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            do {
                let r = try await Geocoder.geocode(trimmed)
                if Task.isCancelled { return }
                results = r
                error = r.isEmpty ? "No matches. Try a city, ZIP, or landmark." : nil
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                self.error = "Search failed. Check your connection."
                results = []
            }
            loading = false
        }
    }

    private func pick(_ s: GeoSuggestion) {
        Haptics.tap()
        store.setManualLocation(s)
        clear()
        focused = false
    }

    private func clear() {
        searchTask?.cancel()
        query = ""
        results = []
        error = nil
        loading = false
    }
}
