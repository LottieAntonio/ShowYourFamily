import SwiftUI

extension Animation {
    static let personTransition = spring(duration: 0.5, bounce: 0.3)
    static let cardTransition = spring(duration: 0.3)
    static let flyTransition = Animation.interpolatingSpring(
        mass: 1.0,
        stiffness: 100,
        damping: 15,
        initialVelocity: 0.5
    )
}