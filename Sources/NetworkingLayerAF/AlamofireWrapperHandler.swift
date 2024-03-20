// Created by Kirby on 8/4/20.
// Copyright © 2020 Kirby. All rights reserved.

import Alamofire
import Foundation
import NetworkingLayerCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol AlamofireWrapperHandler {
    
    func handleDataRequest(for urlRequest: URLRequest,
                           manager: AlamofireWrapperManager,
                           request: NetworkRequest,
                           callbackQueue: DispatchQueue,
                           progressHandler: ProgressHandler?) async throws -> NetworkResponse
    
    func handleDataRequest(for urlRequest: URLRequest,
                           manager: AlamofireWrapperManager,
                           request: NetworkRequest,
                           callbackQueue: DispatchQueue,
                           progressHandler: ProgressHandler?,
                           completion: @escaping (Swift.Result<NetworkResponse, NetworkResponseError>) -> Void) -> AlamofireWrapperBaseRequest?
    
    func handleDownloadRequest(for urlRequest: URLRequest,
                               manager: AlamofireWrapperManager,
                               request: NetworkRequest,
                               callbackQueue: DispatchQueue,
                               destination: DownloadDestination?,
                               progressHandler: ProgressHandler?) async throws -> NetworkResponse

    func handleDownloadRequest(for urlRequest: URLRequest,
                               manager: AlamofireWrapperManager,
                               request: NetworkRequest,
                               callbackQueue: DispatchQueue,
                               destination: DownloadDestination?,
                               progressHandler: ProgressHandler?,
                               completion: @escaping (Swift.Result<NetworkResponse, NetworkResponseError>) -> Void) -> AlamofireWrapperBaseRequest?
    
    func handleUploadMultipart(for urlRequest: URLRequest,
                               multipartBody: [MultipartData],
                               manager: AlamofireWrapperManager,
                               request: NetworkRequest,
                               callbackQueue: DispatchQueue,
                               usingThreshold encodingMemoryThreshold: UInt64,
                               uploadProgressHandler: ProgressHandler?) async throws -> NetworkResponse

    func handleUploadMultipart(for urlRequest: URLRequest,
                               multipartBody: [MultipartData],
                               manager: AlamofireWrapperManager,
                               request: NetworkRequest,
                               callbackQueue: DispatchQueue,
                               usingThreshold encodingMemoryThreshold: UInt64,
                               uploadProgressHandler: ProgressHandler?,
                               completion: @escaping (Swift.Result<NetworkResponse, NetworkResponseError>) -> Void) -> AlamofireWrapperBaseRequest?
}

struct AlamofireWrapperDefaultHandler: AlamofireWrapperHandler {
    
    func handleDataRequest(for urlRequest: URLRequest,
                           manager: AlamofireWrapperManager,
                           request: NetworkRequest,
                           callbackQueue: DispatchQueue,
                           progressHandler: ProgressHandler?) async throws -> NetworkResponse {
        
        let task = manager
            .request(urlRequest)
            .validate(statusCode: request.acceptableStatusCodes)
            .downloadProgress(queue: progressHandler?.callbackQueue ?? .main) { (progress) in
                let progressResponse = ProgressResponse(progress: progress)
                progressHandler?.progressBlock(progressResponse)
            }
            .serializingData(automaticallyCancelling: false,
                             dataPreprocessor: DataResponseSerializer.defaultDataPreprocessor,
                             emptyResponseCodes: request.acceptableEmptyResponseCodes,
                             emptyRequestMethods: DataResponseSerializer.defaultEmptyRequestMethods)
        
        let response = await task.response
        
        let result = handleDataResult(responseData: response, urlRequest: urlRequest)
        
        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
    
    func handleDataRequest(for urlRequest: URLRequest,
                           manager: AlamofireWrapperManager,
                           request: NetworkRequest,
                           callbackQueue: DispatchQueue = .main,
                           progressHandler: ProgressHandler?,
                           completion: @escaping (Swift.Result<NetworkResponse, NetworkResponseError>) -> Void) -> AlamofireWrapperBaseRequest? {

        return manager
            .request(urlRequest)
            .validate(statusCode: request.acceptableStatusCodes)
            .downloadProgress(queue: progressHandler?.callbackQueue ?? .main) { (progress) in
                let progressResponse = ProgressResponse(progress: progress)
                progressHandler?.progressBlock(progressResponse)
            }
            .responseData(queue: callbackQueue,
                          dataPreprocessor: DataResponseSerializer.defaultDataPreprocessor,
                          emptyResponseCodes: DataResponseSerializer.defaultEmptyResponseCodes,
                          emptyRequestMethods: DataResponseSerializer.defaultEmptyRequestMethods) { (responseData) in
                handleDataResponse(responseData: responseData, urlRequest: urlRequest, completion: completion)
            }
    }
    
    func handleDownloadRequest(for urlRequest: URLRequest,
                               manager: AlamofireWrapperManager,
                               request: NetworkRequest,
                               callbackQueue: DispatchQueue,
                               destination: DownloadDestination?,
                               progressHandler: ProgressHandler?) async throws -> NetworkResponse {
        
        let afDestination = createAFDestination(from: destination)

        let task = manager
            .download(urlRequest, to: afDestination)
            .validate(statusCode: request.acceptableStatusCodes)
            .downloadProgress(queue: progressHandler?.callbackQueue ?? .main) { (progress) in
                let progressResponse = ProgressResponse(progress: progress)
                progressHandler?.progressBlock(progressResponse)
            }
            .serializingData(automaticallyCancelling: false,
                             dataPreprocessor: DataResponseSerializer.defaultDataPreprocessor,
                             emptyResponseCodes: DataResponseSerializer.defaultEmptyResponseCodes,
                             emptyRequestMethods: DataResponseSerializer.defaultEmptyRequestMethods)
        
        let downloadResponse = await task.response
        
        let result = handleDownloadResult(downloadResponse: downloadResponse, urlRequest: urlRequest)
        
        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func handleDownloadRequest(for urlRequest: URLRequest,
                               manager: AlamofireWrapperManager,
                               request: NetworkRequest,
                               callbackQueue: DispatchQueue = .main,
                               destination: DownloadDestination?,
                               progressHandler: ProgressHandler?,
                               completion: @escaping (Swift.Result<NetworkResponse, NetworkResponseError>) -> Void) -> AlamofireWrapperBaseRequest? {

        // Note: Can't use responseData for downloading otherwise if destination url is nil, it will trigger a error for certain types of files. (this comment was from alamofire 4, not sure if the new 5 changed(
        let afDestination = createAFDestination(from: destination)

        return manager
            .download(urlRequest, to: afDestination)
            .validate(statusCode: request.acceptableStatusCodes)
            .downloadProgress(queue: progressHandler?.callbackQueue ?? .main) { (progress) in
                let progressResponse = ProgressResponse(progress: progress)
                progressHandler?.progressBlock(progressResponse)
            }
            .response(queue: callbackQueue) { (downloadResponse) in
                
                switch (downloadResponse.response, downloadResponse.error) {
                case let (response?, .none):
                    let response = DownloadResponse(
                        destinationURL: downloadResponse.fileURL,
                        statusCode: response.statusCode,
                        data: Data(),
                        request: urlRequest,
                        httpResponse: downloadResponse.response)
                    
                    completion(.success(response))
                case let (response?, error?):
                    let response = NetworkResponse(statusCode: response.statusCode,
                                                   data: Data(),
                                                   request: urlRequest,
                                                   httpResponse: response)
                    
                    let error = NetworkResponseError.responseError(error, response: response)
                    
                    completion(.failure(error))
                case let (_, .some(error)):
                    completion(.failure(.responseError(error, response: nil)))
                default:
                    completion(.failure(.unknown))
                }
            }
    }
    
    func handleUploadMultipart(for urlRequest: URLRequest,
                               multipartBody: [MultipartData],
                               manager: AlamofireWrapperManager,
                               request: NetworkRequest,
                               callbackQueue: DispatchQueue,
                               usingThreshold encodingMemoryThreshold: UInt64,
                               uploadProgressHandler: ProgressHandler?) async throws -> NetworkResponse {
        
        let task = manager.upload(
            multipartFormData: { (multiPartData) in
                for bodyPart in multipartBody {
                    if let fileName = bodyPart.fileName, let mimeType = bodyPart.mimeType {
                        multiPartData.append(bodyPart.data, withName: bodyPart.name, fileName: fileName, mimeType: mimeType)
                    } else {
                        multiPartData.append(bodyPart.data, withName: bodyPart.name)
                    }
                }
            },
            usingThreshold: encodingMemoryThreshold,
            with: urlRequest)
            .validate(statusCode: request.acceptableStatusCodes)
            .uploadProgress(queue: uploadProgressHandler?.callbackQueue ?? .main) { (progress) in
                let progressResponse = ProgressResponse(progress: progress)
                uploadProgressHandler?.progressBlock(progressResponse)
            }
            .serializingData(automaticallyCancelling: false,
                             dataPreprocessor: DataResponseSerializer.defaultDataPreprocessor,
                             emptyResponseCodes: DataResponseSerializer.defaultEmptyResponseCodes,
                             emptyRequestMethods: DataResponseSerializer.defaultEmptyRequestMethods)
        
        let uploadResponse = await task.response
        
        let result = handleDataResult(responseData: uploadResponse, urlRequest: urlRequest)
        
        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func handleUploadMultipart(
        for urlRequest: URLRequest,
        multipartBody: [MultipartData],
        manager: AlamofireWrapperManager,
        request: NetworkRequest,
        callbackQueue: DispatchQueue = .main,
        usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
        uploadProgressHandler: ProgressHandler?,
        completion: @escaping (Swift.Result<NetworkResponse, NetworkResponseError>) -> Void) -> AlamofireWrapperBaseRequest?  {

        return
            manager.upload(
                multipartFormData: { (multiPartData) in
                    for bodyPart in multipartBody {
                        if let fileName = bodyPart.fileName, let mimeType = bodyPart.mimeType {
                            multiPartData.append(bodyPart.data, withName: bodyPart.name, fileName: fileName, mimeType: mimeType)
                        } else {
                            multiPartData.append(bodyPart.data, withName: bodyPart.name)
                        }
                    }
                },
                usingThreshold: encodingMemoryThreshold,
                with: urlRequest)
            .validate(statusCode: request.acceptableStatusCodes)
            .uploadProgress(queue: uploadProgressHandler?.callbackQueue ?? .main) { (progress) in
                let progressResponse = ProgressResponse(progress: progress)
                uploadProgressHandler?.progressBlock(progressResponse)
            }
            .responseData(
                queue: callbackQueue,
                dataPreprocessor: DataResponseSerializer.defaultDataPreprocessor,
                emptyResponseCodes: DataResponseSerializer.defaultEmptyResponseCodes,
                emptyRequestMethods: DataResponseSerializer.defaultEmptyRequestMethods) { (responseData) in
                handleDataResponse(responseData: responseData, urlRequest: urlRequest, completion: completion)
            }
    }
    
    private func handleDataResult(
        responseData: AFDataResponse<Data>,
        urlRequest: URLRequest) -> Swift.Result<NetworkResponse, NetworkResponseError> {
            
            switch responseData.result {
            case .success(let data):

                if let httpResponse = responseData.response {
                    let response = NetworkResponse(statusCode: httpResponse.statusCode,
                                                   data: data,
                                                   request: urlRequest,
                                                   httpResponse: responseData.response)

                    return .success(response)
                } else {
                    // This should theorectically never happen as there should never be a case where
                    // data exists but httpResponse does not
                    return .failure(.unknown)
                }

            case .failure(let error):

                if let httpResponse = responseData.response {
                    let response = NetworkResponse(statusCode: httpResponse.statusCode,
                                                   data: responseData.data ?? Data(),
                                                   request: urlRequest,
                                                   httpResponse: httpResponse)

                    let error = NetworkResponseError.responseError(error, response: response)
                    
                    return .failure(error)

                } else {
                    return .failure(.responseError(error, response: nil))
                }
            }
    }
    
    private func createAFDestination(from destination: DownloadDestination?) -> Alamofire.DownloadRequest.Destination? {
        let afDestination: Alamofire.DownloadRequest.Destination?
        if let destination {
            afDestination = { _, _ in
                let destinationURL = destination.destinationURL
                
                var options: DownloadRequest.Options = []
                for opt in destination.options {
                    switch opt {
                    case .createIntermediateDirectories:
                        options.insert(.createIntermediateDirectories)
                    case .removePreviousFile:
                        options.insert(.removePreviousFile)
                    }
                }
                
                return (destinationURL, options)
            }
        } else {
            afDestination = nil
        }
        
        return afDestination
    }

    private func handleDataResponse(
        responseData: AFDataResponse<Data>,
        urlRequest: URLRequest,
        completion: @escaping (Swift.Result<NetworkResponse, NetworkResponseError>) -> Void) {
            
            let result = handleDataResult(responseData: responseData, urlRequest: urlRequest)
            
            completion(result)
        }
    
    
    private func handleDownloadResult(
        downloadResponse: AFDownloadResponse<Data>,
        urlRequest: URLRequest) -> Swift.Result<NetworkResponse, NetworkResponseError> {
            
            switch (downloadResponse.response, downloadResponse.error) {
            case let (response?, .none):
                let response = DownloadResponse(
                    destinationURL: downloadResponse.fileURL,
                    statusCode: response.statusCode,
                    data: Data(),
                    request: urlRequest,
                    httpResponse: downloadResponse.response)
                
                return .success(response)
            case let (response?, error?):
                let response = NetworkResponse(statusCode: response.statusCode,
                                               data: Data(),
                                               request: urlRequest,
                                               httpResponse: response)
                
                let error = NetworkResponseError.responseError(error, response: response)
                
                return .failure(error)
            case let (_, .some(error)):
                return .failure(.responseError(error, response: nil))
            default:
                return .failure(.unknown)
            }
        }
    
    private func handleDownloadResponse(
        downloadResponse: AFDownloadResponse<Data>,
        urlRequest: URLRequest,
        completion: @escaping (Swift.Result<NetworkResponse, NetworkResponseError>) -> Void) {
            
            let result = handleDownloadResult(downloadResponse: downloadResponse, urlRequest: urlRequest)
            
            completion(result)
        }
}
