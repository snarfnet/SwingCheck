import SpriteKit
import UIKit

final class BallScene: SKScene {
    var onBallAtContact: ((CFTimeInterval) -> Void)?
    var onBallPassed: (() -> Void)?

    private var ball: SKNode?

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) { fatalError() }

    func throwPitch(type: PitchType, speed: PitchSpeed) {
        ball?.removeAllActions()
        ball?.removeFromParent()

        let container = SKNode()
        addChild(container)
        ball = container

        // ボール本体（白い円 + 縫い目の赤線）
        let radius: CGFloat = 7
        let circle = SKShapeNode(circleOfRadius: radius)
        circle.fillColor = .white
        circle.strokeColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        circle.lineWidth = 1
        container.addChild(circle)

        // 縫い目（赤い弧）
        let seam = SKShapeNode()
        let seamPath = CGMutablePath()
        seamPath.addArc(center: CGPoint(x: -2, y: 0), radius: 5, startAngle: .pi * 0.2, endAngle: .pi * 0.8, clockwise: false)
        seamPath.addArc(center: CGPoint(x: 2, y: 0), radius: 5, startAngle: .pi * 1.2, endAngle: .pi * 1.8, clockwise: false)
        seam.path = seamPath
        seam.strokeColor = UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1)
        seam.lineWidth = 1.2
        seam.fillColor = .clear
        container.addChild(seam)

        let startX = size.width * 0.5
        let startY = size.height * 0.62
        container.position = CGPoint(x: startX, y: startY)
        container.setScale(0.3)

        let dur = speed.duration

        // 終点（球種で変える）
        let endX: CGFloat
        let endY: CGFloat = size.height * 0.22
        switch type {
        case .straight: endX = size.width * 0.5
        case .curve:    endX = size.width * 0.33
        case .slider:   endX = size.width * 0.67
        }

        // 曲線パス
        let path = CGMutablePath()
        path.move(to: CGPoint(x: startX, y: startY))
        let ctrlX: CGFloat = type == .curve ? startX - 40 : (type == .slider ? startX + 40 : startX)
        let ctrlY = (startY + endY) * 0.55
        path.addQuadCurve(to: CGPoint(x: endX, y: endY),
                          control: CGPoint(x: ctrlX, y: ctrlY))

        let move = SKAction.follow(path, asOffset: false, orientToPath: false, duration: dur)
        move.timingMode = .easeIn

        let grow = SKAction.scale(to: 2.8, duration: dur)
        grow.timingMode = .easeIn

        // 回転（縫い目のアニメーション）
        let rotate = SKAction.repeatForever(SKAction.rotate(byAngle: .pi * 2, duration: 0.4))
        circle.run(rotate)

        // コールバック
        let contactAt = dur * 0.78
        let contactAction = SKAction.sequence([
            SKAction.wait(forDuration: contactAt),
            SKAction.run { [weak self] in self?.onBallAtContact?(CACurrentMediaTime()) }
        ])

        let passAction = SKAction.sequence([
            SKAction.wait(forDuration: dur + 0.15),
            SKAction.run { [weak self] in self?.onBallPassed?() },
            SKAction.removeFromParent()
        ])

        container.run(SKAction.group([move, grow, contactAction, passAction]))
    }

    func reset() {
        ball?.removeAllActions()
        ball?.removeFromParent()
        ball = nil
    }
}
