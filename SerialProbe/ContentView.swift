//
//  ContentView.swift
//  SerialProbe
//
//  Created by rayanceking on 2026/3/20.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
struct ContentView: View {
    @StateObject private var workspace: SerialWorkspace
    @State private var isInspectorPresented = true
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
            Color(nsColor: .windowBackgroundColor)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Menu {
                    if workspace.availablePorts.isEmpty {
                        Text("未检测到设备")
                    } else {
                        ForEach(workspace.availablePorts) { port in
                            Button {
                                selectedPortBinding.wrappedValue = port.path
                            } label: {
                                if selectedPortBinding.wrappedValue == port.path {
                                    Label(port.displayName, systemImage: "checkmark")
                                } else {
                                    Text(port.displayName)
                                }
                            }
                        }
                    }
                } label: {
                    Text(selectedPortTitle)
                        .lineLimit(1)
                        .frame(width: 220, alignment: .leading)
                }

                Menu {
                    ForEach(SerialBaudRate.presets) { option in
                        Button {
                            workspace.baudRate = option.rawValue
                        } label: {
                            if workspace.baudRate == option.rawValue {
                                Label(option.label, systemImage: "checkmark")
                            } else {
                                Text(option.label)
                            }
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
                    exportSnapshotToFile()
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    isInspectorPresented.toggle()
                } label: {
                    Label(isInspectorPresented ? "隐藏面板" : "显示面板", systemImage: "sidebar.right")
                }
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

    private var selectedPortTitle: String {
        guard
            let selectedPortPath = workspace.selectedPortPath,
            let selectedPort = workspace.availablePorts.first(where: { $0.path == selectedPortPath })
        else {
            return "未检测到设备"
        }

        return selectedPort.displayName
    }

    private var exportSnapshotText: String {
        let receiveLines = workspace.logEntries
            .filter { $0.direction == .rx }
            .map(\.exportLine)
        let sendLines = workspace.logEntries
            .filter { $0.direction == .tx }
            .map(\.exportLine)

        let receiveSection = """
        === 接收区 ===
        设备：\(selectedPortTitle)
        波特率：\(workspace.baudRate)
        数据条目：\(receiveLines.count)
        \(receiveLines.isEmpty ? "(无接收数据)" : receiveLines.joined(separator: "\n"))
        """

        let sendSection = """
        === 发送区 ===
        发送模式：\(workspace.payloadMode.label)
        换行：\(workspace.lineEnding.label)
        当前输入：\(workspace.composerText.isEmpty ? "(空)" : workspace.composerText)
        历史发送条目：\(sendLines.count)
        \(sendLines.isEmpty ? "(无发送记录)" : sendLines.joined(separator: "\n"))
        """

        return [receiveSection, sendSection].joined(separator: "\n\n")
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

    @MainActor
    private func exportSnapshotToFile() {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                exportSnapshotToFile()
            }
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "serialprobe-snapshot-\(Int(Date().timeIntervalSince1970)).txt"
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = [.plainText]
        } else {
            panel.allowedFileTypes = ["txt"]
        }
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        let handleSelection: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else {
                return
            }

            do {
                try exportSnapshotText.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                exportError = error.localizedDescription
            }
        }

        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: handleSelection)
        } else {
            panel.begin(completionHandler: handleSelection)
        }
    }

}
