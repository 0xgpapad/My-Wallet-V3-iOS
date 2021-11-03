// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import ComponentLibrary
import SwiftUI

struct ButtonExamplesView: View {

    private let data: NavigationLinkProviderList = [
        "Icons": [
            NavigationLinkProvider(view: IconButtonExamples(), title: "👤 IconButton"),
            NavigationLinkProvider(view: CircularIconButtonExamples(), title: "⚪️ CircularIconButton")
        ],
        "Single Buttons": [
            NavigationLinkProvider(view: PrimaryButtonExamplesView(), title: "PrimaryButton"),
            NavigationLinkProvider(view: SmallPrimaryButtonExamplesView(), title: "SmallPrimaryButton"),
            NavigationLinkProvider(view: SecondaryButtonExamplesView(), title: "SecondaryButton"),
            NavigationLinkProvider(view: SmallSecondaryButtonExamplesView(), title: "SmallSecondaryButton"),
            NavigationLinkProvider(view: MinimalButtonExamplesView(), title: "MinimalButton"),
            NavigationLinkProvider(view: SmallMinimalButtonExamplesView(), title: "SmallMinimalButton"),
            NavigationLinkProvider(view: ExchangeBuyButtonExamplesView(), title: "ExchangeBuyButton"),
            NavigationLinkProvider(view: ExchangeSellButtonExamplesView(), title: "ExchangeSellButton")
        ],
        "Multi Buttons": []
    ]

    var body: some View {
        NavigationLinkProviderView(data: data)
    }
}

struct ButtonExamplesView_Previews: PreviewProvider {
    static var previews: some View {
        PrimaryNavigationView {
            ButtonExamplesView()
        }
    }
}
