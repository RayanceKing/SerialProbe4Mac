//
//  SerialWorkbench.swift
//  SerialProbe
//
//  Created by rayanceking on 2026/3/20.
//

import SwiftUI
import UniformTypeIdentifiers
import Darwin
import Combine

@MainActor
final class SerialWorkspace: ObservableObject {
    @Published var availablePorts: [SerialPortDescriptor] = []
    @Published var selectedPortPath: String?
    @Published var connectedPortPath: String?
    @Published var baudRate = SerialBaudRate.defaultValue
    @Published var dataBits: SerialDataBits = .eight
    @Published var parity: SerialParity = .none
    @Published var stopBits: SerialStopBits = .one
    @Published var flowControl: SerialFlowControl = .none
    @Published var displayMode: SerialDisplayMode = .mixed
    @Published var payloadMode: SerialPayloadMode = .text
    @Published var lineEnding: LineEnding = .crlf
    @Published var composerText = ""
    @Published var showTimestamps = true
    @Published var autoScroll = true
    @Published var localEcho = false
    @Published var rxByteCount = 0
    @Published var txByteCount = 0
    @Published var errorCount = 0
    @Published var activePresetName = "开发板控制台"
    @Published var logEntries: [SerialLogEntry] = []

    private var connection: SerialConnection?
    private var monitorTask: Task<Void, Never>?

    let presets: [WorkspacePreset] = WorkspacePreset.defaults
    let quickCommands: [QuickCommand] = QuickCommand.defaults

    init() {
        refreshPorts()
        if let firstPort = availablePorts.first {
            selectedPortPath = firstPort.path
        }
        appendSystemMessage("SerialProbe 已就绪，默认工作流为“开发板控制台”。")
        appendSystemMessage("支持文本与 HEX 双模式发送，推荐先确认波特率后再连接。")
    }

    deinit {
        monitorTask?.cancel()
    }

    var isConnected: Bool {
        connectedPortPath != nil
    }

    var canSend: Bool {
        isConnected && !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var connectionStatusLabel: String {
        isConnected ? "已连接" : "未连接"
    }

    var connectionStatusSymbol: String {
        isConnected ? "dot.radiowaves.left.and.right" : "bolt.horizontal.circle"
    }

    var connectionTint: Color {
        isConnected ? .green : .secondary
    }

    var connectionButtonTitle: String {
        isConnected ? "断开" : "连接"
    }

    var connectionButtonSymbol: String {
        isConnected ? "bolt.slash" : "bolt.horizontal.fill"
    }

    var sessionTitle: String {
        if let port = selectedPort {
            return port.displayName
        }
        return "未选择串口"
    }

    var sessionSubtitle: String {
        if let port = selectedPort {
            return "\(port.detail) · \(activePresetName)"
        }
        return "从左侧选择一个开发板，或先插入 USB 串口设备。"
    }

    var selectedPortSummary: String {
        selectedPort?.path ?? "未选择"
    }

    var lastLogID: UUID? {
        logEntries.last?.id
    }

    var exportFilename: String {
        let name = selectedPort?.displayName.replacingOccurrences(of: ".", with: "-") ?? "session"
        let stamp = Self.exportFilenameDateFormatter.string(from: Date())
        return "\(name)-\(stamp)"
    }

    var exportedLog: String {
        logEntries.map(\.exportLine).joined(separator: "\n")
    }

    private var selectedPort: SerialPortDescriptor? {
        availablePorts.first(where: { $0.path == selectedPortPath })
    }

    private static let exportFilenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HH-mm"
        return formatter
    }()

    func startPortMonitoring() {
        guard monitorTask == nil else { return }

        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refreshPorts()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopPortMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    func refreshPorts() {
        let paths = (try? FileManager.default.contentsOfDirectory(atPath: "/dev")) ?? []
        let ports = paths
            .filter { $0.hasPrefix("cu.") }
            .map { SerialPortDescriptor(path: "/dev/\($0)") }
            .sorted(using: KeyPathComparator(\.displayName))

        availablePorts = ports

        if let selectedPortPath, ports.contains(where: { $0.path == selectedPortPath }) {
            return
        }

        selectedPortPath = ports.first?.path
    }

    func applyPreset(_ preset: WorkspacePreset) {
        baudRate = preset.baudRate
        payloadMode = preset.payloadMode
        lineEnding = preset.lineEnding
        displayMode = preset.displayMode
        localEcho = preset.localEcho
        activePresetName = preset.name
        appendSystemMessage("已切换到“\(preset.name)”场景，推荐波特率 \(preset.baudRate)。")
    }

    func toggleConnection() {
        if isConnected {
            disconnect()
        } else {
            connect()
        }
    }

    func connect() {
        guard let selectedPortPath else {
            appendErrorMessage("请先选择一个可用串口。")
            return
        }

        disconnect()

        do {
            let connection = try SerialConnection(
                path: selectedPortPath,
                configuration: SerialLineConfiguration(
                    baudRate: baudRate,
                    dataBits: dataBits,
                    parity: parity,
                    stopBits: stopBits,
                    flowControl: flowControl
                ),
                onReceive: { [weak self] data in
                    self?.appendPacket(direction: .rx, data: data)
                },
                onDisconnect: { [weak self] reason in
                    self?.connectedPortPath = nil
                    if let reason {
                        self?.appendErrorMessage(reason)
                    } else {
                        self?.appendSystemMessage("串口连接已断开。")
                    }
                }
            )

            self.connection = connection
            connectedPortPath = selectedPortPath
            appendSystemMessage("已连接 \(selectedPort?.displayName ?? selectedPortPath)，\(baudRate) bps。")
        } catch {
            appendErrorMessage(error.localizedDescription)
        }
    }

    func disconnect() {
        connection?.close()
        connection = nil

        if connectedPortPath != nil {
            appendSystemMessage("已主动断开串口。")
        }

        connectedPortPath = nil
    }

    func sendComposer() {
        let payload = composerText
        composerText = ""
        send(rawPayload: payload, mode: payloadMode)
    }

    func send(command: QuickCommand) {
        send(rawPayload: command.payload, mode: command.mode)
    }

    func clearLogs() {
        logEntries.removeAll()
        rxByteCount = 0
        txByteCount = 0
        errorCount = 0
        appendSystemMessage("终端缓存已清空。")
    }

    func appendSystemMessage(_ message: String) {
        appendEntry(
            SerialLogEntry(
                direction: .system,
                timestamp: .now,
                textRepresentation: message,
                hexRepresentation: "",
                byteCount: message.utf8.count
            )
        )
    }

    private func send(rawPayload: String, mode: SerialPayloadMode) {
        guard let connection else {
            appendErrorMessage("串口尚未连接，无法发送。")
            return
        }

        do {
            let data = try SerialPayloadCodec.encode(rawPayload, mode: mode, lineEnding: lineEnding)
            try connection.send(data)

            txByteCount += data.count

            if localEcho || mode == .hex {
                appendPacket(direction: .tx, data: data)
            } else {
                appendEntry(
                    SerialLogEntry(
                        direction: .tx,
                        timestamp: .now,
                        textRepresentation: rawPayload + lineEnding.previewSuffix,
                        hexRepresentation: SerialPayloadCodec.hexString(for: data),
                        byteCount: data.count
                    )
                )
            }
        } catch {
            appendErrorMessage(error.localizedDescription)
        }
    }

    private func appendPacket(direction: SerialDirection, data: Data) {
        if direction == .rx {
            rxByteCount += data.count
        }

        appendEntry(
            SerialLogEntry(
                direction: direction,
                timestamp: .now,
                textRepresentation: String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\0", with: "·"),
                hexRepresentation: SerialPayloadCodec.hexString(for: data),
                byteCount: data.count
            )
        )
    }

    private func appendEntry(_ entry: SerialLogEntry) {
        logEntries.append(entry)

        let overflow = logEntries.count - 800
        if overflow > 0 {
            logEntries.removeFirst(overflow)
        }
    }

    private func appendErrorMessage(_ message: String) {
        errorCount += 1
        appendEntry(
            SerialLogEntry(
                direction: .system,
                timestamp: .now,
                textRepresentation: "错误：\(message)",
                hexRepresentation: "",
                byteCount: 0
            )
        )
    }
}

struct SerialPortDescriptor: Identifiable, Hashable {
    let path: String

    var id: String { path }

    var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent.replacingOccurrences(of: "cu.", with: "")
    }

    var detail: String {
        if path.localizedCaseInsensitiveContains("usbmodem") {
            return "USB CDC 设备"
        }
        if path.localizedCaseInsensitiveContains("usbserial") {
            return "USB-UART 适配器"
        }
        if path.localizedCaseInsensitiveContains("wchusbserial") {
            return "CH34x / WCH 串口"
        }
        if path.localizedCaseInsensitiveContains("bluetooth") {
            return "蓝牙串口桥"
        }
        return path
    }

    var symbolName: String {
        if path.localizedCaseInsensitiveContains("bluetooth") {
            return "dot.radiowaves.left.and.right"
        }
        if path.localizedCaseInsensitiveContains("usb") {
            return "cable.connector"
        }
        return "cpu"
    }
}

struct WorkspacePreset: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let summary: String
    let symbolName: String
    let baudRate: Int
    let payloadMode: SerialPayloadMode
    let lineEnding: LineEnding
    let displayMode: SerialDisplayMode
    let localEcho: Bool
    let tint: Color

    static let defaults: [WorkspacePreset] = [
        WorkspacePreset(
            name: "开发板控制台",
            summary: "115200 / CRLF / 文本流",
            symbolName: "terminal",
            baudRate: 115200,
            payloadMode: .text,
            lineEnding: .crlf,
            displayMode: .mixed,
            localEcho: false,
            tint: .accentColor
        ),
        WorkspacePreset(
            name: "Bootloader 交互",
            summary: "230400 / LF / 快速刷机日志",
            symbolName: "shippingbox",
            baudRate: 230400,
            payloadMode: .text,
            lineEnding: .lf,
            displayMode: .text,
            localEcho: false,
            tint: .orange
        ),
        WorkspacePreset(
            name: "协议抓包",
            summary: "HEX / CR / 原始字节流",
            symbolName: "waveform.path.ecg",
            baudRate: 230400,
            payloadMode: .hex,
            lineEnding: .none,
            displayMode: .hex,
            localEcho: true,
            tint: .purple
        )
    ]
}

struct QuickCommand: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let payload: String
    let mode: SerialPayloadMode

    static let defaults: [QuickCommand] = [
        QuickCommand(name: "重启板卡", payload: "reboot", mode: .text),
        QuickCommand(name: "进入下载模式", payload: "boot", mode: .text),
        QuickCommand(name: "读取版本", payload: "AT+GMR", mode: .text),
        QuickCommand(name: "Ping 帧", payload: "55 AA 01 00 56", mode: .hex),
        QuickCommand(name: "握手序列", payload: "7E 00 08 01 00 00 7E", mode: .hex),
        QuickCommand(name: "帮助", payload: "help", mode: .text)
    ]
}

struct SerialLogEntry: Identifiable, Hashable {
    let id = UUID()
    let direction: SerialDirection
    let timestamp: Date
    let textRepresentation: String
    let hexRepresentation: String
    let byteCount: Int

    var exportLine: String {
        let stamp = Self.exportTimeFormatter.string(from: timestamp)
        if hexRepresentation.isEmpty {
            return "[\(stamp)] [\(direction.badgeTitle)] \(textRepresentation)"
        }
        return "[\(stamp)] [\(direction.badgeTitle)] \(textRepresentation) | \(hexRepresentation)"
    }

    private static let exportTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

enum SerialDirection: Hashable {
    case rx
    case tx
    case system

    var badgeTitle: String {
        switch self {
        case .rx: "RX"
        case .tx: "TX"
        case .system: "SYS"
        }
    }

    var tint: Color {
        switch self {
        case .rx: .green
        case .tx: .blue
        case .system: .orange
        }
    }
}

enum SerialDisplayMode: String, CaseIterable, Identifiable {
    case text
    case hex
    case mixed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: "文本"
        case .hex: "HEX"
        case .mixed: "混合"
        }
    }
}

enum SerialPayloadMode: String, CaseIterable, Identifiable, Hashable {
    case text
    case hex

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: "文本"
        case .hex: "HEX"
        }
    }
}

enum LineEnding: String, CaseIterable, Identifiable, Hashable {
    case none
    case lf
    case crlf
    case cr

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "无"
        case .lf: "LF"
        case .crlf: "CRLF"
        case .cr: "CR"
        }
    }

    var bytes: [UInt8] {
        switch self {
        case .none: []
        case .lf: [0x0A]
        case .crlf: [0x0D, 0x0A]
        case .cr: [0x0D]
        }
    }

    var previewSuffix: String {
        switch self {
        case .none: ""
        case .lf: "\\n"
        case .crlf: "\\r\\n"
        case .cr: "\\r"
        }
    }
}

enum SerialDataBits: Int, CaseIterable, Identifiable {
    case five = 5
    case six = 6
    case seven = 7
    case eight = 8

    var id: Int { rawValue }
    var label: String { "\(rawValue) bit" }

    var flag: tcflag_t {
        switch self {
        case .five: tcflag_t(CS5)
        case .six: tcflag_t(CS6)
        case .seven: tcflag_t(CS7)
        case .eight: tcflag_t(CS8)
        }
    }
}

enum SerialParity: String, CaseIterable, Identifiable {
    case none
    case odd
    case even

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "无"
        case .odd: "奇校验"
        case .even: "偶校验"
        }
    }
}

enum SerialStopBits: Double, CaseIterable, Identifiable {
    case one = 1
    case two = 2

    var id: Double { rawValue }

    var label: String {
        rawValue == 1 ? "1 位" : "2 位"
    }
}

enum SerialFlowControl: String, CaseIterable, Identifiable {
    case none
    case hardware
    case software

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "无"
        case .hardware: "RTS/CTS"
        case .software: "XON/XOFF"
        }
    }
}

enum SerialBaudRate: Int, CaseIterable, Identifiable {
    case b1200 = 1200
    case b2400 = 2400
    case b4800 = 4800
    case b9600 = 9600
    case b19200 = 19200
    case b38400 = 38400
    case b57600 = 57600
    case b115200 = 115200
    case b230400 = 230400

    var id: Int { rawValue }
    var label: String { "\(rawValue)" }

    static let defaultValue = SerialBaudRate.b115200.rawValue
    static let presets = SerialBaudRate.allCases
}

struct SerialLineConfiguration: Hashable {
    let baudRate: Int
    let dataBits: SerialDataBits
    let parity: SerialParity
    let stopBits: SerialStopBits
    let flowControl: SerialFlowControl
}

enum SerialPayloadCodec {
    static func encode(_ payload: String, mode: SerialPayloadMode, lineEnding: LineEnding) throws -> Data {
        var data: Data

        switch mode {
        case .text:
            data = Data(payload.utf8)
        case .hex:
            data = try parseHex(payload)
        }

        data.append(contentsOf: lineEnding.bytes)
        return data
    }

    static func hexString(for data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    static func parseHex(_ input: String) throws -> Data {
        let cleaned = input
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")

        let tokens = cleaned.split(whereSeparator: \.isWhitespace)
        guard !tokens.isEmpty else { return Data() }

        var bytes: [UInt8] = []
        for token in tokens {
            let chunk = String(token)
            if chunk.count > 2 && chunk.count.isMultiple(of: 2) {
                var index = chunk.startIndex
                while index < chunk.endIndex {
                    let nextIndex = chunk.index(index, offsetBy: 2)
                    let pair = String(chunk[index..<nextIndex])
                    guard let byte = UInt8(pair, radix: 16) else {
                        throw SerialCodecError.invalidHexToken(chunk)
                    }
                    bytes.append(byte)
                    index = nextIndex
                }
            } else {
                guard let byte = UInt8(chunk, radix: 16) else {
                    throw SerialCodecError.invalidHexToken(chunk)
                }
                bytes.append(byte)
            }
        }

        return Data(bytes)
    }
}

enum SerialCodecError: LocalizedError {
    case invalidHexToken(String)

    var errorDescription: String? {
        switch self {
        case .invalidHexToken(let token):
            "无法解析 HEX 字节：\(token)"
        }
    }
}

struct SerialLogDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

final class SerialConnection {
    private let fileDescriptor: Int32
    private let queue = DispatchQueue(label: "com.stuwang.serialprobe.connection")
    private var readSource: DispatchSourceRead?
    private let onReceive: @MainActor (Data) -> Void
    private let onDisconnect: @MainActor (String?) -> Void
    private var isClosed = false

    init(
        path: String,
        configuration: SerialLineConfiguration,
        onReceive: @escaping @MainActor (Data) -> Void,
        onDisconnect: @escaping @MainActor (String?) -> Void
    ) throws {
        self.onReceive = onReceive
        self.onDisconnect = onDisconnect

        let fd = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd >= 0 else {
            throw POSIXSerialError.openFailed(errno)
        }

        fileDescriptor = fd

        do {
            try Self.configure(fileDescriptor: fd, with: configuration)
            try Self.flush(fileDescriptor: fd)
            try installReadSource()
        } catch {
            Darwin.close(fd)
            throw error
        }
    }

    deinit {
        close()
    }

    func send(_ data: Data) throws {
        guard !isClosed else {
            throw POSIXSerialError.disconnected
        }

        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return }

            var bytesSent = 0
            while bytesSent < data.count {
                let written = Darwin.write(fileDescriptor, baseAddress + bytesSent, data.count - bytesSent)
                if written < 0 {
                    if errno == EINTR {
                        continue
                    }
                    throw POSIXSerialError.writeFailed(errno)
                }
                bytesSent += written
            }
        }
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true

        readSource?.cancel()
        readSource = nil
        Darwin.close(fileDescriptor)
    }

    private func installReadSource() throws {
        let source = DispatchSource.makeReadSource(fileDescriptor: fileDescriptor, queue: queue)
        readSource = source

        source.setEventHandler { [weak self] in
            guard let self else { return }

            let available = max(Int(source.data), 1)
            var buffer = [UInt8](repeating: 0, count: available)
            let count = Darwin.read(self.fileDescriptor, &buffer, available)

            if count > 0 {
                let data = Data(buffer.prefix(Int(count)))
                Task { @MainActor in
                    self.onReceive(data)
                }
            } else if count == 0 {
                Task { @MainActor in
                    self.onDisconnect(nil)
                }
                self.close()
            } else if errno != EAGAIN && errno != EINTR {
                let error = POSIXSerialError.readFailed(errno).localizedDescription
                Task { @MainActor in
                    self.onDisconnect(error)
                }
                self.close()
            }
        }

        source.setCancelHandler { }
        source.resume()
    }

    private static func flush(fileDescriptor: Int32) throws {
        guard tcflush(fileDescriptor, TCIOFLUSH) == 0 else {
            throw POSIXSerialError.configurationFailed(errno)
        }
    }

    private static func configure(fileDescriptor: Int32, with configuration: SerialLineConfiguration) throws {
        var options = termios()
        guard tcgetattr(fileDescriptor, &options) == 0 else {
            throw POSIXSerialError.configurationFailed(errno)
        }

        cfmakeraw(&options)

        options.c_cflag |= tcflag_t(CLOCAL | CREAD)
        options.c_cflag &= ~tcflag_t(CSIZE)
        options.c_cflag |= configuration.dataBits.flag
        options.c_cflag &= ~tcflag_t(PARENB | PARODD | CSTOPB)
        options.c_cflag &= ~tcflag_t(CRTSCTS)

        options.c_iflag &= ~tcflag_t(IXON | IXOFF | IXANY)
        options.c_oflag = 0
        options.c_lflag = 0

        switch configuration.parity {
        case .none:
            break
        case .odd:
            options.c_cflag |= tcflag_t(PARENB | PARODD)
        case .even:
            options.c_cflag |= tcflag_t(PARENB)
        }

        if configuration.stopBits == .two {
            options.c_cflag |= tcflag_t(CSTOPB)
        }

        switch configuration.flowControl {
        case .none:
            break
        case .hardware:
            options.c_cflag |= tcflag_t(CRTSCTS)
        case .software:
            options.c_iflag |= tcflag_t(IXON | IXOFF)
        }

        if let speed = standardSpeed(for: configuration.baudRate) {
            cfsetispeed(&options, speed)
            cfsetospeed(&options, speed)
        } else {
            cfsetispeed(&options, speed_t(B230400))
            cfsetospeed(&options, speed_t(B230400))
        }

        guard tcsetattr(fileDescriptor, TCSANOW, &options) == 0 else {
            throw POSIXSerialError.configurationFailed(errno)
        }

    }

    private static func standardSpeed(for baudRate: Int) -> speed_t? {
        switch baudRate {
        case 1200: speed_t(B1200)
        case 2400: speed_t(B2400)
        case 4800: speed_t(B4800)
        case 9600: speed_t(B9600)
        case 19200: speed_t(B19200)
        case 38400: speed_t(B38400)
        case 57600: speed_t(B57600)
        case 115200: speed_t(B115200)
        case 230400: speed_t(B230400)
        default: nil
        }
    }
}

enum POSIXSerialError: LocalizedError {
    case openFailed(Int32)
    case configurationFailed(Int32)
    case writeFailed(Int32)
    case readFailed(Int32)
    case disconnected

    var errorDescription: String? {
        switch self {
        case .openFailed(let code):
            "打开串口失败：\(String(cString: strerror(code)))"
        case .configurationFailed(let code):
            "串口参数配置失败：\(String(cString: strerror(code)))"
        case .writeFailed(let code):
            "串口发送失败：\(String(cString: strerror(code)))"
        case .readFailed(let code):
            "串口读取失败：\(String(cString: strerror(code)))"
        case .disconnected:
            "串口连接已关闭。"
        }
    }
}
