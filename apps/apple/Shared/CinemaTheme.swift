import SwiftUI

struct CinemaButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        CinemaButtonBody(configuration: configuration, prominent: prominent)
    }
}

private struct CinemaButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let prominent: Bool
    @Environment(\.isFocused) private var focused
    @Environment(\.isEnabled) private var enabled
    var body: some View {
        configuration.label
            .padding(.horizontal, prominent ? 18 : 10)
            .padding(.vertical, 10)
            .frame(minWidth: 44, minHeight: 44)
            .foregroundStyle(prominent ? Theme.background : Theme.text)
            .background(prominent ? Theme.text : focused ? Theme.surface : .clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(focused ? .white : .clear, lineWidth: 3)
                    .padding(-4)
            }
            .opacity(!enabled ? 0.4 : configuration.isPressed ? 0.65 : 1)
    }
}

struct ChannelLogo: View {
    let channel: Channel
    var body: some View {
        AsyncImage(url: channel.logo.flatMap(URL.init(string:))) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Image(systemName: "tv").resizable().scaledToFit().padding(5)
                .foregroundStyle(Theme.accent)
        }
        .frame(width: Theme.logoSize, height: Theme.logoSize)
        .padding(6).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }
}

struct StatusBanner: View {
    let message: String
    let dismiss: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
            Text(message).font(Theme.detailFont).lineLimit(3)
            Spacer(minLength: 4)
            Button(action: dismiss) { Image(systemName: "xmark") }
                .buttonStyle(CinemaButtonStyle()).accessibilityLabel("Dismiss message")
        }.padding(Theme.contentInset).background(Color.orange.opacity(0.1))
    }
}

