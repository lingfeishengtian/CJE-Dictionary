import Foundation

protocol CSVCodable {
    init(strArray: [Substring]) throws
}

enum CSVError: LocalizedError {
    case runtimeError(String)
    
    var errorDescription: String? {
        return "Resources not Found"
    }
}

func readCSV<T:CSVCodable>(csvURL: URL) -> [T] {
    print("Conjugation manager start CSV reading: \(Date.now.timeIntervalSinceReferenceDate)")
    do {
        var ret: Array<T> = []
        
        guard FileManager.default.fileExists(atPath: csvURL.path) else {
            preconditionFailure("file expected at \(csvURL.path) is missing")
        }

        let data = try Data(contentsOf: csvURL)
        let split = data.withUnsafeBytes { unsafeRawBytes in
            unsafeRawBytes.split(separator: UInt8(ascii: "\n"))
        }
        
        ret.reserveCapacity(split.count - 1)

        for lineDat in split[1...] {
            let line = String(decoding: lineDat, as: UTF8.self)
            let tabSplit = line.split(separator: "\t", omittingEmptySubsequences: false)
            let appendVal = try T(strArray: tabSplit)
            ret.append(appendVal)
        }
        
        print("Conjugation manager finished CSV reading: \(Date.now.timeIntervalSinceReferenceDate)")
        return ret
    } catch {
        print("Conjugation manager error: Couldn't read csv \(csvURL.path()): \(error)")
        return []
    }
}

struct VerbTypes : CSVCodable {
    let id: Int
    let shortDescription: String
    let description: String
    
    init(strArray: [Substring]) throws {
        if strArray.count != 3 {
            throw CSVError.runtimeError("Not enough strings")
        }
        guard let id = Int(strArray[0]) else {
            throw CSVError.runtimeError("Not an Int")
        }
        self.id = id
        self.shortDescription = String(strArray[1])
        self.description = String(strArray[2])
    }
}

struct ConjugationTypes : CSVCodable {
    let id: Int
    let name: String
    
    init(strArray: [Substring]) throws {
        if strArray.count != 2 {
            throw CSVError.runtimeError("Not enough strings")
        }
        guard let id = Int(strArray[0]) else {
            throw CSVError.runtimeError("Not an Int")
        }
        self.id = id
        self.name = String(strArray[1])
    }
}

struct ConjugationNotes : CSVCodable {
    let id: Int
    let description: String
    
    init(strArray: [Substring]) throws {
        if strArray.count != 2 {
            throw CSVError.runtimeError("Not enough strings")
        }
        guard let id = Int(strArray[0]) else {
            throw CSVError.runtimeError("Not an Int")
        }
        self.id = id
        self.description = String(strArray[1])
    }
}

struct Conjugation : CSVCodable {
    let verbId: Int
    let conjugationTypeId: Int
    let isNegative: Bool
    let isFormal: Bool
    let conjugationFormId: Int
    let stemRemovalCharacterNum: Int
    let conjugation: String
    let kanaTextReplacement: String
    let kanjiTextReplacement: String
    let pos2: String // Unused
    
    // The verb - stemRemovalCharacterNum + kanji/kanaTextReplacement + conjugation

    init(strArray: [Substring]) throws {
        if strArray.count != 10 {
            throw CSVError.runtimeError("Not enough strings")
        }
        guard let verbId = Int(strArray[0]) else {
            throw CSVError.runtimeError("Not an Int")
        }
        self.verbId = verbId
        guard let conjugationTypeId = Int(strArray[1]) else {
            throw CSVError.runtimeError("Not an Int")
        }
        self.conjugationTypeId = conjugationTypeId
        guard let isNegative = strArray[2] == "t" ? true : false else {
            throw CSVError.runtimeError("Not a Bool")
        }
        self.isNegative = isNegative
        guard let isFormal = strArray[3] == "t" ? true : false else {
            throw CSVError.runtimeError("Not a Bool")
        }
        self.isFormal = isFormal
        guard let conjugationFormId = Int(strArray[4]) else {
            throw CSVError.runtimeError("Not an Int")
        }
        self.conjugationFormId = conjugationFormId
        guard let stemRemovalCharacterNum = Int(strArray[5]) else {
            throw CSVError.runtimeError("Not an Int")
        }
        self.stemRemovalCharacterNum = stemRemovalCharacterNum
        if strArray[6] != "\"\"" {
            self.conjugation = String(strArray[6])
        } else {
            self.conjugation = ""
        }
        self.kanaTextReplacement = String(strArray[7])
        self.kanjiTextReplacement = String(strArray[8])
        self.pos2 = String(strArray[9])
    }
}

struct ConjugationNotesLinker : CSVCodable {
    let verbId: Int
    let conjugationTypeId: Int
    let isNegative: Bool
    let isFormal: Bool
    let conjugationFormId: Int
    let noteId: Int

    init(strArray: [Substring]) throws {
        if strArray.count != 6 {
            throw CSVError.runtimeError("Not enough strings")
        }
        guard let verbId = Int(strArray[0]) else {
            throw CSVError.runtimeError("Not an Int")
        }
        self.verbId = verbId
        guard let conjugationTypeId = Int(strArray[1]) else {
            throw CSVError.runtimeError("Not an Int")
        }
        self.conjugationTypeId = conjugationTypeId
        guard let isNegative = strArray[2] == "t" ? true : false else {
            throw CSVError.runtimeError("Not a Bool")
        }
        self.isNegative = isNegative
        guard let isFormal = strArray[3] == "t" ? true : false else {
            throw CSVError.runtimeError("Not a Bool")
        }
        self.isFormal = isFormal
        guard let conjugationFormId = Int(strArray[4]) else {
            throw CSVError.runtimeError("Not an Int")
        }
        self.conjugationFormId = conjugationFormId
        guard let noteId = Int(strArray[5]) else {
            throw CSVError.runtimeError("Not an Int")
        }
        self.noteId = noteId
    }
}

enum ConjugationFiles: String {
    case ConjugationTypes = "conj"
    case ConjugationNotesLinker = "conjo_notes"
    case Conjugations = "conjo"
    case ConjugationNotes = "conotes"
    case VerbTypes = "types"
}

public struct VerbDictionaryForm: Hashable {
    let verbTypeId: Int
    let verbDictionaryForm: String
    //let derivations: [VerbDictionaryForm]
    
    public func hash(into hasher: inout Hasher) {
      hasher.combine(verbTypeId)
      hasher.combine(verbDictionaryForm)
    }
}

struct ConjugatedVerb: Hashable, Identifiable {
    let form: String
    let isNegative: Bool
    let isFormal: Bool
    let verb: String
    
    var id: String {
        return form + String(isFormal) + String(isNegative) + verb
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(form)
        hasher.combine(isNegative)
        hasher.combine(isFormal)
        hasher.combine(verb)
    }
}

class ConjugationManager {
    let verbTypes: [VerbTypes]
    let conjugationTypes: [ConjugationTypes]
    let conjugations: [Conjugation]
    let error: Bool
    
    static let sharedInstance = ConjugationManager()

    init() {
        guard let verbTypeURL = Bundle.main.url(forResource: ConjugationFiles.VerbTypes.rawValue, withExtension: "csv"), 
        let cTURL = Bundle.main.url(forResource: ConjugationFiles.ConjugationTypes.rawValue, withExtension: "csv"),
        let cURL = Bundle.main.url(forResource: ConjugationFiles.Conjugations.rawValue, withExtension: "csv") else {
            verbTypes = []
            conjugationTypes = []
            conjugations = []
            error = true
            
            return
        }
        verbTypes = readCSV(csvURL: verbTypeURL)
        conjugationTypes = readCSV(csvURL: cTURL)
        conjugations = readCSV(csvURL: cURL)
        error = false
    }
    
    func isDictionaryForm(_ c: Conjugation) -> Bool {
        return c.isFormal == false &&
        c.isNegative == false &&
        c.conjugationTypeId == 1
    }
    
    func getStemFor(conjugation: Conjugation) -> String {
        let conj = conjugations.first(where: { c in
            isDictionaryForm(c) &&
            c.verbId == conjugation.verbId
        })
        return conj?.conjugation ?? ""
    }
    
    func deconjugate(_ str: String) -> [VerbDictionaryForm] {
        var potentialCandidates: [VerbDictionaryForm] = []
        for conjugation in conjugations {
            if !conjugation.conjugation.isEmpty && str.hasSuffix(conjugation.kanaTextReplacement + conjugation.conjugation) {
                let base = String(str.dropLast(conjugation.conjugation.count + conjugation.kanaTextReplacement.count))
                let combine = base + getStemFor(conjugation: conjugation)
                if isDictionaryForm(conjugation) {
//                    print("\(combine): \(conjugation.conjugation) is dictionary")
                    // potentialCandidates.append(VerbDictionaryForm(verbTypeId: conjugation.verbId, verbDictionaryForm: combine, derivations: []))
                    continue
                }
                // let furtherDeconjugate = deconjugate(combine)
                potentialCandidates.append(VerbDictionaryForm(verbTypeId: conjugation.verbId, verbDictionaryForm: combine))
//                print(furtherDeconjugate)
                //potentialCandidates.append(combine + " " + String(conjugation.verbId) + " " + furtherDeconjugate.joined(separator: " "))
            }
        }
        return potentialCandidates
    }
    
    func conjugate(_ str: String, verbType: String) -> [ConjugatedVerb] {
        var conjugatedStrings: [ConjugatedVerb] = []
        guard let verbType = verbTypes.first(where: { $0.shortDescription == verbType }) else {
            return []
        }
        
        for conjugation in conjugations {
            if conjugation.verbId == verbType.id {
                if let conjugationType = conjugationTypes.first(where: { $0.id == conjugation.conjugationTypeId }) {
                    conjugatedStrings.append(ConjugatedVerb(form: conjugationType.name, isNegative: conjugation.isNegative, isFormal: conjugation.isFormal, verb: String(str.dropLast(conjugation.stemRemovalCharacterNum + conjugation.kanaTextReplacement.count)) + conjugation.kanaTextReplacement + conjugation.conjugation))
                }
            }
        }
        
        return conjugatedStrings
    }
}
