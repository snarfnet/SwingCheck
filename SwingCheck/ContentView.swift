import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var camera = CameraManager()
    @State private var analyzer = SwingAnalyzer()
    @State private var pitchType: PitchType = .straight
    @State private var pitchSpeed: PitchSpeed = .medium
    @State private var showStats = false
    @State private var isSessionActive = false

    @State private var ballScene: BallScene = {
        let scene = BallScene(size: UIScreen.main.bounds.size)
        return scene
    }()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // カメラ映像
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            // 骨格オーバーレイ
            if let pose = camera.currentPose {
                PoseOverlayView(pose: pose, isFrontCamera: !camera.isBackCamera)
                    .ignoresSafeArea()
            }

            // ボールシーン（SpriteKit）
            SpriteView(scene: ballScene, options: [.allowsTransparency])
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // UI
            VStack(spacing: 0) {
                topBar
                Spacer()
                if analyzer.showTimingResult, let result = analyzer.lastTimingResult {
                    timingBanner(result)
                }
                Spacer()
                if isSessionActive {
                    formScoreBar
                }
                controlBar
            }
        }
        .onAppear {
            setupBallScene()
            camera.start()
        }
        .onDisappear { camera.stop() }
        .onChange(of: camera.currentPose) { _, pose in
            guard let pose else { return }
            analyzer.analyze(pose)
        }
        .sheet(isPresented: $showStats) { StatsView(session: analyzer.session) }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // フェーズ表示
            if isSessionActive {
                Text(analyzer.phase.displayName)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(analyzer.phase.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.6))
                    .clipShape(Capsule())
            }

            Spacer()

            // ピッチカウント
            if isSessionActive {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(analyzer.session.totalPitches) \(String(localized: "pitches"))")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(String(format: "%.0f%% \(String(localized: "hit"))", analyzer.session.hitRate))
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // カメラ切替
            Button {
                camera.flipCamera()
            } label: {
                Image(systemName: camera.isBackCamera ? "camera.rotate" : "camera.rotate.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.5))
                    .clipShape(Circle())
            }

            // 統計
            if isSessionActive && analyzer.session.totalPitches > 0 {
                Button { showStats = true } label: {
                    Image(systemName: "chart.bar")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.5))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }

    // MARK: - Timing Banner

    private func timingBanner(_ result: TimingResult) -> some View {
        Text(result.label)
            .font(.system(size: 44, weight: .black, design: .rounded))
            .foregroundStyle(result.color)
            .shadow(color: result.color.opacity(0.8), radius: 20)
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.3), value: analyzer.showTimingResult)
    }

    // MARK: - Form Score Bar

    private var formScoreBar: some View {
        HStack(spacing: 8) {
            FormBar(label: String(localized: "Stance"),   value: analyzer.session.formScore.stance)
            FormBar(label: String(localized: "Hip"),      value: analyzer.session.formScore.hipRotation)
            FormBar(label: String(localized: "Head"),     value: analyzer.session.formScore.headStability)
            FormBar(label: String(localized: "Follow"),   value: analyzer.session.formScore.followThrough)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.55))
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 12) {
            // 球種 & 球速
            HStack(spacing: 8) {
                // 球種
                ForEach(PitchType.allCases) { pt in
                    Button {
                        pitchType = pt
                    } label: {
                        Text(pt.displayName)
                            .font(.caption)
                            .bold()
                            .foregroundStyle(pitchType == pt ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(pitchType == pt ? Color.white : Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                // 球速
                ForEach(PitchSpeed.allCases) { sp in
                    Button {
                        pitchSpeed = sp
                    } label: {
                        Text(sp.displayName)
                            .font(.caption)
                            .bold()
                            .foregroundStyle(pitchSpeed == sp ? .black : .white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(pitchSpeed == sp ? Color.yellow : Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            // メインボタン
            HStack(spacing: 12) {
                if isSessionActive {
                    // PITCH ボタン
                    Button {
                        throwPitch()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "baseball")
                            Text(String(localized: "PITCH!"))
                                .font(.system(size: 20, weight: .black))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // セッション終了
                    Button {
                        endSession()
                    } label: {
                        Text(String(localized: "End"))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(.red.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                } else {
                    // セッション開始
                    Button {
                        startSession()
                    } label: {
                        Text(String(localized: "Start Session"))
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.black.opacity(0.75))
        .padding(.bottom, 0)
    }

    // MARK: - Actions

    private func setupBallScene() {
        ballScene.onBallAtContact = { [self] time in
            analyzer.onBallAtContact(time: time)
        }
        ballScene.onBallPassed = { [self] in
            analyzer.onBallPassed()
        }
    }

    private func startSession() {
        analyzer.startSession()
        isSessionActive = true
    }

    private func endSession() {
        analyzer.stopSession()
        isSessionActive = false
        ballScene.reset()
        if analyzer.session.totalPitches > 0 { showStats = true }
    }

    private func throwPitch() {
        guard !analyzer.isBallInFlight else { return }
        analyzer.onBallThrown()
        ballScene.throwPitch(type: pitchType, speed: pitchSpeed)
    }
}

// MARK: - Form Bar

struct FormBar: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.6))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.15))
                    .frame(width: 50, height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor)
                    .frame(width: 50 * value / 100, height: 6)
            }
            Text(String(format: "%.0f", value))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var barColor: Color {
        switch value {
        case 70...: return .green
        case 40...: return .yellow
        default:    return .red
        }
    }
}

// MARK: - Stats View

struct StatsView: View {
    let session: SwingSession
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.08, blue: 0.12).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // グレード
                        VStack(spacing: 4) {
                            Text(session.formScore.grade)
                                .font(.system(size: 80, weight: .black, design: .rounded))
                                .foregroundStyle(.yellow)
                            Text(String(localized: "Overall Grade"))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.top, 20)

                        // ヒット率
                        HStack(spacing: 24) {
                            StatCard(title: String(localized: "Pitches"), value: "\(session.totalPitches)")
                            StatCard(title: String(localized: "Hit Rate"), value: String(format: "%.0f%%", session.hitRate))
                            StatCard(title: String(localized: "Avg Error"), value: String(format: "%.0fms", session.avgTimingError))
                        }

                        // フォームスコア
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "Form Analysis"))
                                .font(.headline)
                                .foregroundStyle(.white)

                            ScoreRow(label: String(localized: "Stance"),        value: session.formScore.stance)
                            ScoreRow(label: String(localized: "Hip Rotation"),  value: session.formScore.hipRotation)
                            ScoreRow(label: String(localized: "Head Stability"),value: session.formScore.headStability)
                            ScoreRow(label: String(localized: "Follow Through"),value: session.formScore.followThrough)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        // タイミング履歴
                        if !session.timingResults.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(localized: "Timing History"))
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 6) {
                                    ForEach(session.timingResults.indices, id: \.self) { i in
                                        Text(session.timingResults[i].label)
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(session.timingResults[i].color)
                                            .padding(4)
                                            .frame(maxWidth: .infinity)
                                            .background(session.timingResults[i].color.opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("SwingCheck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 28, weight: .black)).foregroundStyle(.white)
            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ScoreRow: View {
    let label: String
    let value: Double
    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.white.opacity(0.8)).frame(width: 130, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.12)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4).fill(scoreColor).frame(width: geo.size.width * value / 100, height: 8)
                }
            }.frame(height: 8)
            Text(String(format: "%.0f", value)).font(.caption).bold().foregroundStyle(.white).frame(width: 32, alignment: .trailing)
        }
    }
    private var scoreColor: Color { value >= 70 ? .green : value >= 40 ? .yellow : .red }
}
