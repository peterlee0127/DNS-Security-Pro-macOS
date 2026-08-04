import Foundation
import Network

enum DNSProtocol: String, Codable, CaseIterable, Identifiable, Sendable {
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

enum DNSProfileTrait: String, Codable, CaseIterable, Identifiable, Sendable {
  case privacy
  case malwareBlocking
  case adBlocking
  case trackerBlocking
  case familyProtection

  var id: String { rawValue }

  var title: String {
    switch self {
    case .privacy: return String(localized: "Privacy")
    case .malwareBlocking: return String(localized: "Malware Blocking")
    case .adBlocking: return String(localized: "Ad Blocking")
    case .trackerBlocking: return String(localized: "Tracker Blocking")
    case .familyProtection: return String(localized: "Family Protection")
    }
  }

  var systemImage: String {
    switch self {
    case .privacy: return "hand.raised.fill"
    case .malwareBlocking: return "checkmark.shield.fill"
    case .adBlocking: return "rectangle.slash"
    case .trackerBlocking: return "eye.slash.fill"
    case .familyProtection: return "figure.2.and.child.holdinghands"
    }
  }
}

struct DNSProfile: Codable, Hashable, Identifiable, Sendable {
  let id: String
  var name: String
  var dnsProtocol: DNSProtocol
  var servers: [String]
  var endpoint: String
  var isBuiltIn: Bool
  var traits: [DNSProfileTrait]?
  var excludedWiFiSSIDs: [String]?
  var excludedDomains: [String]?

  var endpointLabel: String {
    endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var endpointHost: String {
    if dnsProtocol == .https, let host = URL(string: endpointLabel)?.host {
      return host
    }
    return endpointLabel
  }

  var profileTraits: [DNSProfileTrait] {
    traits ?? []
  }

  var wiFiExclusions: [String] {
    excludedWiFiSSIDs ?? []
  }

  var domainExclusions: [String] {
    excludedDomains ?? []
  }

  func validated() throws -> DNSProfile {
    var copy = self
    copy.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    copy.endpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
    copy.servers = servers
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    copy.traits = Array(Set(traits ?? [])).sorted { $0.rawValue < $1.rawValue }
    copy.excludedWiFiSSIDs = Self.normalizedList(excludedWiFiSSIDs ?? [])
    copy.excludedDomains = Self.normalizedDomains(excludedDomains ?? [])
    guard copy.domainExclusions.allSatisfy(Self.isDomainName) else {
      throw DNSProfileValidationError.invalidExcludedDomain
    }

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

  func withID(_ id: String) -> DNSProfile {
    DNSProfile(
      id: id,
      name: name,
      dnsProtocol: dnsProtocol,
      servers: servers,
      endpoint: endpoint,
      isBuiltIn: isBuiltIn,
      traits: traits,
      excludedWiFiSSIDs: excludedWiFiSSIDs,
      excludedDomains: excludedDomains
    )
  }

  private static func isIPAddress(_ value: String) -> Bool {
    IPv4Address(value) != nil || IPv6Address(value) != nil
  }

  private static func normalizedList(_ values: [String]) -> [String] {
    var seen = Set<String>()
    return values.compactMap { value in
      let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return nil }
      let comparisonKey = trimmed.lowercased()
      guard seen.insert(comparisonKey).inserted else { return nil }
      return trimmed
    }
  }

  private static func normalizedDomains(_ values: [String]) -> [String] {
    normalizedList(values).compactMap { value in
      var domain = value.lowercased()
      while domain.hasPrefix("*.") || domain.hasPrefix(".") {
        domain.removeFirst(domain.hasPrefix("*.") ? 2 : 1)
      }
      return domain.isEmpty ? nil : domain
    }
  }

  private static func isDomainName(_ value: String) -> Bool {
    guard value.count <= 253 else { return false }
    return value.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { label in
      guard !label.isEmpty, label.count <= 63 else { return false }
      guard label.first != "-", label.last != "-" else { return false }
      return label.allSatisfy { character in
        character.isASCII && (character.isLetter || character.isNumber || character == "-")
      }
    }
  }

  static var customTemplate: DNSProfile {
    DNSProfile(
      id: UUID().uuidString,
      name: "",
      dnsProtocol: .https,
      servers: [],
      endpoint: "https://",
      isBuiltIn: false,
      traits: [.privacy]
    )
  }

  static let builtInProfiles: [DNSProfile] = [
    DNSProfile(
      id: "cloudflare-doh",
      name: "Cloudflare",
      dnsProtocol: .https,
      servers: ["1.1.1.1", "1.0.0.1"],
      endpoint: "https://cloudflare-dns.com/dns-query",
      isBuiltIn: true,
      traits: [.privacy]
    ),
    DNSProfile(
      id: "cloudflare-dot",
      name: "Cloudflare",
      dnsProtocol: .tls,
      servers: ["1.1.1.1", "1.0.0.1"],
      endpoint: "cloudflare-dns.com",
      isBuiltIn: true,
      traits: [.privacy]
    ),
    DNSProfile(
      id: "google-doh",
      name: "Google Public DNS",
      dnsProtocol: .https,
      servers: ["8.8.8.8", "8.8.4.4"],
      endpoint: "https://dns.google/dns-query",
      isBuiltIn: true,
      traits: [.privacy]
    ),
    DNSProfile(
      id: "google-dot",
      name: "Google Public DNS",
      dnsProtocol: .tls,
      servers: ["8.8.8.8", "8.8.4.4"],
      endpoint: "dns.google",
      isBuiltIn: true,
      traits: [.privacy]
    ),
    DNSProfile(
      id: "quad9-doh",
      name: "Quad9",
      dnsProtocol: .https,
      servers: ["9.9.9.9", "149.112.112.112"],
      endpoint: "https://dns.quad9.net/dns-query",
      isBuiltIn: true,
      traits: [.privacy, .malwareBlocking]
    ),
    DNSProfile(
      id: "adguard-doh",
      name: "AdGuard DNS",
      dnsProtocol: .https,
      servers: ["94.140.14.14", "94.140.15.15"],
      endpoint: "https://dns.adguard-dns.com/dns-query",
      isBuiltIn: true,
      traits: [.privacy, .adBlocking, .trackerBlocking, .malwareBlocking]
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
  case invalidExcludedDomain

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
    case .invalidExcludedDomain:
      return String(localized: "Enter valid domain names for DNS exclusions.")
    }
  }
}
