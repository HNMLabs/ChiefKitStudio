# Security & Cryptographic Architecture

ChiefKit Studio 3.0 includes the cross-platform **`ChiefKitSecurity`** module:

- **Pure-Swift Validated Cryptography:** FIPS 180-4 SHA-224/256/384/512 + Merkle trees, RFC 2104 HMAC, RFC 5869 HKDF, RFC 8018 PBKDF2, RFC 8439 ChaCha20-Poly1305 & XChaCha20-Poly1305 AEAD, and `GF(2^8)` Shamir secret sharing.
- **`EphemerisCore` Celestial-Temporal Authentication:** 9-body J2000 planetary ephemerides, topocentric coordinate transforms, and Celestial-TOTP signed envelopes.
- **Static Vulnerability & Privacy Auditing:** 30 OWASP Mobile Top 10 (M1–M10) static scanner rules and Apple `PrivacyInfo.xcprivacy` compiler.

Run a static security audit from the CLI:

```bash
swift run ChiefKitStudio --security-audit Sources/ChiefKitStudio
```

See [SECURITY.md](../../SECURITY.md) for vulnerability reporting guidelines.
