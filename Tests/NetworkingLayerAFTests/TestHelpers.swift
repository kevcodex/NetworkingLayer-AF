// Copyright © 2020 Gosite. All rights reserved.

import Foundation
@testable import NetworkingLayerCore

enum MockStandardRequest: NetworkRequest {
    case validRequest
    case validRequestWithPath
    case invalidRequest
    case validRequestWithQueryParams
    case validRequestWithHeaders
    case validRequestWithJSONBody
    case validDownload
    case validMultipart
    case validRequestWithQueryParamsEncoded
    case validRequestWithCustomQueryParamsEncoded
    
    var baseURL: URL? {
        switch self {
            
        case .validRequest:
            return URL(string: "https://mockurlawfgafwafawf.com")
        case .validRequestWithPath:
            return URL(string: "https://mockurlawfgafwafawf.com")
        case .invalidRequest:
            return URL(string: "")
        case .validRequestWithQueryParams:
            return URL(string: "https://mockurlawfgafwafawf.com")
        case .validRequestWithHeaders:
            return URL(string: "https://mockurlawfgafwafawf.com")
        case .validRequestWithJSONBody:
            return URL(string: "https://mockurlawfgafwafawf.com")
        case .validDownload:
            return URL(string: "https://mockurlawfgafwafawf.com")
        case .validMultipart:
            return URL(string: "https://mockurlawfgafwafawf.com")
        case .validRequestWithQueryParamsEncoded:
            return URL(string: "https://mockurlawfgafwafawf.com")
        case .validRequestWithCustomQueryParamsEncoded:
            return URL(string: "https://mockurlawfgafwafawf.com")
        }
    }
    
    var path: String {
        switch self {
            
        case .validRequest:
            return ""
        case .validRequestWithPath:
            return "/foo"
        case .invalidRequest:
            return ""
        case .validRequestWithQueryParams:
            return ""
        case .validRequestWithHeaders:
            return ""
        case .validRequestWithJSONBody:
            return ""
        case .validDownload:
            return ""
        case .validMultipart:
            return ""
        case .validRequestWithQueryParamsEncoded:
            return ""
        case .validRequestWithCustomQueryParamsEncoded:
            return ""
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .validRequest:
            return .get
        case .validRequestWithPath:
            return .get
        case .invalidRequest:
            return .get
        case .validRequestWithQueryParams:
            return .get
        case .validRequestWithHeaders:
            return .get
        case .validRequestWithJSONBody:
            return .get
        case .validDownload:
            return .get
        case .validMultipart:
            return .post
        case .validRequestWithQueryParamsEncoded:
            return .get
        case .validRequestWithCustomQueryParamsEncoded:
            return .get
            
        }
    }
    
    var parameters: NetworkQuery? {
        switch self {
        case .validRequest:
            return nil
        case .validRequestWithPath:
            return nil
        case .invalidRequest:
            return nil
        case .validRequestWithQueryParams:
            return  NetworkQuery(parameters: ["foo": "bar", "fooz": "barz"])
        case .validRequestWithHeaders:
            return nil
        case .validRequestWithJSONBody:
            return nil
        case .validDownload:
            return nil
        case .validMultipart:
            return nil
        case .validRequestWithQueryParamsEncoded:
            return NetworkQuery(parameters: ["foo": "bar%a", "fooz": "ba#rz"])
        case .validRequestWithCustomQueryParamsEncoded:
            var characterSet = CharacterSet.urlQueryAllowed
            characterSet.remove("+")
            return NetworkQuery(parameters: ["foo": "bar%a", "fooz": "ba#rz", "fooz1": "ba+rz"], encoding: .custom(characterSet))
        }
    }
    
    var headers: [Header]? {
        switch self {
        case .validRequest:
            return nil
        case .validRequestWithPath:
            return nil
        case .invalidRequest:
            return nil
        case .validRequestWithQueryParams:
            return nil
        case .validRequestWithHeaders:
            return [.init(key: "foo", value: "bar"), .init(key: "fooz", value: "barz")]
        case .validRequestWithJSONBody:
            return nil
        case .validDownload:
            return nil
        case .validMultipart:
            return nil
        case .validRequestWithQueryParamsEncoded:
            return nil
        case .validRequestWithCustomQueryParamsEncoded:
            return nil
        }
    }
    
    var body: NetworkBody? {
        switch self {
        case .validRequest:
            return nil
        case .validRequestWithPath:
            return nil
        case .invalidRequest:
            return nil
        case .validRequestWithQueryParams:
            return nil
        case .validRequestWithHeaders:
            return nil
        case .validRequestWithJSONBody:
            let data =
                """
                    {"foo": "bar"}
                """
                    .data(using: .utf8)
            
            
            return NetworkBody(data: data!, encoding: .json)
        case .validDownload:
            return nil
        case .validMultipart:
            return nil
        case .validRequestWithQueryParamsEncoded:
            return nil
        case .validRequestWithCustomQueryParamsEncoded:
            return nil
        }
    }
    
    var requestType: RequestType {
        switch self {
        case .validRequest:
            return .requestData
        case .validRequestWithPath:
            return .requestData
        case .invalidRequest:
            return .requestData
        case .validRequestWithQueryParams:
            return .requestData
        case .validRequestWithHeaders:
            return .requestData
        case .validRequestWithJSONBody:
            return .requestData
        case .validDownload:
            return .download(nil)
        case .validMultipart:
            let body1 = MultipartData(data: Data(), name: "foo", fileName: "foo.png", mimeType: "image/png")
            return .uploadMultipart(body: [body1])
        case .validRequestWithQueryParamsEncoded:
            return .requestData
        case .validRequestWithCustomQueryParamsEncoded:
            return .requestData
        }
    }
}

struct Foo: Codable, Equatable {
    let foo: String
    let fooz: String
}

struct MockCodableRequest: CodableRequest {
    typealias Response = Foo
    
    var baseURL: URL? {
        return URL(string: "https://mockurlawfgafwafawf.com")
    }
    
    var path: String {
        return ""
    }
    
    var method: HTTPMethod {
        return .get
    }
    
    var parameters: NetworkQuery?
    
    var headers: [Header]?
    
    var body: NetworkBody?
    
    var requestType: RequestType {
        .requestData
    }
}

struct HeaderBuildTestRequest: NetworkRequest {
    
    let bool: Bool

    var baseURL: URL? {
        return URL(string: "https://mockurlawfgafwafawf.com")
    }
    
    var path: String {
        return ""
    }
    
    var method: HTTPMethod {
        return .get
    }
    
    var parameters: NetworkQuery?
    
    var headers: [Header]? {
        if bool {
            Header(key: "if", value: "test")
        } else {
            Header(key: "if", value: "test2")
        }
        Header(key: "e", value: "f")
        Header(key: "g", value: "h")
        
        [Header(key: "array", value: "test")]
        
        ["dict": "test"]
        
        let optional: Header? = Header(key: "optional", value: "test")
        
        if let optional {
            optional
        }
        
        for test in [Header(key: "foo", value: "bar"), Header(key: "baz", value: "fooz")] {
            test
        }
    }
    
    var body: NetworkBody?
    
    var requestType: RequestType {
        .requestData
    }
}
