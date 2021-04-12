//
//  KYCInformationController.swift
//  Blockchain
//
//  Created by Maurice A. on 7/17/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit
import PlatformKit
import PlatformUIKit
import ToolKit
import UIKit

/// A reusable view for displaying static information
final class KYCInformationController: KYCBaseViewController {

    /// typealias for an action to be taken when the primary button/CTA is tapped
    typealias PrimaryButtonAction = ((KYCInformationController) -> Void)

    // MARK: - Properties

    @IBOutlet private var imageView: UIImageView!
    @IBOutlet private var labelTitle: UILabel!
    @IBOutlet private var labelSubtitle: UILabel!
    @IBOutlet private var labelDescription: UILabel!
    @IBOutlet private var buttonPrimaryContainer: PrimaryButtonContainer!

    /// Action invoked when the primary button is tapped
    var primaryButtonAction: PrimaryButtonAction?

    /// The view model
    var viewModel: KYCInformationViewModel?

    /// The view configuration for this view
    var viewConfig: KYCInformationViewConfig = KYCInformationViewConfig.defaultConfig

    private let analyticsService: AnalyticsServiceAPI = resolve()

    // MARK: Factory

    override class func make(with coordinator: KYCCoordinator) -> KYCInformationController {
        let controller: KYCInformationController = makeFromStoryboard()
        controller.coordinator = coordinator
        controller.pageType = .accountStatus
        return controller
    }

    // MARK: - IBActions

    @IBAction func dismiss(_ sender: Any) {
        dismiss(animated: true, completion: {
            self.coordinator.finish()
        })
    }

    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.hidesBackButton = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyViewModel()
        applyViewConfig()
    }

    private func applyViewModel() {
        guard let viewModel = viewModel else {
            imageView.image = nil
            labelTitle.text = ""
            labelSubtitle.superview?.removeFromSuperview()
            labelDescription.text = ""
            buttonPrimaryContainer.title = ""
            var parameters = [String: String]()
            if let presentingViewController = presentingViewController {
                parameters["presenting_view_controller"] = NSStringFromClass(
                    presentingViewController.classForCoder
                ).components(separatedBy: ".").last ?? ""
            }
            analyticsService.trackEvent(
                title: "kyc_information_controller_view_model_nil_error",
                parameters: parameters
            )
            return
        }
        imageView.image = viewModel.image
        labelTitle.text = viewModel.title
        if let subtitle = viewModel.subtitle {
            labelSubtitle.text = subtitle
        } else {
            labelSubtitle.superview?.removeFromSuperview()
        }
        labelDescription.text = viewModel.description
        buttonPrimaryContainer.title = viewModel.buttonTitle ?? ""
    }

    private func applyViewConfig() {
        labelTitle.textColor = viewConfig.titleColor
        buttonPrimaryContainer.isHidden = !viewConfig.isPrimaryButtonEnabled
        buttonPrimaryContainer.actionBlock = { [unowned self] in
            self.primaryButtonAction?(self)
        }
        if let tint = viewConfig.imageTintColor {
            imageView.tintColor = tint
        }
    }

    override func navControllerCTAType() -> NavigationCTA {
        .dismiss
    }

    override func navControllerRightBarButtonTapped(_ navController: KYCOnboardingNavigationController) {
        coordinator.handle(event: .nextPageFromPageType(pageType, nil))
    }
}
