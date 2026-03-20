//
//  ContentView.swift
//  SerialProbe
//
//  Created by rayanceking on 2026/3/20.
//

import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct ContentView: View {
    @StateObject private var workspace: SerialWorkspace
    @State private var isInspectorPresented = true
    @State private var isExportingLog = false
    @State private var exportDocument = SerialLogDocument(text: "")
    @State private var exportError: String?

    init() {
        _workspace = StateObject(wrappedValue: SerialWorkspace())
    }

    init(workspace: SerialWorkspace) {
        _workspace = StateObject(wrappedValue: workspace)
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(workspace: workspace)
                .navigationSplitViewColumnWidth(min: 250, ideal: 290, max: 340)
        } detail: {
            MainWorkbenchView(workspace: workspace)
                .inspector(isPresented: $isInspectorPresented) {
                    InspectorPanel(workspace: workspace)
                        .inspectorColumnWidth(min: 290, ideal: 330, max: 380)
                }
        }
        .navigationSplitViewStyle(.balanced)
        .background {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Picker("串口", selection: selectedPortBinding) {
                    if workspace.availablePorts.isEmpty {
                        Text("未检测到设备").tag("")
                    } else {
                        ForEach(workspace.availablePorts) { port in
                            Text(port.displayName).tag(port.path)
                        }
                    }
                }
                .frame(width: 220)

                Menu {
                    ForEach(SerialBaudRate.presets) { option in
                        Button(option.label) {
                            workspace.baudRate = option.rawValue
                        }
                    }
                } label: {
                    Label("\(workspace.baudRate) bps", systemImage: "speedometer")
                }

                Button {
                    workspace.refreshPorts()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .help("重新扫描可用串口")

                Button {
                    workspace.toggleConnection()
                } label: {
                    Label(workspace.connectionButtonTitle, systemImage: workspace.connectionButtonSymbol)
                        .labelStyle(.titleAndIcon)
                }
                .keyboardShortcut("r", modifiers: [.command])
                .tint(workspace.isConnected ? .red : .accentColor)

                Button {
                    workspace.clearLogs()
                } label: {
                    Label("清空", systemImage: "trash")
                }
                .keyboardShortcut("k", modifiers: [.command])

                Button {
                    exportDocument = SerialLogDocument(text: workspace.exportedLog)
                    isExportingLog = true
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .keyboardShortcut("s", modifiers: [.command])

            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    isInspectorPresented.toggle()
                } label: {
                    Label(isInspectorPresented ? "隐藏面板" : "显示面板", systemImage: "sidebar.right")
                }
            }
        }
        .fileExporter(
            isPresented: $isExportingLog,
            document: exportDocument,
            contentType: .plainText,
            defaultFilename: workspace.exportFilename
        ) { result in
            if case .failure(let error) = result {
                exportError = error.localizedDescription
                workspace.appendSystemMessage("日志导出失败：\(error.localizedDescription)")
            }
        }
        .alert("导出失败", isPresented: exportAlertBinding) {
            Button("好", role: .cancel) {
                exportError = nil
            }
        } message: {
            Text(exportError ?? "")
        }
        .task {
            workspace.startPortMonitoring()
        }
        .onDisappear {
            workspace.stopPortMonitoring()
        }
    }

    private var selectedPortBinding: Binding<String> {
        Binding(
            get: { workspace.selectedPortPath ?? "" },
            set: { newValue in
                workspace.selectedPortPath = newValue.isEmpty ? nil : newValue
            }
        )
    }

    private var exportAlertBinding: Binding<Bool> {
        Binding(
            get: { exportError != nil },
            set: { isPresented in
                if !isPresented {
                    exportError = nil
                }
            }
        )
    }
}
