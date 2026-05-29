import SwiftUI
import Vision

struct PoseOverlayView: View {
    let pose: BodyPose
    let isFrontCamera: Bool

    private let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
        (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.neck, .nose)
    ]

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let w = size.width
                let h = size.height

                func toScreen(_ pt: CGPoint) -> CGPoint {
                    let x = isFrontCamera ? (1 - pt.x) * w : pt.x * w
                    return CGPoint(x: x, y: pt.y * h)
                }

                // 骨格ライン
                for (a, b) in connections {
                    guard let pa = pose.point(a), let pb = pose.point(b) else { continue }
                    var path = Path()
                    path.move(to: toScreen(pa))
                    path.addLine(to: toScreen(pb))
                    ctx.stroke(path, with: .color(.green.opacity(0.75)), lineWidth: 2)
                }

                // ジョイント点
                for (_, pt) in pose.joints {
                    let sp = toScreen(pt)
                    let rect = CGRect(x: sp.x - 3, y: sp.y - 3, width: 6, height: 6)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.green))
                }
            }
        }
    }
}
