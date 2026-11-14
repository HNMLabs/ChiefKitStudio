import ChiefKitStudioCore
import Foundation

// MARK: - OWASP Mobile Top 10 (2024) & Severity Taxonomy

public enum OWASPMobileCategory: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case m1ImproperCredentialUsage = "M1:2024"
    case m2InadequateSupplyChainSecurity = "M2:2024"
    case m3InsecureAuthenticationAuthorization = "M3:2024"
    case m4InsufficientInputOutputValidation = "M4:2024"
    case m5InsecureCommunication = "M5:2024"
    case m6InadequatePrivacyControls = "M6:2024"
    case m7InsufficientBinaryProtections = "M7:2024"
    case m8SecurityMisconfiguration = "M8:2024"
    case m9InsecureDataStorage = "M9:2024"
    case m10InsufficientCryptography = "M10:2024"

    public var title: String {
        switch self {
        case .m1ImproperCredentialUsage:
            return "M1: Improper Credential Usage"
        case .m2InadequateSupplyChainSecurity:
            return "M2: Inadequate Supply Chain Security"
        case .m3InsecureAuthenticationAuthorization:
            return "M3: Insecure Authentication & Authorization"
        case .m4InsufficientInputOutputValidation:
            return "M4: Insufficient Input & Output Validation"
        case .m5InsecureCommunication:
            return "M5: Insecure Communication"
        case .m6InadequatePrivacyControls:
            return "M6: Inadequate Privacy Controls"
        case .m7InsufficientBinaryProtections:
            return "M7: Insufficient Binary Protections"
        case .m8SecurityMisconfiguration:
            return "M8: Security Misconfiguration"
        case .m9InsecureDataStorage:
            return "M9: Insecure Data Storage"
        case .m10InsufficientCryptography:
            return "M10: Insufficient Cryptography"
        }
    }
}

public enum SecuritySeverity: String, CaseIterable, Codable, Equatable, Hashable, Comparable, Sendable {
    case info = "INFO"
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    case critical = "CRITICAL"

    public var numericRank: Int {
        switch self {
        case .info: return 1
        case .low: return 2
        case .medium: return 3
        case .high: return 4
        case .critical: return 5
        }
    }

    public var scorePenaltyPoints: Int {
        switch self {
        case .info: return 1
        case .low: return 4
        case .medium: return 9
        case .high: return 16
        case .critical: return 26
        }
    }

    public static func < (lhs: SecuritySeverity, rhs: SecuritySeverity) -> Bool {
        lhs.numericRank < rhs.numericRank
    }
}

// MARK: - 30 Static Vulnerability Rule Identifiers

public enum SecurityRuleID: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case awsAccessKeyID = "CKS-SEC-001"
    case awsSecretAccessKey = "CKS-SEC-002"
    case githubPersonalOrAppToken = "CKS-SEC-003"
    case stripeLiveSecretKey = "CKS-SEC-004"
    case slackTokenOrWebhook = "CKS-SEC-005"
    case googleCloudAPIKey = "CKS-SEC-006"
    case aiProviderLiveSecretKey = "CKS-SEC-007"
    case privateKeyPEMHeader = "CKS-SEC-008"
    case hardcodedBearerJWT = "CKS-SEC-009"
    case highEntropySecretLiteral = "CKS-SEC-010"
    case cleartextHTTPEndpoint = "CKS-SEC-011"
    case atsAllowsArbitraryLoads = "CKS-SEC-012"
    case tlsServerTrustBypass = "CKS-SEC-013"
    case userDefaultsSensitiveStorage = "CKS-SEC-014"
    case worldReadableOrUnprotectedFile = "CKS-SEC-015"
    case keychainAccessibleAlways = "CKS-SEC-016"
    case legacyBrokenHashMD5OrSHA1 = "CKS-SEC-017"
    case predictableInsecurePRNG = "CKS-SEC-018"
    case weakCipherECBOrDES = "CKS-SEC-019"
    case hardcodedStaticNonceOrSalt = "CKS-SEC-020"
    case sqlStringInterpolationInjection = "CKS-SEC-021"
    case webViewJavaScriptInjection = "CKS-SEC-022"
    case shellProcessCommandInjection = "CKS-SEC-023"
    case unsafeInsecureDeserialization = "CKS-SEC-024"
    case unvalidatedDeepLinkSchemeHandler = "CKS-SEC-025"
    case biometricBooleanGateBypassable = "CKS-SEC-026"
    case sensitivePIIOrTokenLogging = "CKS-SEC-027"
    case clipboardSensitiveLeakage = "CKS-SEC-028"
    case unpinnedMutableSupplyChainRef = "CKS-SEC-029"
    case debugOrLibraryValidationRelaxation = "CKS-SEC-030"

    public var title: String {
        switch self {
        case .awsAccessKeyID: return "Hardcoded AWS Access Key ID"
        case .awsSecretAccessKey: return "Hardcoded AWS Secret Access Key"
        case .githubPersonalOrAppToken: return "Hardcoded GitHub Access Token"
        case .stripeLiveSecretKey: return "Hardcoded Stripe Live Secret Key"
        case .slackTokenOrWebhook: return "Hardcoded Slack Token or Incoming Webhook"
        case .googleCloudAPIKey: return "Hardcoded Google Cloud / Firebase API Key"
        case .aiProviderLiveSecretKey: return "Hardcoded LLM / AI Provider Live API Key"
        case .privateKeyPEMHeader: return "Embedded PEM Private Cryptographic Key"
        case .hardcodedBearerJWT: return "Hardcoded Signed JWT Bearer Credential"
        case .highEntropySecretLiteral: return "High-Entropy Hardcoded Secret Literal"
        case .cleartextHTTPEndpoint: return "Cleartext HTTP Endpoint URL"
        case .atsAllowsArbitraryLoads: return "App Transport Security Arbitrary Loads Enabled"
        case .tlsServerTrustBypass: return "TLS Certificate Trust Validation Bypass"
        case .userDefaultsSensitiveStorage: return "Sensitive Token or Password Stored in UserDefaults / AppStorage"
        case .worldReadableOrUnprotectedFile: return "World-Readable POSIX Mode or Disabled File Protection"
        case .keychainAccessibleAlways: return "Deprecated Over-Permissive Keychain Accessibility"
        case .legacyBrokenHashMD5OrSHA1: return "Broken Cryptographic Hash Function (MD5 / SHA-1)"
        case .predictableInsecurePRNG: return "Non-Cryptographic PRNG or Modulo-Biased Randomness"
        case .weakCipherECBOrDES: return "Insecure Block Cipher Mode (ECB) or Legacy Cipher (DES/3DES/RC4)"
        case .hardcodedStaticNonceOrSalt: return "Static Hardcoded AEAD Nonce, IV, or KDF Salt"
        case .sqlStringInterpolationInjection: return "SQL Query String Interpolation Injection"
        case .webViewJavaScriptInjection: return "WKWebView Unsanitized JavaScript Evaluation or File Access"
        case .shellProcessCommandInjection: return "OS Shell Command String Interpolation Injection"
        case .unsafeInsecureDeserialization: return "NSKeyedUnarchiver Without Secure Coding Enforcement"
        case .unvalidatedDeepLinkSchemeHandler: return "Unvalidated Deep-Link URL Host/Query Dispatch"
        case .biometricBooleanGateBypassable: return "LocalAuthentication Boolean Check Without Keychain AccessControl"
        case .sensitivePIIOrTokenLogging: return "Sensitive PII or Secret Logged Without Privacy Redaction"
        case .clipboardSensitiveLeakage: return "Sensitive Secret Copied to System Pasteboard Without Expiration"
        case .unpinnedMutableSupplyChainRef: return "Unpinned Branch or Cleartext Dependency Source"
        case .debugOrLibraryValidationRelaxation: return "Debug Task-Allow or Disabled Library Validation Entitlement"
        }
    }

    public var severity: SecuritySeverity {
        switch self {
        case .awsAccessKeyID, .awsSecretAccessKey, .githubPersonalOrAppToken,
             .stripeLiveSecretKey, .aiProviderLiveSecretKey, .privateKeyPEMHeader,
             .tlsServerTrustBypass, .weakCipherECBOrDES,
             .sqlStringInterpolationInjection, .shellProcessCommandInjection:
            return .critical
        case .slackTokenOrWebhook, .googleCloudAPIKey, .hardcodedBearerJWT,
             .highEntropySecretLiteral, .cleartextHTTPEndpoint, .atsAllowsArbitraryLoads,
             .userDefaultsSensitiveStorage, .worldReadableOrUnprotectedFile,
             .keychainAccessibleAlways, .legacyBrokenHashMD5OrSHA1,
             .hardcodedStaticNonceOrSalt, .webViewJavaScriptInjection,
             .unsafeInsecureDeserialization, .debugOrLibraryValidationRelaxation:
            return .high
        case .predictableInsecurePRNG, .unvalidatedDeepLinkSchemeHandler,
             .biometricBooleanGateBypassable, .sensitivePIIOrTokenLogging,
             .clipboardSensitiveLeakage, .unpinnedMutableSupplyChainRef:
            return .medium
        }
    }

    public var owaspCategory: OWASPMobileCategory {
        switch self {
        case .awsAccessKeyID, .awsSecretAccessKey, .githubPersonalOrAppToken,
             .stripeLiveSecretKey, .slackTokenOrWebhook, .googleCloudAPIKey,
             .aiProviderLiveSecretKey, .privateKeyPEMHeader, .hardcodedBearerJWT,
             .highEntropySecretLiteral:
            return .m1ImproperCredentialUsage
        case .unpinnedMutableSupplyChainRef:
            return .m2InadequateSupplyChainSecurity
        case .unvalidatedDeepLinkSchemeHandler, .biometricBooleanGateBypassable:
            return .m3InsecureAuthenticationAuthorization
        case .sqlStringInterpolationInjection, .webViewJavaScriptInjection,
             .shellProcessCommandInjection, .unsafeInsecureDeserialization:
            return .m4InsufficientInputOutputValidation
        case .cleartextHTTPEndpoint, .atsAllowsArbitraryLoads, .tlsServerTrustBypass:
            return .m5InsecureCommunication
        case .sensitivePIIOrTokenLogging, .clipboardSensitiveLeakage:
            return .m6InadequatePrivacyControls
        case .debugOrLibraryValidationRelaxation:
            return .m7InsufficientBinaryProtections
        case .worldReadableOrUnprotectedFile:
            return .m8SecurityMisconfiguration
        case .userDefaultsSensitiveStorage, .keychainAccessibleAlways:
            return .m9InsecureDataStorage
        case .legacyBrokenHashMD5OrSHA1, .predictableInsecurePRNG,
             .weakCipherECBOrDES, .hardcodedStaticNonceOrSalt:
            return .m10InsufficientCryptography
        }
    }

    public var cweIdentifier: String {
        switch self {
        case .awsAccessKeyID, .awsSecretAccessKey, .githubPersonalOrAppToken,
             .stripeLiveSecretKey, .slackTokenOrWebhook, .googleCloudAPIKey,
             .aiProviderLiveSecretKey, .hardcodedBearerJWT, .highEntropySecretLiteral:
            return "CWE-798"
        case .privateKeyPEMHeader: return "CWE-321"
        case .cleartextHTTPEndpoint: return "CWE-319"
        case .atsAllowsArbitraryLoads, .tlsServerTrustBypass: return "CWE-295"
        case .userDefaultsSensitiveStorage: return "CWE-312"
        case .worldReadableOrUnprotectedFile: return "CWE-732"
        case .keychainAccessibleAlways: return "CWE-522"
        case .legacyBrokenHashMD5OrSHA1: return "CWE-328"
        case .predictableInsecurePRNG: return "CWE-338"
        case .weakCipherECBOrDES: return "CWE-327"
        case .hardcodedStaticNonceOrSalt: return "CWE-329"
        case .sqlStringInterpolationInjection: return "CWE-89"
        case .webViewJavaScriptInjection: return "CWE-79"
        case .shellProcessCommandInjection: return "CWE-78"
        case .unsafeInsecureDeserialization: return "CWE-502"
        case .unvalidatedDeepLinkSchemeHandler: return "CWE-939"
        case .biometricBooleanGateBypassable: return "CWE-287"
        case .sensitivePIIOrTokenLogging: return "CWE-532"
        case .clipboardSensitiveLeakage: return "CWE-200"
        case .unpinnedMutableSupplyChainRef: return "CWE-829"
        case .debugOrLibraryValidationRelaxation: return "CWE-489"
        }
    }
}

// MARK: - Findings, Source Documents & Scan Reports

public struct SecuritySourceDocument: Codable, Equatable, Hashable, Sendable {
    public let filePath: String
    public let content: String

    public init(filePath: String, content: String) {
        self.filePath = filePath
        self.content = content
    }
}

public struct SecurityFinding: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let ruleID: SecurityRuleID
    public let severity: SecuritySeverity
    public let owaspCategory: OWASPMobileCategory
    public let cweIdentifier: String
    public let filePath: String
    public let lineNumber: Int
    public let columnNumber: Int
    public let redactedEvidence: String
    public let explanation: String
    public let remediationGuidance: String
    public let measuredEntropyBitsPerByte: Double?

    public init(
        ruleID: SecurityRuleID,
        filePath: String,
        lineNumber: Int,
        columnNumber: Int,
        redactedEvidence: String,
        explanation: String,
        remediationGuidance: String,
        measuredEntropyBitsPerByte: Double? = nil
    ) {
        self.id = "\(ruleID.rawValue):\(filePath):\(lineNumber):\(columnNumber)"
        self.ruleID = ruleID
        self.severity = ruleID.severity
        self.owaspCategory = ruleID.owaspCategory
        self.cweIdentifier = ruleID.cweIdentifier
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.columnNumber = columnNumber
        self.redactedEvidence = redactedEvidence
        self.explanation = explanation
        self.remediationGuidance = remediationGuidance
        self.measuredEntropyBitsPerByte = measuredEntropyBitsPerByte
    }
}

public struct SecurityScanConfiguration: Codable, Equatable, Hashable, Sendable {
    public var minimumReportedSeverity: SecuritySeverity
    public var highEntropyThresholdBitsPerByte: Double
    public var minimumSecretLiteralLength: Int
    public var disabledRules: Set<SecurityRuleID>
    public var respectInlineIgnorePragmas: Bool

    public init(
        minimumReportedSeverity: SecuritySeverity = .info,
        highEntropyThresholdBitsPerByte: Double = 4.15,
        minimumSecretLiteralLength: Int = 24,
        disabledRules: Set<SecurityRuleID> = [],
        respectInlineIgnorePragmas: Bool = true
    ) {
        self.minimumReportedSeverity = minimumReportedSeverity
        self.highEntropyThresholdBitsPerByte = highEntropyThresholdBitsPerByte
        self.minimumSecretLiteralLength = minimumSecretLiteralLength
        self.disabledRules = disabledRules
        self.respectInlineIgnorePragmas = respectInlineIgnorePragmas
    }

    public static let standard = SecurityScanConfiguration()
}

public struct SecurityScanReport: Codable, Equatable, Sendable {
    public let scannedFileCount: Int
    public let scannedLineCount: Int
    public let findings: [SecurityFinding]
    public let countsBySeverity: [SecuritySeverity: Int]
    public let countsByOWASP: [OWASPMobileCategory: Int]
    public let staticPostureScore: Int

    public var hasCriticalFindings: Bool {
        (countsBySeverity[.critical] ?? 0) > 0
    }

    public var hasBlockingFindings: Bool {
        (countsBySeverity[.critical] ?? 0) > 0 || (countsBySeverity[.high] ?? 0) > 0
    }
}

// MARK: - Static Security & Vulnerability Scanner Engine

public enum StaticSecurityScanner {
    private struct CompiledPatternRule: Sendable {
        let ruleID: SecurityRuleID
        let regexPattern: String
        let redactMatchedToken: Bool
        let explanation: String
        let remediation: String
    }

    private static let patternCatalog: [CompiledPatternRule] = [
        CompiledPatternRule(
            ruleID: .awsAccessKeyID,
            regexPattern: "\\b(?:AKIA|ASIA)[0-9A-Z]{16}\\b",
            redactMatchedToken: true,
            explanation: "Detected a hardcoded AWS IAM or STS access key identifier in source text.",
            remediation: "Revoke the exposed AWS key immediately and fetch short-lived STS credentials via Workload Identity or backend token exchange."
        ),
        CompiledPatternRule(
            ruleID: .awsSecretAccessKey,
            regexPattern: "(?i)(?:aws_secret_access_key|awsSecretKey|aws_secret)\\s*[:=]\\s*[\"'][A-Za-z0-9/+=]{40}[\"']",
            redactMatchedToken: true,
            explanation: "Detected a 40-character AWS secret access key literal assigned in code or config.",
            remediation: "Remove AWS secret keys from client bundles; sign requests server-side or provision ephemeral credentials."
        ),
        CompiledPatternRule(
            ruleID: .githubPersonalOrAppToken,
            regexPattern: "\\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,255}\\b|\\bgithub_pat_[A-Za-z0-9_]{40,255}\\b",
            redactMatchedToken: true,
            explanation: "Detected an embedded GitHub Personal Access Token or GitHub App installation token.",
            remediation: "Revoke the token in GitHub Developer Settings and inject CI credentials via ephemeral environment variables."
        ),
        CompiledPatternRule(
            ruleID: .stripeLiveSecretKey,
            regexPattern: "\\b(?:sk|rk)_live_[0-9a-zA-Z]{20,99}\\b",
            redactMatchedToken: true,
            explanation: "Detected a Stripe live secret/restricted API key inside source or configuration.",
            remediation: "Client apps must only use Stripe publishable keys (pk_live_...); move sk_live_ operations to your backend."
        ),
        CompiledPatternRule(
            ruleID: .slackTokenOrWebhook,
            regexPattern: "\\bxox[baprs]-[0-9]{10,13}-[0-9]{10,13}-[a-zA-Z0-9]{20,40}\\b|https://hooks\\.slack\\.com/services/T[A-Z0-9]+/B[A-Z0-9]+/[A-Za-z0-9]+",
            redactMatchedToken: true,
            explanation: "Detected a hardcoded Slack bot/user token or incoming webhook URL.",
            remediation: "Rotate the Slack credential and proxy webhook notifications through an authenticated server endpoint."
        ),
        CompiledPatternRule(
            ruleID: .googleCloudAPIKey,
            regexPattern: "\\bAIza[0-9A-Za-z_\\-]{35}\\b",
            redactMatchedToken: true,
            explanation: "Detected a hardcoded Google Cloud / Firebase API key.",
            remediation: "Restrict the API key by iOS/macOS bundle identifier or move privileged GCP calls behind an authenticated gateway."
        ),
        CompiledPatternRule(
            ruleID: .aiProviderLiveSecretKey,
            regexPattern: "\\bsk-(?:proj|ant-api03)-[A-Za-z0-9_\\-]{24,200}\\b",
            redactMatchedToken: true,
            explanation: "Detected a live AI model provider secret API key embedded in client source.",
            remediation: "Never ship provider API keys in mobile/desktop binaries; proxy completions through your backend with EphemerisCore or user auth."
        ),
        CompiledPatternRule(
            ruleID: .privateKeyPEMHeader,
            regexPattern: "-----BEGIN\\s+(?:RSA\\s+|EC\\s+|OPENSSH\\s+|DSA\\s+|ENCRYPTED\\s+)?PRIVATE\\s+KEY-----",
            redactMatchedToken: false,
            explanation: "Embedded PEM private key material detected in source or bundle resource.",
            remediation: "Generate non-exportable device keys inside Secure Enclave / Keychain instead of bundling PEM private keys."
        ),
        CompiledPatternRule(
            ruleID: .hardcodedBearerJWT,
            regexPattern: "\\beyJ[A-Za-z0-9_\\-]{10,}\\.eyJ[A-Za-z0-9_\\-]{10,}\\.[A-Za-z0-9_\\-]{16,}\\b",
            redactMatchedToken: true,
            explanation: "Detected a hardcoded JSON Web Token (JWT) literal.",
            remediation: "Acquire short-lived JWTs dynamically at runtime and persist refresh tokens in Keychain with device-only protection."
        ),
        CompiledPatternRule(
            ruleID: .tlsServerTrustBypass,
            regexPattern: "URLCredential\\s*\\(\\s*trust:|kSSLSessionOptionBreakOnServerAuth|allowsExpiredCertificates\\s*=\\s*true",
            redactMatchedToken: false,
            explanation: "TLS server certificate trust evaluation appears overridden without pinning verification.",
            remediation: "Validate SecTrustEvaluateWithError and pin expected SPKI SHA-256 digests before constructing URLCredential(trust:)."
        ),
        CompiledPatternRule(
            ruleID: .userDefaultsSensitiveStorage,
            regexPattern: "(?:UserDefaults\\.standard\\.set|@AppStorage\\s*\\()[^\\n]*(?i:password|accessToken|refreshToken|secretKey|privateKey|apiKey|sessionToken|passphrase|ssn)",
            redactMatchedToken: false,
            explanation: "Sensitive authentication secret or PII is persisted in unencrypted UserDefaults / @AppStorage plist storage.",
            remediation: "Store tokens and secrets in Keychain with SecAccessControl(.whenUnlockedThisDeviceOnly) or EncryptedWorkspaceVault."
        ),
        CompiledPatternRule(
            ruleID: .worldReadableOrUnprotectedFile,
            regexPattern: "\\b0o?[67][67][67]\\b|\\.noFileProtection\\b|NSFileProtectionNone\\b",
            redactMatchedToken: false,
            explanation: "File created with world-readable/writable POSIX permissions or explicit NSFileProtectionNone.",
            remediation: "Use POSIX mode 0o600 and Data.WritingOptions.completeFileProtection (.completeUnlessOpen if background needed)."
        ),
        CompiledPatternRule(
            ruleID: .keychainAccessibleAlways,
            regexPattern: "\\bkSecAttrAccessibleAlways(?:ThisDeviceOnly)?\\b",
            redactMatchedToken: false,
            explanation: "Keychain item configured with deprecated kSecAttrAccessibleAlways, leaving keys decrypted while locked.",
            remediation: "Migrate to kSecAttrAccessibleWhenUnlockedThisDeviceOnly or kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly."
        ),
        CompiledPatternRule(
            ruleID: .legacyBrokenHashMD5OrSHA1,
            regexPattern: "\\b(?:CC_MD5|CC_SHA1)\\s*\\(|Insecure\\.(?:MD5|SHA1)\\b",
            redactMatchedToken: false,
            explanation: "Collision-broken legacy hash function (MD5 or SHA-1) used in codebase.",
            remediation: "Replace MD5/SHA-1 with SHA256Engine, SHA512Engine, HMACSHA256, or PBKDF2Engine."
        ),
        CompiledPatternRule(
            ruleID: .predictableInsecurePRNG,
            regexPattern: "\\b(?:srand|drand48|srand48|random)\\s*\\(|\\brand\\s*\\(\\s*\\)|\\barc4random\\s*\\(\\s*\\)\\s*%",
            redactMatchedToken: false,
            explanation: "Predictable non-cryptographic PRNG or modulo-biased arc4random() detected.",
            remediation: "Use ChaCha20DRBG.systemRandomBytes(count:), SecRandomCopyBytes, or arc4random_uniform(_:)."
        ),
        CompiledPatternRule(
            ruleID: .weakCipherECBOrDES,
            regexPattern: "\\b(?:kCCOptionECBMode|kCCAlgorithmDES|kCCAlgorithm3DES|kCCAlgorithmRC4|kCCAlgorithmBlowfish)\\b",
            redactMatchedToken: false,
            explanation: "Weak legacy symmetric cipher (DES/3DES/RC4) or unauthenticated ECB block mode detected.",
            remediation: "Migrate to authenticated encryption via ChaCha20Poly1305AEAD or XChaCha20Poly1305AEAD."
        ),
        CompiledPatternRule(
            ruleID: .hardcodedStaticNonceOrSalt,
            regexPattern: "(?i)\\b(?:let|var)\\s+(?:nonce|aeadNonce|iv|initVector|pbkdf2Salt)\\s*(?::\\s*\\[UInt8\\])?\\s*=\\s*(?:\\[\\s*(?:0x[0-9a-f]{1,2}|[0-9]{1,3})(?:\\s*,\\s*(?:0x[0-9a-f]{1,2}|[0-9]{1,3})){7,}\\s*\\]|[\"'][^\"']{8,}[\"'])",
            redactMatchedToken: false,
            explanation: "Static hardcoded byte array or string used as an AEAD nonce/IV or KDF salt (catastrophic under key reuse).",
            remediation: "Generate a fresh unique nonce/salt per seal operation via ChaCha20DRBG or XChaCha20Poly1305AEAD 24-byte nonces."
        ),
        CompiledPatternRule(
            ruleID: .sqlStringInterpolationInjection,
            regexPattern: "(?i)[\"']\\s*(?:SELECT|INSERT\\s+INTO|UPDATE|DELETE\\s+FROM|DROP\\s+TABLE)\\b[^\"']*\\\\\\([^\\)]+\\)",
            redactMatchedToken: false,
            explanation: "Unsanitized Swift string interpolation inside a raw SQL statement enables SQL injection.",
            remediation: "Use parameterized prepared statements (sqlite3_bind_text / sqlite3_bind_int64) with '?' placeholders."
        ),
        CompiledPatternRule(
            ruleID: .webViewJavaScriptInjection,
            regexPattern: "\\.evaluateJavaScript\\s*\\(\\s*\"[^\"]*\\\\\\(|javaScriptCanOpenWindowsAutomatically\\s*=\\s*true|allowFileAccessFromFileURLs",
            redactMatchedToken: false,
            explanation: "WKWebView evaluates interpolated JavaScript strings or enables cross-file URL access.",
            remediation: "Pass structured JSON arguments safely or use WKScriptMessageHandler with strict origin allowlists."
        ),
        CompiledPatternRule(
            ruleID: .shellProcessCommandInjection,
            regexPattern: "(?:launchPath|executableURL)[^\\n]*(?:/bin/sh|/bin/bash|/usr/bin/env)|arguments\\s*=\\s*\\[\\s*\"-c\"\\s*,\\s*\"[^\"]*\\\\\\(",
            redactMatchedToken: false,
            explanation: "Subprocess invokes a shell interpreter with interpolated command strings.",
            remediation: "Invoke the target binary path directly via Process.executableURL and pass untrusted values as discrete argument elements."
        ),
        CompiledPatternRule(
            ruleID: .unsafeInsecureDeserialization,
            regexPattern: "NSKeyedUnarchiver\\.unarchive(?:TopLevel)?ObjectWith|requiresSecureCoding\\s*=\\s*false",
            redactMatchedToken: false,
            explanation: "Insecure object deserialization allows arbitrary class instantiation attacks.",
            remediation: "Use NSKeyedUnarchiver.unarchivedObject(ofClass:from:) with NSSecureCoding = true or Codable JSONDecoder."
        ),
        CompiledPatternRule(
            ruleID: .unvalidatedDeepLinkSchemeHandler,
            regexPattern: "\\.onOpenURL\\s*\\{[^\\n]*(?:URLComponents|queryItems)!",
            redactMatchedToken: false,
            explanation: "Deep-link handler force-unwraps incoming URL components without host/scheme validation.",
            remediation: "Validate url.scheme, url.host against an explicit allowlist and safely parse query items without force-unwrapping."
        ),
        CompiledPatternRule(
            ruleID: .biometricBooleanGateBypassable,
            regexPattern: "evaluatePolicy\\s*\\(\\s*\\.(?:deviceOwnerAuthenticationWithBiometrics|deviceOwnerAuthentication)\\b",
            redactMatchedToken: false,
            explanation: "LAContext.evaluatePolicy returns a user-space Bool that runtime instrumentation (Frida) can hook if not bound to Keychain.",
            remediation: "Bind biometric evaluation cryptographically to a Secure Enclave / Keychain item via SecAccessControlCreateWithFlags(.biometryCurrentSet)."
        ),
        CompiledPatternRule(
            ruleID: .sensitivePIIOrTokenLogging,
            regexPattern: "(?:\\bprint\\s*\\(|\\bNSLog\\s*\\(|privacy:\\s*\\.public)[^\\n]*(?i:password|passphrase|accessToken|refreshToken|secretKey|privateKey|creditCard|ssn|bearer)",
            redactMatchedToken: false,
            explanation: "Sensitive authentication secret or PII appears emitted to stdout, system console, or public OSLog.",
            remediation: "Remove secret logging or mark OSLog interpolations with `privacy: .private(mask: .hash)`."
        ),
        CompiledPatternRule(
            ruleID: .clipboardSensitiveLeakage,
            regexPattern: "(?:UIPasteboard\\.general\\.(?:string|items)\\s*=|NSPasteboard\\.general\\.setString)[^\\n]*(?i:password|token|secret|mnemonic|recovery|seed)",
            redactMatchedToken: false,
            explanation: "Sensitive credential copied to shared system pasteboard without localOnly restriction or expiration.",
            remediation: "Use UIPasteboard.general.setItems(_:options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(45)])."
        ),
        CompiledPatternRule(
            ruleID: .unpinnedMutableSupplyChainRef,
            regexPattern: "\\.package\\s*\\(\\s*url:\\s*\"http://|\\.package\\s*\\([^\\)]*branch:\\s*\"(?:main|master|develop)\"",
            redactMatchedToken: false,
            explanation: "SwiftPM dependency fetched over cleartext HTTP or unpinned mutable branch reference.",
            remediation: "Use HTTPS repository URLs pinned to exact semantic versions or verified commit revisions."
        )
    ]

    // MARK: Public Scanning Entry Points

    public static func scan(
        source: String,
        filePath: String = "InlineSource.swift",
        configuration: SecurityScanConfiguration = .standard
    ) -> SecurityScanReport {
        scan(
            documents: [SecuritySourceDocument(filePath: filePath, content: source)],
            configuration: configuration
        )
    }

    public static func scan(
        documents: [SecuritySourceDocument],
        configuration: SecurityScanConfiguration = .standard
    ) -> SecurityScanReport {
        var allFindings = [SecurityFinding]()
        var totalLines = 0

        let compiledRegexes: [(CompiledPatternRule, NSRegularExpression)] = patternCatalog.compactMap { entry in
            guard !configuration.disabledRules.contains(entry.ruleID) else { return nil }
            guard let rx = try? NSRegularExpression(pattern: entry.regexPattern, options: []) else {
                return nil
            }
            return (entry, rx)
        }

        for doc in documents {
            let lines = doc.content.isEmpty ? [] : doc.content.components(separatedBy: "\n")
            totalLines += lines.count

            // 1. Line-by-line regex, cleartext HTTP, and high-entropy secret literal checks
            for (zeroIdx, line) in lines.enumerated() {
                let lineNum = zeroIdx + 1
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }

                for (rule, regex) in compiledRegexes {
                    if configuration.respectInlineIgnorePragmas && isRuleIgnoredOnLine(line, ruleID: rule.ruleID) {
                        continue
                    }
                    let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
                    let matches = regex.matches(in: line, options: [], range: nsRange)
                    for match in matches {
                        guard let swiftRange = Range(match.range, in: line) else { continue }
                        let col = line.distance(from: line.startIndex, to: swiftRange.lowerBound) + 1
                        let matchedText = String(line[swiftRange])
                        let evidence = rule.redactMatchedToken ? redactSecret(matchedText) : truncateSnippet(line)

                        allFindings.append(
                            SecurityFinding(
                                ruleID: rule.ruleID,
                                filePath: doc.filePath,
                                lineNumber: lineNum,
                                columnNumber: col,
                                redactedEvidence: evidence,
                                explanation: rule.explanation,
                                remediationGuidance: rule.remediation
                            )
                        )
                    }
                }

                // Rule 011: Cleartext HTTP URLs (filtering benign XML DTDs & loopback addresses)
                if !configuration.disabledRules.contains(.cleartextHTTPEndpoint),
                   !(configuration.respectInlineIgnorePragmas && isRuleIgnoredOnLine(line, ruleID: .cleartextHTTPEndpoint)) {
                    allFindings.append(contentsOf: scanCleartextHTTP(in: line, filePath: doc.filePath, lineNumber: lineNum))
                }

                // Rule 010: High-entropy hardcoded secret string literals
                if !configuration.disabledRules.contains(.highEntropySecretLiteral),
                   !(configuration.respectInlineIgnorePragmas && isRuleIgnoredOnLine(line, ruleID: .highEntropySecretLiteral)) {
                    allFindings.append(
                        contentsOf: scanHighEntropySecrets(
                            in: line,
                            filePath: doc.filePath,
                            lineNumber: lineNum,
                            existingFindingsOnLine: allFindings.filter { $0.filePath == doc.filePath && $0.lineNumber == lineNum },
                            config: configuration
                        )
                    )
                }
            }

            // 2. Multi-line Plist / XML / Entitlement configuration checks (ATS & Hardened Runtime)
            allFindings.append(
                contentsOf: scanMultiLinePlistMisconfigurations(
                    lines: lines,
                    filePath: doc.filePath,
                    config: configuration
                )
            )
        }

        // Filter by minimum severity and deduplicate identical rule+line hits
        var seenIDs = Set<String>()
        var filtered = [SecurityFinding]()
        for item in allFindings where item.severity >= configuration.minimumReportedSeverity {
            if seenIDs.insert(item.id).inserted {
                filtered.append(item)
            }
        }

        filtered.sort {
            if $0.severity != $1.severity { return $0.severity > $1.severity }
            if $0.filePath != $1.filePath { return $0.filePath < $1.filePath }
            return $0.lineNumber < $1.lineNumber
        }

        var bySeverity: [SecuritySeverity: Int] = [:]
        var byOWASP: [OWASPMobileCategory: Int] = [:]
        var totalPenalty = 0

        for finding in filtered {
            bySeverity[finding.severity, default: 0] += 1
            byOWASP[finding.owaspCategory, default: 0] += 1
            totalPenalty += finding.severity.scorePenaltyPoints
        }

        let postureScore = max(0, min(100, 100 - totalPenalty))

        return SecurityScanReport(
            scannedFileCount: documents.count,
            scannedLineCount: totalLines,
            findings: filtered,
            countsBySeverity: bySeverity,
            countsByOWASP: byOWASP,
            staticPostureScore: postureScore
        )
    }

    // MARK: Specialized Lexical & Entropy Detectors

    private static func scanCleartextHTTP(
        in line: String,
        filePath: String,
        lineNumber: Int
    ) -> [SecurityFinding] {
        guard line.contains("http://") else { return [] }
        guard let rx = try? NSRegularExpression(pattern: "http://[A-Za-z0-9._~:/?#\\[\\]@!$&'()*+,;=%\\-]+") else {
            return []
        }
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        var out = [SecurityFinding]()

        let benignPrefixes = [
            "http://localhost",
            "http://127.0.0.1",
            "http://0.0.0.0",
            "http://[::1]",
            "http://www.apple.com/DTDs",
            "http://www.w3.org/",
            "http://schemas.xmlsoap.org/",
            "http://ns.adobe.com/"
        ]

        for match in rx.matches(in: line, range: nsRange) {
            guard let range = Range(match.range, in: line) else { continue }
            let urlText = String(line[range])
            if benignPrefixes.contains(where: { urlText.lowercased().hasPrefix($0.lowercased()) }) {
                continue
            }
            let col = line.distance(from: line.startIndex, to: range.lowerBound) + 1
            out.append(
                SecurityFinding(
                    ruleID: .cleartextHTTPEndpoint,
                    filePath: filePath,
                    lineNumber: lineNumber,
                    columnNumber: col,
                    redactedEvidence: urlText,
                    explanation: "Unencrypted cleartext HTTP endpoint exposes traffic to MITM interception and stripping.",
                    remediationGuidance: "Upgrade endpoint to HTTPS (TLS 1.3) and enforce App Transport Security."
                )
            )
        }
        return out
    }

    private static func scanHighEntropySecrets(
        in line: String,
        filePath: String,
        lineNumber: Int,
        existingFindingsOnLine: [SecurityFinding],
        config: SecurityScanConfiguration
    ) -> [SecurityFinding] {
        // Skip if a specific vendor token rule already flagged this line
        if existingFindingsOnLine.contains(where: { $0.owaspCategory == .m1ImproperCredentialUsage }) {
            return []
        }

        let lower = line.lowercased()
        let credentialKeywords = [
            "secret", "apikey", "api_key", "authkey", "privatekey", "private_key",
            "accesstoken", "access_token", "clientsecret", "client_secret", "hmac_key", "masterkey"
        ]
        guard credentialKeywords.contains(where: { lower.contains($0) }) else {
            return []
        }

        guard let quoteRx = try? NSRegularExpression(pattern: "[\"']([A-Za-z0-9+/=_\\-]{20,256})[\"']") else {
            return []
        }
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        var findings = [SecurityFinding]()

        for match in quoteRx.matches(in: line, range: nsRange) {
            guard match.numberOfRanges >= 2,
                  let literalRange = Range(match.range(at: 1), in: line)
            else { continue }
            let candidate = String(line[literalRange])
            guard candidate.count >= config.minimumSecretLiteralLength else { continue }

            // Exclude obvious variable names / camelCase identifiers without digits or mixed entropy
            let hasDigit = candidate.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) }
            let hasLetter = candidate.unicodeScalars.contains { CharacterSet.letters.contains($0) }
            guard hasDigit && hasLetter else { continue }

            let entropy = EphemerisEntropyEstimator.analyzeBytes(Array(candidate.utf8)).shannonBitsPerByte
            if entropy >= config.highEntropyThresholdBitsPerByte {
                let col = line.distance(from: line.startIndex, to: literalRange.lowerBound) + 1
                findings.append(
                    SecurityFinding(
                        ruleID: .highEntropySecretLiteral,
                        filePath: filePath,
                        lineNumber: lineNumber,
                        columnNumber: col,
                        redactedEvidence: redactSecret(candidate),
                        explanation: String(
                            format: "High-entropy credential string literal (%.2f bits/byte across %d chars) assigned to secret-named identifier.",
                            entropy,
                            candidate.count
                        ),
                        remediationGuidance: "Move secret material out of source control into Keychain, `.xcconfig` git-ignored secrets, or server-side vault.",
                        measuredEntropyBitsPerByte: entropy
                    )
                )
            }
        }
        return findings
    }

    private static func scanMultiLinePlistMisconfigurations(
        lines: [String],
        filePath: String,
        config: SecurityScanConfiguration
    ) -> [SecurityFinding] {
        var out = [SecurityFinding]()
        for idx in 0..<lines.count {
            let line = lines[idx]
            let nextWindow = lines[idx..<min(lines.count, idx + 3)].joined(separator: " ")

            // Rule 012: ATS NSAllowsArbitraryLoads / NSExceptionAllowsInsecureHTTPLoads
            if !config.disabledRules.contains(.atsAllowsArbitraryLoads),
               (line.contains("NSAllowsArbitraryLoads") || line.contains("NSExceptionAllowsInsecureHTTPLoads")),
               (nextWindow.contains("<true/>") || nextWindow.contains("= true") || nextWindow.contains(": true")) {
                if !(config.respectInlineIgnorePragmas && isRuleIgnoredOnLine(line, ruleID: .atsAllowsArbitraryLoads)) {
                    out.append(
                        SecurityFinding(
                            ruleID: .atsAllowsArbitraryLoads,
                            filePath: filePath,
                            lineNumber: idx + 1,
                            columnNumber: 1,
                            redactedEvidence: truncateSnippet(line),
                            explanation: "App Transport Security protection is globally or domain-widely disabled.",
                            remediationGuidance: "Set NSAllowsArbitraryLoads to false and require TLS 1.2+ with forward secrecy."
                        )
                    )
                }
            }

            // Rule 030: Debug get-task-allow or disabled library validation in Release entitlements
            if !config.disabledRules.contains(.debugOrLibraryValidationRelaxation),
               (line.contains("get-task-allow") || line.contains("disable-library-validation") || line.contains("cs.allow-dyld-environment-variables")),
               (nextWindow.contains("<true/>") || nextWindow.contains("= true")) {
                if !(config.respectInlineIgnorePragmas && isRuleIgnoredOnLine(line, ruleID: .debugOrLibraryValidationRelaxation)) {
                    out.append(
                        SecurityFinding(
                            ruleID: .debugOrLibraryValidationRelaxation,
                            filePath: filePath,
                            lineNumber: idx + 1,
                            columnNumber: 1,
                            redactedEvidence: truncateSnippet(line),
                            explanation: "Entitlement relaxes Hardened Runtime library validation or allows debugger attachment in production.",
                            remediationGuidance: "Remove get-task-allow / disable-library-validation from Release entitlements."
                        )
                    )
                }
            }
        }
        return out
    }

    private static func isRuleIgnoredOnLine(_ line: String, ruleID: SecurityRuleID) -> Bool {
        guard let markerRange = line.range(of: "chiefkit-security-ignore:") else { return false }
        let suffix = line[markerRange.upperBound...]
        return suffix.contains("ALL") || suffix.contains(ruleID.rawValue)
    }

    private static func redactSecret(_ raw: String) -> String {
        let chars = Array(raw)
        guard chars.count > 8 else { return String(repeating: "*", count: max(4, chars.count)) }
        let prefix = String(chars.prefix(4))
        let suffix = String(chars.suffix(3))
        let maskedCount = min(16, chars.count - 7)
        return "\(prefix)\(String(repeating: "*", count: maskedCount))\(suffix)"
    }

    private static func truncateSnippet(_ rawLine: String) -> String {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 96 { return trimmed }
        return String(trimmed.prefix(93)) + "..."
    }
}
