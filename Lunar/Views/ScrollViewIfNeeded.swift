// MIT License
//
// Copyright (c) 2021 Daniel Klöck
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import SwiftUI

// MARK: - ScrollViewIfNeeded

public struct ScrollViewIfNeeded<Content>: View where Content: View {
    // MARK: Lifecycle

    /// Creates a new instance that's scrollable in the direction of the given
    /// axis and can show indicators while scrolling if the
    /// Content's size is greater than the ScrollView's.
    ///
    /// - Parameters:
    ///   - axes: The scroll view's scrollable axis. The default axis is the
    ///     vertical axis.
    ///   - showsIndicators: A Boolean value that indicates whether the scroll
    ///     view displays the scrollable component of the content offset, in a way
    ///     suitable for the platform. The default value for this parameter is
    ///     `true`.
    ///   - content: The view builder that creates the scrollable view.
    public init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    // MARK: Public

    /// The scroll view's content.
    public var content: Content

    /// The scrollable axes of the scroll view.
    ///
    /// The default value is ``Axis/vertical``.
    public var axes: Axis.Set

    /// A value that indicates whether the scroll view displays the scrollable
    /// component of the content offset, in a way that's suitable for the
    /// platform.
    ///
    /// The default is `true`.
    public var showsIndicators: Bool

    public var body: some View {
        GeometryReader { geometryReader in
            ScrollView(activeScrollingDirections, showsIndicators: showsIndicators) {
                content
                    .background(
                        GeometryReader {
                            // calculate size by consumed background and store in
                            // view preference
                            Color.clear.preference(
                                key: ViewSizeKey.self,
                                value: $0.frame(in: .local).size
                            )
                        }
                    )
            }
            .onPreferenceChange(ViewSizeKey.self) {
                fitsVertically = $0.height <= geometryReader.size.height
                fitsHorizontally = $0.width <= geometryReader.size.width
            }
        }
    }

    // MARK: Internal

    var activeScrollingDirections: Axis.Set {
        axes.intersection((fitsVertically ? [] : Axis.Set.vertical).union(fitsHorizontally ? [] : Axis.Set.horizontal))
    }

    // MARK: Private

    private struct ViewSizeKey: PreferenceKey {
        static var defaultValue: CGSize { .zero }

        static func reduce(value: inout Value, nextValue: () -> Value) {
            let next = nextValue()
            value = CGSize(
                width: value.width + next.width,
                height: value.height + next.height
            )
        }
    }

    @State private var fitsVertically = false
    @State private var fitsHorizontally = false
}

// MARK: - ScrollViewIfNeeded_Previews

struct ScrollViewIfNeeded_Previews: PreviewProvider {
    static var previews: some View {
        ScrollViewIfNeeded {
            Text("Fits")
                .background(Color.blue)
        }
        .previewLayout(.fixed(width: 100, height: 100))
        .previewDisplayName("Fits")

        ScrollViewIfNeeded([.horizontal, .vertical]) {
            VStack {
                ForEach(1 ... 50, id: \.self) {
                    Text("\($0)")
                        .frame(width: 30, height: 30)
                        .background(Color.blue)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .previewLayout(.fixed(width: 100, height: 100))
        .previewDisplayName("Fits horizontally")

        ScrollViewIfNeeded([.horizontal, .vertical]) {
            HStack {
                ForEach(1 ... 50, id: \.self) {
                    Text("\($0)")
                        .frame(width: 30, height: 30)
                        .background(Color.blue)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .previewLayout(.fixed(width: 100, height: 100))
        .previewDisplayName("Fits vertically")

        ScrollViewIfNeeded([.horizontal, .vertical]) {
            HStack {
                ForEach(1 ... 50, id: \.self) {
                    Text("\($0)")
                        .frame(width: 30, height: 30 * CGFloat($0))
                        .background(Color.blue)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .previewLayout(.fixed(width: 100, height: 100))
        .previewDisplayName("Does not fit")

        ScrollViewIfNeeded(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(1 ... 50, id: \.self) {
                    Text("\($0)")
                        .frame(width: 30, height: 30 * CGFloat($0))
                        .background(Color.blue)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .previewLayout(.fixed(width: 100, height: 100))
        .previewDisplayName("Only horizontal scrolling enabled")

        ScrollViewIfNeeded {
            HStack {
                ForEach(1 ... 50, id: \.self) {
                    Text("\($0)")
                        .frame(width: 30, height: 30 * CGFloat($0))
                        .background(Color.blue)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .previewLayout(.fixed(width: 100, height: 100))
        .previewDisplayName("Only vertical scrolling enabled")
    }
}

// MARK: - OverflowContentViewModifier

var menuOverflowSetter: DispatchWorkItem? {
    didSet { oldValue?.cancel() }
}

// MARK: - OverflowContentViewModifier

struct OverflowContentViewModifier: ViewModifier {
    // MARK: Internal

    @EnvironmentObject var env: EnvState

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geom in
                    Color.clear.onAppear {
                        menuOverflowSetter = mainAsyncAfter(ms: 500) {
                            contentOverflow = geom.size.height + MENU_VERTICAL_PADDING > env.menuMaxHeight
                        }
                        withAnimation(.fastSpring) {
                            env.menuHeight = geom.size.height
                        }
                    }
                    .onChange(of: geom.size.height) { height in
                        menuOverflowSetter = mainAsyncAfter(ms: 500) {
                            contentOverflow = height + MENU_VERTICAL_PADDING > env.menuMaxHeight
                        }
                        withAnimation(.fastSpring) {
                            env.menuHeight = height
                        }
                    }
                }
            )
            .wrappedInScrollView(when: contentOverflow)
    }

    // MARK: Private

    @State private var contentOverflow = false
}

extension View {
    @ViewBuilder
    func wrappedInScrollView(when condition: Bool) -> some View {
        if condition {
            ScrollView(.vertical, showsIndicators: false) {
                self
            }
        } else {
            self
        }
    }
}

extension View {
    func scrollOnOverflow() -> some View {
        modifier(OverflowContentViewModifier())
    }
}
