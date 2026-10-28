import Foundation

// This describes one request, not all traffic or ownership by a particular DNS profile.
enum DNSUsageVerdict: Equatable {
  case encrypted, unencrypted, inconclusive

  init(protocols: [URLSessionTaskMetrics.DomainResolutionProtocol], usesProxy: Bool) {
    let protocols = Set(protocols)
    guard !usesProxy, protocols.count == 1, let value = protocols.first else {
      self = .inconclusive
      return
    }
    switch value {
    case .https, .tls: self = .encrypted
    case .udp, .tcp: self = .unencrypted
    default: self = .inconclusive
    }
  }

  var title: String {
    switch self {
    case .encrypted: return String(localized: "Encrypted DNS observed")
    case .unencrypted: return String(localized: "Unencrypted DNS observed")
    case .inconclusive: return String(localized: "DNS usage could not be determined")
    }
  }
}

struct DNSUsageResult {
  let verdict: DNSUsageVerdict
  let host: String
  let protocols: [URLSessionTaskMetrics.DomainResolutionProtocol]
  let measuredAt: Date

  var protocolName: String {
    guard Set(protocols).count == 1, let value = protocols.first else {
      return String(localized: "Unknown")
    }
    switch value {
    case .https: return "DNS over HTTPS"
    case .tls: return "DNS over TLS"
    case .udp: return "DNS over UDP"
    case .tcp: return "DNS over TCP"
    default: return String(localized: "Unknown")
    }
  }
}

@MainActor
final class DNSUsageDiagnostic: NSObject, @preconcurrency URLSessionTaskDelegate {
  private var session: URLSession?
  private var protocols: [URLSessionTaskMetrics.DomainResolutionProtocol] = []
  private var usesProxy = false
  private var completion: ((DNSUsageResult) -> Void)?

  func start(completion: @escaping (DNSUsageResult) -> Void) {
    cancel()
    self.completion = completion
    request(host: "\(UUID().uuidString.lowercased()).map.help.every1dns.net")
  }

  func cancel() {
    completion = nil
    session?.invalidateAndCancel()
    session = nil
  }

  private func request(host: String) {
    protocols = []
    usesProxy = false
    let configuration = URLSessionConfiguration.ephemeral
    configuration.urlCache = nil
    configuration.urlCredentialStorage = nil
    configuration.httpCookieStorage = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    configuration.timeoutIntervalForRequest = 5
    configuration.timeoutIntervalForResource = 8
    let session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    self.session = session
    var request = URLRequest(url: URL(string: "https://\(host)/")!)
    request.httpMethod = "HEAD"
    session.dataTask(with: request).resume()
  }

  func urlSession(
    _ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics
  ) {
    guard session === self.session else { return }
    usesProxy = metrics.transactionMetrics.contains { $0.isProxyConnection }
    // Cached DNS and reused connections cannot establish a fresh DNS observation.
    protocols = metrics.transactionMetrics.filter {
      !$0.isReusedConnection && $0.resourceFetchType == .networkLoad
        && $0.domainLookupStartDate != nil && $0.domainLookupEndDate != nil
    }.map(\.domainResolutionProtocol)
  }

  func urlSession(
    _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?
  ) {
    guard session === self.session, let host = task.originalRequest?.url?.host else { return }
    let verdict = DNSUsageVerdict(protocols: protocols, usesProxy: usesProxy)
    session.finishTasksAndInvalidate()
    self.session = nil
    // Filters can block the diagnostic domain; try a widely reachable host once.
    if verdict == .inconclusive, host != "www.apple.com", !usesProxy {
      request(host: "www.apple.com")
      return
    }
    let callback = completion
    completion = nil
    callback?(DNSUsageResult(verdict: verdict, host: host, protocols: protocols, measuredAt: Date()))
  }

  func urlSession(
    _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}
