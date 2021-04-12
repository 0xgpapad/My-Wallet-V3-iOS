//
//  Rx+Accessibility.swift
//  PlatformUIKit
//
//  Created by Daniel Huri on 17/02/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import RxCocoa
import RxSwift

extension Reactive where Base: UIView {
    
    /// Bindable sink for `Accessibility`
    public var accessibility: Binder<Accessibility> {
        Binder(self.base) { view, accessibility in
            view.accessibility = accessibility
        }
    }
}
