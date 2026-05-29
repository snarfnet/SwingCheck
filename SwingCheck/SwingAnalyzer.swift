import Foundation
import Vision
import QuartzCore

@Observable
final class SwingAnalyzer {
    var session = SwingSession()
    var phase: SwingPhase = .ready
    var isSessionActive = false
    var lastTimingResult: TimingResult?
    var showTimingResult = false
    var isBallInFlight = false

    private var ballContactTime: CFTimeInterval = 0
    private var swingCooldown: CFTimeInterval = 0
    private let swingThreshold: Double = 0.055
    private let cooldownInterval: CFTimeInterval = 1.2

    private var prevLeftWrist: CGPoint?
    private var prevRightWrist: CGPoint?
    private var prevNose: CGPoint?

    private var stanceSamples: [Double] = []
    private var hipRotSamples: [Double] = []
    private var headSamples: [Double] = []
    private var followSamples: [Double] = []

    func startSession() {
        session = SwingSession()
        phase = .ready
        stanceSamples = []; hipRotSamples = []; headSamples = []; followSamples = []
        prevLeftWrist = nil; prevRightWrist = nil; prevNose = nil
        swingCooldown = 0
        isBallInFlight = false
        isSessionActive = true
    }

    func stopSession() { isSessionActive = false }

    func onBallThrown() {
        isBallInFlight = true
        session.totalPitches += 1
        phase = .load
    }

    func onBallAtContact(time: CFTimeInterval) {
        ballContactTime = time
    }

    func onBallPassed() {
        guard isBallInFlight else { return }
        isBallInFlight = false
        // ボールが通り過ぎてもスイングなし
        if phase == .load || phase == .ready {
            let result = TimingResult.noSwing
            session.timingResults.append(result)
            showResult(result)
            phase = .ready
        }
    }

    func analyze(_ pose: BodyPose) {
        guard isSessionActive else { return }
        let now = CACurrentMediaTime()

        let lw = pose.point(.leftWrist)
        let rw = pose.point(.rightWrist)
        let ls = pose.point(.leftShoulder)
        let rs = pose.point(.rightShoulder)
        let lh = pose.point(.leftHip)
        let rh = pose.point(.rightHip)
        let nose = pose.point(.nose)

        // スイング検出
        if now - swingCooldown >= cooldownInterval {
            var maxVel: Double = 0
            if let lw, let plw = prevLeftWrist { maxVel = max(maxVel, hypot(lw.x - plw.x, lw.y - plw.y)) }
            if let rw, let prw = prevRightWrist { maxVel = max(maxVel, hypot(rw.x - prw.x, rw.y - prw.y)) }

            if maxVel > swingThreshold {
                swingCooldown = now
                session.swings += 1
                phase = .swing

                if isBallInFlight {
                    let errMs = abs(now - ballContactTime) * 1000
                    let result: TimingResult = errMs < 100 ? .perfect : errMs < 220 ? .good : errMs < 380 ? .fair : .miss
                    session.timingResults.append(result)
                    session.timingErrors.append(errMs)
                    showResult(result)
                    isBallInFlight = false
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    self?.phase = .follow
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                        self?.phase = .ready
                    }
                }
            }
        }

        // フォーム解析
        analyzeForm(ls: ls, rs: rs, lh: lh, rh: rh, nose: nose, lw: lw, rw: rw, pose: pose)

        prevLeftWrist = lw
        prevRightWrist = rw
        prevNose = nose
    }

    private func analyzeForm(ls: CGPoint?, rs: CGPoint?, lh: CGPoint?, rh: CGPoint?,
                              nose: CGPoint?, lw: CGPoint?, rw: CGPoint?, pose: BodyPose) {
        // スタンス幅
        if let la = pose.point(.leftAnkle), let ra = pose.point(.rightAnkle),
           let ls, let rs {
            let fw = abs(la.x - ra.x)
            let sw = abs(ls.x - rs.x)
            let ratio = fw / max(sw, 0.01)
            stanceSamples.append(max(0, min(100, 100 - abs(ratio - 1.2) * 140)))
        }

        // 腰の回転
        if let lh, let rh, let ls, let rs {
            let ha = atan2(rh.y - lh.y, rh.x - lh.x)
            let sa = atan2(rs.y - ls.y, rs.x - ls.x)
            hipRotSamples.append(min(100, abs(ha - sa) * 280))
        }

        // 頭の安定性
        if let nose, let prev = prevNose {
            let mv = hypot(nose.x - prev.x, nose.y - prev.y)
            headSamples.append(max(0, min(100, (1 - mv / 0.025) * 100)))
        }

        // フォロースルー（スイング後の腕の伸び）
        if phase == .follow, let lw, let ls, let rw, let rs {
            let le = hypot(lw.x - ls.x, lw.y - ls.y)
            let re = hypot(rw.x - rs.x, rw.y - rs.y)
            followSamples.append(min(100, (le + re) / 2 * 380))
        }

        let w = 30
        session.formScore.stance        = avg(stanceSamples.suffix(w))
        session.formScore.hipRotation   = avg(hipRotSamples.suffix(w))
        session.formScore.headStability = avg(headSamples.suffix(w))
        session.formScore.followThrough = avg(followSamples.suffix(w))
    }

    private func showResult(_ result: TimingResult) {
        lastTimingResult = result
        showTimingResult = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showTimingResult = false
        }
    }

    private func avg(_ s: ArraySlice<Double>) -> Double {
        s.isEmpty ? 0 : s.reduce(0,+) / Double(s.count)
    }
}
