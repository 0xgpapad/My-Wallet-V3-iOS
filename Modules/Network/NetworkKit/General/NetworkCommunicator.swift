// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import AnalyticsKit
import Combine
import DIKit

protocol NetworkCommunicatorAPI {

    /// Performs network requests
    /// - Parameter request: the request object describes the network request to be performed
    func dataTaskPublisher(
        for request: NetworkRequest
    ) -> AnyPublisher<ServerResponse, NetworkError>
}

final class NetworkCommunicator: NetworkCommunicatorAPI {

    // MARK: - Private properties

    private let session: NetworkSession
    private let queue: DispatchQueue
    private let authenticator: AuthenticatorAPI?
    private let eventRecorder: AnalyticsEventRecording?

    // MARK: - Setup

    init(session: NetworkSession = resolve(),
         sessionDelegate: SessionDelegateAPI = resolve(),
         sessionHandler: NetworkSessionDelegateAPI = resolve(),
         queue: DispatchQueue = DispatchQueue.global(qos: .background),
         authenticator: AuthenticatorAPI? = nil,
         eventRecorder: AnalyticsEventRecording? = nil) {
        self.session = session
        self.queue = queue
        self.authenticator = authenticator
        self.eventRecorder = eventRecorder

        sessionDelegate.delegate = sessionHandler
    }

    // MARK: - Internal methods

    func dataTaskPublisher(
        for request: NetworkRequest
    ) -> AnyPublisher<ServerResponse, NetworkError> {
        guard request.authenticated else {
            return execute(request: request)
        }
        guard let authenticator = authenticator else {
            fatalError("Authenticator missing")
        }
        let execute = self.execute
        return authenticator
            .authenticate { [execute] token in
                execute(request.adding(authenticationToken: token))
            }
    }

    // MARK: - Private methods

    private func execute(
        request: NetworkRequest
    ) -> AnyPublisher<ServerResponse, NetworkError> {
        session.erasedDataTaskPublisher(for: request.urlRequest)
            .mapError(NetworkError.urlError)
            .flatMap { elements -> AnyPublisher<ServerResponse, NetworkError> in
                request.responseHandler.handle(elements: elements, for: request)
            }
            .eraseToAnyPublisher()
            .recordErrors(on: eventRecorder, request: request) { request, error -> AnalyticsEvent? in
                error.analyticsEvent(for: request) { serverErrorResponse in
                    request.decoder.decodeFailureToString(errorResponse: serverErrorResponse)
                }
            }
            .subscribe(on: queue)
            .eraseToAnyPublisher()
    }
}

protocol NetworkSession {

    func erasedDataTaskPublisher(
        for request: URLRequest
    ) -> AnyPublisher<(data: Data, response: URLResponse), URLError>
}

extension URLSession: NetworkSession {

    func erasedDataTaskPublisher(
        for request: URLRequest
    ) -> AnyPublisher<(data: Data, response: URLResponse), URLError> {
        dataTaskPublisher(for: request)
            .eraseToAnyPublisher()
    }
}

extension AnyPublisher where Output == ServerResponse,
                             Failure == NetworkError {

    fileprivate func recordErrors(
        on recorder: AnalyticsEventRecording?,
        request: NetworkRequest,
        errorMapper: @escaping (NetworkRequest, NetworkError) -> AnalyticsEvent?
    ) -> AnyPublisher<ServerResponse, NetworkError> {
        handleEvents(
            receiveCompletion: { completion in
                guard case .failure(let communicatorError) = completion else {
                    return
                }
                guard let event = errorMapper(request, communicatorError) else {
                    return
                }
                recorder?.record(event: event)
            }
        )
        .eraseToAnyPublisher()
    }
}
