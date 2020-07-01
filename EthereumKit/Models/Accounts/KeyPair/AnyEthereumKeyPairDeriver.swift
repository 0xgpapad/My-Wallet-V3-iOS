//
//  EthereumKeyPairDeriver.swift
//  EthereumKit
//
//  Created by Jack on 05/04/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

import PlatformKit
import RxSwift
import web3swift

public protocol EthereumKeyPairDeriverAPI: KeyPairDeriverAPI where Input == EthereumKeyDerivationInput, Pair == EthereumKeyPair {
    func derive(input: Input) -> Result<Pair, Error>
}

public class AnyEthereumKeyPairDeriver: EthereumKeyPairDeriverAPI {
    public static let shared = AnyEthereumKeyPairDeriver()
    
    private let deriver: AnyKeyPairDeriver<EthereumKeyPair, EthereumKeyDerivationInput>
    
    // MARK: - Init
    
    public convenience init() {
        self.init(with: EthereumKeyPairDeriver.shared)
    }
    
    public init<D: KeyPairDeriverAPI>(with deriver: D) where D.Input == EthereumKeyDerivationInput, D.Pair == EthereumKeyPair {
        self.deriver = AnyKeyPairDeriver<EthereumKeyPair, EthereumKeyDerivationInput>(deriver: deriver)
    }
    
    public func derive(input: EthereumKeyDerivationInput) -> Result<EthereumKeyPair, Error> {
        deriver.derive(input: input)
    }
}
