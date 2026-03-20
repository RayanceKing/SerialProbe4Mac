//
//  InspectorPanel.swift
//  SerialProbe
//
//  Created by rayanceking on 2026/3/20.
//

import SwiftUI

struct InspectorPanel: View {
    @ObservedObject var workspace: SerialWorkspace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                inspectorCard("链路参数") {
                    Picker("数据位", selection: binding(\.dataBits)) {
                        ForEach(SerialDataBits.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }

                    Picker("校验位", selection: binding(\.parity)) {
                        ForEach(SerialParity.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }

                    Picker("停止位", selection: binding(\.stopBits)) {
                        ForEach(SerialStopBits.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }

                    Picker("流控", selection: binding(\.flowControl)) {
                        ForEach(SerialFlowControl.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                }

                inspectorCard("会话统计") {
                    LabeledContent("接收字节") {
                        Text("\(workspace.rxByteCount)")
                            .contentTransition(.numericText())
                    }
                    LabeledContent("发送字节") {
                        Text("\(workspace.txByteCount)")
                            .contentTransition(.numericText())
                    }
                    LabeledContent("错误数") {
                        Text("\(workspace.errorCount)")
                            .foregroundStyle(workspace.errorCount == 0 ? Color.secondary : Color.orange)
                            .contentTransition(.numericText())
                    }
                    LabeledContent("当前端口") {
                        Text(workspace.selectedPortSummary)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                }

                inspectorCard("推荐操作") {
                    ForEach(workspace.presets) { preset in
                        Button {
                            workspace.applyPreset(preset)
                        } label: {
                            Label(preset.name, systemImage: preset.symbolName)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(18)
        }
        .background(.thinMaterial)
    }

    private func binding<Value>(_ keyPath: ReferenceWritableKeyPath<SerialWorkspace, Value>) -> Binding<Value> {
        Binding(
            get: { workspace[keyPath: keyPath] },
            set: { workspace[keyPath: keyPath] = $0 }
        )
    }

    private func inspectorCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
