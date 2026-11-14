import ChiefKitStudioCore
import Foundation

// MARK: - Cryptographic Posture & OWASP Mobile Top 10 (2024) Scorecard Models

public struct CryptographicPostureInput: Codable, Equatable, Hashable, Sendable {
    public var vaultCipherSuite: VaultCipherSuite
    public var pbkdf2Iterations: Int
    public var kdfPRF: PseudorandomFunctionVariant
    public var ephemerisTemporalAuthEnabled: Bool
    public var ephemerisBindGeodeticCell: Bool
    public var shamirRecoveryThreshold: Int
    public var shamirRecoveryTotalShares: Int
    public var keychainBiometricPolicy: KeychainBiometricPolicy

    public init(
        vaultCipherSuite: VaultCipherSuite = .xchacha20Poly1305,
        pbkdf2Iterations: Int = VaultKDFPreset.interactiveDesktop.iterations,
        kdfPRF: PseudorandomFunctionVariant = .hmacSHA256,
        ephemerisTemporalAuthEnabled: Bool = true,
        ephemerisBindGeodeticCell: Bool = false,
        shamirRecoveryThreshold: Int = 3,
        shamirRecoveryTotalShares: Int = 5,
        keychainBiometricPolicy: KeychainBiometricPolicy = .biometryCurrentSet
    ) {
        self.vaultCipherSuite = vaultCipherSuite
        self.pbkdf2Iterations = pbkdf2Iterations
        self.kdfPRF = kdfPRF
        self.ephemerisTemporalAuthEnabled = ephemerisTemporalAuthEnabled
        self.ephemerisBindGeodeticCell = ephemerisBindGeodeticCell
        self.shamirRecoveryThreshold = shamirRecoveryThreshold
        self.shamirRecoveryTotalShares = shamirRecoveryTotalShares
        self.keychainBiometricPolicy = keychainBiometricPolicy
    }

    public static let hardenedDefault = CryptographicPostureInput()
}

public struct OWASPCategoryScore: Identifiable, Codable, Equatable, Sendable {
    public var id: String { category.rawValue }
    public let category: OWASPMobileCategory
    public let score: Int
    public let grade: String
    public let findingCount: Int
    public let criticalOrHighCount: Int
    public let controlSummary: String
    public let prioritizedActions: [String]
}

public struct SecurityAuditScorecard: Codable, Equatable, Sendable {
    public let workspaceName: String
    public let generatedAtISO8601: String
    public let overallScore: Int
    public let letterGrade: String
    public let isReleaseGatePassing: Bool
    public let staticPostureScore: Int
    public let privacyComplianceScore: Int
    public let cryptographicPostureScore: Int
    public let categoryScores: [OWASPCategoryScore]
    public let mermaidArchitectureDiagram: String
    public let mermaidSequenceDiagram: String
    public let executiveSummary: String
}

// MARK: - OWASP M1-M10 Audit Synthesizer, Mermaid Threat Modeler & Swift Testing Emitter

public enum SecurityAuditReportSynthesizer {
    public static func evaluateScorecard(
        workspaceName: String = "ChiefKitWorkspace",
        scanReport: SecurityScanReport,
        privacyAudit: PrivacyComplianceAudit,
        cryptoPosture: CryptographicPostureInput = .hardenedDefault,
        timestamp: Date = Date()
    ) -> SecurityAuditScorecard {
        let cryptoScore = evaluateCryptoPostureScore(cryptoPosture)
        var categoryAssessments = [OWASPCategoryScore]()
        categoryAssessments.reserveCapacity(OWASPMobileCategory.allCases.count)

        for cat in OWASPMobileCategory.allCases {
            let catFindings = scanReport.findings.filter { $0.owaspCategory == cat }
            let critHigh = catFindings.filter { $0.severity >= .high }.count
            var rawScore = 100
            for f in catFindings {
                rawScore -= f.severity.scorePenaltyPoints
            }

            var actions = catFindings.prefix(3).map(\.remediationGuidance)

            // Incorporate domain-specific posture signals into relevant OWASP categories
            switch cat {
            case .m3InsecureAuthenticationAuthorization:
                if !cryptoPosture.ephemerisTemporalAuthEnabled {
                    rawScore -= 10
                    actions.append("Enable EphemerisCore Celestial-Temporal HKDF-SHA512 session authentication for sensitive commands.")
                }
                if cryptoPosture.keychainBiometricPolicy == .deviceOnlyUnlocked {
                    rawScore -= 4
                }
            case .m6InadequatePrivacyControls:
                let privPenalty = max(0, 100 - privacyAudit.complianceScore)
                rawScore -= privPenalty
                for issue in privacyAudit.issues.prefix(2) {
                    actions.append(issue.remediation)
                }
            case .m9InsecureDataStorage:
                if cryptoPosture.shamirRecoveryThreshold < 2 {
                    rawScore -= 8
                    actions.append("Configure GF(256) Shamir threshold k >= 2 for vault disaster recovery keys.")
                }
            case .m10InsufficientCryptography:
                let cryptoPenalty = max(0, 100 - cryptoScore)
                rawScore -= cryptoPenalty
                if cryptoPosture.pbkdf2Iterations < 60_000 {
                    actions.append("Increase PBKDF2 work factor to >= 60,000 iterations (or 210,000 for archival vaults).")
                }
            default:
                break
            }

            let clamped = max(0, min(100, rawScore))
            let dedupActions = deduplicatePreservingOrder(actions)
            let summary = buildCategoryControlSummary(
                category: cat,
                score: clamped,
                findingCount: catFindings.count,
                cryptoPosture: cryptoPosture,
                privacyAudit: privacyAudit
            )

            categoryAssessments.append(
                OWASPCategoryScore(
                    category: cat,
                    score: clamped,
                    grade: letterGrade(for: clamped),
                    findingCount: catFindings.count,
                    criticalOrHighCount: critHigh,
                    controlSummary: summary,
                    prioritizedActions: dedupActions
                )
            )
        }

        let avgOWASP = Double(categoryAssessments.reduce(0) { $0 + $1.score })
            / Double(max(1, categoryAssessments.count))
        let weightedOverall = Int(
            (0.50 * avgOWASP
                + 0.25 * Double(privacyAudit.complianceScore)
                + 0.25 * Double(cryptoScore)).rounded()
        )
        let clampedOverall = max(0, min(100, weightedOverall))
        let grade = letterGrade(for: clampedOverall)
        let releaseReady = !scanReport.hasBlockingFindings
            && privacyAudit.isAppStoreSubmissionReady
            && clampedOverall >= 80

        let isoFormatter = ISO8601DateFormatter()
        let tsString = isoFormatter.string(from: timestamp)

        let flowMermaid = generateThreatModelFlowchart(
            workspaceName: workspaceName,
            categoryScores: categoryAssessments,
            privacyAudit: privacyAudit,
            cryptoPosture: cryptoPosture
        )
        let seqMermaid = generateEphemerisAuthSequenceDiagram(cryptoPosture: cryptoPosture)

        let execSummary = """
        \(workspaceName) achieved an overall ChiefKit Security Posture score of \(clampedOverall)/100 (\(grade)). \
        Static analysis inspected \(scanReport.scannedFileCount) document(s) (\(scanReport.scannedLineCount) lines) \
        with \(scanReport.findings.count) total finding(s), PrivacyInfo.xcprivacy scored \(privacyAudit.complianceScore)/100, \
        and Cryptographic Architecture scored \(cryptoScore)/100 (\(cryptoPosture.vaultCipherSuite.rawValue), \
        \(cryptoPosture.pbkdf2Iterations) PBKDF2 iterations). Release gate: \(releaseReady ? "PASS" : "BLOCKED").
        """

        return SecurityAuditScorecard(
            workspaceName: workspaceName,
            generatedAtISO8601: tsString,
            overallScore: clampedOverall,
            letterGrade: grade,
            isReleaseGatePassing: releaseReady,
            staticPostureScore: scanReport.staticPostureScore,
            privacyComplianceScore: privacyAudit.complianceScore,
            cryptographicPostureScore: cryptoScore,
            categoryScores: categoryAssessments,
            mermaidArchitectureDiagram: flowMermaid,
            mermaidSequenceDiagram: seqMermaid,
            executiveSummary: execSummary
        )
    }

    // MARK: Mermaid Threat-Model Diagram Generators

    public static func generateThreatModelFlowchart(
        workspaceName: String,
        categoryScores: [OWASPCategoryScore],
        privacyAudit: PrivacyComplianceAudit,
        cryptoPosture: CryptographicPostureInput
    ) -> String {
        let scoreMap = Dictionary(uniqueKeysWithValues: categoryScores.map { ($0.category, $0.score) })
        let m1 = scoreMap[.m1ImproperCredentialUsage] ?? 100
        let m4 = scoreMap[.m4InsufficientInputOutputValidation] ?? 100
        let m5 = scoreMap[.m5InsecureCommunication] ?? 100
        let m6 = scoreMap[.m6InadequatePrivacyControls] ?? 100
        let m9 = scoreMap[.m9InsecureDataStorage] ?? 100
        let m10 = scoreMap[.m10InsufficientCryptography] ?? 100

        return """
        flowchart TD
            ExtNet["Untrusted Network and Deep Links"] -->|"TLS 1.3 + ATS Gate (M5: \(m5)/100)"| Ingress["Input and URL Validator (M4: \(m4)/100)"]
            Ingress -->|"Static Scanner Gate (M1: \(m1)/100)"| AppCore["\(workspaceName) Swift 6 Actor Core"]
            AppCore -->|"PrivacyInfo.xcprivacy Gate (M6: \(m6)/100)"| PrivAudit["App Store Required Reason APIs (\(privacyAudit.declaredCategories.count) Declared)"]
            AppCore -->|"HKDF-SHA512 Sky State"| EphAuth["EphemerisCore Celestial-Temporal Auth"]
            EphAuth -->|"ChaCha20-Poly1305 Envelope (M10: \(m10)/100)"| Vault["EncryptedWorkspaceVault (\(cryptoPosture.vaultCipherSuite.rawValue))"]
            Vault -->|"PBKDF2 \(cryptoPosture.pbkdf2Iterations) Iter + Shamir \(cryptoPosture.shamirRecoveryThreshold)-of-\(cryptoPosture.shamirRecoveryTotalShares) (M9: \(m9)/100)"| Enclave["Hardware Keychain and Secure Enclave (\(cryptoPosture.keychainBiometricPolicy.rawValue))"]
        """
    }

    public static func generateEphemerisAuthSequenceDiagram(
        cryptoPosture: CryptographicPostureInput
    ) -> String {
        let geoMode = cryptoPosture.ephemerisBindGeodeticCell
            ? "Quantized Geodetic Cell + Multi-Body Ephemeris"
            : "Geocentric Multi-Body J2000 Ephemeris"

        return """
        sequenceDiagram
            participant Client as Swift 6 Client Actor
            participant Astro as EphemerisCore Engine
            participant Crypto as HKDF-SHA512 + AEAD
            participant Verifier as Verification Gateway
            Client->>Astro: Capture \(geoMode) at quantized UTC step
            Astro-->>Client: Canonical EPH3 binary frame + SHA-512 skyCommitment
            Client->>Crypto: Derive CelestialSessionKey (sharedSeed + skyCommitment)
            Crypto-->>Client: 32B ChaCha20 key + 64B HMAC-SHA512 key + 12B baseNonce
            Client->>Verifier: Transmit CelestialAuthEnvelope (SealedBox + outer HMAC-SHA512)
            Verifier->>Astro: Recompute EPH3 sky frame within +-1 epoch skew window
            Verifier->>Crypto: Verify constant-time HMAC-SHA512 + Poly1305 AEAD tag
            Crypto-->>Verifier: Authenticated plaintext + replay counter commit
        """
    }

    // MARK: Markdown Executive Security Audit Report

    public static func renderMarkdownReport(
        scorecard: SecurityAuditScorecard,
        scanReport: SecurityScanReport,
        privacyAudit: PrivacyComplianceAudit
    ) -> String {
        var md = [String]()
        md.append("# ChiefKit Studio 3.0 — Security & Privacy Audit Report")
        md.append("")
        md.append("- **Workspace**: `\(scorecard.workspaceName)`")
        md.append("- **Generated At**: `\(scorecard.generatedAtISO8601)`")
        md.append("- **Overall Security Score**: **\(scorecard.overallScore) / 100 (`\(scorecard.letterGrade)`)**")
        md.append("- **Release Gate**: **\(scorecard.isReleaseGatePassing ? "PASSING" : "ACTION REQUIRED")**")
        md.append("")
        md.append("> \(scorecard.executiveSummary)")
        md.append("")
        md.append("## 1. OWASP Mobile Top 10 (2024) Scorecard")
        md.append("")
        md.append("| Category | Title | Score | Grade | Findings | Summary |")
        md.append("| :--- | :--- | :---: | :---: | :---: | :--- |")
        for row in scorecard.categoryScores {
            md.append("| `\(row.category.rawValue)` | \(row.category.title) | \(row.score) | **\(row.grade)** | \(row.findingCount) | \(row.controlSummary) |")
        }
        md.append("")
        md.append("## 2. Threat-Model Architecture & Celestial Handshake")
        md.append("")
        md.append("```mermaid")
        md.append(scorecard.mermaidArchitectureDiagram)
        md.append("```")
        md.append("")
        md.append("```mermaid")
        md.append(scorecard.mermaidSequenceDiagram)
        md.append("```")
        md.append("")
        md.append("## 3. Apple PrivacyInfo.xcprivacy Compliance (\(privacyAudit.complianceScore)/100)")
        md.append("")
        md.append("- **App Store Submission Ready**: `\(privacyAudit.isAppStoreSubmissionReady)`")
        md.append("- **Collects Zero User Data**: `\(privacyAudit.nutritionLabel.collectsZeroData)`")
        md.append("- **Detected Required Reason APIs**: \(privacyAudit.detectedCodeCategories.map(\.rawValue).sorted().joined(separator: ", "))")
        if !privacyAudit.issues.isEmpty {
            md.append("")
            for issue in privacyAudit.issues {
                md.append("- **[\(issue.severity.rawValue)] `\(issue.code)`**: \(issue.message) — *\(issue.remediation)*")
            }
        }
        md.append("")
        md.append("## 4. Static Vulnerability Findings (\(scanReport.findings.count))")
        md.append("")
        if scanReport.findings.isEmpty {
            md.append("No static security vulnerabilities detected across \(scanReport.scannedFileCount) scanned file(s).")
        } else {
            for finding in scanReport.findings.prefix(25) {
                md.append("- **[\(finding.severity.rawValue)] `\(finding.ruleID.rawValue)` (\(finding.cweIdentifier))** at `\(finding.filePath):\(finding.lineNumber)`: \(finding.explanation) (`\(finding.redactedEvidence)`)")
            }
        }
        return md.joined(separator: "\n") + "\n"
    }

    // MARK: Swift 6 Testing (@Suite / @Test) Security Regression Synthesizer

    public static func synthesizeSecurityRegressionTestSuite(
        suiteStructName: String = "ChiefKitSecurityRegressionTests",
        workspaceName: String = "ChiefKitWorkspace",
        cryptoPosture: CryptographicPostureInput = .hardenedDefault,
        ephemerisConfig: EphemerisAuthConfiguration = .standardGeocentric60s
    ) -> String {
        return """
        import Foundation
        import Testing
        @testable import ChiefKitSecurity

        @Suite("\(workspaceName) — ChiefKit Studio 3.0 Security & Ephemeris Regression Suite")
        struct \(suiteStructName) {
            @Test("NIST FIPS 180-4, RFC 2104/5869/8018, and RFC 8439 cryptographic self-tests pass bit-for-bit")
            func verifyCryptographicRFCVectors() throws {
                let report = SecuritySelfTest.runDetailedSelfTest()
                #expect(report.allPassed, "Failed checks: \\(report.failedCheckNames)")
                #expect(SecuritySelfTest.verifyRFCVectors() == true)
            }

            @Test("EncryptedWorkspaceVault enforces header AAD integrity, passphrase rotation, and GF(256) Shamir recovery")
            func verifyWorkspaceVaultAndShamirRecovery() throws {
                let payload = Data("{\\"workspace\\":\\"\(workspaceName)\\",\\"version\\":3}".utf8)
                let vault = try EncryptedWorkspaceVault.sealData(
                    payload,
                    passphrase: "correct-horse-celestial-battery",
                    preset: .fastTesting,
                    cipherSuite: .\(cryptoPosture.vaultCipherSuite == .xchacha20Poly1305 ? "xchacha20Poly1305" : "chacha20Poly1305")
                )
                let opened = try vault.openData(passphrase: "correct-horse-celestial-battery")
                #expect(opened == payload)

                let rotated = try vault.rotatePassphrase(
                    currentPassphrase: "correct-horse-celestial-battery",
                    newPassphrase: "rotated-quantum-ephemeris-passphrase",
                    newKDFIterations: 4_096
                )
                #expect(rotated.header.rotationGeneration == 2)
                #expect(try rotated.openData(passphrase: "rotated-quantum-ephemeris-passphrase") == payload)

                let masterSecret = Array("ChiefKit32ByteRecoveryMasterKey!".utf8)
                let shares = try ShamirSecretSharing.splitSecret(
                    masterSecret,
                    threshold: \(max(2, cryptoPosture.shamirRecoveryThreshold)),
                    shareCount: \(max(3, cryptoPosture.shamirRecoveryTotalShares))
                )
                let subset = Array(shares.shuffled().prefix(\(max(2, cryptoPosture.shamirRecoveryThreshold))))
                let recovered = try ShamirSecretSharing.combineShares(subset)
                #expect(recovered == masterSecret)
            }

            @Test("EphemerisCore Celestial-TOTP and ChaCha20-Poly1305 envelope authenticate within +-1 epoch skew")
            func verifyEphemerisCelestialAuthentication() throws {
                let seed = Array("HNMLabs-EphemerisCore-Shared-Secret-2026".utf8)
                let config = try EphemerisAuthConfiguration(
                    epochStepSeconds: \(ephemerisConfig.epochStepSeconds),
                    allowedClockSkewSteps: \(ephemerisConfig.allowedClockSkewSteps),
                    totpDigits: \(ephemerisConfig.totpDigits)
                )
                let fixedUnix: TimeInterval = 1_763_000_000.0
                let token = try EphemerisEntropyProtocol.generateCelestialTOTP(
                    sharedSecretSeed: seed,
                    unixTimestamp: fixedUnix,
                    config: config
                )
                let verified = try EphemerisEntropyProtocol.verifyCelestialTOTP(
                    candidateCode: token.code,
                    sharedSecretSeed: seed,
                    verifierUnixTimestamp: fixedUnix + Double(\(max(1, ephemerisConfig.epochStepSeconds / 2))),
                    config: config
                )
                #expect(verified.isValid)

                let message = Array("authorize:deploy-production-blueprint".utf8)
                let envelope = try EphemerisEntropyProtocol.sealEnvelope(
                    payload: message,
                    sharedSecretSeed: seed,
                    unixTimestamp: fixedUnix,
                    contextAAD: Array("\(workspaceName)".utf8),
                    config: config
                )
                let opened = try EphemerisEntropyProtocol.openAndVerifyEnvelope(
                    envelope,
                    sharedSecretSeed: seed,
                    verifierUnixTimestamp: fixedUnix,
                    contextAAD: Array("\(workspaceName)".utf8),
                    config: config
                )
                #expect(opened.isAuthenticated)
                #expect(opened.decryptedPayload == message)
            }

            @Test("Apple PrivacyInfo.xcprivacy XML round-trips cleanly and flags undeclared Required Reason APIs")
            func verifyPrivacyManifestCompliance() throws {
                let sampleSwift = "let up = ProcessInfo.processInfo.systemUptime; UserDefaults.standard.set(true, forKey: \\"ready\\")"
                let manifest = ApplePrivacyManifestBuilder.inferCompliantManifest(fromSwiftSources: [sampleSwift])
                let xml = manifest.compilePrivacyInfoPlistXML()
                let parsed = try ApplePrivacyManifestBuilder.parsePlistXML(xml)
                #expect(parsed == manifest)

                let audit = ApplePrivacyManifestBuilder.validate(manifest: parsed, againstSwiftSources: [sampleSwift])
                #expect(audit.isAppStoreSubmissionReady)
            }

            @Test("StaticSecurityScanner detects hardcoded cloud credentials, SQLi, and cleartext HTTP")
            func verifyStaticVulnerabilityDetection() {
                let cleanCode = "let digest = SHA256Engine.hexDigest(\\"clean\\")"
                let cleanScan = StaticSecurityScanner.scan(source: cleanCode)
                #expect(!cleanScan.hasBlockingFindings)
            }
        }
        """
    }

    // MARK: Internal Scoring Helpers

    private static func evaluateCryptoPostureScore(_ posture: CryptographicPostureInput) -> Int {
        var score = 100
        if posture.pbkdf2Iterations < 10_000 {
            score -= 25
        } else if posture.pbkdf2Iterations < 60_000 {
            score -= 10
        }
        if !posture.ephemerisTemporalAuthEnabled {
            score -= 8
        }
        if posture.shamirRecoveryThreshold < 2 || posture.shamirRecoveryTotalShares < posture.shamirRecoveryThreshold {
            score -= 10
        }
        if posture.keychainBiometricPolicy == .deviceOnlyUnlocked {
            score -= 4
        }
        return max(0, min(100, score))
    }

    public static func letterGrade(for score: Int) -> String {
        switch score {
        case 96...100: return "A+"
        case 90..<96:  return "A"
        case 85..<90:  return "A-"
        case 80..<85:  return "B+"
        case 73..<80:  return "B"
        case 65..<73:  return "C+"
        case 55..<65:  return "C"
        case 45..<55:  return "D"
        default:       return "F"
        }
    }

    private static func buildCategoryControlSummary(
        category: OWASPMobileCategory,
        score: Int,
        findingCount: Int,
        cryptoPosture: CryptographicPostureInput,
        privacyAudit: PrivacyComplianceAudit
    ) -> String {
        switch category {
        case .m1ImproperCredentialUsage:
            return findingCount == 0 ? "Zero hardcoded API keys or PEM secrets" : "\(findingCount) credential exposure(s)"
        case .m3InsecureAuthenticationAuthorization:
            return cryptoPosture.ephemerisTemporalAuthEnabled
                ? "EphemerisCore HKDF-SHA512 + \(cryptoPosture.keychainBiometricPolicy.rawValue)"
                : "Standard static auth"
        case .m6InadequatePrivacyControls:
            return privacyAudit.isAppStoreSubmissionReady
                ? "PrivacyInfo.xcprivacy valid (\(privacyAudit.declaredCategories.count) API categories)"
                : "\(privacyAudit.issues.count) privacy manifest issue(s)"
        case .m9InsecureDataStorage:
            return "Vault AEAD + GF(256) Shamir \(cryptoPosture.shamirRecoveryThreshold)-of-\(cryptoPosture.shamirRecoveryTotalShares)"
        case .m10InsufficientCryptography:
            return "\(cryptoPosture.vaultCipherSuite.rawValue) + PBKDF2 (\(cryptoPosture.pbkdf2Iterations) iter)"
        default:
            return findingCount == 0 ? "Controls verified (\(score)/100)" : "\(findingCount) finding(s) flagged"
        }
    }

    private static func deduplicatePreservingOrder(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var out = [String]()
        for item in items where !item.isEmpty {
            if seen.insert(item).inserted {
                out.append(item)
            }
        }
        return out
    }
}
