// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine
import NetworkKit

/// A potential SMS service error
public enum SMSServiceError: LocalizedError {

    /// missing credentials
    case missingCredentials(MissingCredentialsError)

    /// other network errors
    case networkError(NetworkError)
}

public protocol SMSServiceAPI: AnyObject {
    /// Requests SMS OTP
    func request(isResend: Bool) -> AnyPublisher<Void, SMSServiceError>
}
