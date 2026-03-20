//
//  ComposerPanel.swift
//  SerialProbe
//
//  Created by rayanceking on 2026/3/20.
//

import SwiftUI

struct ComposerPanel: View {
    @ObservedObject var workspace: SerialWorkspace
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("发送区")
                    .font(.headline)
                Spacer()
                Picker("显示", selection: binding(\.displayMode)) {
                    ForEach(SerialDisplayMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }

            TextField("输入文本或 HEX 字节，例如 `55 AA 10 01`", text: binding(\.composerText), axis: .vertical)
                .focused($isComposerFocused)
                .lineLimit(2 ... 6)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onSubmit {
                    workspace.sendComposer()
                }

            HStack {
                Picker("发送模式", selection: binding(\.payloadMode)) {
                    ForEach(SerialPayloadMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .frame(width: 150)

                Picker("换行", selection: binding(\.lineEnding)) {
                    ForEach(LineEnding.allCases) { ending in
                        Text(ending.label).tag(ending)
                    }
                }
                .frame(width: 130)

                Toggle("本地回显", isOn: binding(\.localEcho))
                Toggle("自动滚动", isOn: binding(\.autoScroll))
                Toggle("时间戳", isOn: binding(\.showTimestamps))

                Spacer()

                Button("发送") {
                    workspace.sendComposer()
                    isComposerFocused = true
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .buttonStyle(.borderedProminent)
                .disabled(!workspace.canSend)
            }

            QuickCommandStrip(workspace: workspace)
        }
        .padding(18)
        .background(.bar)
    }

    private func binding<Value>(_ keyPath: ReferenceWritableKeyPath<SerialWorkspace, Value>) -> Binding<Value> {
        Binding(
            get: { workspace[keyPath: keyPath] },
            set: { workspace[keyPath: keyPath] = $0 }
        )
    }
}

private struct QuickCommandStrip: View {
    @ObservedObject var workspace: SerialWorkspace

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(workspace.quickCommands) { command in
                Button {
                    workspace.send(command: command)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(command.name)
                                .font(.subheadline.weight(.semibold))
                            Spacer(minLength: 0)
                            Text(command.mode.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        Text(command.payload)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!workspace.isConnected)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("快捷发送命令")
    }
}
