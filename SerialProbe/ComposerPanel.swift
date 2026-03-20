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
    @State private var isCollapsed = false

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

                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: "inset.filled.bottomthird.square")
                }
                .buttonStyle(.plain)
                .foregroundColor(isCollapsed ? .secondary : .accentColor)
                .help(isCollapsed ? "展开发送区" : "收缩发送区")
            }

            if !isCollapsed {
                Group {
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isCollapsed)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("常用命令")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

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
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(QuickCommandPressStyle())
                    .disabled(!workspace.isConnected)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("快捷发送命令")
    }
}

private struct QuickCommandPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        configuration.isPressed ? Color.accentColor.opacity(0.45) : Color.clear,
                        lineWidth: 1
                    )
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
