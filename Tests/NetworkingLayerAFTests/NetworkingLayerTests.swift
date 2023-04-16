// Created by GoSite 191 on 8/3/20.
// Copyright © 2020 Gosite. All rights reserved.

import XCTest
import Alamofire
import NetworkingLayerCore
@testable import NetworkingLayerAF

final class NetworkingLayerTests: XCTestCase {

    func test_basicData_isSuccess() {
        let mockManager = MockSessionManager()
        let wrapper = AlamofireWrapper(manager: mockManager)

        let mockRequest = MockStandardRequest.validRequest

        let foo = wrapper.send(request: mockRequest) { (result) in
            switch result {
            case .success(let response):
                XCTAssert(response.data.count == 30)
            case .failure:
                XCTFail()
            }
        }
        
        XCTAssert(foo != nil)
    }
    
    func test_basicDownload_isSuccess() {
        let mockManager = MockSessionManager()
        let wrapper = AlamofireWrapper(manager: mockManager)

        let mockRequest = MockStandardRequest.validDownload

        let foo = wrapper.send(request: mockRequest) { (result) in
            switch result {
            case .success(let response):
                
                guard let downloadResponse = response as? NetworkingLayerCore.DownloadResponse else {
                    XCTFail()
                    return
                }
                
                XCTAssert(downloadResponse.destinationURL?.absoluteString == "temp")
            case .failure:
                XCTFail()
            }
        }
        
        XCTAssert(foo != nil)
    }
    
    func test_basicCodable_isSucessful() {
        let mockManager = MockSessionManager()
        let wrapper = AlamofireWrapper(manager: mockManager)

        let mockRequest = MockCodableRequest()
        
        let foo = wrapper.send(codableRequest: mockRequest) { (result) in
            switch result {
            case .success(let response):
                
                let foo = Foo(foo: "test", fooz: "tester")
                
                XCTAssert(foo == response.object)
            case .failure:
                XCTFail()
            }
        }
        
        XCTAssert(foo != nil)
    }
    
    func test_invalidBasicRequest_returnsError() {
        
        var mockManager = MockSessionManager()
        mockManager.responseType = .invalid
        let wrapper = AlamofireWrapper(manager: mockManager)

        let mockRequest = MockCodableRequest()
        
        let foo = wrapper.send(codableRequest: mockRequest) { (result) in
            switch result {
            case .success:
                XCTFail()

            case .failure(let error):
                switch error {
                case .responseError(let error, let response):
                    let expectation = Foo(foo: "test", fooz: "tester")
                    
                    let responseObject = try! JSONDecoder().decode(Foo.self, from: response!.data)
                    
                    XCTAssert(expectation == responseObject)
                    
                    switch error.asAFError {
                    case .sessionTaskFailed(let error):
                        XCTAssert(error.localizedDescription == "Failure")
                    default:
                        XCTFail()
                    }
                default:
                    XCTFail()
                }

            }
        }
        
        XCTAssert(foo != nil)
    }
    
    func test_BasicMultipartUpload_IsSuccessful() {
        let mockManager = MockSessionManager()
        let wrapper = AlamofireWrapper(manager: mockManager)

        let request = MockStandardRequest.validMultipart
        
        let foo = wrapper.send(request: request) { (result) in
            switch result {
            case .success(let response):
                
                let expectation = Foo(foo: "test", fooz: "tester")

                let responseObject = try! JSONDecoder().decode(Foo.self, from: response.data)
                
                let multipartData = try! mockManager.multipartData.encode()
                
                XCTAssert(multipartData.count == 173)
                XCTAssert(expectation == responseObject)
                XCTAssert(response.data.count == 30)
            case .failure:
                XCTFail()
            }
        }
        
        XCTAssert(foo != nil)
    }
}

extension NetworkingLayerTests {
    struct MockSessionManager: AlamofireWrapperManager {
        
        enum ResponseType {
            case valid
            case invalid
        }
        
        var responseType: ResponseType = .valid

        let session = URLSession(configuration: URLSessionConfiguration.default)
        
        var multipartData = MultipartFormData()
        
        func request(_ urlRequest: URLRequestConvertible) -> AlamofireWrapperDataRequest {
            switch responseType {
            case .valid:
                return MockDataRequest()
            case .invalid:
                return MockInvalidDataRequest()
            }
        }
        
        func download(_ urlRequest: URLRequestConvertible, to destination: DownloadRequest.Destination?) -> AlamofireWrapperDownloadRequest {
            // TODO: -
            return MockDownloadRequest()
        }
        
        func upload(multipartFormData: @escaping (MultipartFormData) -> Void, usingThreshold encodingMemoryThreshold: UInt64, with urlRequest: URLRequestConvertible) -> AlamofireWrapperUploadRequest {

            multipartFormData(multipartData)
                        
            let uploadRequest = MockUploadRequest()
            return uploadRequest
        }
    }

    struct MockDataRequest: AlamofireWrapperDataRequest {
        func serializingData(automaticallyCancelling shouldAutomaticallyCancel: Bool, dataPreprocessor: DataPreprocessor, emptyResponseCodes: Set<Int>, emptyRequestMethods: Set<Alamofire.HTTPMethod>) -> DataTask<Data> {
            fatalError()
        }
        
        var task: URLSessionTask? = FakeURLSessionTask()
        
        func responseData(queue: DispatchQueue, dataPreprocessor: DataPreprocessor, emptyResponseCodes: Set<Int>, emptyRequestMethods: Set<Alamofire.HTTPMethod>, completionHandler: @escaping (AFDataResponse<Data>) -> Void) -> NetworkingLayerTests.MockDataRequest {

            let foo = Foo(foo: "test", fooz: "tester")
            let data = try! JSONEncoder().encode(foo)
            
            let mockResponse = AFDataResponse<Data>(request: nil, response: HTTPURLResponse(), data: data, metrics: nil, serializationDuration: 1, result: .success(data))
                        
            completionHandler(mockResponse)
            
            return self
        }
        
        func validate<S>(statusCode acceptableStatusCodes: S) -> MockDataRequest where S : Sequence, S.Element == Int {
            return self
        }
        
        func downloadProgress(queue: DispatchQueue, closure: @escaping Request.ProgressHandler) -> MockDataRequest {
            return self
        }
    }

    struct MockDownloadRequest: AlamofireWrapperDownloadRequest {
        func serializingData(automaticallyCancelling shouldAutomaticallyCancel: Bool, dataPreprocessor: DataPreprocessor, emptyResponseCodes: Set<Int>, emptyRequestMethods: Set<Alamofire.HTTPMethod>) -> DownloadTask<Data> {
            fatalError()
        }
        
        var task: URLSessionTask? = FakeURLSessionTask()
        
        func response(queue: DispatchQueue, completionHandler: @escaping (AFDownloadResponse<URL?>) -> Void) -> NetworkingLayerTests.MockDownloadRequest {
            
            
            let mockResponse = AFDownloadResponse<URL?>(request: nil, response: HTTPURLResponse(), fileURL: URL(string: "temp"), resumeData: nil, metrics: nil, serializationDuration: 1, result: .success(URL(string: "temp")))
            
            completionHandler(mockResponse)
            
            return self
        }
        
        func validate<S>(statusCode acceptableStatusCodes: S) -> NetworkingLayerTests.MockDownloadRequest where S : Sequence, S.Element == Int {
            return self
        }
        
        func downloadProgress(queue: DispatchQueue, closure: @escaping Request.ProgressHandler) -> NetworkingLayerTests.MockDownloadRequest {
            return self
        }
    }
    
    struct MockInvalidDataRequest: AlamofireWrapperDataRequest {
        func serializingData(automaticallyCancelling shouldAutomaticallyCancel: Bool, dataPreprocessor: DataPreprocessor, emptyResponseCodes: Set<Int>, emptyRequestMethods: Set<Alamofire.HTTPMethod>) -> DataTask<Data> {
            fatalError()
        }
        
        var task: URLSessionTask? = FakeURLSessionTask()
        
        func responseData(queue: DispatchQueue, dataPreprocessor: DataPreprocessor, emptyResponseCodes: Set<Int>, emptyRequestMethods: Set<Alamofire.HTTPMethod>, completionHandler: @escaping (AFDataResponse<Data>) -> Void) -> NetworkingLayerTests.MockInvalidDataRequest {
            let foo = Foo(foo: "test", fooz: "tester")
            let data = try! JSONEncoder().encode(foo)
            
            let mockResponse = AFDataResponse<Data>(request: nil, response: HTTPURLResponse(url: URL(string: "https://blank.com")!, statusCode: 404, httpVersion: nil, headerFields: nil), data: data, metrics: nil, serializationDuration: 1.0, result: .failure(AFError.sessionTaskFailed(error: BasicError(message: "Failure"))))
            
            completionHandler(mockResponse)
            
            return self
        }
        
        func validate<S>(statusCode acceptableStatusCodes: S) -> NetworkingLayerTests.MockInvalidDataRequest where S : Sequence, S.Element == Int {
            return self
        }
        
        func downloadProgress(queue: DispatchQueue, closure: @escaping Request.ProgressHandler) -> NetworkingLayerTests.MockInvalidDataRequest {
            return self
        }
    }
    
    struct MockUploadRequest: AlamofireWrapperUploadRequest {
        func serializingData(automaticallyCancelling shouldAutomaticallyCancel: Bool, dataPreprocessor: DataPreprocessor, emptyResponseCodes: Set<Int>, emptyRequestMethods: Set<Alamofire.HTTPMethod>) -> DataTask<Data> {
            fatalError()
        }
        
        var task: URLSessionTask? = FakeURLSessionTask()
        
        func responseData(queue: DispatchQueue, dataPreprocessor: DataPreprocessor, emptyResponseCodes: Set<Int>, emptyRequestMethods: Set<Alamofire.HTTPMethod>, completionHandler: @escaping (AFDataResponse<Data>) -> Void) -> NetworkingLayerTests.MockUploadRequest {
            
            let foo = Foo(foo: "test", fooz: "tester")
            let data = try! JSONEncoder().encode(foo)
            
            let mockResponse = AFDataResponse<Data>(request: nil, response: HTTPURLResponse(), data: data, metrics: nil, serializationDuration: 1, result: .success(data))
            
            completionHandler(mockResponse)
            
            return self
        }
        
        func validate<S>(statusCode acceptableStatusCodes: S) -> MockUploadRequest where S : Sequence, S.Element == Int {
            return self
        }
        
        func downloadProgress(queue: DispatchQueue, closure: @escaping Request.ProgressHandler) -> MockUploadRequest {
            return self
        }
        
        func uploadProgress(queue: DispatchQueue, closure: @escaping Request.ProgressHandler) -> NetworkingLayerTests.MockUploadRequest {
            return self
        }
    }
    
    class FakeURLSessionTask: URLSessionTask {
        override init() {
            
        }
    }
    
    struct BasicError: Error, LocalizedError {
        let message: String
        
        var errorDescription: String? {
            return message
        }
    }
    

}



