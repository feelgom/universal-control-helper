import Foundation
import Network
import UniversalControlCore

protocol RelayTransport: AnyObject {
    var statusDidChange: ((String) -> Void)? { get set }
    func start()
    func stop()
}

final class SourceClient: RelayTransport {
    var statusDidChange: ((String) -> Void)?
    var authenticationDidComplete: ((Int) -> Void)?

    private let queue = DispatchQueue(label: "io.yoonsungji.universalcontrolhelper.source-network")
    private let tokenProvider: () -> String
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var framer = LineFramer()
    private var authenticated = false
    private var peerProtocolVersion = 1
    private var availableEndpoints: [NWEndpoint] = []

    init(tokenProvider: @escaping () -> String) {
        self.tokenProvider = tokenProvider
    }

    func start() {
        stop()
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_uniinputfix._tcp", domain: nil)
        let browser = NWBrowser(for: descriptor, using: .tcp)
        browser.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready: self?.report("대상 Mac 검색 중")
            case .failed(let error): self?.report("검색 오류: \(error.localizedDescription)")
            case .cancelled: break
            default: break
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            self.availableEndpoints = results.map(\.endpoint)
            self.connectIfNeeded()
        }
        self.browser = browser
        browser.start(queue: queue)
    }

    func stop() {
        browser?.cancel()
        browser = nil
        connection?.cancel()
        connection = nil
        authenticated = false
        peerProtocolVersion = 1
        framer = LineFramer()
        availableEndpoints = []
    }

    func synchronizeInputSource(_ inputSource: InputSourceState) {
        queue.async { [weak self] in
            guard let self, self.authenticated, let connection = self.connection else { return }
            let message = RelayProtocol.inputSourceMessage(
                inputSource,
                token: self.tokenProvider(),
                peerProtocolVersion: self.peerProtocolVersion
            )
            self.send(message, over: connection)
        }
    }

    private func connect(to endpoint: NWEndpoint) {
        report("대상 Mac 연결 중")
        let connection = NWConnection(to: endpoint, using: .tcp)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .ready:
                self.report("인증 중")
                self.send(.hello(token: self.tokenProvider()), over: connection)
                self.receive(on: connection)
            case .failed(let error):
                self.report("연결 오류: \(error.localizedDescription)")
                self.disconnect(connection)
            case .cancelled:
                self.disconnect(connection)
            default: break
            }
        }
        connection.start(queue: queue)
    }

    private func connectIfNeeded() {
        guard connection == nil, let endpoint = availableEndpoints.first else { return }
        connect(to: endpoint)
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self, weak connection] data, _, complete, error in
            guard let self, let connection else { return }
            if let data, !data.isEmpty {
                do {
                    for frame in try self.framer.append(data) {
                        let message = try RelayCodec.decode(frame)
                        if message.kind == .helloAck, message.token == self.tokenProvider() {
                            self.authenticated = true
                            self.peerProtocolVersion = message.protocolVersion ?? 1
                            let peerProtocolVersion = self.peerProtocolVersion
                            self.report("연결됨 · 입력 소스 동기화 중")
                            DispatchQueue.main.async { [weak self] in
                                self?.authenticationDidComplete?(peerProtocolVersion)
                            }
                        }
                    }
                } catch {
                    self.report("잘못된 응답")
                    connection.cancel()
                    return
                }
            }
            if complete || error != nil {
                self.disconnect(connection)
                return
            }
            self.receive(on: connection)
        }
    }

    private func send(_ message: RelayMessage, over connection: NWConnection) {
        guard let data = try? RelayCodec.encodeLine(message) else { return }
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error {
                self?.report("전송 오류: \(error.localizedDescription)")
            }
        })
    }

    private func disconnect(_ candidate: NWConnection) {
        guard connection === candidate else { return }
        connection = nil
        authenticated = false
        peerProtocolVersion = 1
        framer = LineFramer()
        report("연결 끊김 · 다시 검색 중")
        queue.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, self.browser != nil else { return }
            self.connectIfNeeded()
        }
    }

    private func report(_ status: String) {
        DispatchQueue.main.async { [weak self] in self?.statusDidChange?(status) }
    }
}

final class TargetServer: RelayTransport {
    var statusDidChange: ((String) -> Void)?
    var messageReceived: ((RelayMessage) -> Void)?

    private let queue = DispatchQueue(label: "io.yoonsungji.universalcontrolhelper.target-network")
    private let tokenProvider: () -> String
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var framers: [ObjectIdentifier: LineFramer] = [:]
    private var authenticatedConnections: Set<ObjectIdentifier> = []

    init(tokenProvider: @escaping () -> String) {
        self.tokenProvider = tokenProvider
    }

    func start() {
        stop()
        do {
            let listener = try NWListener(using: .tcp, on: .any)
            listener.service = NWListener.Service(
                name: Host.current().localizedName ?? "Universal Control Helper",
                type: "_uniinputfix._tcp"
            )
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready: self?.report("대기 중 · 소스 Mac을 찾을 수 있음")
                case .failed(let error): self?.report("수신 오류: \(error.localizedDescription)")
                case .cancelled: break
                default: break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            report("수신 시작 실패: \(error.localizedDescription)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
        framers.removeAll()
        authenticatedConnections.removeAll()
    }

    private func accept(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        connections[id] = connection
        framers[id] = LineFramer()
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .ready:
                self.report("소스 Mac 연결됨 · 인증 대기")
                self.receive(on: connection)
            case .failed, .cancelled:
                self.remove(connection)
            default: break
            }
        }
        connection.start(queue: queue)
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self, weak connection] data, _, complete, error in
            guard let self, let connection else { return }
            if let data, !data.isEmpty {
                do {
                    let id = ObjectIdentifier(connection)
                    var framer = self.framers[id] ?? LineFramer()
                    let frames = try framer.append(data)
                    self.framers[id] = framer
                    for frame in frames {
                        let message = try RelayCodec.decode(frame)
                        guard message.token == self.tokenProvider() else {
                            self.report("페어링 코드 불일치")
                            connection.cancel()
                            return
                        }
                        if message.kind == .hello {
                            self.authenticatedConnections.insert(id)
                            self.send(.helloAck(token: self.tokenProvider()), over: connection)
                            self.report("연결됨 · 입력 소스 동기화 중")
                        } else {
                            guard self.authenticatedConnections.contains(id) else {
                                self.report("인증되지 않은 입력 데이터 차단")
                                connection.cancel()
                                return
                            }
                            DispatchQueue.main.async { [weak self] in self?.messageReceived?(message) }
                        }
                    }
                } catch {
                    self.report("잘못된 입력 데이터 차단")
                    connection.cancel()
                    return
                }
            }
            if complete || error != nil {
                self.remove(connection)
                return
            }
            self.receive(on: connection)
        }
    }

    private func send(_ message: RelayMessage, over connection: NWConnection) {
        guard let data = try? RelayCodec.encodeLine(message) else { return }
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    private func remove(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        connections.removeValue(forKey: id)
        framers.removeValue(forKey: id)
        authenticatedConnections.remove(id)
        report("연결 끊김 · 대기 중")
    }

    private func report(_ status: String) {
        DispatchQueue.main.async { [weak self] in self?.statusDidChange?(status) }
    }
}
