//
//  BaseTableViewController.swift
//  PlatformUIKit
//
//  Created by Daniel Huri on 30/03/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//
import RxSwift
import RxCocoa

open class BaseTableViewController: BaseScreenViewController {

    // MARK: - Public UI Elements
    
    @IBOutlet public var tableView: SelfSizingTableView!

    // MARK: - Private UI Elements

    @IBOutlet private var buttonStackView: UIStackView!
    @IBOutlet private var bottomContainerView: UIView!
    @IBOutlet private var scrollView: UIScrollView!

    // MARK: - Public UI Constraints
    
    @IBOutlet public var tableViewBottomConstraint: NSLayoutConstraint!

    // MARK: - Setup
    
    public init() {
        super.init(nibName: BaseTableViewController.objectName, bundle: BaseTableViewController.bundle)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.keyboardDismissMode = .interactive
    }

    public func addButton(with viewModel: ButtonViewModel) {
        let buttonView = ButtonView()
        buttonView.viewModel = viewModel
        buttonStackView.addArrangedSubview(buttonView)
        buttonView.layout(dimension: .height, to: 48)
    }

    private let _contentSizeDisposeBag = DisposeBag()

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.availableHeight = scrollView.frame.height
        tableView.unavailableHeight = bottomContainerView.frame.height
    }
}
