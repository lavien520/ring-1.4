import Foundation
import Network

// MARK: - State Types

enum AgentState: String, Codable {
    case idle
    case thinking
    case working
    case attention      // needs user confirmation
    case error
    case sleeping
    case notification
}

struct StatePayload: Codable {
    let state: AgentState
    let session_id: String?
    let event: String?
    let agent_id: String?
    let session_title: String?
}

// Permission request from Claude Code (blocking HTTP hook)
struct PermissionRequest {
    let toolName: String?
    let sessionId: String?
    let agentId: String?
    let connection: NWConnection
}

// MARK: - State Monitor Delegate

protocol StateMonitorDelegate: AnyObject {
    func stateMonitor(_ monitor: StateMonitor, didUpdateState state: AgentState, forAgent agentId: String)
    func stateMonitor(_ monitor: StateMonitor, didReceivePermission toolName: String?, sessionId: String?)
}

// MARK: - State Monitor

final class StateMonitor {
    weak var delegate: StateMonitorDelegate?

    private var listener: NWListener?
    private let port: UInt16 = Constants.serverPort
    private let queue = DispatchQueue(label: "com.ring.state-monitor", qos: .userInitiated)

    // Track state per agent
    private var agentStates: [String: AgentState] = [:]

    // Pending permission request (connection held open until user decides)
    private var pendingPermission: PermissionRequest?

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[StateMonitor] Listening on port \(self.port)")
            case .failed(let error):
                print("[StateMonitor] Failed: \(error)")
            default:
                break
            }
        }

        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    func getState(forAgent agentId: String) -> AgentState {
        return agentStates[agentId] ?? .idle
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)

        receiveRequest(connection: connection)
    }

    private func receiveRequest(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, !data.isEmpty else {
                connection.cancel()
                return
            }

            let holdsConnection = self.processRequest(data: data, connection: connection)

            // For /permission requests, the connection is held open until user decides
            if !holdsConnection && (isComplete || error != nil) {
                connection.cancel()
            }
        }
    }

    @discardableResult
    private func processRequest(data: Data, connection: NWConnection) -> Bool {
        guard let request = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, status: "400 Bad Request", body: "{\"error\":\"invalid encoding\"}")
            return false
        }

        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse(connection: connection, status: "400 Bad Request", body: "{\"error\":\"empty request\"}")
            return false
        }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, status: "400 Bad Request", body: "{\"error\":\"invalid request line\"}")
            return false
        }

        let method = parts[0]
        let path = parts[1]

        // Find body (after empty line)
        let headerBodySeparator = "\r\n\r\n"
        var body = ""
        if let range = request.range(of: headerBodySeparator) {
            body = String(request[range.upperBound...])
        }

        switch (method, path) {
        case ("POST", "/state"):
            handleStatePost(body: body, connection: connection)
            return false
        case ("GET", "/state"):
            handleStateGet(connection: connection)
            return false
        case ("POST", "/permission"):
            handlePermissionPost(body: body, connection: connection)
            return true  // Connection held open for user decision
        default:
            sendResponse(connection: connection, status: "404 Not Found", body: "{\"error\":\"not found\"}")
            return false
        }
    }

    // MARK: - Route Handlers

    private func handleStatePost(body: String, connection: NWConnection) {
        guard let data = body.data(using: .utf8),
              let payload = try? JSONDecoder().decode(StatePayload.self, from: data) else {
            sendResponse(connection: connection, status: "400 Bad Request", body: "{\"error\":\"invalid json\"}")
            return
        }

        let agentId = payload.agent_id ?? "unknown"
        agentStates[agentId] = payload.state

        print("[StateMonitor] Agent: \(agentId), State: \(payload.state.rawValue), Event: \(payload.event ?? "nil")")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.stateMonitor(self, didUpdateState: payload.state, forAgent: agentId)
        }

        let response = "{\"status\":\"ok\",\"app\":\"ring\"}"
        sendResponse(connection: connection, status: "200 OK", body: response)
    }

    private func handleStateGet(connection: NWConnection) {
        let states = agentStates.mapValues { $0.rawValue }
        let responseData: [String: Any] = ["app": "ring", "agents": states]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: responseData),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            sendResponse(connection: connection, status: "500 Internal Server Error", body: "{\"error\":\"json serialization failed\"}")
            return
        }
        sendResponse(connection: connection, status: "200 OK", body: jsonString)
    }

    private func handlePermissionPost(body: String, connection: NWConnection) {
        // Parse the permission request body
        let data = body.data(using: .utf8) ?? Data()
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let toolName = json?["tool_name"] as? String
        let sessionId = json?["session_id"] as? String
        let agentId = json?["agent_id"] as? String

        print("[StateMonitor] PermissionRequest: tool=\(toolName ?? "nil") session=\(sessionId ?? "nil")")

        // Cancel any previous pending permission
        if let prev = pendingPermission {
            sendNoDecisionResponse(connection: prev.connection)
        }

        // Hold the connection open — don't respond yet
        pendingPermission = PermissionRequest(
            toolName: toolName,
            sessionId: sessionId,
            agentId: agentId,
            connection: connection
        )

        // Notify delegate to show popup
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.stateMonitor(self, didReceivePermission: toolName, sessionId: sessionId)
        }
    }

    // Called when user clicks Allow/Deny/Allow All in the popup
    func resolvePermission(behavior: String) {
        guard let permission = pendingPermission else { return }
        pendingPermission = nil

        let responseBody: [String: Any] = [
            "hookSpecificOutput": [
                "hookEventName": "PermissionRequest",
                "decision": [
                    "behavior": behavior
                ]
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: responseBody),
              let body = String(data: data, encoding: .utf8) else {
            permission.connection.cancel()
            return
        }

        let httpResponse = "HTTP/1.1 200 OK\r\n" +
            "Content-Type: application/json\r\n" +
            "Content-Length: \(body.utf8.count)\r\n" +
            "x-ring-server: ring\r\n" +
            "Connection: close\r\n" +
            "\r\n" +
            body

        guard let responseData = httpResponse.data(using: .utf8) else {
            permission.connection.cancel()
            return
        }

        permission.connection.send(content: responseData, completion: .contentProcessed { _ in
            permission.connection.cancel()
        })

        print("[StateMonitor] Permission resolved: \(behavior)")
    }

    // Send a no-decision response (drop connection so Claude Code falls back to terminal)
    private func sendNoDecisionResponse(connection: NWConnection) {
        connection.cancel()
    }

    // MARK: - Response Helper

    private func sendResponse(connection: NWConnection, status: String, body: String) {
        let httpResponse = "HTTP/1.1 \(status)\r\n" +
            "Content-Type: application/json\r\n" +
            "Content-Length: \(body.utf8.count)\r\n" +
            "x-ring-server: ring\r\n" +
            "Connection: close\r\n" +
            "\r\n" +
            body

        guard let data = httpResponse.data(using: .utf8) else {
            connection.cancel()
            return
        }
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
