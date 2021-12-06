// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import ComponentLibrary
import SwiftUI

public struct RootView: View {

    @State var colorScheme: ColorScheme
    @State var layoutDirection: LayoutDirection

    private let data: NavigationLinkProviderList = [
        "1 - Base": [
            NavigationLinkProvider(view: ColorsExamplesView(), title: "🌈 Colors"),
            NavigationLinkProvider(view: TypographyExamplesView(), title: "🔠 Typography"),
            NavigationLinkProvider(view: SpacingExamplesView(), title: "🔳 Spacing Rules"),
            NavigationLinkProvider(view: IconsExamplesView(), title: "🖼 Icons")
        ],
        "2 - Primitives": [
            NavigationLinkProvider(view: TabBarExamplesView(), title: "🎼 TabBar"),
            NavigationLinkProvider(view: ButtonExamplesView(), title: "🕹 Buttons"),
            NavigationLinkProvider(view: PrimaryDividerExamples(), title: "🗂 Dividers"),
            NavigationLinkProvider(view: PrimarySwitchExamples(), title: "🔌 PrimarySwitch"),
            NavigationLinkProvider(view: TagExamples(), title: "🏷 Tag"),
            NavigationLinkProvider(view: CheckboxExamples(), title: "✅ Checkbox"),
            NavigationLinkProvider(view: RichTextExamples(), title: "🤑 Rich Text"),
            NavigationLinkProvider(view: SegmentedControlExamples(), title: "🚥 SegmentedControl"),
            NavigationLinkProvider(view: InputExamples(), title: "⌨️ Input"),
            NavigationLinkProvider(view: PrimaryPickerExamples(), title: "⛏ Picker"),
            NavigationLinkProvider(view: AlertToastExamples(), title: " 🚨 AlertToast"),
            NavigationLinkProvider(view: PageControlExamples(), title: "📑 PageControl"),
            NavigationLinkProvider(view: PrimarySliderExamples(), title: "🎚 Slider"),
            NavigationLinkProvider(view: RadioExamples(), title: "🔘 Radio")
        ],
        "3 - Compositions": [
            NavigationLinkProvider(view: PrimaryNavigationExamples(), title: "✈️ Navigation"),
            NavigationLinkProvider(view: CalloutCardExamples(), title: "💬 CalloutCard"),
            NavigationLinkProvider(view: SectionHeadersExamples(), title: "🪖 SectionHeaders"),
            NavigationLinkProvider(view: RowExamplesView(), title: "🚣‍♀️ Rows"),
            NavigationLinkProvider(view: BottomSheetExamples(), title: "📄 BottomSheet"),
            NavigationLinkProvider(view: SearchBarExamples(), title: "🔎 SearchBar"),
            NavigationLinkProvider(view: AlertCardExamples(), title: "🌋 AlertCard")
        ]
    ]

    public init(colorScheme: ColorScheme = .light, layoutDirection: LayoutDirection = .leftToRight) {
        _colorScheme = State(initialValue: colorScheme)
        _layoutDirection = State(initialValue: layoutDirection)
    }

    public var body: some View {
        PrimaryNavigationView {
            NavigationLinkProviderView(data: data)
                .primaryNavigation(title: "📚 Component Library") {
                    Button(colorScheme == .light ? "🌗" : "🌓") {
                        colorScheme = colorScheme == .light ? .dark : .light
                    }

                    Button(layoutDirection == .leftToRight ? "➡️" : "⬅️") {
                        layoutDirection = layoutDirection == .leftToRight ? .rightToLeft : .leftToRight
                    }
                }
        }
        .colorScheme(colorScheme)
        .environment(\.layoutDirection, layoutDirection)
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(
            ColorScheme.allCases,
            id: \.self
        ) { colorScheme in
            RootView(colorScheme: colorScheme)
        }
    }
}
