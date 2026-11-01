import XCTest
import AVFoundation
import simd
@testable import THREADS

final class GeometryTests: XCTestCase {
    func testFiniteProjectionClampsToEndpoints() {
        XCTAssertEqual(Geometry.closestPoint([4, 0, 0], [0, 0, 0], [1, 0, 0]), [1, 0, 0])
        XCTAssertEqual(Geometry.closestPoint([-2, 0, 0], [0, 0, 0], [1, 0, 0]), [0, 0, 0])
    }
    func testCrossingSegmentsMeet() { XCTAssertEqual(Geometry.segmentDistance([-1, 0, 0], [1, 0, 0], [0, -1, 0], [0, 1, 0]), 0, accuracy: 0.00001) }
    func testParallelSegmentsKeepSeparation() { XCTAssertEqual(Geometry.segmentDistance([0, 0, 0], [1, 0, 0], [0, 2, 0], [1, 2, 0]), 2, accuracy: 0.00001) }
    func testDegenerateSegmentsAreFinite() { XCTAssertEqual(Geometry.segmentDistance(.zero, .zero, [0, 2, 0], [0, 2, 0]), 2, accuracy: 0.00001) }
    func testAllPrimaryStringsWithinSeatedReach() {
        for i in 0..<Instrument.count { XCTAssertLessThan(simd_length(Instrument.center(i)), 0.91) }
    }
    func testLatticeHasValidTriangleIndices() {
        var mesh = TubeMesh(); mesh.add(path: [[0, 0, 0], [1, 1, 0], [2, 0, 0]], radius: 0.01)
        XCTAssertEqual(mesh.positions.count, mesh.normals.count)
        XCTAssertEqual(mesh.indices.count, 48)
        XCTAssertTrue(mesh.indices.allSatisfy { Int($0) < mesh.positions.count })
        XCTAssertTrue(mesh.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
    }
}

final class GestureTests: XCTestCase {
    func testPartlyOccludedHandStillProvidesPluckingAndOpenPalm() {
        let sample = HandSample.make(side: 0, tip: [0, 0.19, 0], thumb: nil, palm: [0, 0.09, 0],
            wrist: .zero, middle: [0.02, 0.20, 0], ring: nil, timestamp: 1)
        XCTAssertNotNil(sample); XCTAssertTrue(sample!.open); XCTAssertFalse(sample!.pinchAvailable)
        XCTAssertNil(HandSample.make(side: 0, tip: nil, thumb: .zero, palm: .zero, wrist: .zero, middle: nil, ring: nil, timestamp: 1))
    }
    func testClosedOrPointingHandDoesNotBecomeAnOpenPalm() {
        let sample = HandSample.make(side: 0, tip: [0, 0.19, 0], thumb: [0.1, 0, 0], palm: [0, 0.09, 0],
            wrist: .zero, middle: [0, 0.08, 0], ring: [0, 0.07, 0], timestamp: 1)
        XCTAssertFalse(sample!.open)
    }
    func testWaveAcceptsRelaxedSweepOutsideTheOldNarrowBox() {
        var gate = WaveGate(); let p = Instrument.endpoints(4).1 + [0, -0.04, 0.10]
        _ = gate.sample(palm: p + [-0.06, 0, 0], open: true, at: 1)
        XCTAssertNotNil(gate.sample(palm: p, open: true, at: 1.08))
        XCTAssertNil(gate.sample(palm: p + [0.06, 0, 0], open: true, at: 1.16))
    }
    func testWaveRejectsClosedFarStationaryAndReacquiredHands() {
        var gate = WaveGate(); let p = Instrument.center(4)
        _ = gate.sample(palm: p, open: true, at: 1)
        XCTAssertNil(gate.sample(palm: p, open: true, at: 1.05))
        XCTAssertNil(gate.sample(palm: p + [0.1, 0, 0], open: false, at: 1.10))
        XCTAssertNil(gate.sample(palm: p, open: true, at: 1.15))
        gate.reset()
        _ = gate.sample(palm: [3, 3, 3], open: true, at: 2)
        XCTAssertNil(gate.sample(palm: [3.1, 3, 3], open: true, at: 2.08))
        gate.reset()
        _ = gate.sample(palm: p + [-0.06, 0, 0], open: true, at: 3)
        XCTAssertNil(gate.sample(palm: p + [0.06, 0, 0], open: true, at: 4))
    }
    func testSmallTrackingJitterCannotAccumulateAWave() {
        var gate = WaveGate(); let p = Instrument.center(4)
        for i in 0..<200 {
            XCTAssertNil(gate.sample(palm: p + [i % 2 == 0 ? 0.001 : -0.001, 0, 0], open: true, at: 1 + Double(i) * 0.02))
        }
    }
    func testGentleHighRateBrushCanPluckWithoutAFullCentimeterStep() {
        var gate = CrossingGate(); let p = Instrument.center(4)
        _ = gate.sample(point: p + [-0.01, 0, 0.02], at: 1)
        XCTAssertEqual(gate.sample(point: p + [-0.009, 0, 0.02], at: 1.012).map(\.0), [4])
    }
    func testRealCrossingPlucksOneString() {
        var gate = CrossingGate(); let c = Instrument.center(4)
        _ = gate.sample(point: c + [-0.025, 0, 0], at: 1)
        let hits = gate.sample(point: c + [0.025, 0, 0], at: 1.05)
        XCTAssertEqual(hits.map(\.0), [4]); XCTAssertGreaterThan(hits[0].1, 0.1)
    }
    func testStationaryFingerDoesNotRetrigger() {
        var gate = CrossingGate(); let c = Instrument.center(4)
        _ = gate.sample(point: c, at: 1)
        XCTAssertTrue(gate.sample(point: c, at: 1.02).isEmpty)
    }
    func testTrackingJumpIsRejected() {
        var gate = CrossingGate(); let c = Instrument.center(4)
        _ = gate.sample(point: c + [-0.3, 0, 0], at: 1)
        XCTAssertTrue(gate.sample(point: c + [0.3, 0, 0], at: 1.02).isEmpty)
    }
    func testOldTrackingSampleIsRejected() {
        var gate = CrossingGate(); let c = Instrument.center(4)
        _ = gate.sample(point: c + [-0.025, 0, 0], at: 1)
        XCTAssertTrue(gate.sample(point: c + [0.025, 0, 0], at: 2).isEmpty)
    }
    func testGrabbedStringIsExcluded() {
        var gate = CrossingGate(); let c = Instrument.center(4)
        _ = gate.sample(point: c + [-0.025, 0, 0], at: 1)
        XCTAssertTrue(gate.sample(point: c + [0.025, 0, 0], at: 1.05, excluded: 4).isEmpty)
    }
    func testContactMustLeaveBeforeRearming() {
        var gate = CrossingGate(); let c = Instrument.center(4)
        _ = gate.sample(point: c + [-0.025, 0, 0], at: 1)
        _ = gate.sample(point: c + [0.025, 0, 0], at: 1.05)
        XCTAssertTrue(gate.sample(point: c + [-0.015, 0, 0], at: 1.10).isEmpty)
    }
    func testResetDropsOldTrajectory() {
        var gate = CrossingGate(); _ = gate.sample(point: .zero, at: 1); gate.reset()
        XCTAssertNil(gate.previous)
    }
    func testVibrationDecaysAndEndpointsStayFixed() {
        var motion = StringMotion(); motion.excite(1)
        let (a, b) = Instrument.endpoints(2)
        for _ in 0..<240 { motion.step(1 / 60) }
        XCTAssertLessThan(motion.amplitude, 0.00001)
        XCTAssertLessThan(simd_distance(motion.point(a, b, t: 0), a), 0.00001)
        XCTAssertLessThan(simd_distance(motion.point(a, b, t: 1), b), 0.00001)
    }
    func testReleaseReturnsToRest() {
        var motion = StringMotion(); motion.pull = [0.15, 0, 0]; motion.targetPull = motion.pull
        for _ in 0..<180 { motion.step(1 / 60) }
        XCTAssertLessThan(simd_length(motion.pull), 0.0001)
    }
    func testReducedMotionRemovesVibration() { var m = StringMotion(); m.excite(1); m.step(0.02, reducedMotion: true); XCTAssertEqual(m.amplitude, 0) }
}

final class LoopTests: XCTestCase {
    func testEmptyRecordingRemainsEmpty() { var l = PerformanceLoop(); l.record(at: 0); l.stop(at: 2); XCTAssertEqual(l.state, .empty) }
    func testPlaybackPreservesTimingAcrossBoundary() {
        var l = PerformanceLoop(); l.record(at: 0)
        l.append(string: 3, strength: 0.7, tension: 0.1, at: 0.1); l.stop(at: 2)
        XCTAssertTrue(l.tick(at: 2.05).isEmpty)
        XCTAssertEqual(l.tick(at: 2.11).map(\.string), [3])
        XCTAssertEqual(l.tick(at: 4.11).map(\.string), [3])
    }
    func testLoopDoesNotRecapturePlayback() {
        var l = PerformanceLoop(); l.record(at: 0); l.append(string: 0, strength: 1, tension: 0, at: 0.1); l.stop(at: 2)
        l.append(string: 1, strength: 1, tension: 0, at: 2.2); XCTAssertEqual(l.events.count, 1)
    }
    func testPausePreservesPlayhead() {
        var l = PerformanceLoop(); l.record(at: 0); l.append(string: 0, strength: 1, tension: 0, at: 0.5); l.stop(at: 2)
        l.toggle(at: 2.4); XCTAssertEqual(l.state, .paused); XCTAssertTrue(l.tick(at: 4).isEmpty)
        l.toggle(at: 5); XCTAssertEqual(l.tick(at: 5.11).count, 1)
    }
    func testAutoStopAtTwelveSeconds() {
        var l = PerformanceLoop(); l.record(at: 0); l.append(string: 2, strength: 1, tension: 0, at: 1)
        _ = l.tick(at: 12); XCTAssertEqual(l.state, .playing); XCTAssertEqual(l.duration, 12)
    }
    func testStallDoesNotBurstOldNotes() {
        var l = PerformanceLoop(); l.record(at: 0); l.append(string: 0, strength: 1, tension: 0, at: 0.4); l.stop(at: 2)
        XCTAssertTrue(l.tick(at: 5).isEmpty)
    }
    func testClearRemovesPerformance() { var l = PerformanceLoop(); l.record(at: 1); l.append(string: 0, strength: 1, tension: 0, at: 2); l.clear(); XCTAssertTrue(l.events.isEmpty); XCTAssertEqual(l.state, .empty) }
    func testEventStorageBounded() { var l = PerformanceLoop(); l.record(at: 0); for _ in 0..<700 { l.append(string: 1, strength: 1, tension: 0, at: 1) }; XCTAssertEqual(l.events.count, 512) }
}

final class AcousticTests: XCTestCase {
    func testScaleIsMinorPentatonic() { XCTAssertEqual(Set(Instrument.midi.map { ($0 - 50) % 12 }), Set([0, 3, 5, 7, 10])) }
    func testA4IsConcertPitch() { XCTAssertEqual(Instrument.frequency(8), 440, accuracy: 0.00001) }
    func testGeneratedNoteFiniteAndHasHeadroom() {
        let data = AcousticSynthesis.samples(frequency: 220, duration: 1)
        XCTAssertEqual(data.count, 48_000); XCTAssertTrue(data.allSatisfy(\.isFinite))
        XCTAssertLessThanOrEqual(data.map { abs($0) }.max()!, 0.761)
        XCTAssertGreaterThan(data.map { abs($0) }.max()!, 0.4)
    }
    func testAttackStartsAtZero() { XCTAssertEqual(AcousticSynthesis.samples(frequency: 220, duration: 0.1).first, 0) }
    func testTailDecays() {
        let d = AcousticSynthesis.samples(frequency: 220)
        func rms(_ range: Range<Int>) -> Float { sqrt(range.reduce(Float(0)) { $0 + d[$1] * d[$1] } / Float(range.count)) }
        XCTAssertLessThan(rms(200_000..<220_000), rms(2_000..<22_000) * 0.15)
    }
    func testSynthesisIsRepeatable() { XCTAssertEqual(AcousticSynthesis.samples(frequency: 220, duration: 0.02), AcousticSynthesis.samples(frequency: 220, duration: 0.02)) }
    func testRenderedNotesAreTunedWithinTenCents() {
        for i in 0..<Instrument.count {
            let f = Instrument.frequency(i)
            let data = AcousticSynthesis.samples(frequency: f, duration: 1)
            let expected = 48_000 / f
            let lags = Array((Int(expected) - 4)...(Int(expected) + 4))
            let correlations = lags.map { lag -> Double in
                var sum = 0.0
                for k in stride(from: 4_800, to: 28_800, by: 3) { sum += Double(data[k] * data[k + lag]) }
                return sum
            }
            let peak = correlations.indices.max { correlations[$0] < correlations[$1] }!
            XCTAssertTrue(peak > 0 && peak < correlations.count - 1)
            guard peak > 0, peak < correlations.count - 1 else { continue }
            let a = correlations[peak - 1], b = correlations[peak], c = correlations[peak + 1]
            let offset = 0.5 * (a - c) / (a - 2 * b + c)
            let measured = 48_000 / (Double(lags[peak]) + offset)
            XCTAssertLessThan(abs(1200 * log2(measured / f)), 10, "String \(i): \(measured) Hz")
        }
    }
}

@MainActor final class IntegrationTests: XCTestCase {
    func testRapidRecoveryRequestsOpenOnlyOneControlWindow() {
        let m = FieldModel(); m.immersive = true; var opened = 0
        for _ in 0..<10 { m.requestControls { opened += 1 } }
        XCTAssertEqual(opened, 1)
        m.controlsAppeared()
        m.requestControls { opened += 1 }; XCTAssertEqual(opened, 1)
        m.controlsDisappeared()
        m.requestControls { opened += 1 }; XCTAssertEqual(opened, 2)
        m.immersive = false; m.controlsDisappeared()
        m.requestControls { opened += 1 }; XCTAssertEqual(opened, 2)
    }
    func testWaveFromPartlyOccludedHandReachesTheInstrument() {
        let m = FieldModel(); m.immersive = true
        let p = Instrument.center(4)
        func feed(_ x: Float, _ time: Double) {
            let palm = m.chamber.worldPoint(p + [x, 0, 0.08])
            m.receive(side: 0, sample: HandSample(side: 0, tip: palm + [0, 0.13, 0], thumb: palm,
                palm: palm, open: true, timestamp: time, pinchAvailable: false))
        }
        feed(-0.06, 1); feed(0, 1.08)
        XCTAssertTrue(m.motions[0].energy > 0)
        XCTAssertTrue(m.motions[7].energy > 0)
    }
    func testChangingReachPreservesLoopAndClearsHeldStrings() {
        let m = FieldModel(); m.immersive = true
        m.record(); m.pluck(3); m.record(); m.drag(3, displacement: [0.1, 0, 0])
        m.setReach(.original)
        XCTAssertEqual(m.loopCount, 1); XCTAssertEqual(m.loopState, .playing)
        XCTAssertFalse(m.motions[3].grabbed)
    }
    func testGuidedPlayAdvancesOnlyForIntendedLiveNotes() {
        let m = FieldModel(); m.immersive = true; m.startGuidedPlay()
        m.pluck(3, source: "demo"); XCTAssertEqual(m.guidedTarget, 0)
        m.pluck(0, source: "loop"); XCTAssertEqual(m.guidedTarget, 0)
        for i in GuidedPhrase.notes { m.pluck(i, source: "demo") }
        XCTAssertTrue(m.guidedPhrase!.complete)
        m.stopGuidedPlay(); XCTAssertNil(m.guidedTarget)
    }
    func testEchoDoesNotSwallowLiveContactOrRecaptureItsTail() {
        let m = FieldModel(); m.immersive = true; m.echoEnabled = true
        m.record(); m.pluck(4, source: "echo"); m.pluck(4, source: "touch"); m.record()
        XCTAssertEqual(m.loopCount, 1)
    }
    func testReachTransformRoundTripsForTurnedHead() {
        let chamber = ResonanceChamber()
        var head = simd_float4x4(simd_quatf(angle: .pi / 2, axis: [0, 1, 0]))
        head.columns.3 = [1, 1.5, 2, 1]
        chamber.calibrate(to: head)
        let p = Instrument.center(3)
        XCTAssertLessThan(simd_distance(p, chamber.localPoint(chamber.worldPoint(p))), 0.00001)
        let close = chamber.worldPoint(p)
        chamber.reach = .original
        XCTAssertGreaterThan(simd_distance(close, chamber.worldPoint(p)), 0.15)
    }
    func testClearUndoRestoresNotesAndKeepsPlaybackPaused() {
        let model = FieldModel(); model.immersive = true
        model.record(); model.pluck(3); model.record()
        XCTAssertEqual(model.loopState, .playing); XCTAssertEqual(model.loopCount, 1)
        model.clearLoopWithUndo()
        XCTAssertTrue(model.canUndoLoopClear); XCTAssertEqual(model.loopCount, 0)
        model.undoLoopClear()
        XCTAssertFalse(model.canUndoLoopClear); XCTAssertEqual(model.loopCount, 1)
        XCTAssertEqual(model.loopState, .paused)
    }
    func testRecenterPreservesThePerformance() {
        let model = FieldModel(); model.immersive = true
        model.record(); model.pluck(3); model.record()
        model.recenter()
        XCTAssertEqual(model.loopState, .playing); XCTAssertEqual(model.loopCount, 1)
    }
    func testResetDiscardsUndoSnapshot() {
        let model = FieldModel(); model.immersive = true
        model.record(); model.pluck(3); model.record(); model.clearLoopWithUndo()
        model.reset(); model.undoLoopClear()
        XCTAssertFalse(model.canUndoLoopClear); XCTAssertEqual(model.loopCount, 0)
        XCTAssertEqual(model.loopState, .empty)
    }
    func testClearDoesNotInterruptAnActiveRecording() {
        let model = FieldModel(); model.immersive = true
        model.record(); model.pluck(3); model.clearLoopWithUndo()
        XCTAssertFalse(model.canUndoLoopClear); XCTAssertEqual(model.loopState, .recording)
    }

    func testStretchClampAndResetClearInteractionState() {
        let m = FieldModel(); m.immersive = true
        m.drag(3, displacement: [1, 1, 1]); XCTAssertEqual(simd_length(m.motions[3].targetPull), 0.18, accuracy: 0.00001)
        m.reset(); XCTAssertTrue(m.motions.allSatisfy { !$0.grabbed && $0.energy == 0 })
    }
    func testLostHandReleasesGrab() {
        let m = FieldModel(); m.immersive = true
        let p = m.chamber.worldPoint(Instrument.center(4))
        m.receive(side: 0, sample: HandSample(side: 0, tip: p, thumb: p + [0.01, 0, 0], palm: p, open: false, timestamp: 1))
        m.receive(side: 0, sample: nil)
        XCTAssertFalse(m.motions[4].grabbed)
    }
    func testProceduralSceneBuildsActualGeometry() throws {
        let chamber = ResonanceChamber(); try chamber.build()
        XCTAssertEqual(chamber.decorativeCount, 520); XCTAssertEqual(chamber.strings.count, 10)
        XCTAssertGreaterThan(chamber.triangleCount, 60_000)
    }
}

final class MusicalFeatureTests: XCTestCase {
    func testEveryMoodRetunesTheBaseBankToItsDeclaredPitch() {
        for mood in Soundscape.allCases {
            XCTAssertEqual(mood.midi.count, Instrument.count)
            for i in 0..<Instrument.count {
                let result = Instrument.frequency(i) * Double(mood.rate(i))
                let expected = 440 * pow(2, Double(mood.midi[i] - 69) / 12)
                XCTAssertEqual(result, expected, accuracy: 0.001)
            }
        }
    }
    func testEchoIsFiniteAndStaleEchoesNeverBurstAfterAPause() {
        var echo = EchoTrail(); echo.append(string: 2, strength: 1, tension: 0, at: 1)
        XCTAssertTrue(echo.tick(at: 1.1).isEmpty)
        XCTAssertEqual(echo.tick(at: 1.33).map(\.strength), [0.38])
        XCTAssertEqual(echo.tick(at: 1.65).map(\.strength), [0.16])
        XCTAssertTrue(echo.tick(at: 2).isEmpty)
        echo.append(string: 2, strength: 1, tension: 0, at: 3)
        XCTAssertTrue(echo.tick(at: 10).isEmpty)
        echo.append(string: 2, strength: 1, tension: 0, at: 11); echo.clear()
        XCTAssertTrue(echo.tick(at: 11.33).isEmpty)
    }
}
