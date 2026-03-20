//
//  TerminalFeedView.swift
//  SerialProbe
//
//  Created by rayanceking on 2026/3/20.
//

import SwiftUI

struct TerminalFeedView: View {
    @ObservedObject var workspace: SerialWorkspace

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if workspace.logEntries.isEmpty {
                        ContentUnavailableView(
                            "等待串口数据",
                            systemImage: "waveform.and.magnifyingglass",
                            description: Text("连接开发板后，接收流会按时间顺序显示在这里。")
                        )
                        .frame(maxWidth: .infinity, minHeight: 360)
                    } else {
                        ForEach(workspace.logEntries) { entry in
                            TerminalRow(
                                entry: entry,
                                displayMode: workspace.displayMode,
                                showTimestamp: workspace.showTimestamps
                            )
                            .id(entry.id)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            .onChange(of: workspace.lastLogID, initial: true) { _, lastLogID in
                guard workspace.autoScroll, let lastLogID else { return }
                withAnimation(.snappy(duration: 0.2)) {
                    proxy.scrollTo(lastLogID, anchor: .bottom)
                }
            }
        }
    }
}

private struct TerminalRow: View {
    let entry: SerialLogEntry
    let displayMode: SerialDisplayMode
    let showTimestamp: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(entry.direction.badgeTitle)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(entry.direction.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(entry.direction.tint.opacity(0.12))
                    )

                if showTimestamp {
                    Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("\(entry.byteCount)B")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            switch displayMode {
            case .text:
                LogBubble(text: entry.textRepresentation, tint: entry.direction.tint)
            case .hex:
                LogBubble(text: entry.hexRepresentation, tint: entry.direction.tint)
            case .mixed:
                VStack(alignment: .leading, spacing: 6) {
                    LogBubble(text: entry.textRepresentation, tint: entry.direction.tint)
                    if !entry.hexRepresentation.isEmpty {
                        Text(entry.hexRepresentation)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LogBubble: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text.isEmpty ? " " : text)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.08))
            )
    }
}
