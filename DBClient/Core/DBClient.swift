//
//  DBClient.swift
//  DBClient
//
//  Created by Yury Grinenko on 03.11.16.
//  Copyright © 2016 Yalantis. All rights reserved.
//

import Foundation
import YALResult

public typealias Result = YALResult.Result

public enum DBClientError: Error {
    case noPrimaryKey
    case noData
}

/// Protocol for transaction restrictions in `DBClient`.
/// Used for transactions of all type.
public protocol Stored {
    
    /// Primary key for an object.
    static var primaryKeyName: String? { get }
    
    /// Primary value for an instance
    var valueOfPrimaryKey: CVarArg? { get }
    
}

/// Describes abstract database transactions, common for all engines.
public protocol DBClient {
    
    /// Executes given request and calls completion result wrapped in `Result`.
    ///
    /// - Parameters:
    ///   - request: request to execute
    ///   - completion: `Result` with array of objects or error in case of failude.
    func execute<T>(_ request: FetchRequest<T>, completion: @escaping (Result<[T]>) -> Void)
    
    /// Creates observable request from given `FetchRequest`.
    ///
    /// - Parameter request: fetch request to be observed
    /// - Returns: observable of for given request.
    func observable<T>(for request: FetchRequest<T>) -> RequestObservable<T>
    
    /// Inserts objects to database.
    ///
    /// - Parameters:
    ///   - objects: list of objects to be inserted
    ///   - completion: `Result` with inserted objects or appropriate error in case of failure.
    func insert<T: Stored>(_ objects: [T], completion: @escaping (Result<[T]>) -> Void)
    
    /// Updates changed performed with objects to database.
    ///
    /// - Parameters:
    ///   - objects: list of objects to be updated
    ///   - completion: `Result` with updated objects or appropriate error in case of failure.
    func update<T: Stored>(_ objects: [T], completion: @escaping (Result<[T]>) -> Void)
    
    /// Deletes objects from database.
    ///
    /// - Parameters:
    ///   - objects: list of objects to be deleted
    ///   - completion: `Result` with appropriate error in case of failure.
    func delete<T: Stored>(_ objects: [T], completion: @escaping (Result<()>) -> Void)
    
    /// Iterates through given objects and updates existing in database instances or creates them
    ///
    /// - Parameters:
    ///   - objects: objects to be worked with
    ///   - completion: `Result` with inserted and updated instances.
    func upsert<T : Stored>(_ objects: [T], completion: @escaping (Result<(updated: [T], inserted: [T])>) -> Void)
    
    /// Synchronously inserts objects to database.
    ///
    /// - Parameters:
    ///   - objects: list of objects to be inserted
    /// - Returns: `Result` with inserted objects or appropriate error in case of failure.
    @discardableResult
    func insert<T: Stored>(_ objects: [T]) -> Result<[T]>
    
    /// Synchronously updates changed performed with objects to database.
    ///
    /// - Parameters:
    ///   - objects: list of objects to be updated
    /// - Returns: `Result` with updated objects or appropriate error in case of failure.
    @discardableResult
    func update<T: Stored>(_ objects: [T]) -> Result<[T]>
    
    /// Synchronously deletes objects from database.
    ///
    /// - Parameters:
    ///   - objects: list of objects to be deleted
    /// - Returns: `Result` with appropriate error in case of failure.
    @discardableResult
    func delete<T: Stored>(_ objects: [T]) -> Result<()>
    
    /// Synchronously iterates through given objects and updates existing in database instances or creates them
    ///
    /// - Parameters:
    ///   - objects: objects to be worked with
    /// - Returns: `Result` with inserted and updated instances.
    @discardableResult
    func upsert<T : Stored>(_ objects: [T]) -> Result<(updated: [T], inserted: [T])>
    
}

public extension DBClient {
    
    /// Fetch all entities from database
    ///
    /// - Parameter completion: `Result` with array of objects
    func findAll<T: Stored>(completion: @escaping (Result<[T]>) -> Void) {
        execute(FetchRequest(), completion: completion)
    }
    
    /// Finds first element with given value as primary.
    /// If no primary key specified for given type, or object with such value doesn't exist returns nil.
    ///
    /// - Parameters:
    ///   - type: type of object to search for
    ///   - primaryValue: the value of primary key field to search for
    ///   - predicate: predicate for request
    ///   - completion: `Result` with found object or nil
    func findFirst<T: Stored>(_ type: T.Type, primaryValue: String, predicate: NSPredicate? = nil, completion: @escaping (Result<T?>) -> Void) {
        guard let primaryKey = type.primaryKeyName else {
            completion(.failure(DBClientError.noPrimaryKey))
            return
        }
        
        let primaryKeyPredicate = NSPredicate(format: "\(primaryKey) == %@", primaryValue)
        let fetchPredicate: NSPredicate
        if let predicate = predicate {
            fetchPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [primaryKeyPredicate, predicate])
        } else {
            fetchPredicate = primaryKeyPredicate
        }
        let request = FetchRequest<T>(predicate: fetchPredicate, fetchLimit: 1)
        
        execute(request) { result in
            completion(result.map({ $0.first }))
        }
    }
    
    /// Inserts object to database.
    ///
    /// - Parameters:
    ///   - object: object to be inserted
    ///   - completion: `Result` with inserted object or appropriate error in case of failure.
    func insert<T: Stored>(_ object: T, completion: @escaping (Result<T>) -> Void) {
        insert([object], completion: { completion($0.next(self.convertArrayTaskToSingleObject)) })
    }
    
    /// Updates changed performed with object to database.
    ///
    /// - Parameters:
    ///   - object: object to be updated
    ///   - completion: `Result` with updated object or appropriate error in case of failure.
    func update<T: Stored>(_ object: T, completion: @escaping (Result<T>) -> Void) {
        update([object], completion: { completion($0.next(self.convertArrayTaskToSingleObject)) })
    }
    
    /// Deletes object from database.
    ///
    /// - Parameters:
    ///   - object: object to be deleted
    ///   - completion: `Result` with appropriate error in case of failure.
    func delete<T: Stored>(_ object: T, completion: @escaping (Result<()>) -> Void) {
        delete([object], completion: completion)
    }
    
    private func convertArrayTaskToSingleObject<T>(_ array: [T]) -> Result<T> {
        guard let first = array.first else {
            return .failure(DBClientError.noData)
        }
        return .success(first)
    }
    
}
