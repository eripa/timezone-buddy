// SPDX-FileCopyrightText: 2026 Eric Ripa
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// A searchable list of every time zone known to the system.
struct AddTimeZoneView: View {
    let settings: AppSettings

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    /// Matching zones, best match first.
    ///
    /// Zones share names and abbreviations — every Eastern zone answers to
    /// "EST" — so results are ranked and the user chooses, rather than the
    /// first row being assumed correct.
    private var results: [TimeZoneEntry.Match] {
        TimeZoneEntry.search(searchText)
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

            TextField("Search cities, regions, names, or abbreviations", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Divider()

            if results.isEmpty {
                ContentUnavailableView(
                    "No Time Zones Found",
                    systemImage: "globe",
                    description: Text(
                        "Try a city, region, time zone name, or abbreviation — such as Calgary, Mountain Time, or MST."
                    )
                )
            } else {
                // A LazyVStack rather than a List: SwiftUI's List is backed by
                // NSOutlineView, which crashes inside Xcode Previews when it
                // diffs these rows while the hosting view is being attached.
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { result in
                            zoneRow(for: result)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(width: 440, height: 520)
        .onAppear {
            isSearchFocused = true
        }
    }

    private func zoneRow(for result: TimeZoneEntry.Match) -> some View {
        let entry = result.entry
        let isAdded = settings.zones.contains { $0.identifier == entry.identifier }

        return Button {
            settings.addZone(identifier: entry.identifier)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(entry.cityName)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)

                        if !entry.abbreviationDescription.isEmpty {
                            Text(entry.abbreviationDescription)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
                        }
                    }

                    Text(subtitle(for: result))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(TimeFormatting.gmtOffset(entry.timeZone, at: .now))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(isAdded ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAdded)
        .help(isAdded ? "\(entry.cityName) is already added" : "Add \(entry.cityName) — \(entry.displayName)")
    }

    /// The zone's name, prefixed with the alias that found it so a match for
    /// "Calgary" doesn't look like an unrelated Edmonton row.
    private func subtitle(for result: TimeZoneEntry.Match) -> String {
        guard let alias = result.matchedAlias else { return result.entry.displayName }
        return "\(alias) · \(result.entry.displayName)"
    }
}

#Preview("Add Time Zones") {
    AddTimeZoneView(settings: AppSettings())
}
