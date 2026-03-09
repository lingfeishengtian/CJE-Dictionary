import Foundation
import RealmSwift

@objc(wordIndex)
final class MongoWordIndexObject: Object {
    @Persisted var id: Int64
    @Persisted var wort: String?
    @Persisted var w: String?
    @Persisted var m: String?
}

@objc(word)
final class MongoWordObject: Object {
    @Persisted var id: Int64
    @Persisted var m: String?
}

private let mongoRealmObjectTypes: [Object.Type] = [
    MongoWordIndexObject.self,
    MongoWordObject.self,
    Wort.self,
    Details.self,
    Subdetails.self,
    Example.self
]

func mongoRealmConfiguration(filePath: String) -> Realm.Configuration {
    var configuration = CONFIGURATION
    configuration.fileURL = URL(fileURLWithPath: filePath)
    configuration.objectTypes = mongoRealmObjectTypes
    return configuration
}
