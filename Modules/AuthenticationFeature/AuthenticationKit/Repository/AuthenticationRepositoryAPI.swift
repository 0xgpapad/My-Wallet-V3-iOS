// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Combine

/// `AuthenticationRepositoryAPI` is the interface for communicating with the AuthenticationAPIClient for various data layer operations
public protocol AuthenticationRepositoryAPI {

    /// Sends a verification email to the user's email address. Thie will trigger the send GUID reminder endpoint and user will receive a link to verify their device in their inbox if they have an account registered with the email
    /// - Parameters: emailAddress: The email address of the user
    /// - Parameters: captcha: The captcha token returned from reCaptcha Service
    /// - Returns: A combine `Publisher` that emits an EmptyNetworkResponse on success or NetworkError on failure
    func sendDeviceVerificationEmail(to emailAddress: String, captcha: String) -> AnyPublisher<Void, AuthenticationServiceError>

    /// Authorize the login to the associated email identified by the email code. The email code is received by decrypting the base64 information encrypted in the magic link from the device verification email
    /// - Parameters: sessionToken: The session token stored in the repository
    /// - Parameters: emailCode: The email code for the authorization
    /// - Returns: A combine `Publisher` that emits an EmptyNetworkResponse on success or NetworkError on failure
    func authorizeLogin(sessionToken: String, emailCode: String) -> AnyPublisher<Void, AuthenticationServiceError>
}
