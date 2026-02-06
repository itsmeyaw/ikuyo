//
//  DataProviderError.swift
//  Ikuyo
//
//  Created by Yudhistira Wibowo on 25.01.26.
//

import Foundation

enum DataProviderError: LocalizedError {
    case responseError(String)
    
    var errorDescription: String? {
        switch self {
        case .responseError(let message): "Response Error: \(message)"
        }
    }
}
