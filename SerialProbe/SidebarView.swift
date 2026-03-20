//
//  SidebarView.swift
//  SerialProbe
//
//  Created by rayanceking on 2026/3/20.
//

import SwiftUI

struct SidebarView: View {
    @ObservedObject var workspace: SerialWorkspace

    var body: some View {
        List {
            Section("检测到的开发板") {
                if workspace.availablePorts.isEmpty {
                    ContentUnavailableView(
                        "暂无串口设备",
                        systemImage: "cable.connector.slash",
                        description: Text("插入开发板后点击工具栏中的“刷新”。")
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(workspace.availablePorts) { port in
                        Button {
                            workspace.selectedPortPath = port.path
                        } label: {
                            SidebarPortRow(
                                port: port,
                                isSelected: workspace.selectedPortPath == port.path,
                                isConnected: workspace.connectedPortPath == port.path
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("调试场景") {
                ForEach(workspace.presets) { preset in
                    Button {
                        workspace.applyPreset(preset)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                Text(preset.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: preset.symbolName)
                                .foregroundStyle(preset.tint, .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("常用指令") {
                ForEach(workspace.quickCommands.prefix(4)) { command in
                    Button {
                        workspace.send(command: command)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(command.name)
                                Text(command.payload)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(command.mode.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!workspace.isConnected)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            SidebarStatusFooter(workspace: workspace)
                .padding(12)
                .background(.regularMaterial)
        }
    }
}

struct SidebarPortRow: View {
    let port: SerialPortDescriptor
    let isSelected: Bool
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: port.symbolName)
                .font(.title3)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(port.displayName)
                        .fontWeight(.medium)
                    if isConnected {
                        Text("LIVE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.green)
                    }
                }

                Text(port.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(port.displayName)，\(port.detail)")
    }
}

struct SidebarStatusFooter: View {
    @ObservedObject var workspace: SerialWorkspace

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(workspace.connectionStatusLabel, systemImage: workspace.connectionStatusSymbol)
                    .labelStyle(.titleAndIcon)
                    .font(.headline)
                Spacer()
                Text(workspace.activePresetName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                StatPill(title: "RX", value: "\(workspace.rxByteCount) B", tint: .green)
                StatPill(title: "TX", value: "\(workspace.txByteCount) B", tint: .blue)
                StatPill(title: "ERR", value: "\(workspace.errorCount)", tint: .orange)
            }
        }
    }
}
