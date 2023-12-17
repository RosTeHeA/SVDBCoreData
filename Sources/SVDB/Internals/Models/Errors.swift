//
//  File.swift
//
//
//  Created by Jordan Howlett on 8/4/23.
//

import Foundation

public enum SVDBError: Error {
    case collectionAlreadyExists
    case coreDataError(String)
}

public enum CollectionError: Error {
    case fetchFailed(String)
    case saveFailed(String)
    case deleteFailed(String)
}
