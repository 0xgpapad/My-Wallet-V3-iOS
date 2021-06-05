// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import PlatformUIKit
import RxCocoa
import RxSwift
import UIKit

/// This component presents to the user an address QR for a given asset.
/// Allows the user to conveniently copy or share the address.
final class AddressViewController: UIViewController {

    // MARK: - UI Properties

    @IBOutlet private var assetNameLabel: UILabel!
    @IBOutlet private var assetImageView: UIImageView!
    @IBOutlet private var qrAddressView: QRAddressView!
    @IBOutlet private var copyButtonView: ButtonView!
    @IBOutlet private var shareButtonView: ButtonView!

    @IBOutlet private var qrAddressViewTopConstraint: NSLayoutConstraint!
    @IBOutlet private var buttonsBottomConstraint: NSLayoutConstraint!

    // MARK: - Injected

    private let presenter: AddressPresenter

    private let disposeBag = DisposeBag()

    // MARK: - Lifecycle

    init(using presenter: AddressPresenter) {
        self.presenter = presenter
        super.init(nibName: String(describing: AddressViewController.self), bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        assetImageView.image = presenter.assetImage
        assetImageView.accessibility = .id(AccessibilityIdentifiers.Address.assetImageView)

        assetNameLabel.accessibility = presenter.titleAccessibility
        assetNameLabel.text = presenter.assetName
        assetNameLabel.textColor = .titleText

        copyButtonView.viewModel = presenter.copyViewModel
        shareButtonView.viewModel = presenter.shareViewModel
        qrAddressView.viewModel = presenter.qrAddressViewModel

        if Constants.Booleans.isUsingScreenSizeEqualIphone5S {
            qrAddressViewTopConstraint.constant = 20
            buttonsBottomConstraint.constant = 20
        }

        // Bind presenter address status
        presenter.status
            .filter { $0.isAwaitingFetch }
            .bind { [weak self] _ in
                self?.presenter.fetchAddress()
            }
            .disposed(by: disposeBag)

        // Bind address sharing to display activity
        presenter.addressShare
            .bind { [weak self] address in
                let viewController = UIActivityViewController(activityItems: [address],
                                                              applicationActivities: nil)
                self?.present(viewController, animated: true)
            }
            .disposed(by: disposeBag)
    }
}
