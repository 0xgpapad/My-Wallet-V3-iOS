// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import NetworkError

protocol ERC20AccountAPIClientAPI {

    func fetchTransactions(
        from address: String,
        page: String?,
        contractAddress: String
    ) -> AnyPublisher<ERC20TransfersResponse, NetworkError>

    func isContract(
        address: String
    ) -> AnyPublisher<ERC20IsContractResponse, NetworkError>
}
