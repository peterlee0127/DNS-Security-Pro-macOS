import Foundation
import Network

enum DNSProtocol: String, Codable, CaseIterable, Identifiable {
  case https = "DNS over HTTPS"
  case tls = "DNS over TLS"

  var id: String { rawValue }

  var shortName: String {
    switch self {
    case .https: return "DoH"
    case .tls: return "DoT"
    }
  }
}

struct DNSProfile: Codable, Hashable, Identifiable {
  let id: String
  var name: String
  var dnsProtocol: DNSProtocol
  var servers: [String]
  var endpoint: String
  var isBuiltIn: Bool

  var endpointLabel: String {
    endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var endpointHost: String {
    if dnsProtocol == .https, let host = URL(string: endpointLabel)?.host {
      return host
    }
    return endpointLabel
  }

  func validated() throws -> DNSProfile {
    var copy = self
    copy.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    copy.endpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
    copy.servers = servers
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    guard !copy.name.isEmpty else {
      throw DNSProfileValidationError.missingName
    }
    guard !copy.endpoint.isEmpty else {
      throw DNSProfileValidationError.missingEndpoint
    }
    guard copy.servers.allSatisfy(Self.isIPAddress) else {
      throw DNSProfileValidationError.invalidServerAddress
    }

    switch copy.dnsProtocol {
    case .https:
      guard
        let url = URL(string: copy.endpoint),
        url.scheme?.lowercased() == "https",
        url.host?.isEmpty == false
      else {
        throw DNSProfileValidationError.invalidHTTPSURL
      }
    case .tls:
      guard !copy.servers.isEmpty else {
        throw DNSProfileValidationError.missingServers
      }
      guard
        !copy.endpoint.contains("://"),
        let components = URLComponents(string: "tls://\(copy.endpoint)"),
        components.host?.isEmpty == false,
        components.port == nil,
        components.user == nil,
        components.password == nil,
        components.query == nil,
        components.fragment == nil,
        components.path.isEmpty
      else {
        throw DNSProfileValidationError.invalidTLSServerName
      }
    }

    return copy
  }

  private static func isIPAddress(_ value: String) -> Bool {
    IPv4Address(value) != nil || IPv6Address(value) != nil
  }

  static var customTemplate: DNSProfile {
    DNSProfile(
      id: UUID().uuidString,
      name: "",
      dnsProtocol: .https,
      servers: [],
      endpoint: "https://",
      isBuiltIn: false
    )
  }

  static let builtInProfiles: [DNSProfile] = [
    DNSProfile(
      id: "cloudflare-doh",
      name: "Cloudflare",
      dnsProtocol: .https,
      servers: ["1.1.1.1", "1.0.0.1"],
      endpoint: "https://cloudflare-dns.com/dns-query",
      isBuiltIn: true
    ),
    DNSProfile(
      id: "cloudflare-dot",
      name: "Cloudflare",
      dnsProtocol: .tls,
      servers: ["1.1.1.1", "1.0.0.1"],
      endpoint: "cloudflare-dns.com",
      isBuiltIn: true
    ),
    DNSProfile(
      id: "google-doh",
      name: "Google Public DNS",
      dnsProtocol: .https,
      servers: ["8.8.8.8", "8.8.4.4"],
      endpoint: "https://dns.google/dns-query",
      isBuiltIn: true
    ),
    DNSProfile(
      id: "google-dot",
      name: "Google Public DNS",
      dnsProtocol: .tls,
      servers: ["8.8.8.8", "8.8.4.4"],
      endpoint: "dns.google",
      isBuiltIn: true
    ),
    DNSProfile(
      id: "quad9-doh",
      name: "Quad9",
      dnsProtocol: .https,
      servers: ["9.9.9.9", "149.112.112.112"],
      endpoint: "https://dns.quad9.net/dns-query",
      isBuiltIn: true
    ),
    DNSProfile(
      id: "adguard-doh",
      name: "AdGuard DNS",
      dnsProtocol: .https,
      servers: ["94.140.14.14", "94.140.15.15"],
      endpoint: "https://dns.adguard-dns.com/dns-query",
      isBuiltIn: true
    ),
  ]
}

enum DNSProfileValidationError: LocalizedError {
  case missingName
  case missingEndpoint
  case missingServers
  case invalidServerAddress
  case invalidHTTPSURL
  case invalidTLSServerName

  var errorDescription: String? {
    switch self {
    case .missingName:
      return String(localized: "Enter a profile name.")
    case .missingEndpoint:
      return String(localized: "Enter a DNS endpoint.")
    case .missingServers:
      return String(localized: "DNS over TLS requires at least one bootstrap server address.")
    case .invalidServerAddress:
      return String(localized: "Enter valid IPv4 or IPv6 addresses for bootstrap servers.")
    case .invalidHTTPSURL:
      return String(localized: "Enter a valid HTTPS URL for DNS over HTTPS.")
    case .invalidTLSServerName:
      return String(localized: "Enter a TLS server name without http:// or https://.")
    }
  }
}
