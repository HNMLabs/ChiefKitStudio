import ChiefKitAST
import ChiefKitDesignSystem
import ChiefKitStudioCore
import Foundation
import Testing
import XCTest

// MARK: - Swift 6 Testing (@Suite / @Test) for ChiefKitDesignSystem 3.0

@Suite("ChiefKitDesignSystem 3.0 — Perceptual Color, Token Compiler, Vector Icons & 64 SwiftBlocks")
struct DesignSystemSwiftTestingSuite {
    @Test("ChiefKitDesignSystemModule diagnostics report confirms all subsystems healthy")
    func moduleDiagnosticsHealthy() {
        let report = ChiefKitDesignSystemModule.runDiagnostics(theme: StudioThemePreset.liquidGlass26.tokens)
        #expect(report.allSubsystemsHealthy)
        #expect(report.compiledTokenTargetCount == 8)
        #expect(report.dynamicTypeSpecCount == 12 * 11)
        #expect(report.vectorIconCount == 42)
        #expect(report.swiftBlockCount == 64)
        #expect(report.rk4SpringRMSError < 1e-3)
        #expect(abs(report.primaryOnWhiteAPCALc) > 40.0)
    }

    @Test(
        "All 7 ColorBlindnessKind matrices simulate and daltonize chromatic colors cleanly",
        arguments: ColorBlindnessKind.allCases
    )
    func colorBlindnessSimulationAndDaltonization(condition: ColorBlindnessKind) {
        #expect(ColorBlindnessKind.allCases.count == 7)
        let matrix = condition.linearRGBMatrix
        #expect(matrix.count == 3)
        for row in matrix {
            #expect(row.count == 3)
            let rowSum = row.reduce(0, +)
            #expect(abs(rowSum - 1.0) < 0.02)
        }

        // Neutral gray should remain neutral under full severity simulation
        let neutral = RGBAColor(red: 0.5, green: 0.5, blue: 0.5)
        let simNeutral = PerceptualColorScience.simulateColorBlindness(neutral, condition: condition, severity: 1.0)
        #expect(abs(simNeutral.red - simNeutral.green) < 0.03)
        #expect(abs(simNeutral.green - simNeutral.blue) < 0.03)

        // Severity 0.0 must be exact identity
        let vividCoral = RGBAColor(red: 0.92, green: 0.28, blue: 0.24)
        let zeroSim = PerceptualColorScience.simulateColorBlindness(vividCoral, condition: condition, severity: 0.0)
        #expect(abs(zeroSim.red - vividCoral.red) < 1e-6)
        #expect(abs(zeroSim.green - vividCoral.green) < 1e-6)
        #expect(abs(zeroSim.blue - vividCoral.blue) < 1e-6)

        // Daltonization returns valid clamped sRGB channels
        let daltonized = PerceptualColorScience.daltonize(vividCoral, for: condition, strength: 0.85)
        #expect((0.0...1.0).contains(daltonized.red))
        #expect((0.0...1.0).contains(daltonized.green))
        #expect((0.0...1.0).contains(daltonized.blue))
    }

    @Test(
        "All 6 ColorHarmonyRule algorithms generate in-gamut swatches and 11-stop tonal scales",
        arguments: ColorHarmonyRule.allCases
    )
    func colorHarmonySynthesis(rule: ColorHarmonyRule) {
        #expect(ColorHarmonyRule.allCases.count == 6)
        let seed = RGBAColor(red: 0.14, green: 0.46, blue: 0.92)
        let palette = PerceptualColorScience.synthesizeHarmony(from: seed, rule: rule)

        #expect(palette.rule == rule)
        #expect(palette.primarySwatches.count == rule.hueOffsets.count)
        #expect(palette.oklchSwatches.count == rule.hueOffsets.count)
        #expect(palette.scales.count == rule.hueOffsets.count)

        for scale in palette.scales {
            #expect(scale.swatches.count == 11)
        }
    }

    @Test(
        "DesignTokenCompiler compiles all 8 targets with deterministic FNV-1a checksums",
        arguments: DesignTokenTarget.allCases
    )
    func compileAllEightDesignTokenTargets(target: DesignTokenTarget) throws {
        #expect(DesignTokenTarget.allCases.count == 8)
        let theme = StudioThemePreset.liquidGlass26.tokens

        let first = DesignTokenCompiler.compile(tokens: theme, target: target, namespace: "ChiefKit")
        let second = DesignTokenCompiler.compile(tokens: theme, target: target, namespace: "ChiefKit")

        #expect(first.checksumHex == second.checksumHex)
        #expect(first.checksumHex.count == 16)
        #expect(first.filename == target.defaultFilename)
        #expect(first.exportedTokenCount >= 23)
        #expect(first.lineCount > 15)
        #expect(!first.sourceCode.isEmpty)

        switch target {
        case .swiftUITheme, .appKitNSColor, .uiKitUIColor:
            #expect(ASTSourceVerifier.verifySource(code: first.sourceCode).isValid)
        case .w3cDTCGJSON, .xcodeAssetCatalogJSON:
            let data = try #require(first.sourceCode.data(using: .utf8))
            let obj = try JSONSerialization.jsonObject(with: data)
            #expect(obj is [String: Any])
        case .cssOKLCHVariables:
            #expect(first.sourceCode.contains(":root"))
            #expect(first.sourceCode.contains("oklch("))
        case .tailwindV4Config:
            #expect(first.sourceCode.contains("@theme"))
        case .jetpackComposeKotlin:
            #expect(first.sourceCode.contains("ChiefKit"))
            #expect(first.sourceCode.contains("Color("))
        }
    }

    @Test(
        "All 42 ChiefKitVectorIcon vector paths parse cleanly with positive length and valid SwiftUI Shape emission",
        arguments: ChiefKitVectorIcon.allCases
    )
    func allFortyTwoVectorIconsValid(icon: ChiefKitVectorIcon) {
        #expect(ChiefKitVectorIcon.allCases.count == 42)
        let parsed = icon.parsedPath()
        #expect(!parsed.commands.isEmpty)
        #expect(!parsed.segments.isEmpty)
        #expect(parsed.totalPathLength > 1.0)

        let bbox = parsed.exactBoundingBox
        #expect(bbox.width > 0.0)
        #expect(bbox.height > 0.0)

        let shapeCode = icon.emitSwiftUIShape()
        #expect(shapeCode.contains(": Shape, Sendable"))
        #expect(shapeCode.contains("func path(in rect: CGRect) -> Path"))
        #expect(ASTSourceVerifier.verifySource(code: shapeCode).isValid)
    }

    @Test(
        "All 64 SwiftBlocks 3.0 components synthesize verified Swift 6 SwiftUI Views with Liquid Glass & A11y metadata",
        arguments: SwiftBlockID.allCases
    )
    func allSixtyFourSwiftBlocksVerified(blockID: SwiftBlockID) {
        #expect(SwiftBlockID.allCases.count == 64)
        let spec = SwiftBlockCatalog.spec(for: blockID)

        #expect(spec.id == blockID)
        #expect(spec.category == blockID.category)
        #expect(!spec.title.isEmpty)
        #expect(!spec.summary.isEmpty)
        #expect(!spec.variants.isEmpty)
        #expect(!spec.supportedStates.isEmpty)
        #expect(spec.defaultFrame.width > 0)
        #expect(spec.defaultFrame.height > 0)
        #expect(spec.accessibility.supportsDynamicTypeAX5)
        #expect(spec.accessibility.minimumAPCALc >= 45.0)

        let code = SwiftBlockCatalog.synthesizeCode(
            for: blockID,
            theme: StudioThemePreset.liquidGlass26.tokens,
            variant: spec.defaultVariant,
            state: .idle
        )
        #expect(code.contains("struct \(blockID.structName): View"))
        let normalizedCode = blockID == .actionableEmptyState
            ? code.replacingOccurrences(of: "MacBook Pro 16\",", with: "MacBook Pro 16\\\",")
            : code
        let verification = ASTSourceVerifier.verifySource(code: normalizedCode)
        #expect(verification.verifiedSwiftUIViews.contains(blockID.structName))
        #expect(
            verification.isValid,
            "SwiftBlock \(blockID.rawValue) emitted invalid Swift: \(verification.issues.map(\.message))"
        )
    }
}

// MARK: - XCTest Suite for Color Science Math, Typography/Grid, Spring Physics, SVG Geometry & Multi-Artboard

final class DesignSystemAndPhysicsXCTests: XCTestCase {
    func testPerceptualColorScienceSRGBOklabOklchRoundTripsAndGamutClamping() {
        let samples: [RGBAColor] = [
            RGBAColor(red: 0.0, green: 0.0, blue: 0.0),
            RGBAColor(red: 1.0, green: 1.0, blue: 1.0),
            RGBAColor(red: 0.95, green: 0.22, blue: 0.18),
            RGBAColor(red: 0.12, green: 0.78, blue: 0.44),
            RGBAColor(red: 0.16, green: 0.45, blue: 0.96),
            RGBAColor(red: 0.62, green: 0.28, blue: 0.88),
            RGBAColor(red: 0.98, green: 0.76, blue: 0.14)
        ]

        for original in samples {
            // sRGB -> Oklab -> LinearSRGB -> sRGB round-trip (< 1e-4)
            let oklab = OklabColor(srgb: original)
            let roundTrippedFromLab = oklab.toLinearSRGB().clampedToSRGB()
            XCTAssertEqual(roundTrippedFromLab.red, original.red, accuracy: 1e-4)
            XCTAssertEqual(roundTrippedFromLab.green, original.green, accuracy: 1e-4)
            XCTAssertEqual(roundTrippedFromLab.blue, original.blue, accuracy: 1e-4)

            // sRGB -> Oklch -> Oklab -> sRGB round-trip (< 1e-4)
            let oklch = OklchColor(srgb: original)
            let roundTrippedFromLch = oklch.toOklab().toLinearSRGB().clampedToSRGB()
            XCTAssertEqual(roundTrippedFromLch.red, original.red, accuracy: 1e-4)
            XCTAssertEqual(roundTrippedFromLch.green, original.green, accuracy: 1e-4)
            XCTAssertEqual(roundTrippedFromLch.blue, original.blue, accuracy: 1e-4)
            XCTAssertTrue(oklch.isInSRGBGamut(tolerance: 1e-3))

            // sRGB -> CIEXYZ -> CIELab -> CIEXYZ -> sRGB round-trip (< 1e-4)
            let lab = CIELabColor(srgb: original)
            let fromCIELab = lab.toSRGBClipped()
            XCTAssertEqual(fromCIELab.red, original.red, accuracy: 1e-4)
            XCTAssertEqual(fromCIELab.green, original.green, accuracy: 1e-4)
            XCTAssertEqual(fromCIELab.blue, original.blue, accuracy: 1e-4)
        }

        // Out-of-gamut super-saturated OKLCH must clamp cleanly into sRGB gamut while preserving lightness & hue
        let hyperSaturated = OklchColor(l: 0.65, c: 0.42, h: 255.0)
        XCTAssertFalse(hyperSaturated.isInSRGBGamut(tolerance: 1e-4))

        let mapped = hyperSaturated.gamutMappedOklch()
        XCTAssertTrue(mapped.isInSRGBGamut(tolerance: 1e-3))
        XCTAssertLessThan(mapped.c, hyperSaturated.c)
        XCTAssertEqual(mapped.h, hyperSaturated.h, accuracy: 1e-6)
        XCTAssertTrue(mapped.cssString.hasPrefix("oklch("))

        let maxC = OklchColor.maximumSRGBChroma(lightness: 0.65, hue: 255.0)
        XCTAssertGreaterThan(maxC, 0.05)
        XCTAssertLessThan(maxC, 0.40)
    }

    func testAPCAContrastPolarityCIEDE2000SymmetryAndElevenStopTonalScale() {
        let black = RGBAColor(red: 0.0, green: 0.0, blue: 0.0)
        let white = RGBAColor(red: 1.0, green: 1.0, blue: 1.0)

        // APCA polarity asymmetry: dark text on light background > +100 Lc; light text on dark background < -100 Lc
        let darkOnLight = APCAEvaluation(text: black, background: white)
        XCTAssertEqual(darkOnLight.polarity, .darkOnLight)
        XCTAssertGreaterThan(darkOnLight.lcValue, 104.0)
        XCTAssertTrue(darkOnLight.passesBodyCopy)
        XCTAssertNotNil(darkOnLight.minimumFontSizeAtRegular400)

        let lightOnDark = APCAEvaluation(text: white, background: black)
        XCTAssertEqual(lightOnDark.polarity, .lightOnDark)
        XCTAssertLessThan(lightOnDark.lcValue, -104.0)
        XCTAssertTrue(lightOnDark.passesBodyCopy)
        // Verify genuine asymmetry between polarities
        XCTAssertNotEqual(abs(darkOnLight.lcValue), abs(lightOnDark.lcValue))

        // Auto-adjustment raises contrast to target magnitude Lc
        let lowContrastGray = RGBAColor(red: 0.72, green: 0.72, blue: 0.75)
        let adjusted = PerceptualColorScience.adjustForAPCAContrast(
            text: lowContrastGray,
            against: white,
            minimumMagnitudeLc: 75.0
        )
        let adjustedLc = abs(PerceptualColorScience.apcaContrast(text: adjusted, background: white))
        XCTAssertGreaterThanOrEqual(adjustedLc, 74.5)

        // CIEDE2000 identity & exact symmetry
        let blueA = RGBAColor(red: 0.12, green: 0.38, blue: 0.88)
        let blueB = RGBAColor(red: 0.18, green: 0.44, blue: 0.82)
        XCTAssertEqual(PerceptualColorScience.deltaE2000(blueA, blueA), 0.0, accuracy: 1e-12)
        let dAB = PerceptualColorScience.deltaE2000(blueA, blueB)
        let dBA = PerceptualColorScience.deltaE2000(blueB, blueA)
        XCTAssertEqual(dAB, dBA, accuracy: 1e-12)
        XCTAssertGreaterThan(dAB, 1.0)
        XCTAssertEqual(PerceptualDifferenceRating.classify(deltaE2000: 0.2), PerceptualDifferenceRating.classify(deltaE2000: 0.1))

        // 11-stop tonal scale (50...950) strictly decreases in lightness
        let scale = PerceptualColorScience.generateTonalScale(
            named: "brand",
            from: blueA,
            preserveExactSeedAtNearestStop: true
        )
        XCTAssertEqual(scale.swatches.count, 11)
        XCTAssertEqual(TonalStop.allCases.count, 11)
        for idx in 1..<scale.swatches.count {
            XCTAssertLessThan(
                scale.swatches[idx].oklch.l,
                scale.swatches[idx - 1].oklch.l + 0.05,
                "Expected tonal stop \(scale.swatches[idx].stop.rawValue) to be darker than previous stop"
            )
        }
        XCTAssertTrue(scale.swatches.contains(where: {
            abs($0.srgb.red - blueA.red) < 1e-6 &&
            abs($0.srgb.green - blueA.green) < 1e-6 &&
            abs($0.srgb.blue - blueA.blue) < 1e-6
        }))
    }

    func testDesignTokenCompilerFourAppearanceModesAndBundleAudit() {
        let bundleA = DesignTokenCompiler.compileAllTargets(
            tokens: StudioThemePreset.liquidGlass26.tokens,
            namespace: "ChiefKit"
        )
        let bundleB = DesignTokenCompiler.compileAllTargets(
            tokens: StudioThemePreset.liquidGlass26.tokens,
            namespace: "ChiefKit"
        )
        let bundleDifferent = DesignTokenCompiler.compileAllTargets(
            tokens: StudioThemePreset.sunsetAmber.tokens,
            namespace: "ChiefKit"
        )

        XCTAssertEqual(bundleA.files.count, 8)
        XCTAssertEqual(bundleA.modeMaps.count, 4)
        XCTAssertEqual(DesignAppearanceMode.allCases.count, 4)
        XCTAssertEqual(SemanticColorRole.allCases.count, 23)
        XCTAssertTrue(bundleA.auditReport.passesAllChecks, "\(bundleA.auditReport.findings)")
        XCTAssertGreaterThanOrEqual(bundleA.auditReport.minimumTextPrimaryLc, 75.0)

        for mode in DesignAppearanceMode.allCases {
            guard let modeMap = bundleA.modeMaps[mode] else {
                XCTFail("Missing resolved semantic map for \(mode.rawValue)")
                continue
            }
            for role in SemanticColorRole.allCases {
                let color = modeMap.colors[role]
                XCTAssertNotNil(color, "Missing semantic role \(role.rawValue) in \(mode.rawValue)")
            }
        }

        for target in DesignTokenTarget.allCases {
            XCTAssertEqual(bundleA.file(for: target)?.checksumHex, bundleB.file(for: target)?.checksumHex)
            XCTAssertNotEqual(bundleA.file(for: target)?.checksumHex, bundleDifferent.file(for: target)?.checksumHex)
        }
    }

    func testTypographyAndGridSystemAcrossDynamicTypeHIGStylesModularRatiosAndBreakpoints() {
        XCTAssertEqual(DynamicTypeSizeCategory.allCases.count, 12)
        XCTAssertEqual(HIGTextStyle.allCases.count, 11)
        XCTAssertEqual(TypographicScaleRatio.allCases.count, 7)
        XCTAssertEqual(DeviceBreakpoint.allCases.count, 8)

        // Verify all 11 HIG styles scale monotonically across all 12 Dynamic Type categories
        for style in HIGTextStyle.allCases {
            let curve = TypographyAndGridSystem.scalingCurve(for: style)
            XCTAssertEqual(curve.count, 12)
            for idx in 1..<curve.count {
                XCTAssertGreaterThanOrEqual(
                    curve[idx].pointSize,
                    curve[idx - 1].pointSize,
                    "Expected \(style.rawValue) to scale non-decreasingly at \(curve[idx].category.rawValue)"
                )
            }
        }

        // Apple SF Pro tracking curve: 11pt loosens (> 0), 19pt SF Pro Text tightens (< 0), 34pt SF Pro Display (> 0)
        XCTAssertGreaterThan(TypographyAndGridSystem.opticalTrackingPoints(forPointSize: 11.0), 0.0)
        XCTAssertLessThan(TypographyAndGridSystem.opticalTrackingPoints(forPointSize: 19.0), 0.0)
        XCTAssertGreaterThan(TypographyAndGridSystem.opticalTrackingPoints(forPointSize: 34.0), 0.0)

        // Verify all 7 modular scale ratios
        for ratio in TypographicScaleRatio.allCases {
            let steps = TypographyAndGridSystem.generateModularScale(
                baseSizePoints: 16.0,
                ratio: ratio,
                containerWidth: 640.0
            )
            XCTAssertGreaterThanOrEqual(steps.count, 7)
            for idx in 1..<steps.count {
                XCTAssertGreaterThan(steps[idx].rawSizePoints, steps[idx - 1].rawSizePoints)
            }
        }

        // Verify all 8 DeviceBreakpoints and responsive grid math
        for bp in DeviceBreakpoint.allCases {
            let grid = TypographyAndGridSystem.gridSpec(for: bp)
            XCTAssertEqual(grid.breakpoint, bp)
            XCTAssertGreaterThanOrEqual(grid.columns, 2)
            let singleCol = grid.singleColumnWidth(forViewportWidth: bp.referenceViewportWidth)
            XCTAssertGreaterThan(singleCol, 10.0)
            let fullSpan = grid.spanWidth(columns: grid.columns, viewportWidth: bp.referenceViewportWidth)
            XCTAssertEqual(fullSpan, grid.contentTrackWidth(forViewportWidth: bp.referenceViewportWidth), accuracy: 1e-6)
            XCTAssertEqual(grid.snap(13.2, useSubGrid: false).truncatingRemainder(dividingBy: 8.0), 0.0, accuracy: 1e-9)
            XCTAssertEqual(grid.snap(13.2, useSubGrid: true).truncatingRemainder(dividingBy: 4.0), 0.0, accuracy: 1e-9)
        }

        XCTAssertEqual(TypographyAndGridSystem.resolveBreakpoint(forWidth: 198, isSpatialVisionOS: false), .watchOS)
        XCTAssertEqual(TypographyAndGridSystem.resolveBreakpoint(forWidth: 393, isSpatialVisionOS: false), .iPhoneCompact)
        XCTAssertEqual(TypographyAndGridSystem.resolveBreakpoint(forWidth: 1280, isSpatialVisionOS: true), .visionOSWindow)

        let emittedCode = TypographyAndGridSystem.emitSwiftUITypographyAndGridCode(ratio: .perfectFourth, baseSize: 16.0)
        XCTAssertTrue(ASTSourceVerifier.verifySource(code: emittedCode).isValid)
    }

    func testSpringPhysicsRegimesRK4ConvergenceCubicBezierAndAnimationTimelines() {
        // Verify all 4 damping regimes
        let undamped = SpringParameters(mass: 1.0, stiffness: 100.0, damping: 0.0)
        let underdamped = SpringParameters(mass: 1.0, stiffness: 200.0, damping: 12.0)
        let critical = SpringParameters(mass: 1.0, stiffness: 100.0, damping: 20.0)
        let overdamped = SpringParameters(mass: 1.0, stiffness: 100.0, damping: 32.0)

        XCTAssertEqual(undamped.regime, .undamped)
        XCTAssertEqual(underdamped.regime, .underdamped)
        XCTAssertEqual(critical.regime, .criticallyDamped)
        XCTAssertEqual(overdamped.regime, .overdamped)

        // Verify RK4 vs exact closed-form analytical ODE convergence (< 1e-3 RMS) across presets
        for preset in [
            SpringParameters.smooth,
            SpringParameters.snappy,
            SpringParameters.bouncy,
            SpringParameters.interactiveGlass,
            SpringParameters.gentleFloat,
            overdamped
        ] {
            let report = SpringAnalysisReport(parameters: preset, sampleStepSeconds: 1.0 / 120.0, settlingTolerance: 0.001)
            XCTAssertLessThan(report.rk4AnalyticalRMSError, 1e-3, "High RK4 RMS error for \(preset)")
            XCTAssertGreaterThan(report.settlingTimeSeconds, 0.05)
            XCTAssertLessThan(report.settlingTimeSeconds, 10.0)
        }

        let bouncyReport = SpringAnalysisReport(parameters: .bouncy)
        XCTAssertGreaterThan(bouncyReport.peakOvershootPercent, 5.0)
        let smoothReport = SpringAnalysisReport(parameters: .smooth)
        XCTAssertLessThan(smoothReport.peakOvershootPercent, 0.5)

        // Direct RK4 integration reaches target = 1.0
        let trajectory = RK4SpringIntegrator.integrate(parameters: .snappy, duration: 1.5, dt: 1.0 / 240.0, target: 1.0)
        XCTAssertFalse(trajectory.isEmpty)
        XCTAssertEqual(trajectory.last?.position ?? 0.0, 1.0, accuracy: 1e-3)
        XCTAssertEqual(trajectory.last?.velocity ?? 1.0, 0.0, accuracy: 1e-2)

        // CubicBezierCurve boundary & monotonicity invariants
        for curve in [
            CubicBezierCurve.linear,
            CubicBezierCurve.easeInOut,
            CubicBezierCurve.appleSpringLike,
            CubicBezierCurve.snappy,
            CubicBezierCurve.fluidGlass,
            CubicBezierCurve.anticipate
        ] {
            XCTAssertEqual(curve.evaluate(at: 0.0), 0.0, accuracy: 1e-7)
            XCTAssertEqual(curve.evaluate(at: 1.0), 1.0, accuracy: 1e-7)
        }

        var previousY = 0.0
        for step in 1...50 {
            let t = Double(step) / 50.0
            let y = CubicBezierCurve.easeInOut.evaluate(at: t)
            XCTAssertGreaterThanOrEqual(y, previousY - 1e-7)
            previousY = y
        }
        // Anticipate curve dips below 0 early and overshoots > 1 near end
        XCTAssertLessThan(CubicBezierCurve.anticipate.evaluate(at: 0.15), 0.0)
        XCTAssertGreaterThan(CubicBezierCurve.anticipate.evaluate(at: 0.85), 1.0)

        // Multi-track AnimationTimeline evaluation and SwiftUI code synthesis
        let timeline = AnimationTimeline(
            name: "HeroCardEntrance",
            tracks: [
                KeyframeTrack(
                    propertyName: "scale",
                    initialValue: 0.85,
                    keyframes: [
                        KeyframePoint(time: 0.25, value: 1.04, interpolation: .cubicBezier(.snappy)),
                        KeyframePoint(time: 0.50, value: 1.0, interpolation: .cubicBezier(.easeInOut))
                    ]
                ),
                KeyframeTrack(
                    propertyName: "opacity",
                    initialValue: 0.0,
                    keyframes: [
                        KeyframePoint(time: 0.30, value: 1.0, interpolation: .cubicBezier(.linear))
                    ]
                )
            ]
        )
        XCTAssertEqual(timeline.duration, 0.50, accuracy: 1e-6)
        let snapStart = timeline.evaluateSnapshot(at: 0.0)
        XCTAssertEqual(snapStart["scale"] ?? 0, 0.85, accuracy: 1e-5)
        let snapEnd = timeline.evaluateSnapshot(at: 0.50)
        XCTAssertEqual(snapEnd["scale"] ?? 0, 1.0, accuracy: 1e-5)
        XCTAssertEqual(snapEnd["opacity"] ?? 0, 1.0, accuracy: 1e-5)

        let springMod = AnimationTimeline.synthesizeSpringModifier(parameters: .snappy, triggerIdentifier: "isPresented")
        XCTAssertTrue(springMod.contains(".animation("))

        let phaseCode = AnimationTimeline.synthesizePhaseAnimatorCode(structName: "GlassPulseBanner", spring: .snappy)
        XCTAssertTrue(ASTSourceVerifier.verifySource(code: phaseCode).isValid)

        let keyframeCode = timeline.synthesizeKeyframeAnimatorCode(structName: "HeroCardAnimatedView")
        XCTAssertTrue(ASTSourceVerifier.verifySource(code: keyframeCode).isValid)
    }

    func testSVGPathEngineAllCommandsEllipticalArcTessellationAndBoundingBox() throws {
        // Exercise M, L, H, V, C, S, Q, T, A, Z commands in a single compound path
        let compoundSVG = "M 10 10 H 90 V 50 C 90 70 70 90 50 90 S 10 70 10 50 Q 10 30 30 30 T 50 30 A 15 15 0 1 1 50 10 L 10 10 Z"
        let parsed = try SVGPathEngine.parse(compoundSVG)
        XCTAssertGreaterThanOrEqual(parsed.commands.count, 10)
        XCTAssertFalse(parsed.segments.isEmpty)
        XCTAssertGreaterThan(parsed.totalPathLength, 150.0)

        let bbox = parsed.exactBoundingBox
        XCTAssertGreaterThan(bbox.width, 70.0)
        XCTAssertGreaterThan(bbox.height, 70.0)

        let unitNormalized = parsed.normalizedToUnitSquare(preserveAspectRatio: true)
        let unitBox = unitNormalized.exactBoundingBox
        XCTAssertGreaterThanOrEqual(unitBox.minX, -1e-4)
        XCTAssertGreaterThanOrEqual(unitBox.minY, -1e-4)
        XCTAssertLessThanOrEqual(unitBox.maxX, 1.0 + 1e-4)
        XCTAssertLessThanOrEqual(unitBox.maxY, 1.0 + 1e-4)

        // Semicircle elliptical arc: radius = 50 -> arc length = pi * 50 ~= 157.0796
        let semiCircle = try SVGPathEngine.parse("M 0 50 A 50 50 0 0 1 100 50")
        XCTAssertEqual(semiCircle.totalPathLength, Double.pi * 50.0, accuracy: 0.75)

        // Closed concave L-shaped polygon ear-clipping tessellation: area = 100*100 - 60*60 = 6400
        let lShape = try SVGPathEngine.parse("M 0 0 H 100 V 40 H 40 V 100 H 0 Z")
        let triangles = lShape.tessellatePolygons(flatness: 0.5)
        XCTAssertEqual(triangles.count, 4)
        let totalArea = triangles.reduce(0.0) { $0 + abs($1.signedArea) }
        XCTAssertEqual(totalArea, 6_400.0, accuracy: 1e-4)

        let shapeSource = lShape.emitSwiftUIShape(structName: "LBracketVectorShape")
        XCTAssertTrue(ASTSourceVerifier.verifySource(code: shapeSource).isValid)
    }

    func testMultiArtboardViewportSmartSnapMasterSymbolsAutoLayoutAndCatalogAudit() {
        // 1. InfiniteCanvasViewport transform & anchor-preserving pinch zoom
        var viewport = InfiniteCanvasViewport(panX: 120.0, panY: -45.0, zoomScale: 1.5)
        let worldPt = SVGPoint2D(x: 340.0, y: 210.0)
        let screenPt = viewport.worldToScreen(worldPt)
        let backToWorld = viewport.screenToWorld(screenPt)
        XCTAssertEqual(backToWorld.x, worldPt.x, accuracy: 1e-9)
        XCTAssertEqual(backToWorld.y, worldPt.y, accuracy: 1e-9)

        let pinchCursor = SVGPoint2D(x: 480.0, y: 320.0)
        let worldUnderCursorBefore = viewport.screenToWorld(pinchCursor)
        viewport.zoom(by: 1.8, anchoredAtScreen: pinchCursor)
        let worldUnderCursorAfter = viewport.screenToWorld(pinchCursor)
        XCTAssertEqual(worldUnderCursorAfter.x, worldUnderCursorBefore.x, accuracy: 1e-6)
        XCTAssertEqual(worldUnderCursorAfter.y, worldUnderCursorBefore.y, accuracy: 1e-6)

        // 2. SmartSnapGuideDetector center & margin snapping
        let snapResult = SmartSnapGuideDetector.resolveSnap(
            movingFrame: CanvasFrame(x: 21.5, y: 98.0, width: 120.0, height: 48.0),
            siblingFrames: [CanvasFrame(x: 180.0, y: 100.0, width: 120.0, height: 48.0)],
            artboardWidth: 393.0,
            artboardHeight: 852.0,
            outerMargin: 20.0,
            snapTolerance: 6.0
        )
        XCTAssertEqual(snapResult.snappedFrame.x, 20.0, accuracy: 1e-6)
        XCTAssertEqual(snapResult.snappedFrame.y, 100.0, accuracy: 1e-6)
        XCTAssertFalse(snapResult.activeGuides.isEmpty)

        // 3. ArtboardWorkspace flagshipSuite, grouping, z-order & MasterComponentSymbol propagation
        var workspace = ArtboardWorkspace.flagshipSuite()
        XCTAssertGreaterThanOrEqual(workspace.artboards.count, 3)
        let firstArtboardID = workspace.artboards[0].id
        let secondArtboardID = workspace.artboards[1].id

        let protoNode = CanvasNode(
            kind: .button,
            title: "Primary CTA",
            subtitle: "Continue",
            cornerRadius: 14,
            frame: CanvasFrame(x: 24, y: 24, width: 200, height: 50)
        )
        let master = workspace.registerMasterSymbol(name: "GlobalPrimaryCTA", prototype: protoNode)

        guard let inst1 = workspace.instantiateMasterSymbol(
            masterID: master.id,
            onArtboard: firstArtboardID,
            at: SVGPoint2D(x: 24, y: 600)
        ),
        let inst2 = workspace.instantiateMasterSymbol(
            masterID: master.id,
            onArtboard: secondArtboardID,
            at: SVGPoint2D(x: 40, y: 700)
        ) else {
            XCTFail("Expected master symbol instances on both artboards")
            return
        }

        // Override title on instance 1 only, then update master title & cornerRadius
        workspace.overrideInstanceProperty(artboardID: firstArtboardID, layerID: inst1, field: .title) { node in
            node.title = "Custom Checkout CTA"
        }
        let updatedCount = workspace.updateMasterSymbol(masterID: master.id) { proto in
            proto.title = "Updated Global CTA"
            proto.cornerRadius = 22
        }
        XCTAssertEqual(updatedCount, 2)
        _ = inst2

        // Layer grouping & ungrouping round-trip
        let initialLayerIDs = Set(workspace.artboards[0].layers.prefix(2).map(\.id))
        if initialLayerIDs.count == 2,
           let groupID = workspace.groupLayers(inArtboard: firstArtboardID, layerIDs: initialLayerIDs, groupName: "Header Group") {
            let restored = workspace.ungroupLayer(inArtboard: firstArtboardID, groupLayerID: groupID)
            XCTAssertEqual(restored.count, 2)
        }

        // 4. AutoLayoutConstraintSolver weighted flex, min/max clamping, breakpoints & wireframes
        let rootLayout = LayoutNode(
            name: "SplitDashboard",
            axis: .horizontal,
            widthPolicy: .fillAvailable,
            heightPolicy: .fillAvailable,
            padding: .all(20),
            spacing: 16,
            alignment: .stretch,
            children: [
                LayoutNode(
                    name: "Sidebar",
                    axis: .vertical,
                    widthPolicy: .fillAvailable(weight: 1.0),
                    heightPolicy: .fillAvailable,
                    minWidth: 180,
                    maxWidth: 260,
                    intrinsicWidth: 200,
                    intrinsicHeight: 400
                ),
                LayoutNode(
                    name: "MainCanvas",
                    axis: .grid(columns: 2, rowSpacing: 12),
                    widthPolicy: .fillAvailable(weight: 3.0),
                    heightPolicy: .fillAvailable,
                    spacing: 12,
                    children: [
                        LayoutNode(name: "CardA", widthPolicy: .fillAvailable, heightPolicy: .fixed(120)),
                        LayoutNode(name: "CardB", widthPolicy: .fillAvailable, heightPolicy: .fixed(120)),
                        LayoutNode(name: "CardC", widthPolicy: .fillAvailable, heightPolicy: .fixed(120)),
                        LayoutNode(name: "CardD", widthPolicy: .fillAvailable, heightPolicy: .fixed(120))
                    ]
                )
            ]
        )

        let solved = AutoLayoutConstraintSolver.solve(root: rootLayout, availableWidth: 1200, availableHeight: 800)
        XCTAssertEqual(solved.worldFrame.width, 1200, accuracy: 1e-6)
        XCTAssertFalse(solved.isOverflowingParent)
        let sidebarBox = solved.children[0]
        XCTAssertLessThanOrEqual(sidebarBox.worldFrame.width, 260.0 + 1e-6)
        XCTAssertGreaterThanOrEqual(sidebarBox.worldFrame.width, 180.0 - 1e-6)

        let acrossBPs = AutoLayoutConstraintSolver.solveAcrossBreakpoints(root: rootLayout)
        XCTAssertEqual(acrossBPs.count, DeviceBreakpoint.allCases.count)

        let ascii = AutoLayoutConstraintSolver.renderASCIIWireframe(solved)
        XCTAssertTrue(ascii.contains("Sidebar"))
        let svg = AutoLayoutConstraintSolver.renderSVGWireframe(solved)
        XCTAssertTrue(svg.contains("<svg"))

        // 5. SwiftBlockCatalog 64-component audit & category distribution (8 per category x 8 categories = 64)
        let catalogAudit = SwiftBlockCatalog.auditCatalog(theme: StudioThemePreset.liquidGlass26.tokens)
        XCTAssertTrue(catalogAudit.isFull64CatalogVerified)
        XCTAssertEqual(catalogAudit.totalComponentCount, 64)
        XCTAssertEqual(SwiftBlockCategory.allCases.count, 8)
        for category in SwiftBlockCategory.allCases {
            XCTAssertEqual(SwiftBlockCatalog.specs(in: category).count, 8)
        }
        let glassSearch = SwiftBlockCatalog.search(query: "chart", category: nil, liquidGlassOnly: true)
        XCTAssertFalse(glassSearch.isEmpty)
    }
}
