//
//  AnnouncementRecord+Key.swift
//  Blockchain
//
//  Created by Daniel Huri on 23/08/2019.
//  Copyright © 2019 Blockchain Luxembourg S.A. All rights reserved.
//

extension AnnouncementRecord {
    
    public enum Key: String, CaseIterable {
        
        // MARK: - Persistent
        
        case walletIntro = "announcement-cache-wallet-intro"
        case verifyEmail = "announcement-cache-email-verification"
        case blockstackAirdropRegisteredMini = "announcement-cache-stx-registered-airdrop-mini"
        case simpleBuyPendingTransaction = "announcement-simple-buy-pending-transaction"
        case simpleBuyKYCIncomplete = "announcement-simple-buy-kyc-incomplete"
        
        // MARK: - Periodic
        
        case backupFunds = "announcement-cache-backup-funds"
        case twoFA = "announcement-cache-2fa"
        case buyBitcoin = "announcement-cache-buy-btc"
        case transferBitcoin = "announcement-cache-transfer-btc"
        case kycAirdrop = "announcement-cache-kyc-airdrop"
        case swap = "announcement-cache-swap"
        
        // MARK: - One Time
        
        case blockstackAirdropReceived = "announcement-cache-kyc-stx-airdrop-received"
        case identityVerification = "announcement-cache-identity-verification"
        case pax = "announcement-cache-pax"
        case exchange = "announcement-cache-pit"
        case bitpay = "announcement-cache-bitpay"
        case resubmitDocuments = "announcement-cache-resubmit-documents"
    }
    
    @available(*, deprecated, message: "`LegacyKey` was superseded by `Key` and is not being used anymore.")
    enum LegacyKey: String {
        
        case shouldHidePITLinkingCard
        case hasSeenPAXCard
        
        var key: Key? {
            switch self {
            case .hasSeenPAXCard:
                return .pax
            case .shouldHidePITLinkingCard:
                return .exchange
            }
        }
    }
}

