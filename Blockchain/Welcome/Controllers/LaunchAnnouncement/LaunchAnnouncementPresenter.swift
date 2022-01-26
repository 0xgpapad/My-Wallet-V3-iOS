// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import PlatformKit
import PlatformUIKit
import RxSwift
import ToolKit

final class LaunchAnnouncementPresenter: VersionUpdateAlertDisplaying {

    // MARK: - Properties

    private let interactor: LaunchAnnouncementInteractor
    private let alertPresenter: AlertViewPresenter

    private let disposeBag = DisposeBag()

    // MARK: - Setup

    init(
        interactor: LaunchAnnouncementInteractor = LaunchAnnouncementInteractor(),
        alertPresenter: AlertViewPresenter = .shared
    ) {
        self.alertPresenter = alertPresenter
        self.interactor = interactor
    }

    // MARK: - API

    /// Checks for announcement and displays it if needed
    func execute() {
        interactor.updateType
            .subscribe(
                onSuccess: { [weak self] update in
                    guard let self = self else { return }
                    switch update {
                    case .maintenance(let options):
                        self.alertPresenter.showMaintenanceError(from: options)
                    case .jailbrokenWarning:
                        self.alertPresenter.checkAndWarnOnJailbrokenPhones()
                    case .updateIfNeeded(let update):
                        self.displayVersionUpdateAlertIfNeeded(for: update)
                    }
                },
                onFailure: { error in
                    Logger.shared.error(error)
                }
            )
            .disposed(by: disposeBag)
    }
}
