import Foundation
import Network
import Security

enum DNSProbeStatus: Equatable, Sendable {
  case reachable
  case failed
}

struct DNSProbeResult: Identifiable, Sendable {
  let profileID: String
  let status: DNSProbeStatus
  let latencyMilliseconds: Int?
  let measuredAt: Date
  let detail: String

  var id: String { profileID }
}

enum DNSProbeError: LocalizedError {
  case invalidEndpoint
  case invalidResponse
  case serverFailure(Int)
  case timedOut
  case connectionEnded

  var errorDescription: String? {
    switch self {
    case .invalidEndpoint:
      return String(localized: "The DNS endpoint is invalid.")
    case .invalidResponse:
      return String(localized: "The resolver returned an invalid DNS response.")
    case .serverFailure(let statusCode):
      return String(
        format: String(localized: "The resolver returned HTTP status %lld."),
        statusCode
      )
    case .timedOut:
      return String(localized: "The DNS test timed out.")
    case .connectionEnded:
      return String(localized: "The resolver closed the connection early.")
    }
  }
}

final class DNSProbeService {
  private let timeout: TimeInterval
  private let session: URLSession

  init(timeout: TimeInterval = 6) {
    self.timeout = timeout
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = timeout
    configuration.timeoutIntervalForResource = timeout
    configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    session = URLSession(configuration: configuration)
  }

  func probe(
    profile: DNSProfile,
    completion: @escaping @Sendable (DNSProbeResult) -> Void
  ) {
    let transactionID = UInt16.random(in: .min ... .max)
    let query = DNSWireMessage.query(transactionID: transactionID)
    let startedAt = Date()

    let finish: @Sendable (Result<Void, Error>) -> Void = { result in
      let latency = max(0, Int(Date().timeIntervalSince(startedAt) * 1_000))
      switch result {
      case .success:
        completion(
          DNSProbeResult(
            profileID: profile.id,
            status: .reachable,
            latencyMilliseconds: latency,
            measuredAt: Date(),
            detail: String(localized: "DNS query succeeded.")
          )
        )
      case .failure(let error):
        completion(
          DNSProbeResult(
            profileID: profile.id,
            status: .failed,
            latencyMilliseconds: nil,
            measuredAt: Date(),
            detail: error.localizedDescription
          )
        )
      }
    }

    switch profile.dnsProtocol {
    case .https:
      probeHTTPS(
        profile: profile,
        query: query,
        transactionID: transactionID,
        completion: finish
      )
    case .tls:
      probeTLS(
        profile: profile,
        query: query,
        transactionID: transactionID,
        completion: finish
      )
    }
  }

  private func probeHTTPS(
    profile: DNSProfile,
    query: Data,
    transactionID: UInt16,
    completion: @escaping @Sendable (Result<Void, Error>) -> Void
  ) {
    guard let endpoint = URL(string: profile.endpoint) else {
      completion(.failure(DNSProbeError.invalidEndpoint))
      return
    }

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.httpBody = query
    request.timeoutInterval = timeout
    request.setValue("application/dns-message", forHTTPHeaderField: "Accept")
    request.setValue("application/dns-message", forHTTPHeaderField: "Content-Type")
    request.setValue("no-store", forHTTPHeaderField: "Cache-Control")

    session.dataTask(with: request) { data, response, error in
      if let error {
        completion(.failure(error))
        return
      }
      guard let httpResponse = response as? HTTPURLResponse else {
        completion(.failure(DNSProbeError.invalidResponse))
        return
      }
      guard (200 ... 299).contains(httpResponse.statusCode) else {
        completion(.failure(DNSProbeError.serverFailure(httpResponse.statusCode)))
        return
      }
      guard let data else {
        completion(.failure(DNSProbeError.invalidResponse))
        return
      }

      do {
        try DNSWireMessage.validateResponse(data, transactionID: transactionID)
        completion(.success(()))
      } catch {
        completion(.failure(error))
      }
    }.resume()
  }

  private func probeTLS(
    profile: DNSProfile,
    query: Data,
    transactionID: UInt16,
    completion: @escaping @Sendable (Result<Void, Error>) -> Void
  ) {
    let destinations = profile.servers.isEmpty ? [profile.endpoint] : profile.servers

    @Sendable func attempt(_ index: Int, previousError: Error? = nil) {
      guard destinations.indices.contains(index) else {
        completion(.failure(previousError ?? DNSProbeError.invalidEndpoint))
        return
      }

      DoTProbeOperation(
        profile: profile,
        destination: destinations[index],
        query: query,
        transactionID: transactionID,
        timeout: timeout
      ) { result in
        switch result {
        case .success:
          completion(.success(()))
        case .failure(let error):
          attempt(index + 1, previousError: error)
        }
      }.start()
    }

    attempt(0)
  }
}

private final class DoTProbeOperation: @unchecked Sendable {
  private let profile: DNSProfile
  private let destination: String
  private let query: Data
  private let transactionID: UInt16
  private let timeout: TimeInterval
  private let completion: @Sendable (Result<Void, Error>) -> Void
  private let queue = DispatchQueue(label: "app.peterlee.dns-security-pro.dot-probe")

  private var connection: NWConnection?
  private var didFinish = false
  private var didSendQuery = false

  init(
    profile: DNSProfile,
    destination: String,
    query: Data,
    transactionID: UInt16,
    timeout: TimeInterval,
    completion: @escaping @Sendable (Result<Void, Error>) -> Void
  ) {
    self.profile = profile
    self.destination = destination
    self.query = query
    self.transactionID = transactionID
    self.timeout = timeout
    self.completion = completion
  }

  func start() {
    let tlsOptions = NWProtocolTLS.Options()
    sec_protocol_options_set_tls_server_name(
      tlsOptions.securityProtocolOptions,
      profile.endpoint
    )

    let parameters = NWParameters(tls: tlsOptions)
    let connection = NWConnection(
      host: NWEndpoint.Host(destination),
      port: NWEndpoint.Port(integerLiteral: 853),
      using: parameters
    )
    self.connection = connection

    connection.stateUpdateHandler = { [self] state in
      switch state {
      case .ready:
        if !self.didSendQuery {
          self.didSendQuery = true
          self.sendQuery()
        }
      case .failed(let error):
        self.finish(.failure(error))
      case .cancelled:
        break
      default:
        break
      }
    }

    queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
      self?.finish(.failure(DNSProbeError.timedOut))
    }
    connection.start(queue: queue)
  }

  private func sendQuery() {
    var length = UInt16(query.count).bigEndian
    var framedQuery = Data(bytes: &length, count: MemoryLayout<UInt16>.size)
    framedQuery.append(query)

    connection?.send(content: framedQuery, completion: .contentProcessed { [weak self] error in
      guard let self else { return }
      if let error {
        self.finish(.failure(error))
      } else {
        self.receiveExact(byteCount: 2) { result in
          switch result {
          case .success(let lengthData):
            let responseLength = lengthData.reduce(0) { ($0 << 8) | Int($1) }
            guard responseLength >= 12 else {
              self.finish(.failure(DNSProbeError.invalidResponse))
              return
            }
            self.receiveExact(byteCount: responseLength) { responseResult in
              switch responseResult {
              case .success(let response):
                do {
                  try DNSWireMessage.validateResponse(
                    response,
                    transactionID: self.transactionID
                  )
                  self.finish(.success(()))
                } catch {
                  self.finish(.failure(error))
                }
              case .failure(let error):
                self.finish(.failure(error))
              }
            }
          case .failure(let error):
            self.finish(.failure(error))
          }
        }
      }
    })
  }

  private func receiveExact(
    byteCount: Int,
    accumulated: Data = Data(),
    completion: @escaping (Result<Data, Error>) -> Void
  ) {
    let remaining = byteCount - accumulated.count
    guard remaining > 0 else {
      completion(.success(accumulated))
      return
    }

    connection?.receive(
      minimumIncompleteLength: 1,
      maximumLength: remaining
    ) { [weak self] content, _, isComplete, error in
      guard let self else { return }
      if let error {
        completion(.failure(error))
        return
      }

      var updated = accumulated
      if let content {
        updated.append(content)
      }
      if updated.count == byteCount {
        completion(.success(updated))
      } else if isComplete {
        completion(.failure(DNSProbeError.connectionEnded))
      } else {
        self.receiveExact(
          byteCount: byteCount,
          accumulated: updated,
          completion: completion
        )
      }
    }
  }

  private func finish(_ result: Result<Void, Error>) {
    guard !didFinish else { return }
    didFinish = true
    connection?.stateUpdateHandler = nil
    connection?.cancel()
    connection = nil
    completion(result)
  }
}

private enum DNSWireMessage {
  static func query(transactionID: UInt16) -> Data {
    var data = Data()
    append(transactionID, to: &data)
    append(0x0100, to: &data) // Recursion desired.
    append(1, to: &data) // One question.
    append(0, to: &data)
    append(0, to: &data)
    append(0, to: &data)

    for label in ["example", "com"] {
      data.append(UInt8(label.utf8.count))
      data.append(contentsOf: label.utf8)
    }
    data.append(0)
    append(1, to: &data) // A record.
    append(1, to: &data) // IN class.
    return data
  }

  static func validateResponse(_ data: Data, transactionID: UInt16) throws {
    guard data.count >= 12 else {
      throw DNSProbeError.invalidResponse
    }
    let responseID = UInt16(data[0]) << 8 | UInt16(data[1])
    let flags = UInt16(data[2]) << 8 | UInt16(data[3])
    let isResponse = flags & 0x8000 != 0
    let responseCode = Int(flags & 0x000F)
    guard responseID == transactionID, isResponse, responseCode == 0 else {
      throw DNSProbeError.invalidResponse
    }
  }

  private static func append(_ value: UInt16, to data: inout Data) {
    data.append(UInt8((value >> 8) & 0xFF))
    data.append(UInt8(value & 0xFF))
  }
}
