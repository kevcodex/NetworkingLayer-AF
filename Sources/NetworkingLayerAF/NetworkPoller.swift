// Created by Kirby on 6/10/21.
// Copyright © 2021 Kirby. All rights reserved.

import Foundation
import NetworkingLayerCore

// Simple network poller.
// Will continiously check network request. up to a limit.
// TODO: - Allow cancelling
class NetworkPoller<E: NetworkRequest, C: Codable> {
    let request: E
    
    let delay: TimeInterval
    
    /// Does not include first call. So if 4, total calls will be 5
    let maxRetries: Int
    
    private var count = 0
        
    init(request: E, delay: TimeInterval = 0.5, maxRetries: Int = 4) {
        self.request = request
        self.delay = delay
        self.maxRetries = maxRetries
    }
        
    func poll(intervalBlock: @escaping (ResponseObject<C>) -> Bool,
              completion: @escaping (Result<ResponseObject<C>, Error>) -> Void)  {
        
        if count == 0 {
            recursivlyCallNetworkRequest(intervalBlock: intervalBlock, completion: completion)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.recursivlyCallNetworkRequest(intervalBlock: intervalBlock, completion: completion)
            }
        }
    }
    
    func reset() {
        count = 0
    }
    
    private func recursivlyCallNetworkRequest(intervalBlock: @escaping (ResponseObject<C>) -> Bool,
                                              completion: @escaping (Result<ResponseObject<C>, Error>) -> Void) {
        NetworkingLayer(wrapper: AlamofireWrapper()).send(request: self.request, codableType: C.self) { result in
            switch result {
            case .success(let response):
                self.count += 1

                if self.count > self.maxRetries {
                    self.reset()
                    completion(.success(response))
                } else {
                    // Check if this is the response you wanted.
                    // Otherwise continue to poll.
                    if intervalBlock(response) {
                        self.reset()
                        completion(.success(response))
                    } else {
                        self.poll(intervalBlock: intervalBlock, completion: completion)
                    }
                }

            case .failure(let error):
                self.count += 1
                
                // Continue to poll if failure.
                if self.count > self.maxRetries {
                    self.reset()
                    completion(.failure(error))
                } else {
                    self.poll(intervalBlock: intervalBlock, completion: completion)
                }
            }
        }
    }
}
