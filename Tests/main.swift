import Foundation

// Run: swiftc DNSSecurityProMac/Services/DNSUsageDiagnostic.swift Tests/main.swift -o /tmp/dns-usage-check && /tmp/dns-usage-check
let cases: [([URLSessionTaskMetrics.DomainResolutionProtocol], Bool, DNSUsageVerdict)] = [
  ([.https], false, .encrypted),
  ([.tls], false, .encrypted),
  ([.udp], false, .unencrypted),
  ([.tcp], false, .unencrypted),
  ([], false, .inconclusive),
  ([.unknown], false, .inconclusive),
  ([.https, .unknown], false, .inconclusive),
  ([.https, .udp], false, .inconclusive),
  ([.https, .tls], false, .inconclusive),
  ([.https, .https], false, .encrypted),
  ([.https], true, .inconclusive),
  ([.udp], true, .inconclusive),
]
for (protocols, proxy, expected) in cases {
  precondition(DNSUsageVerdict(protocols: protocols, usesProxy: proxy) == expected)
}
let result = DNSUsageResult(verdict: .encrypted, host: "test.example", protocols: [.tls], measuredAt: Date())
precondition(result.protocolName == "DNS over TLS")
print("DNS usage classification checks passed (\(cases.count) cases).")
