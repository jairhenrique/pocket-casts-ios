import SwiftUI

/// A horizontal carousel view with next item "peeking" support
/// - `carouselItemsToDisplay` to change how many of the `items` will be displayed per page
/// - `carouselItemSpacing` to adjust the spacing between the items
/// - `carouselPeekAmount` to control how much (if any) of the next item on the next page should display
/// Add the `currentIndex` binding to be notified when the page changes
struct HorizontalCarousel<Content: View, T: Identifiable>: View {
    /// Binding for the currently selected index
    @Binding private var index: Int

    /* Internal properties */
    private var itemsToDisplay = 1
    private var spacing: Double = 0
    private var peekAmount: PeekAmount = .constant(10)

    private let items: [T]
    private let content: (T) -> Content

    /// An offset amount set by the gesture used to move the items in the stack during a drag
    @GestureState private var gestureOffset: Double = 0

    /// Internal tracking of the visible index used to calculate the offset
    @State private var visibleIndex = 0

    init(currentIndex: Binding<Int>? = .constant(0), items: [T], @ViewBuilder content: @escaping (T) -> Content) {
        self._index = currentIndex ?? .constant(0)
        self.items = items
        self.content = content
    }

    /// Sets the number of items to display per page
    func carouselItemsToDisplay(_ value: Int) -> Self {
        update { carousel in
            carousel.itemsToDisplay = value.clamped(to: 0..<items.count)
        }
    }

    /// Sets the spacing between each item and the leading/trailing margins
    func carouselItemSpacing(_ value: CGFloat) -> Self {
        update { carousel in
            carousel.spacing = max(0, value)
        }
    }

    /// The amount the next item to display
    func carouselPeekAmount(_ value: PeekAmount) -> Self {
        update { carousel in
            carousel.peekAmount = value
        }
    }

    /// The max total number of pages to be able to swipe through
    private var maxPages: Int {
        items.count - itemsToDisplay
    }

    var body: some View {
        GeometryReader { proxy in
            let baseWidth = proxy.size.width - spacing

            let peekAmount: Double = {
                guard maxPages > 1 else {
                    return 0
                }

                switch self.peekAmount {
                case let .constant(value):
                    return value

                case let .percent(value):
                    return baseWidth * value
                }
            }()

            // Calculate the item size to be the width minus the trailing spacing and the trailing peek amount
            let itemWidth = (baseWidth - peekAmount) / CGFloat(itemsToDisplay)

            // The current X offset to apply to the HStack
            // This is what gives the appearance of scrolling since it pairs with the drag gesture offset
            // This uses negative values because we're moving the base X position to the left
            let offsetX: CGFloat = {
                let isLast = visibleIndex == maxPages

                // Add the leading padding and calculate the current item offset
                var x = spacing + (CGFloat(visibleIndex) * -itemWidth)

                // If we're displaying the last item, then adjust the offset so we show the peek on the leading side
                if isLast {
                    x += peekAmount
                }

                // Apply the gesture offset so the view updates
                x += gestureOffset

                return x
            }()

            // The actual carousel
            HStack(spacing: spacing) {
                ForEach(items) { item in
                    content(item)
                        // Update each items width according to the calculated width above
                        // We apply the spacing again to apply the trailing spacing
                        .frame(width: max(0, itemWidth - spacing))
                }
            }
            // Apply a little spring animation while gesturing so it doesn't feel so ... boring ... but not too much
            // to make the entire thing spring around. To add more springyness up the damping
            .animation(.interpolatingSpring(stiffness: 350, damping: 30, initialVelocity: 10), value: gestureOffset)
            .offset(x: offsetX)
            .highPriorityGesture(
                DragGesture()
                // When the gesture is done, we use the predictedEnd calculate the next page based on the
                // gestures momentum
                    .onEnded { value in
                        let endIndex = calculateIndex(value.predictedEndTranslation, itemWidth: itemWidth)

                        // We're done animating so snap to the next index
                        visibleIndex = endIndex
                        index = endIndex
                    }
                    .onChanged { value in
                        // Inform the listening of index changes while we're dragging
                        index = calculateIndex(value.translation, itemWidth: itemWidth)
                    }
                    // Keep track of the gesture's offset so we can "scroll"
                    .updating($gestureOffset, body: { value, state, _ in
                        state = value.translation.width
                    })
            )
        }
    }

    /// Calculate the current index based on the given translation and item widths
    private func calculateIndex(_ translation: CGSize, itemWidth: CGFloat) -> Int {
        let offset = (-translation.width / itemWidth).rounded()

        return (visibleIndex + Int(offset))
            // Keep the next page within the page bounds
            .clamped(to: 0..<maxPages)
            // Prevent the next page from being more than page item away
            .clamped(to: visibleIndex-itemsToDisplay..<visibleIndex+itemsToDisplay)
    }


    /// Passes a mutable version of self to the block and returns the modified version
    private func update(_ block: (inout Self) -> Void) -> Self {
        var mutableSelf = self
        block(&mutableSelf)
        return mutableSelf
    }

    enum PeekAmount {
        /// A static peek value
        case constant(Double)

        /// A dynamic value based off the total carousel width
        /// A value between 0 and 1
        /// Ex: 0.1 will have the peek take up 10% of the total carousel width
        case percent(Double)
    }
}

// MARK: - Preview

struct HorizontalCarousel_Preview: PreviewProvider {
    static var previews: some View {
        ContainerView()
    }

    private struct ColorItem: Identifiable {
        let color: Color
        var id: String {
            color.description
        }
    }

    struct ContainerView: View {
        @State var peek: CGFloat = 50
        @State var spacing: CGFloat = 20
        @State var items: CGFloat = 1
        @State var isConstant: Bool = true

        var body: some View {
            let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
            let pages: [ColorItem] = colors.map { ColorItem(color: $0) }

            VStack {
                Spacer()

                VStack {
                    HStack {
                        Text("Peek Type")
                        Spacer()
                        Button("Constant Amount") {
                            isConstant = true
                            peek = 10
                        }
                        .padding(5)
                        .background((isConstant ? Color.blue : Color.clear).cornerRadius(10))
                        .foregroundColor(isConstant ? Color.white : nil)

                        Button("Percentage") {
                            isConstant = false
                            peek = 0.1
                        }
                        .padding(5)
                        .background((!isConstant ? Color.blue : Color.clear).cornerRadius(10))
                        .foregroundColor(!isConstant ? Color.white : nil)

                    }
                    HStack {
                        Text("Peek Amount")
                        if isConstant {
                            Slider(value: $peek, in: 0...200)
                        } else {
                            Slider(value: $peek, in: 0...0.5)
                        }
                        Text("\(peek)")
                    }

                    HStack {
                        Text("Item Spacing")
                        Slider(value: $spacing, in: 0...50)
                        Text("\(spacing)")
                    }

                    HStack {
                        Text("Items Per Page")
                        Slider(value: $items, in: 1...20)
                        Text("\(Int(items))")
                    }
                }.padding()

                HorizontalCarousel(items: pages) { item in
                    Rectangle()
                        .cornerRadius(5)
                        .foregroundColor(item.color)
                }
                .carouselItemsToDisplay(Int(items))
                .carouselItemSpacing(spacing)
                .carouselPeekAmount(
                    isConstant ? .constant(peek) : .percent(peek)
                )
                .frame(height: 200)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }
}
