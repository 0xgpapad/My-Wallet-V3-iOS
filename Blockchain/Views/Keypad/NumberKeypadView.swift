// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import PlatformUIKit

protocol NumberKeypadViewDelegate: class {
    func onAddInputTapped(value: String)
    func onDelimiterTapped()
    func onBackspaceTapped()
}

@IBDesignable
class NumberKeypadView: NibBasedView {

    @IBOutlet var keypadButtons: [UIButton]!
    weak var delegate: NumberKeypadViewDelegate?
    fileprivate var feedback: UIImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    
    @IBInspectable var buttonTitleColor: UIColor = .brandPrimary {
        didSet {
            keypadButtons.forEach { button in
                button.setTitleColor(buttonTitleColor, for: .normal)
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        keypadButtons.forEach({ $0.isExclusiveTouch = true })
        keypadButtons.forEach {
            if let title = $0.titleLabel?.text {
                $0.accessibilityIdentifier = AccessibilityIdentifiers.NumberKeypadView.numberButton + "." + title
            } else {
                $0.accessibilityIdentifier = AccessibilityIdentifiers.NumberKeypadView.backspace
            }
        }
        guard let delimiter = keypadButtons.first(where: { $0.titleLabel?.text == "." }) else { return }
        delimiter.setTitle(Locale.current.decimalSeparator ?? ".", for: .normal)
        delimiter.accessibilityIdentifier = AccessibilityIdentifiers.NumberKeypadView.decimalButton
    }
    
    func updateKeypadVisibility(_ visibility: Visibility, animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let keypadButtons = keypadButtons else { return }
        guard keypadButtons.count > 0 else { return }
        
        if animated == false {
            keypadButtons.forEach({ $0.alpha = visibility.defaultAlpha })
            alpha = visibility.defaultAlpha
            completion?()
            return
        }
        
        var buttons = keypadButtons
        let transform: CGAffineTransform = visibility == .hidden ? CGAffineTransform(scaleX: 0.01, y: 0.01) : .identity
        while buttons.count > 0 {
            guard let animatedButton = buttons.randomItem() else { return }
            buttons = buttons.filter({ $0.currentTitle != animatedButton.currentTitle })
            UIView.animate(withDuration: 0.2, delay: 0.05, options: .curveEaseIn, animations: {
                animatedButton.alpha = visibility.defaultAlpha
                animatedButton.transform = transform
            }, completion: { _ in
                completion?()
            })
        }
        
        alpha = visibility.defaultAlpha
    }

    @IBAction func delimiterButtonTapped(_ sender: UIButton) {
        feedback.prepare()
        feedback.impactOccurred()
        delegate?.onDelimiterTapped()
    }
    
    @IBAction func numberButtonTapped(_ sender: UIButton) {
        guard let titleLabel = sender.titleLabel, let value = titleLabel.text else { return }
        feedback.prepare()
        feedback.impactOccurred()
        delegate?.onAddInputTapped(value: value)
    }

    @IBAction func backspaceButtonTapped(_ sender: Any) {
        feedback.prepare()
        feedback.impactOccurred()
        delegate?.onBackspaceTapped()
    }
}
