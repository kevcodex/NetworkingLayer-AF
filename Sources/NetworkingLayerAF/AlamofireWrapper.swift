//  Copyright © 2020 Kirby. All rights reserved.
//

import Alamofire
import Foundation
import NetworkingLayerCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension NetworkingLayer {
    init() {
        self.init(wrapper: AlamofireWrapper())
    }
}

/// A simple wrapper around Alamofire to abstract out the request building from client.
public struct AlamofireWrapper: Networkable {
    
    private let manager: AlamofireWrapperManager
    private let handler: AlamofireWrapperHandler

    #if !(os(watchOS) || os(Linux) || os(Windows))
    public var isConnectedToInternet: Bool {
        return Self.isConnectedToInternet
    }
    
    
    public static var isConnectedToInternet: Bool {
        return NetworkReachabilityManager()?.isReachable ?? false
    }
    #endif

    public init(manager: AlamofireWrapperManager = AlamofireWrapper.defaultManager,
                handler: AlamofireWrapperHandler = AlamofireWrapper.defaultHandler) {
        self.manager = manager
        self.handler = handler
    }
    
    // One problem is cancelling a task. Might want a wrapper that creates a task then sends.
    public func send<Request: NetworkRequest>(request: Request,
                                              callbackQueue: DispatchQueue = .main,
                                              progressHandler: ProgressHandler? = nil) async throws -> NetworkResponse {
        guard let urlRequest = request.buildURLRequest() else {
            throw NetworkResponseError.badRequest(message: "Bad URL Request")
        }
        
        switch request.requestType {
        case .requestData:
            return try await handler.handleDataRequest(for: urlRequest,
                                                       manager: manager,
                                                       request: request,
                                                       callbackQueue: callbackQueue,
                                                       progressHandler: progressHandler)
            
        case .download(let destination):
            return try await handler.handleDownloadRequest(for: urlRequest,
                                                           manager: manager,
                                                           request: request,
                                                           callbackQueue: callbackQueue,
                                                           destination: destination,
                                                           progressHandler: progressHandler)
            
            
        case .uploadMultipart(let body):
            return try await handler.handleUploadMultipart(for: urlRequest,
                                                           multipartBody: body,
                                                           manager: manager,
                                                           request: request,
                                                           callbackQueue: callbackQueue,
                                                           usingThreshold: MultipartFormData.encodingMemoryThreshold,
                                                           uploadProgressHandler: progressHandler)
        }
    }
    
    /// Send a request to expect data from response.
    /// - Parameter callbackQueue: nil will default to main.
    @discardableResult
    public func send<Request: NetworkRequest>(request: Request,
                                              callbackQueue: DispatchQueue = .main,
                                              progressHandler: ProgressHandler? = nil,
                                              completion: @escaping (Swift.Result<NetworkResponse, NetworkResponseError>) -> Void) -> NetworkTask? {
        
        guard let urlRequest = request.buildURLRequest() else {
            completion(.failure(.badRequest(message: "Bad URL Request")))
            return nil
        }
        
        switch request.requestType {
        case .requestData:
            return handler.handleDataRequest(for: urlRequest,
                                             manager: manager,
                                             request: request,
                                             callbackQueue: callbackQueue,
                                             progressHandler: progressHandler,
                                             completion: completion)?.task
            
        case .download(let destination):
            return handler.handleDownloadRequest(for: urlRequest,
                                                 manager: manager,
                                                 request: request,
                                                 callbackQueue: callbackQueue,
                                                 destination: destination,
                                                 progressHandler: progressHandler,
                                                 completion: completion)?.task
            
        case .uploadMultipart(let body):
            return handler.handleUploadMultipart(for: urlRequest,
                                                 multipartBody: body,
                                                 manager: manager,
                                                 request: request,
                                                 callbackQueue: callbackQueue,
                                                 usingThreshold: MultipartFormData.encodingMemoryThreshold,
                                                 uploadProgressHandler: progressHandler,
                                                 completion: completion)?.task
        }
    }
    
    // MARK: Codable Requests
    /// Makes a network request with any codable response object and will return it.
    @discardableResult
    public func send<Request: CodableRequest>(
        codableRequest: Request,
        callbackQueue: DispatchQueue = .main,
        progressHandler: ProgressHandler? = nil,
        completion: @escaping (Swift.Result<ResponseObject<Request.Response>, NetworkResponseError>) -> Void)
    -> NetworkTask? {
        
        send(request: codableRequest,
             callbackQueue: callbackQueue,
             progressHandler: progressHandler) { (result) in
            
            decode(result: result, completion: completion)
        }
    }
    
    /// Makes a network request with any codable response object and will return it.
    
    @discardableResult
    public func send<Request: CodableRequest>(
        codableRequest: Request,
        callbackQueue: DispatchQueue = .main,
        progressHandler: ProgressHandler? = nil) async throws -> ResponseObject<Request.Response> {
            
            let response = try await send(request: codableRequest,
                                          callbackQueue: callbackQueue,
                                          progressHandler: progressHandler)
            
            return try decodeSuccess(from: response)
        }
    
    @discardableResult
    public func send<Request: NetworkRequest, C: Decodable>(
        request: Request,
        codableType: C.Type,
        callbackQueue: DispatchQueue = .main,
        progressHandler: ProgressHandler? = nil) async throws
    -> ResponseObject<C> {
        
        let response = try await send(request: request,
                                      callbackQueue: callbackQueue,
                                      progressHandler: progressHandler)
        
        return try decodeSuccess(from: response)
    }
    
    @discardableResult
    public func send<Request: NetworkRequest, C: Decodable>(
        request: Request,
        codableType: C.Type,
        callbackQueue: DispatchQueue = .main,
        progressHandler: ProgressHandler? = nil,
        completion: @escaping (Swift.Result<ResponseObject<C>, NetworkResponseError>) -> Void)
    -> NetworkTask? {
        
        send(request: request,
             callbackQueue: callbackQueue,
             progressHandler: progressHandler) { (result) in
            
            decode(result: result, completion: completion)
        }
    }
    
    public func cancelAll() {
        manager.session.getAllTasks { (tasks) in
            tasks.forEach { $0.cancel() }
        }
    }
    
    private func decodeResult<C: Decodable>(
        result: Swift.Result<NetworkResponse, NetworkResponseError>) -> Swift.Result<ResponseObject<C>, NetworkResponseError> {
            
            switch result {
            case .success(let response):
                do {
                    return .success(try decodeSuccess(from: response))
                } catch {
                    return .failure(.responseParseError(error, response: response))
                }
            case .failure(let error):
                return .failure(error)
            }
        }
    
    private func decodeSuccess<C: Decodable>(from response: NetworkResponse) throws -> ResponseObject<C> {
        let decoder = JSONDecoder()
        let object = try decoder.decode(C.self, from: response.data)
        let response = ResponseObject(object: object,
                                      statusCode: response.statusCode,
                                      data: response.data,
                                      request: response.request,
                                      httpResponse: response.httpResponse)
        
        return response
    }
    
    private func decode<C: Decodable>(
        result: Swift.Result<NetworkResponse, NetworkResponseError>,
        completion: @escaping (Swift.Result<ResponseObject<C>, NetworkResponseError>) -> Void) {
            
            let decodedResult: Swift.Result<ResponseObject<C>, NetworkResponseError> = decodeResult(result: result)
            completion(decodedResult)
        }
}

extension AlamofireWrapper {
    public static let defaultHandler: AlamofireWrapperHandler = {
        return AlamofireWrapperDefaultHandler()
    }()
    
    public static let defaultManager: AlamofireWrapperManager = {
        return Session.default
    }()
}
