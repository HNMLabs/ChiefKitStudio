# Security Policy — ChiefKit Studio 3.0

## Supported Versions

| Version | Supported | Notes |
| --- | --- | --- |
| **3.0.x (Master Suite)** | Yes | Active Swift 6 strict-concurrency & `ChiefKitSecurity` baseline |
| **2.5.x** | Security fixes | Upgrade to 3.0 recommended |
| **< 2.5** | No | Legacy MVP |

## Built-In Security Architecture (`ChiefKitSecurity`)

ChiefKit Studio 3.0 runs **100% offline / on-device** with zero cloud AI calls and ships with `ChiefKitSecurity`:

- **Pure-Swift Validated Primitives:** FIPS 180-4 SHA-224/256/384/512, RFC 2104 HMAC, RFC 5869 HKDF, RFC 8018 PBKDF2, RFC 8439 ChaCha20-Poly1305 & XChaCha20-Poly1305 AEAD, and `GF(2^8)` Shamir secret sharing verified against official NIST/RFC test vectors.
- **Encrypted `.chiefkit.vault` Containers:** Authenticated encryption with PBKDF2 key stretching and constant-time MAC verification.
- **Static Vulnerability & Privacy Auditing:** 30 OWASP Mobile Top 10 (2024 M1–M10) static rules (`swift run ChiefKitStudio --security-audit <path>`) and Apple `PrivacyInfo.xcprivacy` validation.

## Reporting a Vulnerability

Please do **not** open public issues for suspected security vulnerabilities. Report vulnerabilities privately via GitHub:

- Maintainer: [@ChiefVenzox](https://github.com/ChiefVenzox)
- Organization Repository: [HNMLabs/ChiefKitStudio](https://github.com/HNMLabs/ChiefKitStudio)

Include a description of the issue, reproduction steps, affected OS/Swift version, and expected impact.
