//
//  File.swift
//
//
//  Created by Jordan Howlett on 8/4/23.
// Adapted for use with CoreData by RosTeHea on 12-16-2023
//

import CoreData
import NaturalLanguage

@available(macOS 10.15, *)
@available(iOS 13.0, *)
public class Collection {
    private let name: String
    private let context: NSManagedObjectContext

    init(name: String, context: NSManagedObjectContext) {
        self.name = name
        self.context = context
    }

    public func addDocument(id: UUID? = nil, text: String, embedding: [Double]) {
        let document = SVDBDocument(context: context)
        document.id = id ?? UUID()
        document.text = text
        document.embedding = embedding

        saveContext()
    }

    public func addDocuments(_ docs: [SVDBDocument]) {
        docs.forEach { context.insert($0) }
        saveContext()
    }

    public func removeDocument(byId id: UUID) {
        let fetchRequest: NSFetchRequest<SVDBDocument> = SVDBDocument.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let results = try context.fetch(fetchRequest)
            results.forEach { context.delete($0) }
            saveContext()
        } catch {
            print("Failed to remove document: \(error.localizedDescription)")
        }
    }

    public func search(
            query: [Double],
            num_results: Int = 10,
            threshold: Double? = nil
        ) -> [SearchResult] {
            let fetchRequest: NSFetchRequest<SVDBDocument> = SVDBDocument.fetchRequest()

            do {
                let documents = try context.fetch(fetchRequest)
                return documents.compactMap { document in
                    let id = document.id
                    let text = document.text
                    let vector = document.embedding
                    let similarity = calculateCosineSimilarity(query: query, vector: vector)

                    if let thresholdValue = threshold, similarity < thresholdValue {
                        return nil
                    }

                    return SearchResult(id: id, text: text, score: similarity)
                }
                .sorted(by: { $0.score > $1.score })
                .prefix(num_results)
                .map { $0 }
            } catch {
                print("Search failed: \(error.localizedDescription)")
                return []
            }
        }

    private func saveContext() {
         do {
             try context.save()
         } catch {
             print("Failed to save context: \(error.localizedDescription)")
         }
     }

     public func clear() {
         let fetchRequest: NSFetchRequest<NSFetchRequestResult> = SVDBDocument.fetchRequest()
         let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

         do {
             try context.execute(deleteRequest)
             saveContext()
         } catch {
             print("Failed to clear documents: \(error.localizedDescription)")
         }
     }
 }
