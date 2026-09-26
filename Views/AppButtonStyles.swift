import SwiftUI

struct CapsuleActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let color: Color
    var foregroundColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? foregroundColor : Color.secondary)
            .background(
                Capsule()
                    .fill(isEnabled ? color.opacity(configuration.isPressed ? 0.78 : 1) : Color.secondary.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(isEnabled ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .contentShape(Capsule())
    }
}
