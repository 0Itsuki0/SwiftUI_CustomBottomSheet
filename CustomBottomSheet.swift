import SwiftUI


extension View {
    @ViewBuilder
    func bottomSheet<Content: View>(
        isPresented: Binding<Bool>,
        detent: SheetDetent,
        cornerRadius: CGFloat,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self
            .fullScreenCover(
                isPresented: isPresented,
                content: {
                    BottomSheet(
                        isPresented: isPresented,
                        detent: detent,
                        cornerRadius: cornerRadius,
                        onDismiss: onDismiss,
                        content: content
                    )
                    .presentationBackground(Color.clear)
                }
            )
            .transaction({
                $0.animation = nil
                $0.disablesAnimations = true
            })
    }
}

enum SheetDetent {
    case medium
    case large
    case fraction(CGFloat)
    case height(CGFloat)

    var system: PresentationDetent {
        switch self {
        case .medium: return .medium
        case .large: return .large
        case .fraction(let f): return .fraction(f)
        case .height(let h): return .height(h)
        }
    }
}

struct BottomSheet<Content: View>: View {
    @Binding var isPresented: Bool
    let detent: SheetDetent
    let cornerRadius: CGFloat
    let onDismiss: (() -> Void)?

    @ViewBuilder
    let content: Content

    @GestureState private var drag: CGFloat = 0

    @State private var baseOffset: CGFloat = 0
    @State private var appearOffset: CGFloat = 0
    @State private var isDismissing = false

    private let animation: Animation = .spring(
        response: 0.35,
        dampingFraction: 0.8
    )
    private var downwardDrag: CGFloat {
        max(drag, 0)
    }

    private var upwardStretch: CGFloat {
        abs(min(drag, 0)) * 0.5  // resistance
    }

    var body: some View {
        GeometryReader { geo in
            let sheetHeight = resolvedHeight(in: geo)
            if isPresented || isDismissing {
                ZStack(alignment: .bottom) {
                    // Background dim + blur
                    Color.black.opacity(
                        0.2
                            * ((sheetHeight - (baseOffset + downwardDrag))
                                / sheetHeight)
                    )
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismiss(geo)
                    }

                    sheet(geo)
                }
                .onAppear {
                    // start off-screen
                    appearOffset = geo.size.height

                    // animate up
                    withAnimation(self.animation) {
                        appearOffset = 0
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .all)
    }

    private func sheet(_ geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // drag indicator
            Capsule()
                .fill(Color.black.opacity(0.2))
                .frame(width: 40, height: 6)
                .padding(.vertical, 8)

            // Actual Content
            content
        }
        .frame(
            height: resolvedHeight(in: geo) + upwardStretch,  // stretch instead of move
            alignment: .top  // if we don't have top alignment and if the content overflow, the drag indicator will get pushed off the view
        )
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: cornerRadius,
                topTrailingRadius: cornerRadius
            )
            .fill(Color(.systemBackground))
        )
        .offset(y: baseOffset + downwardDrag + appearOffset)  // only downward moves
        .gesture(
            dragGesture(geo),
            isEnabled: self.isPresented && !self.isDismissing
        )
        .animation(
            self.animation,
            value: upwardStretch
        )
        .animation(
            self.animation,
            value: baseOffset
        )
    }

    // MARK: - Gesture
    private func dragGesture(_ geo: GeometryProxy) -> some Gesture {
        DragGesture()
            .updating($drag) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let raw = value.translation.height

                // lock position BEFORE gesture resets
                baseOffset += raw

                let dismissThreshold = resolvedHeight(in: geo) * 0.2
                if raw > dismissThreshold {
                    dismiss(geo)
                } else {
                    baseOffset = 0
                }
            }
    }

    // MARK: - Dismiss
    private func dismiss(_ geo: GeometryProxy) {
        isDismissing = true
        self.onDismiss?()
        withAnimation {
            baseOffset = geo.size.height
        } completion: {
            isPresented = false
            isDismissing = false
            baseOffset = 0
            appearOffset = 0
        }
    }

    // MARK: - resolve height from detent
    private func resolvedHeight(in geo: GeometryProxy) -> CGFloat {
        let max = geo.size.height
        switch detent {
        case .large:
            return max * 0.9

        case .medium:
            return max * 0.5

        case .fraction(let f):
            return max * f

        case .height(let h):
            return h
        }
    }
}
