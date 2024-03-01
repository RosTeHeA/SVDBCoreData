//
//  File.swift
//
//
//  Created by Jordan Howlett on 8/4/23.
//

import Accelerate
import CoreML
import NaturalLanguage

@available(macOS 10.15, *)
@available(iOS 13.0, *)
public class Collection {
    private var documents: [UUID: Document] = [:]
    private let name: String
    private let synchronizationQueue = DispatchQueue(label: "com.streamline.collectionSynchronizationQueue", attributes: .concurrent)

    init(name: String) {
        self.name = name
    }

    public func addDocument(id: UUID? = nil, text: String, embedding: [Double]) {
        synchronizationQueue.async(flags: .barrier) {
            let document = Document(
                id: id ?? UUID(),
                text: text,
                embedding: embedding
            )

            self.documents[document.id] = document
            self.save()
        }
    }

    public func addDocuments(_ docs: [Document]) {
        synchronizationQueue.async(flags: .barrier) {
            docs.forEach { self.documents[$0.id] = $0 }
            self.save()
        }
    }
    
    public func removeDocument(byId id: UUID) {
        synchronizationQueue.async(flags: .barrier) {
            self.documents[id] = nil
            self.save()
        }
    }

    public func search(
        query: [Double],
        num_results: Int = 10,
        threshold: Double? = nil
    ) -> [SearchResult] {
        let queryMagnitude = sqrt(query.reduce(0) { $0 + $1 * $1 })

        var similarities: [SearchResult] = []
        for document in documents.values {
            let id = document.id
            let text = document.text
            let vector = document.embedding
            let magnitude = sqrt(vector.reduce(0) { $0 + $1 * $1 })
            let similarity = MathFunctions.cosineSimilarity(query, vector, magnitudeA: queryMagnitude, magnitudeB: magnitude)

            if let thresholdValue = threshold, similarity < thresholdValue {
                continue
            }

            similarities.append(SearchResult(id: id, text: text, score: similarity))
        }

        return Array(similarities.sorted(by: { $0.score > $1.score }).prefix(num_results))
    }

    private func save() {
        let svdbDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("SVDB")
        try? FileManager.default.createDirectory(at: svdbDirectory, withIntermediateDirectories: true, attributes: nil)
        
        let fileURL = svdbDirectory.appendingPathComponent("\(name).json")
        
        DispatchQueue.global(qos: .background).async {
            do {
                let encodedDocuments = try JSONEncoder().encode(self.documents)
                let compressedData = try (encodedDocuments as NSData).compressed(using: .zlib)
                try compressedData.write(to: fileURL)
            } catch {
                print("Failed to save documents: \(error.localizedDescription)")
            }
        }
    }

    public func load() throws {
        let svdbDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("SVDB")
        let fileURL = svdbDirectory.appendingPathComponent("\(name).json")

        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("File does not exist for collection \(name), initializing with empty documents.")
            documents = [:]
            return
        }

        do {
            let compressedData = try Data(contentsOf: fileURL)

            let decompressedData = try (compressedData as NSData).decompressed(using: .zlib)
            documents = try JSONDecoder().decode([UUID: Document].self, from: decompressedData as Data)

            print("Successfully loaded collection: \(name)")
        } catch {
            print("Failed to load collection \(name): \(error.localizedDescription)")
            throw CollectionError.loadFailed(error.localizedDescription)
        }
    }

    public func clear() {
        documents.removeAll()
        save()
    }
}
