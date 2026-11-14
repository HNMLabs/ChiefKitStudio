import ChiefKitStudioCore
import Foundation

// MARK: - Vertical 6: Pro Audio, RAW Darkroom & Broadcast Blueprints

public enum MediaAndCreatorBlueprints: Sendable {
    public static let specs: [EnterpriseBlueprintSpec] = [
        nonlinearPodcastMasteringDAW,
        rawPhotoColorGradingDarkroom,
        liveStreamSceneSwitcher
    ]

    // MARK: 16. Non-Linear Podcast & Mastering DAW

    public static let nonlinearPodcastMasteringDAW = EnterpriseBlueprintSpec(
        id: .nonlinearPodcastMasteringDAW,
        vertical: .mediaCreator,
        title: "Non-Linear Podcast Mastering DAW",
        subtitle: "ITU-R BS.1770-4 -16 LUFS loudness normalization, -1.0 dBTP true-peak limiting, and transcript ripple cuts.",
        sfSymbol: "waveform.badge.mic",
        complexityTier: .enterprise,
        supportedPlatforms: [.macOS, .iPadOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "DialogueTrackStrip",
                tableName: "dialogue_track_strips",
                summary: "Floating-point 32-bit multi-track vocal channel strip with integrated LUFS and true-peak telemetry.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"trk-host\"", isIndexed: true, summary: "Channel strip identifier."),
                    BlueprintEntityField(name: "speakerName", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Host · Shure SM7B\"", summary: "Track label and mic chain."),
                    BlueprintEntityField(name: "integratedLUFS", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "-19.4", summary: "Measured ITU-R BS.1770-4 integrated loudness in LUFS."),
                    BlueprintEntityField(name: "truePeakDBTP", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "-2.8", summary: "4x oversampled inter-sample true peak in dBTP."),
                    BlueprintEntityField(name: "makeupGainDB", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "0.0", summary: "Applied mastering makeup gain in dB."),
                    BlueprintEntityField(name: "isMuted", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "false", summary: "Channel mute state.")
                ],
                computedHelpersSwift: """
                public var postGainLUFS: Double {
                    integratedLUFS + makeupGainDB
                }

                public func requiredGainDelta(toTargetLUFS target: Double = -16.0) -> Double {
                    target - postGainLUFS
                }

                public var isTruePeakSafe: Bool {
                    (truePeakDBTP + min(makeupGainDB, 1.8)) <= -1.0
                }
                """
            ),
            BlueprintDomainEntity(
                name: "TranscriptTimelineSegment",
                tableName: "transcript_timeline_segments",
                summary: "Word-aligned Whisper/Speech local transcript segment supporting non-destructive ripple edits.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"seg-01\"", isIndexed: true, summary: "Timeline segment ID."),
                    BlueprintEntityField(name: "startSeconds", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "14.2", summary: "Segment start timecode in seconds."),
                    BlueprintEntityField(name: "durationSeconds", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "1.4", summary: "Segment duration in seconds."),
                    BlueprintEntityField(name: "spokenText", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"um\"", summary: "Recognized word or phrase."),
                    BlueprintEntityField(name: "isFillerCandidate", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "true", summary: "True for disfluencies/silences."),
                    BlueprintEntityField(name: "isRippleRemoved", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "false", summary: "True when non-destructively bypassed from master bounce.")
                ],
                computedHelpersSwift: """
                public var activePlaybackDuration: Double {
                    isRippleRemoved ? 0.0 : durationSeconds
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "tracks",
                swiftType: "[DialogueTrackStrip]",
                initialValueLiteral: """
                [
                    DialogueTrackStrip(id: "trk-host", speakerName: "Host · Shure SM7B", integratedLUFS: -19.6, truePeakDBTP: -3.2, makeupGainDB: 0.0, isMuted: false),
                    DialogueTrackStrip(id: "trk-guest", speakerName: "Guest · Neumann TLM 103", integratedLUFS: -21.2, truePeakDBTP: -4.1, makeupGainDB: 0.0, isMuted: false)
                ]
                """,
                summary: "Session vocal and stem channel strips."
            ),
            BlueprintStateProperty(
                name: "segments",
                swiftType: "[TranscriptTimelineSegment]",
                initialValueLiteral: """
                [
                    TranscriptTimelineSegment(id: "seg-01", startSeconds: 0.0, durationSeconds: 18.5, spokenText: "Welcome back to Systems Deep Dive episode forty-two.", isFillerCandidate: false, isRippleRemoved: false),
                    TranscriptTimelineSegment(id: "seg-02", startSeconds: 18.5, durationSeconds: 1.6, spokenText: "[um + breath pause]", isFillerCandidate: true, isRippleRemoved: false),
                    TranscriptTimelineSegment(id: "seg-03", startSeconds: 20.1, durationSeconds: 24.0, spokenText: "Today we benchmark lock-free ring buffers in Swift 6.", isFillerCandidate: false, isRippleRemoved: false)
                ]
                """,
                summary: "Timecode-synced transcript edit segments."
            ),
            BlueprintStateProperty(
                name: "targetLoudnessLUFS",
                swiftType: "Double",
                initialValueLiteral: "-16.0",
                summary: "Apple Podcasts / Spotify stereo loudness target (-16.0 LUFS)."
            ),
            BlueprintStateProperty(
                name: "playheadSeconds",
                swiftType: "Double",
                initialValueLiteral: "0.0",
                summary: "Current transport scrubber position in seconds."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "normalizeAllTracksToTargetLUFS",
                matchPattern: ".normalizeAllTracksToTargetLUFS",
                buttonTitle: "Normalize to -16 LUFS",
                sampleDispatchLiteral: ".normalizeAllTracksToTargetLUFS",
                summary: "Computes exact ITU-R BS.1770 makeup gain per vocal stem and engages -1.0 dBTP brickwall ceiling.",
                mutationBodySwift: """
                for idx in state.tracks.indices where !state.tracks[idx].isMuted {
                    let delta = state.targetLoudnessLUFS - state.tracks[idx].integratedLUFS
                    state.tracks[idx].makeupGainDB = delta
                    state.tracks[idx].truePeakDBTP = min(-1.0, state.tracks[idx].truePeakDBTP + delta * 0.4)
                }
                state.lastAuditMessage = "Normalized \\(state.tracks.count) stems to \\(state.targetLoudnessLUFS) LUFS (-1.0 dBTP ceiling)"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "rippleCutFillerSegments",
                matchPattern: ".rippleCutFillerSegments",
                buttonTitle: "Ripple-Cut Filler Pauses",
                sampleDispatchLiteral: ".rippleCutFillerSegments",
                summary: "Non-destructively bypasses all flagged filler/silence segments with 15ms equal-power crossfades.",
                mutationBodySwift: """
                var cutCount = 0
                for idx in state.segments.indices where state.segments[idx].isFillerCandidate && !state.segments[idx].isRippleRemoved {
                    state.segments[idx].isRippleRemoved = true
                    cutCount += 1
                }
                state.lastAuditMessage = "Ripple-cut \\(cutCount) disfluency segment(s)"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "scrubPlayhead(toSeconds: Double)",
                matchPattern: ".scrubPlayhead(let toSeconds)",
                summary: "Moves sample-accurate timeline transport playhead.",
                mutationBodySwift: """
                state.playheadSeconds = min(max(0.0, toSeconds), state.masterTimelineDurationSeconds)
                state.lastAuditMessage = String(format: "Scrubbed transport to %.2fs", state.playheadSeconds)
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchEpisodeSession",
                method: .get,
                path: "/v1/daw/episodes/active/tracks",
                responseType: "[DialogueTrackStrip]",
                offlineStubSwift: "PodcastMasteringDAWState().tracks",
                summary: "Loads multi-track stem metadata and loudness cache."
            ),
            BlueprintAPIEndpoint(
                methodName: "publishMasteredEpisodeRSS",
                method: .post,
                path: "/v1/daw/episodes/publish",
                requestPayloadType: "[DialogueTrackStrip]",
                responseType: "Bool",
                requiresIdempotencyKey: true,
                offlineStubSwift: "true",
                summary: "Uploads AAC-LC / FLAC bounce and chapter markers to podcast CDN."
            ),
            BlueprintAPIEndpoint(
                methodName: "fetchAlignedTranscript",
                method: .get,
                path: "/v1/daw/episodes/transcript",
                responseType: "[TranscriptTimelineSegment]",
                offlineStubSwift: "PodcastMasteringDAWState().segments",
                summary: "Retrieves word-level timecode transcript segments."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "programLUFS", label: "Target Loudness", value: "-16.0 LUFS", delta: "ITU-R BS.1770-4", sfSymbol: "speaker.wave.3.fill"),
            BlueprintKPIMetric(key: "truePeak", label: "True-Peak Ceiling", value: "-1.0 dBTP", delta: "4x Oversampled", sfSymbol: "waveform.path"),
            BlueprintKPIMetric(key: "fillerSaved", label: "Disfluency Candidates", value: "1.6s Ready", delta: "Non-destructive", sfSymbol: "scissors"),
            BlueprintKPIMetric(key: "engineDSP", label: "CoreAudio Buffer", value: "128 frames", delta: "2.67ms @ 48kHz", sfSymbol: "dial.high.fill")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "daw-1", headline: "Host · Shure SM7B (48kHz / 32-bit float)", subheadline: "Raw -19.6 LUFS · True Peak -3.2 dBTP · De-esser active", trailingMetric: "+3.6 dB needed", statusTag: "STEM 1"),
            BlueprintSampleRecord(id: "daw-2", headline: "Guest · Neumann TLM 103 (Double-Ender)", subheadline: "Raw -21.2 LUFS · True Peak -4.1 dBTP · Phase aligned", trailingMetric: "+5.2 dB needed", statusTag: "STEM 2"),
            BlueprintSampleRecord(id: "daw-3", headline: "00:18.5 · [um + breath pause] (1.60s)", subheadline: "Detected locally via Speech framework · 15ms crossfade", trailingMetric: "-1.60s", statusTag: "FILLER")
        ],
        onboardingPages: [
            FlowPage(
                id: "audio-interface",
                title: "Select CoreAudio Device & Sample Rate",
                body: "Lock 48 kHz broadcast clock and low-jitter 128-sample monitoring buffers.",
                style: "hero",
                actions: ["Bind CoreAudio Clock"]
            ),
            FlowPage(
                id: "loudness-spec",
                title: "Choose Broadcast Loudness Standard",
                body: "Normalize stereo dialogue to -16 LUFS (Apple/Spotify) or -23 LUFS (EBU R128).",
                style: "choice",
                actions: ["-16 LUFS Podcast Spec", "-23 LUFS EBU Broadcast"]
            ),
            FlowPage(
                id: "daw-ready",
                title: "Mastering DAW & Transcript Editor Live",
                body: "LUFS metering, true-peak limiting, and ripple transcript editing are armed.",
                style: "completion",
                actions: ["Launch Mastering DAW"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "daw.title", en: "Non-Linear Podcast Mastering DAW", tr: "Doğrusal Olmayan Podcast Mastering Stüdyosu"),
            BlueprintLocalizedKey(key: "daw.normalize", en: "Normalize to -16 LUFS", tr: "-16 LUFS Seviyesine Dengele"),
            BlueprintLocalizedKey(key: "daw.ripple_cut", en: "Ripple-Cut Filler Words", tr: "Dolgu Kelimeleri Kaydırarak Kes"),
            BlueprintLocalizedKey(key: "daw.true_peak", en: "True-Peak Brickwall Limiter", tr: "Gerçek Tepe Sınırlayıcı (dBTP)"),
            BlueprintLocalizedKey(key: "daw.bounce", en: "Export Mastered WAV / Chapters", tr: "Master WAV ve Bölümleri Dışa Aktar"),
            BlueprintLocalizedKey(key: "daw.playhead", en: "Sample-Accurate Playhead", tr: "Örneklem Hassasiyetli Oynatma İmleci")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryDiskSpace",
                reasonCodes: ["E174.1"],
                purposeSummary: "Checks NVMe scratch space before multi-gigabyte 32-bit float WAV bounces."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryFileTimestamp",
                reasonCodes: ["C617.1"],
                purposeSummary: "Validates waveform peak-file cache freshness against source WAV files."
            )
        ],
        customStateComputedSwift: """
        public var masterTimelineDurationSeconds: Double {
            segments.reduce(0.0) { $0 + $1.activePlaybackDuration }
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("ITU-R BS.1770 Loudness & Timeline", systemImage: "slider.horizontal.below.waveform")
                    .font(.headline)
                Spacer()
                Text("\\(String(format: "%.1f", store.state.masterTimelineDurationSeconds))s Master")
                    .font(.caption.monospacedDigit().bold())
            }
            ForEach(store.state.tracks) { trk in
                HStack {
                    Text(trk.speakerName)
                        .font(.caption)
                    Spacer()
                    Text("\\(String(format: "%.1f", trk.postGainLUFS)) LUFS · \\(String(format: "%.1f", trk.truePeakDBTP)) dBTP")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        let fillers = state.segments.filter { $0.isFillerCandidate && !$0.isRippleRemoved }.count
        return String(format: "Mastering Copilot: Master duration %.1fs; %d un-cut filler pause(s) remaining.", state.masterTimelineDurationSeconds, fillers)
        """,
        customUnitTestsSwift: """
        @Test("LUFS normalization hits -16.0 LUFS target and ripple cut shortens master duration")
        func lufsNormalizationAndRippleCut() {
            var state = PodcastMasteringDAWState()
            let beforeDuration = state.masterTimelineDurationSeconds
            _ = PodcastMasteringDAWReducer.reduce(state: &state, action: .normalizeAllTracksToTargetLUFS)
            #expect(abs(state.tracks[0].postGainLUFS - (-16.0)) < 0.001)
            #expect(abs(state.tracks[1].postGainLUFS - (-16.0)) < 0.001)

            _ = PodcastMasteringDAWReducer.reduce(state: &state, action: .rippleCutFillerSegments)
            #expect(state.masterTimelineDurationSeconds < beforeDuration)
        }
        """,
        securityPostureHighlights: [
            "On-device speech alignment ensures unreleased interview audio never uploads to third-party transcription clouds.",
            "Non-destructive edit decision lists preserve original 32-bit float broadcast WAV files untouched.",
            "Checksummed XMP/ID3 chapter metadata embedded deterministically on export."
        ]
    )

    // MARK: 17. RAW Photo & ACEScg Color Grading Darkroom

    public static let rawPhotoColorGradingDarkroom = EnterpriseBlueprintSpec(
        id: .rawPhotoColorGradingDarkroom,
        vertical: .mediaCreator,
        title: "RAW Photo Color Grading Darkroom",
        subtitle: "Non-destructive 16-bit linear RAW exposure EV, Kelvin white balance, 3D LUT film emulation, and XMP culling.",
        sfSymbol: "camera.aperture",
        complexityTier: .professional,
        supportedPlatforms: [.macOS, .iPadOS, .iOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "RAWPhotoDevelopNode",
                tableName: "raw_photo_develop_nodes",
                summary: "Non-destructive parametric sidecar recipe for a 14/16-bit Bayer or ProRAW negative.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"raw-0042\"", isIndexed: true, summary: "Asset catalog UUID."),
                    BlueprintEntityField(name: "fileName", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"DSC08412.ARW\"", isIndexed: true, summary: "Camera RAW filename."),
                    BlueprintEntityField(name: "exposureEV", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "0.35", summary: "Linear exposure compensation in EV stops [-5, +5]."),
                    BlueprintEntityField(name: "whiteBalanceKelvin", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "5450", summary: "Illuminant color temperature in Kelvin [2000, 25000]."),
                    BlueprintEntityField(name: "highlightRecovery", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "0.42", summary: "Highlight roll-off compression [0, 1]."),
                    BlueprintEntityField(name: "appliedLUTName", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"KodakPortra400_ACES.cube\"", summary: "33x33x33 tetrahedral 3D LUT name."),
                    BlueprintEntityField(name: "pickFlag", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "1", isIndexed: true, summary: "1 = Pick, 0 = Unflagged, -1 = Reject.")
                ],
                computedHelpersSwift: """
                public var linearExposureGainMultiplier: Double {
                    Foundation.pow(2.0, exposureEV)
                }

                public var isKeeperPick: Bool {
                    pickFlag > 0
                }
                """
            ),
            BlueprintDomainEntity(
                name: "TetrahedralFilmLUT",
                tableName: "tetrahedral_film_luts",
                summary: "Calibrated 3D .cube look-up table operating in ACEScct / ProPhoto wide-gamut space.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"lut-portra\"", isIndexed: true, summary: "LUT identifier."),
                    BlueprintEntityField(name: "displayTitle", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"Portra 400 Warm Halation\"", summary: "Film stock look title."),
                    BlueprintEntityField(name: "gridDimension", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "33", summary: "Cube lattice size (33 or 65)."),
                    BlueprintEntityField(name: "defaultStrength", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "0.85", summary: "Blend opacity [0, 1].")
                ],
                computedHelpersSwift: """
                public var latticePointCount: Int {
                    gridDimension * gridDimension * gridDimension
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "negatives",
                swiftType: "[RAWPhotoDevelopNode]",
                initialValueLiteral: """
                [
                    RAWPhotoDevelopNode(id: "raw-0042", fileName: "DSC08412.ARW · 61MP", exposureEV: 0.35, whiteBalanceKelvin: 5450, highlightRecovery: 0.42, appliedLUTName: "KodakPortra400_ACES.cube", pickFlag: 1),
                    RAWPhotoDevelopNode(id: "raw-0043", fileName: "DSC08415.ARW · 61MP", exposureEV: -0.20, whiteBalanceKelvin: 4900, highlightRecovery: 0.65, appliedLUTName: "IlfordHP5_Silver.cube", pickFlag: 1),
                    RAWPhotoDevelopNode(id: "raw-0044", fileName: "DSC08419.ARW · Motion Blur", exposureEV: 0.0, whiteBalanceKelvin: 5200, highlightRecovery: 0.0, appliedLUTName: "LinearNeutral.cube", pickFlag: -1)
                ]
                """,
                summary: "Filmstrip RAW negatives with non-destructive develop parameters."
            ),
            BlueprintStateProperty(
                name: "installedLUTs",
                swiftType: "[TetrahedralFilmLUT]",
                initialValueLiteral: """
                [
                    TetrahedralFilmLUT(id: "lut-portra", displayTitle: "Portra 400 Warm", gridDimension: 33, defaultStrength: 0.85),
                    TetrahedralFilmLUT(id: "lut-ektar", displayTitle: "Ektar 100 Scenic", gridDimension: 65, defaultStrength: 0.75)
                ]
                """,
                summary: "Installed 3D .cube LUT library."
            ),
            BlueprintStateProperty(
                name: "showPicksOnly",
                swiftType: "Bool",
                initialValueLiteral: "false",
                summary: "Filters filmstrip to keepers (pickFlag == 1)."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "adjustDevelopExposure(assetID: String, deltaEV: Double, kelvin: Int)",
                matchPattern: ".adjustDevelopExposure(let assetID, let deltaEV, let kelvin)",
                buttonTitle: "+0.50 EV & 5600K",
                sampleDispatchLiteral: ".adjustDevelopExposure(assetID: \"raw-0042\", deltaEV: 0.50, kelvin: 5600)",
                summary: "Updates non-destructive sidecar EV stop offset and illuminant white balance.",
                mutationBodySwift: """
                guard let idx = state.negatives.firstIndex(where: { $0.id == assetID }) else { break }
                state.negatives[idx].exposureEV = min(max(state.negatives[idx].exposureEV + deltaEV, -5.0), 5.0)
                state.negatives[idx].whiteBalanceKelvin = min(max(kelvin, 2000), 25_000)
                state.lastAuditMessage = "Adjusted \\(state.negatives[idx].fileName) to \\(String(format: "%+.2f", state.negatives[idx].exposureEV)) EV, \\(state.negatives[idx].whiteBalanceKelvin)K"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "batchSyncLUTAcrossPicks(lutFilename: String)",
                matchPattern: ".batchSyncLUTAcrossPicks(let lutFilename)",
                buttonTitle: "Sync Ektar LUT to Picks",
                sampleDispatchLiteral: ".batchSyncLUTAcrossPicks(lutFilename: \"Ektar100_65.cube\")",
                summary: "Applies selected 3D LUT recipe across all keeper-flagged negatives in shoot.",
                mutationBodySwift: """
                var count = 0
                for idx in state.negatives.indices where state.negatives[idx].isKeeperPick {
                    state.negatives[idx].appliedLUTName = lutFilename
                    count += 1
                }
                state.lastAuditMessage = "Batch-synced \\(lutFilename) across \\(count) keeper RAWs"
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchShootSidecars",
                method: .get,
                path: "/v1/darkroom/shoots/active/xmp",
                responseType: "[RAWPhotoDevelopNode]",
                offlineStubSwift: "RAWColorDarkroomState().negatives",
                summary: "Fetches lightweight XMP parametric edit recipes across studio devices."
            ),
            BlueprintAPIEndpoint(
                methodName: "pushXMPSidecarBatch",
                method: .put,
                path: "/v1/darkroom/shoots/active/xmp",
                requestPayloadType: "[RAWPhotoDevelopNode]",
                responseType: "Bool",
                requiresIdempotencyKey: true,
                offlineStubSwift: "true",
                summary: "Synchronizes non-destructive XMP sidecars (~4 KB each) without uploading 80 MB RAWs."
            ),
            BlueprintAPIEndpoint(
                methodName: "fetchCloudLUTPresets",
                method: .get,
                path: "/v1/darkroom/luts",
                responseType: "[TetrahedralFilmLUT]",
                offlineStubSwift: "RAWColorDarkroomState().installedLUTs",
                summary: "Lists studio-calibrated 3D .cube LUT packs."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "keeperRatio", label: "Culled Keeper Picks", value: "2 / 3 RAWs", delta: "66.7% select rate", sfSymbol: "flag.fill"),
            BlueprintKPIMetric(key: "colorPipe", label: "Working Gamut", value: "ACEScg 16f", delta: "EDR XDR 1600 nits", sfSymbol: "sparkles.tv.fill"),
            BlueprintKPIMetric(key: "metalTile", label: "Metal Tile Render", value: "4.1 ms", delta: "61MP @ 120Hz", sfSymbol: "gpu"),
            BlueprintKPIMetric(key: "xmpSync", label: "Sidecar Footprint", value: "12.4 KB", delta: "RAWs stay local", sfSymbol: "externaldrive.fill.badge.checkmark")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "raw-1", headline: "DSC08412.ARW · 61MP Full-Frame RAW", subheadline: "+0.35 EV · 5450K · KodakPortra400_ACES.cube", trailingMetric: "Pick ★", statusTag: "GRADED"),
            BlueprintSampleRecord(id: "raw-2", headline: "DSC08415.ARW · 61MP Full-Frame RAW", subheadline: "-0.20 EV · 4900K · IlfordHP5_Silver.cube", trailingMetric: "Pick ★", statusTag: "MONOCHROME"),
            BlueprintSampleRecord(id: "raw-3", headline: "DSC08419.ARW · Shutter Motion Blur", subheadline: "0.00 EV · 5200K · Flagged for reject archive", trailingMetric: "Reject ✕", statusTag: "CULLED")
        ],
        onboardingPages: [
            FlowPage(
                id: "edr-display",
                title: "Enable XDR Reference Color Pipeline",
                body: "Grade 16-bit linear RAW highlights on Liquid Retina XDR displays without tone-map clipping.",
                style: "hero",
                actions: ["Enable ACEScg + EDR"]
            ),
            FlowPage(
                id: "sidecar-mode",
                title: "Configure Non-Destructive XMP Storage",
                body: "Write industry-standard .xmp sidecars next to DNG, ARW, CR3, and NEF originals.",
                style: "choice",
                actions: ["Standard XMP Sidecars", "SQLite + XMP Dual Sync"]
            ),
            FlowPage(
                id: "darkroom-ready",
                title: "RAW Color Darkroom Ready",
                body: "EV exposure math, Kelvin white balance, and batch 3D LUT syncing are active.",
                style: "completion",
                actions: ["Launch RAW Darkroom"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "raw.title", en: "RAW Photo Color Grading Darkroom", tr: "RAW Fotoğraf ve Renk Düzenleme Karanlık Odası"),
            BlueprintLocalizedKey(key: "raw.exposure_ev", en: "Linear Exposure (EV)", tr: "Doğrusal Pozlama Telafisi (EV)"),
            BlueprintLocalizedKey(key: "raw.white_balance", en: "Illuminant Kelvin Temperature", tr: "Beyaz Dengesi Kelvin Sıcaklığı"),
            BlueprintLocalizedKey(key: "raw.batch_lut", en: "Batch Sync 3D LUT to Picks", tr: "Seçilenlere Toplu 3B LUT Uygula"),
            BlueprintLocalizedKey(key: "raw.keeper_pick", en: "Flagged as Keeper", tr: "Seçkin Kare Olarak İşaretlendi"),
            BlueprintLocalizedKey(key: "raw.xmp_export", en: "Write Non-Destructive XMP", tr: "Tahribatsız XMP Yan Dosyası Yaz")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryDiskSpace",
                reasonCodes: ["E174.1"],
                purposeSummary: "Checks CFexpress / SSD free space before 16-bit TIFF batch exports."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryFileTimestamp",
                reasonCodes: ["C617.1"],
                purposeSummary: "Preserves original EXIF capture timestamps across XMP sidecar updates."
            )
        ],
        customStateComputedSwift: """
        public var keeperCount: Int {
            negatives.filter(\\.isKeeperPick).count
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("ACEScg Parametric Grade Inspector", systemImage: "dial.medium.fill")
                    .font(.headline)
                Spacer()
                Text("Keepers: \\(store.state.keeperCount)/\\(store.state.negatives.count)")
                    .font(.caption.monospacedDigit().bold())
            }
            if let lead = store.state.negatives.first {
                Text("\\(lead.fileName) · Gain \\(String(format: "%.2fx", lead.linearExposureGainMultiplier)) · \\(lead.appliedLUTName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        return "Darkroom Copilot: \\(state.keeperCount) keeper(s) selected; primary RAW gain \\(String(format: "%.2fx", state.negatives.first?.linearExposureGainMultiplier ?? 1.0))."
        """,
        customUnitTestsSwift: """
        @Test("EV exposure stop math doubles linear gain at +1.0 EV and batch LUT ignores rejects")
        func evExposureGainAndBatchLUT() {
            var state = RAWColorDarkroomState()
            _ = RAWColorDarkroomReducer.reduce(
                state: &state,
                action: .adjustDevelopExposure(assetID: "raw-0042", deltaEV: 0.65, kelvin: 5600)
            )
            #expect(abs(state.negatives[0].exposureEV - 1.0) < 0.001)
            #expect(abs(state.negatives[0].linearExposureGainMultiplier - 2.0) < 0.001)

            _ = RAWColorDarkroomReducer.reduce(
                state: &state,
                action: .batchSyncLUTAcrossPicks(lutFilename: "Ektar100_65.cube")
            )
            #expect(state.negatives[0].appliedLUTName == "Ektar100_65.cube")
            #expect(state.negatives[2].appliedLUTName == "LinearNeutral.cube")
        }
        """,
        securityPostureHighlights: [
            "Optional EXIF GPS/serial stripping protects photojournalist and client location privacy on export.",
            "Original camera RAW binaries are opened read-only and never mutated in place.",
            "C2PA content authenticity manifest hash ready for editorial delivery."
        ]
    )

    // MARK: 18. Multi-Cam Live Stream Scene Switcher

    public static let liveStreamSceneSwitcher = EnterpriseBlueprintSpec(
        id: .liveStreamSceneSwitcher,
        vertical: .mediaCreator,
        title: "Live Stream Scene Switcher",
        subtitle: "Multi-cam NDI/SRT/UVC tally switching, Preview/Program dissolve transitions, and adaptive bitrate control.",
        sfSymbol: "video.badge.waveform.fill",
        complexityTier: .enterprise,
        supportedPlatforms: [.macOS, .iPadOS],
        domainEntities: [
            BlueprintDomainEntity(
                name: "MultiCamSceneInput",
                tableName: "multicam_scene_inputs",
                summary: "Live HDMI/UVC, NDI HX3, or remote SRT camera source with hardware tally state and frame drop counter.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"cam-1\"", isIndexed: true, summary: "Switcher bus input ID."),
                    BlueprintEntityField(name: "sceneTitle", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"CAM A · Sony FX3 Wide\"", summary: "Multiviewer UMD tally label."),
                    BlueprintEntityField(name: "transportProtocol", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"HDMI_CAPTURE_10BIT\"", summary: "HDMI_CAPTURE_10BIT, NDI_HX3, SRT_CALLER."),
                    BlueprintEntityField(name: "tallyBus", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"PROGRAM\"", isIndexed: true, summary: "PROGRAM (Red), PREVIEW (Green), STANDBY."),
                    BlueprintEntityField(name: "droppedFrames", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "0", summary: "Cumulative dropped frames in current broadcast."),
                    BlueprintEntityField(name: "audioSyncDelayMs", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "35", summary: "Lip-sync delay compensation in milliseconds.")
                ],
                computedHelpersSwift: """
                public var isOnAirProgram: Bool {
                    tallyBus == "PROGRAM"
                }

                public var isQueuedPreview: Bool {
                    tallyBus == "PREVIEW"
                }
                """
            ),
            BlueprintDomainEntity(
                name: "SRTBroadcastEncoderStatus",
                tableName: "srt_broadcast_encoder_status",
                summary: "Hardware VideoToolbox HEVC/AV1 encoder telemetry with SRT RTT congestion adaptation.",
                fields: [
                    BlueprintEntityField(name: "id", swiftType: "String", sqlType: "TEXT NOT NULL", defaultValueLiteral: "\"enc-main\"", isIndexed: true, summary: "Primary encoder output ID."),
                    BlueprintEntityField(name: "targetBitrateKbps", swiftType: "Int", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "12500", summary: "Configured target video bitrate in kbps."),
                    BlueprintEntityField(name: "srtRTTMillis", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "28.0", summary: "SRT relay round-trip latency in milliseconds."),
                    BlueprintEntityField(name: "packetLossPercent", swiftType: "Double", sqlType: "REAL NOT NULL", defaultValueLiteral: "0.12", summary: "Measured uplink packet loss %."),
                    BlueprintEntityField(name: "isOnAirLive", swiftType: "Bool", sqlType: "INTEGER NOT NULL", defaultValueLiteral: "true", summary: "True when streaming to ingest relay.")
                ],
                computedHelpersSwift: """
                public var isLinkCongested: Bool {
                    packetLossPercent >= 2.0 || srtRTTMillis >= 180.0
                }
                """
            )
        ],
        stateProperties: [
            BlueprintStateProperty(
                name: "inputs",
                swiftType: "[MultiCamSceneInput]",
                initialValueLiteral: """
                [
                    MultiCamSceneInput(id: "cam-1", sceneTitle: "CAM A · Host Desk 4K60", transportProtocol: "HDMI_CAPTURE_10BIT", tallyBus: "PROGRAM", droppedFrames: 0, audioSyncDelayMs: 32),
                    MultiCamSceneInput(id: "cam-2", sceneTitle: "CAM B · Overhead Product Macro", transportProtocol: "NDI_HX3", tallyBus: "PREVIEW", droppedFrames: 1, audioSyncDelayMs: 48),
                    MultiCamSceneInput(id: "cam-3", sceneTitle: "CAM C · Remote Guest SRT", transportProtocol: "SRT_CALLER", tallyBus: "STANDBY", droppedFrames: 0, audioSyncDelayMs: 0)
                ]
                """,
                summary: "Multiviewer camera & screen-share scene inputs."
            ),
            BlueprintStateProperty(
                name: "encoder",
                swiftType: "SRTBroadcastEncoderStatus",
                initialValueLiteral: "SRTBroadcastEncoderStatus()",
                summary: "Primary VideoToolbox SRT/RTMP hardware encoder status."
            ),
            BlueprintStateProperty(
                name: "transitionDurationFrames",
                swiftType: "Int",
                initialValueLiteral: "18",
                summary: "Auto-dissolve mix duration in 60fps frames (18f = 300ms)."
            )
        ],
        reducerActions: [
            BlueprintReducerAction(
                caseDeclaration: "executeAutoTransitionSwap",
                matchPattern: ".executeAutoTransitionSwap",
                buttonTitle: "AUTO Transition (PGM <-> PVW)",
                sampleDispatchLiteral: ".executeAutoTransitionSwap",
                summary: "Atomically transitions queued PREVIEW input to live PROGRAM red tally and moves old PROGRAM to PREVIEW.",
                mutationBodySwift: """
                guard let pgmIdx = state.inputs.firstIndex(where: \\.isOnAirProgram),
                      let pvwIdx = state.inputs.firstIndex(where: \\.isQueuedPreview) else { break }
                state.inputs[pgmIdx].tallyBus = "PREVIEW"
                state.inputs[pvwIdx].tallyBus = "PROGRAM"
                state.lastAuditMessage = "Transitioned \\(state.inputs[pvwIdx].sceneTitle) -> PROGRAM"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "queuePreviewInput(inputID: String)",
                matchPattern: ".queuePreviewInput(let inputID)",
                buttonTitle: "Queue CAM C to Preview",
                sampleDispatchLiteral: ".queuePreviewInput(inputID: \"cam-3\")",
                summary: "Assigns green PREVIEW tally to selected standby source without disturbing live PROGRAM.",
                mutationBodySwift: """
                guard let targetIdx = state.inputs.firstIndex(where: { $0.id == inputID }),
                      !state.inputs[targetIdx].isOnAirProgram else { break }
                for idx in state.inputs.indices where state.inputs[idx].isQueuedPreview {
                    state.inputs[idx].tallyBus = "STANDBY"
                }
                state.inputs[targetIdx].tallyBus = "PREVIEW"
                state.lastAuditMessage = "Queued \\(state.inputs[targetIdx].sceneTitle) on PREVIEW bus"
                """
            ),
            BlueprintReducerAction(
                caseDeclaration: "adaptBitrateForNetworkTelemetry(rttMs: Double, lossPercent: Double)",
                matchPattern: ".adaptBitrateForNetworkTelemetry(let rttMs, let lossPercent)",
                summary: "Steps down hardware encoder bitrate by 25% when SRT uplink packet loss >= 2%.",
                mutationBodySwift: """
                state.encoder.srtRTTMillis = rttMs
                state.encoder.packetLossPercent = lossPercent
                if state.encoder.isLinkCongested {
                    state.encoder.targetBitrateKbps = max(2500, Int(Double(state.encoder.targetBitrateKbps) * 0.75))
                    state.lastAuditMessage = "Congestion step-down -> \\(state.encoder.targetBitrateKbps) kbps"
                } else {
                    state.lastAuditMessage = "Uplink nominal @ \\(state.encoder.targetBitrateKbps) kbps"
                }
                """
            )
        ],
        apiEndpoints: [
            BlueprintAPIEndpoint(
                methodName: "fetchMultiviewerBusState",
                method: .get,
                path: "/v1/switcher/inputs",
                responseType: "[MultiCamSceneInput]",
                offlineStubSwift: "LiveSceneDirectorState().inputs",
                summary: "Reads current Program/Preview tally matrix for Companion/StreamDeck."
            ),
            BlueprintAPIEndpoint(
                methodName: "triggerAutoTransition",
                method: .post,
                path: "/v1/switcher/transitions/auto",
                responseType: "Bool",
                requiresIdempotencyKey: true,
                offlineStubSwift: "true",
                summary: "Fires frame-accurate GPU mix transition."
            ),
            BlueprintAPIEndpoint(
                methodName: "fetchEncoderTelemetry",
                method: .get,
                path: "/v1/switcher/encoder",
                responseType: "SRTBroadcastEncoderStatus",
                offlineStubSwift: "LiveSceneDirectorState().encoder",
                summary: "Polls VideoToolbox HEVC/SRT transport telemetry."
            )
        ],
        kpiMetrics: [
            BlueprintKPIMetric(key: "pgmSource", label: "PROGRAM (Red Tally)", value: "CAM A · 4K60", delta: "0 dropped frames", sfSymbol: "dot.radiowaves.left.and.right"),
            BlueprintKPIMetric(key: "pvwSource", label: "PREVIEW (Green)", value: "CAM B · NDI", delta: "18f dissolve", sfSymbol: "rectangle.on.rectangle"),
            BlueprintKPIMetric(key: "srtBitrate", label: "HEVC Uplink", value: "12.5 Mbps", delta: "0.12% loss", sfSymbol: "antenna.radiowaves.left.and.right"),
            BlueprintKPIMetric(key: "gpuCompositor", label: "Metal Compositor", value: "1.9 ms", delta: "60.00 fps locked", sfSymbol: "tv.and.mediabox.fill")
        ],
        sampleRecords: [
            BlueprintSampleRecord(id: "sw-1", headline: "CAM A · Host Desk 4K60 (HDMI 10-bit)", subheadline: "Lip-sync +32ms · 0 dropped frames · Live on air", trailingMetric: "RED TALLY", statusTag: "PROGRAM"),
            BlueprintSampleRecord(id: "sw-2", headline: "CAM B · Overhead Product Macro (NDI HX3)", subheadline: "Lip-sync +48ms · 1 dropped frame · Next up", trailingMetric: "GREEN TALLY", statusTag: "PREVIEW"),
            BlueprintSampleRecord(id: "sw-3", headline: "CAM C · Remote Guest Feed (SRT AES-128)", subheadline: "RTT 28ms · Echo-cancelled mix-minus bus", trailingMetric: "STANDBY", statusTag: "READY")
        ],
        onboardingPages: [
            FlowPage(
                id: "discover-sources",
                title: "Discover UVC Capture Cards, NDI & SRT Feeds",
                body: "Auto-detect HDMI capture devices over USB-C/Thunderbolt and mDNS NDI studio cameras.",
                style: "hero",
                actions: ["Scan Studio Inputs"]
            ),
            FlowPage(
                id: "ingest-protocol",
                title: "Configure Encrypted SRT or RTMP Ingest",
                body: "Enable AES-128 SRT ARQ retransmission with automatic congestion bitrate step-down.",
                style: "choice",
                actions: ["SRT Low-Latency HEVC", "Dual SRT + Local ProRes ISO"]
            ),
            FlowPage(
                id: "switcher-ready",
                title: "Live Broadcast Director Armed",
                body: "Hardware tally buses, mix-minus audio, and GPU transitions are ready.",
                style: "completion",
                actions: ["Launch Live Switcher"]
            )
        ],
        localizationKeysTR_EN: [
            BlueprintLocalizedKey(key: "live.title", en: "Live Stream Scene Switcher", tr: "Canlı Yayın Sahne Yönetmeni"),
            BlueprintLocalizedKey(key: "live.auto_transition", en: "Auto Dissolve Transition", tr: "Yumuşak Sahne Geçişi (AUTO)"),
            BlueprintLocalizedKey(key: "live.program_bus", en: "On-Air Program Bus", tr: "Yayındaki Program Hattı (PGM)"),
            BlueprintLocalizedKey(key: "live.preview_bus", en: "Queued Preview Bus", tr: "Hazır Önizleme Hattı (PVW)"),
            BlueprintLocalizedKey(key: "live.adaptive_bitrate", en: "Congestion Bitrate Step-Down", tr: "Ağ Yoğunluğunda Bit Hızı Düşürme"),
            BlueprintLocalizedKey(key: "live.iso_record", en: "Local ProRes ISO Recording", tr: "Yerel ProRes Çoklu Kamera Kaydı")
        ],
        privacyAPICategories: [
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategoryDiskSpace",
                reasonCodes: ["E174.1"],
                purposeSummary: "Monitors free NVMe capacity during simultaneous multi-cam ProRes ISO recording."
            ),
            BlueprintPrivacyAPICategory(
                categoryIdentifier: "NSPrivacyAccessedAPICategorySystemBootTime",
                reasonCodes: ["35F9.1"],
                purposeSummary: "Synchronizes A/V presentation timestamps across USB and NDI clocks."
            )
        ],
        customStateComputedSwift: """
        public var programSceneTitle: String {
            inputs.first(where: \\.isOnAirProgram)?.sceneTitle ?? "BLACK_SAFE"
        }

        public var previewSceneTitle: String {
            inputs.first(where: \\.isQueuedPreview)?.sceneTitle ?? "NONE"
        }
        """,
        customSwiftUIInspectorSwift: """
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Tally Multiviewer Bus", systemImage: "dot.radiowaves.right")
                    .font(.headline)
                Spacer()
                Text("\\(store.state.encoder.targetBitrateKbps) kbps")
                    .font(.caption.monospacedDigit().bold())
            }
            Text("PGM: \\(store.state.programSceneTitle) | PVW: \\(store.state.previewSceneTitle)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        """,
        localAICopilotRoutineSwift: """
        return "Broadcast Copilot: PGM=\\(state.programSceneTitle), PVW=\\(state.previewSceneTitle), SRT loss=\\(state.encoder.packetLossPercent)%."
        """,
        customUnitTestsSwift: """
        @Test("Auto transition atomically swaps Program and Preview tally buses; congestion steps down bitrate")
        func tallySwapAndCongestionAdaptation() {
            var state = LiveSceneDirectorState()
            _ = LiveSceneDirectorReducer.reduce(state: &state, action: .executeAutoTransitionSwap)
            #expect(state.inputs[0].tallyBus == "PREVIEW")
            #expect(state.inputs[1].tallyBus == "PROGRAM")

            _ = LiveSceneDirectorReducer.reduce(
                state: &state,
                action: .adaptBitrateForNetworkTelemetry(rttMs: 210.0, lossPercent: 3.4)
            )
            #expect(state.encoder.targetBitrateKbps < 12_500)
        }
        """,
        securityPostureHighlights: [
            "AES-128/256 passphrase encryption protects remote SRT contributor video feeds.",
            "Stream ingest keys sealed in macOS Keychain and redacted from diagnostic exports.",
            "Loopback Companion API requires bearer token authentication on studio VLAN."
        ]
    )
}
