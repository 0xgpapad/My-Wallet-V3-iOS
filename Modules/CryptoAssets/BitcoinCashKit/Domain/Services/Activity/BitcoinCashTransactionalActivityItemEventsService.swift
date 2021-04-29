// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import DIKit
import PlatformKit
import RxSwift

public final class BitcoinCashTransactionalActivityItemEventsService: TransactionalActivityItemEventFetcherAPI {
    
    public typealias PageModel = PageResult<TransactionalActivityItemEvent>
    
    private let transactionsService: BitcoinCashHistoricalTransactionService
    
    public init(transactionsService: BitcoinCashHistoricalTransactionService = resolve()) {
        self.transactionsService = transactionsService
    }
    
    public func fetchTransactionalActivityEvents(token: String?, limit: Int) -> Single<PageModel> {
        transactionsService
            .fetchTransactions(token: nil, size: 50)
            .map(weak: self) { (self, output) -> PageResult<TransactionalActivityItemEvent> in
                let items = output.items.map { $0.activityItemEvent }
                return PageResult(
                    hasNextPage: items.count == limit,
                    items: items
                )
            }
    }
}

extension BitcoinCashHistoricalTransaction {
    fileprivate var activityItemEvent: TransactionalActivityItemEvent {
        var status: TransactionalActivityItemEvent.EventStatus
        switch isConfirmed {
        case true:
            status = .complete
        case false:
            status = .pending(
                confirmations: .init(
                    current: confirmations,
                    total: BitcoinCashHistoricalTransaction.requiredConfirmations
                )
            )
        }
        return .init(identifier: identifier,
                     creationDate: createdAt,
                     status: status,
                     type: direction == .debit ? .receive : .send,
                     amount: amount
        )
    }
}
