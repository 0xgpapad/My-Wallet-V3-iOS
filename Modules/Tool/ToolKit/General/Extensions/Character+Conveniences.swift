//
//  Character+Conveniences.swift
//  ToolKit
//
//  Created by Daniel Huri on 27/01/2020.
//  Copyright © 2020 Blockchain Luxembourg S.A. All rights reserved.
//

import Foundation

extension Character {
    public func inSet(characterSet: CharacterSet) -> Bool {
        CharacterSet(charactersIn: "\(self)").isSubset(of: characterSet)
    }
}
