//
//  MainWorkbenchView.swift
//  SerialProbe
//
//  Created by rayanceking on 2026/3/20.
//

import SwiftUI

struct MainWorkbenchView: View {
    @ObservedObject var workspace: SerialWorkspace

    var body: some View {
        VStack(spacing: 0) {
            SessionHeroHeader(workspace: workspace)
            Divider()
            TerminalFeedView(workspace: workspace)
            Divider()
            ComposerPanel(workspace: workspace)
        }
    }
}

private struct SessionHeroHeader: View {
    @ObservedObject var workspace: SerialWorkspace

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(workspace.sessionTitle)
                        .font(.title2.weight(.semibold))
                    Text(workspace.sessionSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    StatusBadge(
                        title: workspace.connectionStatusLabel,
                        symbol: workspace.connectionStatusSymbol,
                        tint: workspace.connectionTint
                    )
                    StatusBadge(
                        title: workspace.displayMode.label,
                        symbol: "rectangle.3.group.bubble",
                        tint: .indigo
                    )
                }
            }

            HStack(spacing: 12) {
                KeyMetricCard(
                    title: "串口配置",
                    value: "\(workspace.baudRate) / \(workspace.dataBits.label) / \(workspace.parity.label)",
                    detail: workspace.flowControl.label,
                    tint: .accentColor
                )
                KeyMetricCard(
                    title: "会话统计",
                    value: "\(workspace.logEntries.count) 帧",
                    detail: "自动滚动 \(workspace.autoScroll ? "开启" : "关闭")",
                    tint: .green
                )
                KeyMetricCard(
                    title: "发送模式",
                    value: workspace.payloadMode.label,
                    detail: "换行 \(workspace.lineEnding.label)",
                    tint: .orange
                )
            }
        }
        .padding(20)
        .background(.regularMaterial)
    }
}

private struct KeyMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(tint.opacity(0.15), lineWidth: 1)
                )
        }
    }
}

private struct StatusBadge: View {
    let title: String
    let symbol: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .foregroundStyle(tint)
    }
}
