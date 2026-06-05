import SwiftUI

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .shadow(radius: 4)
    }
}

// Modifier for toast presentation
struct ToastModifier: ViewModifier {
    @Binding var message: String?
    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if let msg = message {
                ToastView(message: msg)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        dismissTask?.cancel()
                        dismissTask = Task {
                            try? await Task.sleep(for: .seconds(2.5))
                            guard !Task.isCancelled else { return }
                            withAnimation { message = nil }
                        }
                    }
                    .onDisappear {
                        dismissTask?.cancel()
                    }
            }
        }
        .animation(.spring(), value: message)
    }
}

extension View {
    func toast(message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
