import CoreData
import NaturalLanguage

@available(macOS 10.15, *)
@available(iOS 13.0, *)
public class SVDB {
    public static let shared = SVDB()
    private var collections: [String: Collection] = [:]

    private init() {}

    public func collection(_ name: String, context: NSManagedObjectContext) throws -> Collection {
        if let existingCollection = collections[name] {
            return existingCollection
        }

        let newCollection = Collection(name: name, context: context)
        collections[name] = newCollection
        return newCollection
    }

    public func getCollection(_ name: String) -> Collection? {
        return collections[name]
    }

    public func releaseCollection(_ name: String) {
        collections[name] = nil
    }

    public func reset() {
        for (_, collection) in collections {
            collection.clear()
        }
        collections.removeAll()
    }
}
