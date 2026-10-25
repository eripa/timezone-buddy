// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// A searchable list of every time zone known to the system.
struct AddTimeZoneView: View {
    let settings: AppSettings

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private static let allIdentifiers = TimeZone.knownTimeZoneIdentifiers.sorted()

    private var filteredIdentifiers: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Self.allIdentifiers }

        return Self.allIdentifiers.filter { identifier in
            identifier.localizedCaseInsensitiveContains(query)
                || Self.cityName(for: identifier).localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Time Zones")
                    .font(.headline)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)

            TextField("Search cities, regions, or abbreviations", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .onSubmit {
                    addFirstAvailableResult()
                }

            Divider()

            if filteredIdentifiers.isEmpty {
                ContentUnavailableView(
                    "No Time Zones Found",
                    systemImage: "globe",
                    description: Text("Try a different city, region, or abbreviation.")
                )
            } else {
                List(filteredIdentifiers, id: \.self) { identifier in
                    // Workaround for an Xcode preview crash with custom List rows on macOS.
                    #if DEBUG
                    AnyView(EmptyView())
                    #endif
                    zoneRow(for: identifier)
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 440, height: 520)
        .onAppear {
            isSearchFocused = true
        }
    }

    private func addFirstAvailableResult() {
        let alreadyAdded = Set(settings.zones.map(\.identifier))
        guard let identifier = filteredIdentifiers.first(where: { !alreadyAdded.contains($0) }) else {
            return
        }
        settings.addZone(identifier: identifier)
    }

    private func zoneRow(for identifier: String) -> some View {
        let zone = Self.zone(for: identifier)
        let isAdded = settings.zones.contains { $0.identifier == identifier }

        return Button {
            settings.addZone(identifier: identifier)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(Self.cityName(for: identifier))
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(identifier)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(TimeFormatting.gmtOffset(zone, at: .now))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(isAdded ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .disabled(isAdded)
        .help(isAdded ? "\(Self.cityName(for: identifier)) is already added" : "Add \(Self.cityName(for: identifier))")
    }

    private static func cityName(for identifier: String) -> String {
        guard let city = identifier.split(separator: "/").last else {
            return identifier
        }
        return city.replacingOccurrences(of: "_", with: " ")
    }

    private static func zone(for identifier: String) -> TimeZone {
        TimeZone(identifier: identifier) ?? .current
    }
}

#Preview("Add Time Zones") {
    AddTimeZoneView(settings: AppSettings())
}
