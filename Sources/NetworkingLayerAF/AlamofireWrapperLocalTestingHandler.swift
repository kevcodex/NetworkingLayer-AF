// Created by Kirby 191 on 8/4/20.
// Copyright © 2020 Kirby. All rights reserved.

import Foundation
import NetworkingLayerCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Handler that will get local test data.
struct AlamofireWrapperLocalTestingHandler: AlamofireWrapperHandler {

    
    func handleDataRequest(for urlRequest: URLRequest, manager: AlamofireWrapperManager, request: NetworkRequest, callbackQueue: DispatchQueue, progressHandler: ProgressHandler?) async throws -> NetworkResponse {
        
        guard let url = request.testURL,
              let data = try? Data(contentsOf: url) else {
                  throw NetworkResponseError.badRequest(message: "missing test data")
              }
        
        let response = NetworkResponse(statusCode: 200, data: data, request: nil, httpResponse: nil)
        
        return response
    }
    
    
    func handleDataRequest(for urlRequest: URLRequest, manager: AlamofireWrapperManager, request: NetworkRequest, callbackQueue: DispatchQueue, progressHandler: ProgressHandler?, completion: @escaping (Result<NetworkResponse, NetworkResponseError>) -> Void) -> AlamofireWrapperBaseRequest? {
        
        guard let url = request.testURL,
              let data = try? Data(contentsOf: url) else {
                  completion(.failure(.badRequest(message: "missing test data")))
                  return nil
              }
        
        let response = NetworkResponse(statusCode: 200, data: data, request: nil, httpResponse: nil)
        
        completion(.success(response))
        
        return nil
    }
    
    
    func handleDownloadRequest(for urlRequest: URLRequest, manager: AlamofireWrapperManager, request: NetworkRequest, callbackQueue: DispatchQueue, destination: DownloadDestination?, progressHandler: ProgressHandler?) async throws -> NetworkResponse {
        
        
        // TODO: - setup return for download response
        throw NetworkResponseError.badRequest(message: "TODO")
    }
    
    func handleDownloadRequest(for urlRequest: URLRequest, manager: AlamofireWrapperManager, request: NetworkRequest, callbackQueue: DispatchQueue, destination: DownloadDestination?, progressHandler: ProgressHandler?, completion: @escaping (Result<NetworkResponse, NetworkResponseError>) -> Void) -> AlamofireWrapperBaseRequest? {
        
        // TODO: - setup return for download response
        return nil
    }
    
    func handleUploadMultipart(for urlRequest: URLRequest, multipartBody: [MultipartData], manager: AlamofireWrapperManager, request: NetworkRequest, callbackQueue: DispatchQueue, usingThreshold encodingMemoryThreshold: UInt64, uploadProgressHandler: ProgressHandler?) async throws -> NetworkResponse {
        guard let url = request.testURL,
              let data = try? Data(contentsOf: url) else {
                  throw NetworkResponseError.badRequest(message: "missing test data")
              }
        
        let response = NetworkResponse(statusCode: 200, data: data, request: nil, httpResponse: nil)
        
        return response
    }
    
    func handleUploadMultipart(for urlRequest: URLRequest, multipartBody: [MultipartData], manager: AlamofireWrapperManager, request: NetworkRequest, callbackQueue: DispatchQueue, usingThreshold encodingMemoryThreshold: UInt64, uploadProgressHandler: ProgressHandler?, completion: @escaping (Result<NetworkResponse, NetworkResponseError>) -> Void) -> AlamofireWrapperBaseRequest? {
        
        guard let url = request.testURL,
              let data = try? Data(contentsOf: url) else {
                  completion(.failure(.badRequest(message: "missing test data")))
                  return nil
              }
        
        let response = NetworkResponse(statusCode: 200, data: data, request: nil, httpResponse: nil)
        
        completion(.success(response))
        
        return nil
    }
}

extension AlamofireWrapper {
    static let testHandler: AlamofireWrapperHandler = {
        return AlamofireWrapperLocalTestingHandler()
    }()
}
