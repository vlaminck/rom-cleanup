#!/usr/bin/xcrun swift -i

import Foundation

let filteredDirectoryName = "filtered"
var totalRomsProcessed = 0
var filteredRomCount = 0

// MARK: debugging

class FunctionTimer {
    private var startDate: NSDate?
    private var endDate: NSDate?
    
    init(autoStart: Bool = true) {
        if autoStart {
            start()
        }
    }
    
    var duration: Double? {
        guard let startDate = startDate, endDate = endDate else { return nil }
        return endDate.timeIntervalSinceDate(startDate)
    }
    
    func start() {
        startDate = NSDate()
    }
    
    // conveniently returns the duration
    func end() -> Double? {
        endDate = NSDate()
        return duration
    }
}


// MARK: object declarations

enum RomRegion: String {
    //    (1) Japan & Korea
    //    (4) USA & Brazil - NTSC
    case A  // Australia
    case J  // Japan
    case B  // Brazil
    case K  // Korea
    case C  // China
    case NL // Netherlands
    case E  // Europe
    case PD // Public Domain
    case F  // France
    case S  // Spain
    //    (F) World (Genesis)
    case FC // French Canadian
    case SW // Sweden
    case FN // Finland
    case U  // USA
    case G  // Germany
    case UK // England
    case GR // Greece
    case Unk// Unknown Country
    case HK // Hong Kong
    case I  // Italy
    case H  // Holland
    case Unl// Unlicensed
    case JU // Japan & USA
    case UE // Europe & USA
    
    init?(fromName name: String) {
        let regionPattern = "(?<=\\()(.*?)(?=\\))" // Looking for all strings withing parenthases like "U" in the string "Metroid (U) [!].nes"
        guard let regex = try? NSRegularExpression(pattern: regionPattern, options: NSRegularExpressionOptions.CaseInsensitive) else { return nil }
        
        let range = NSRange(location: 0, length: name.characters.count)
        var regionString: String?
        regex.enumerateMatchesInString(name, options: NSMatchingOptions.ReportCompletion, range: range) { (result, _, _) in
            guard let result = result else { return }   // we need a result to evaluate
            guard regionString == nil else { return }   // we found a region in the previous enumeration
            
            let subRange = result.rangeAtIndex(0)
            regionString = (name as NSString).substringWithRange(subRange)
        }
        
        guard regionString != nil else { return nil }
        guard let region = RomRegion(rawValue: regionString!) else { return nil } // I don't love the force cast here, but the guard above proves it's there
        
        self = region
    }
    
    var formatted: String {
        return "(\(rawValue))"
    }
}
extension RomRegion: Comparable {}
/// we're going to use the same logic as strings. Lower is better
func <(x: RomRegion, y: RomRegion) -> Bool {
    guard x != y else { return false }
    
    // preffered order
    // U, E, J, then alphabetical
    
    // check .U
    if x == .U { return true }
    if y == .U { return false }
    
    // check .E
    if x == .E { return true }
    if y == .E { return false }
    
    // check .J
    if x == .J { return true }
    if y == .J { return false }
    
    // all others are equal
    return x.rawValue < y.rawValue
}

enum RomType: String, CustomStringConvertible {
    case NES = ".nes"
    case SNES = ".smc"
    case Genesis = ".gen"
    case N64 = ".z64"
    case GB = ".gb"
    case GBC = ".gbc"
    case GBA = ".gba"
    
    var directoryName: String {
        switch self {
        case .NES: return "nes"
        case .SNES: return "snes"
        case .Genesis: return "megadrive"
        case .N64: return "n64"
        case .GB: return "gb"
        case .GBC: return "gbc"
        case .GBA: return "gba"
        }
    }
    
    var description: String {
        switch self {
        case .NES: return "NES"
        case .SNES: return "SNES"
        case .Genesis: return "Genesis"
        case .N64: return "N64"
        case .GB: return "Gameboy"
        case .GBC: return "Gameboy Color"
        case .GBA: return "Gameboy Advance"
        }
    }
    
    init?(fromName name: String) {
        guard let fileExtension = name.componentsSeparatedByString(".").last,
            romType = RomType(rawValue: ".\(fileExtension)") else {
                return nil
        }
        self = romType
    }
    
}

enum RomCode: String {
    case Verified = "[!]"   // [!] Verified good dump. Thank God for these!
    /// These don't actually work.
    // TODO: write regex to find Fixed and Alternate versions or just make an isVerified Bool on ROM
    case Fixed = "[f]"      // [f] A fixed game has been altered in some way so that it will run better on a copier or emulator.
    case Alternate = "[a]"  // [a] This is simply an alternate version of a ROM. Many games have been re-released to fix bugs or even to eliminate Game Genie codes (Yes, Nintendo hates that device).
    // I don't care about any other type. If you do, check this out https://64bitorless.wordpress.com/rom-suffix-explanations/
    
    init?(fromName name: String) {
        if name.containsString(RomCode.Verified.rawValue) {
            self = .Verified
        } else if name.containsString(RomCode.Fixed.rawValue) {
            self = .Fixed
        } else if name.containsString(RomCode.Alternate.rawValue) {
            self = .Alternate
        } else {
            return nil
        }
    }
    
}
extension RomCode: Comparable {}
func <(x: RomCode, y: RomCode) -> Bool {
    if x == y { return false }
    if x == .Verified { return true }
    if y == .Verified { return false }
    if x == .Fixed { return true }
    if y == .Fixed { return false }
    return true
}

struct ROM {
    
    // provided by creator
    let name: String
    let path: String
    
    // set during initialisation during init
    let region: RomRegion?
    let type: RomType?
    let cleanName: String
    let isVerified: Bool
    
    init(name: String, path: String) {
        self.name = name
        self.path = path
        region = RomRegion(fromName: name)
        type = RomType(fromName: name)
        if let r = region, regionRange = name.rangeOfString("(\(r.rawValue)") {
            cleanName = name.substringToIndex(regionRange.startIndex).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        } else {
            cleanName = name
        }
        isVerified = name.containsString("[!]")
    }
    
    var gbaName: String? {
        guard let gbaType = type where gbaType == RomType.GBA else { return nil }

        func matchesNumberedSystem(name: String) -> Bool {
            let firstFour = (name as NSString).substringToIndex(4)
            if Int(firstFour) == nil {
                // not a number
                return false
            }
            
            return name.hasPrefix("\(firstFour) - ")
        }
        
        var gbaName: String = matchesNumberedSystem(name) ? (name as NSString).substringFromIndex(7) : name
        if let lastIndex = gbaName.characters.indexOf("(") ?? gbaName.rangeOfString(".gba")?.startIndex {
            gbaName = gbaName.substringToIndex(lastIndex)
        }
        gbaName = gbaName.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        if let region = region {
            gbaName = "\(gbaName) (\(region.rawValue))"
        }
        return "\(gbaName)\(gbaType.rawValue)"
    }
}
extension ROM: Comparable {}
func ==(x: ROM, y: ROM) -> Bool {
    return x.name == y.name
}
func <(x: ROM, y: ROM) -> Bool {
    guard x.cleanName == y.cleanName else {
        // the game names are not the same, order alphabetically
        return x.name < y.name
    }
    
    if x.isVerified && !y.isVerified {
        return true
    }
    if !x.isVerified && y.isVerified {
        return false
    }
    
    // codes are essentially equivelent
    
    if x.region != y.region {
        // regions are different; sort by region
        return x.region < y.region
    } else {
        // same code and region; sort by name
        if x.name.characters.count == y.name.characters.count {
            // name lengths are the same. order alphabetically
            // assert "1943 (U) (PRG0) [!]" < "1943 (U) (PRG1) [!]"
            return x.name < y.name
        }
        
        // name lengths are not the same, order by suffix simplicity
        // assert "1943 (U) [!]" < "1943 (U) [f1][!]"
        return x.name.characters.count < y.name.characters.count
    }
}

// MARK: function declarations


func lookForRoms(directory: String, logPrefix: String) -> [ROM] {
    guard let contentsAtPath = try? NSFileManager.defaultManager().contentsOfDirectoryAtPath(directory) else {
        print("\(logPrefix)NOT A DIRECTORY: \(directory)")
        return []
    }
    
    if let lastDirectoryComponent = directory.componentsSeparatedByString("/").last {
        if lastDirectoryComponent == filteredDirectoryName {
            print("\(logPrefix)Skipping: \(filteredDirectoryName)")
            return []
        }
        print("\(logPrefix)Checking: \(lastDirectoryComponent)")
    }
    
    return contentsAtPath.reduce([]) { (var roms, contentItem) in
        let itemPath: String = "\(directory)/\(contentItem)"
        
        if let _ = try? NSFileManager.defaultManager().contentsOfDirectoryAtPath(itemPath) {
            // it's a directory, check everything in it
            roms = roms + lookForRoms(itemPath, logPrefix: "\(logPrefix) ")
            return roms
        }

        let rom = ROM(name: contentItem, path: itemPath)
        totalRomsProcessed += 1
        if let region = rom.region where region == .U || region == .UE || region == .JU {
            // only process specific regions
//            print("\(logPrefix)Taking: \(rom.name)")
            roms.append(rom)
        } else {
//            print("\(logPrefix)Skipping: \(rom.name)")
        }

        return roms
    }
}

func moveRom(fromPath: String, to toPath: String) {
    let itemUrl = NSURL(fileURLWithPath: fromPath)
    do {
        let destinationUrl = NSURL.fileURLWithPath(toPath, isDirectory: true)
//        if let destinationName = destinationUrl.lastPathComponent {
//            print("copying \(destinationName)")
//        }
        try NSFileManager.defaultManager().copyItemAtURL(itemUrl, toURL: destinationUrl)
        if let destinationName = destinationUrl.lastPathComponent {
            print("copyied \(destinationName)")
        }
    } catch(let error) {
//        print(error)
    }
}

func createDirectory(path: String) {
    // TODO: look for directory instead of blindly trying to create it
    do {
        let _ = try NSFileManager.defaultManager().createDirectoryAtPath(path, withIntermediateDirectories: false, attributes: nil)
        print("created directory: \(path)")
    } catch {
        // directory already exists
    }
}

func removeDuplicatesByPriority(roms: [ROM]) -> [ROM] {
    var allSystems: [RomType: [String: [ROM]]] = [:]
    for rom in roms {
        guard let type = rom.type else {
            print("skipping rom with unknown type: \(rom)")
            continue
        }
        
        var chunked: [String: [ROM]] = allSystems[type] ?? [:]
        var existingRoms:[ROM] = chunked[rom.cleanName] ?? []
        existingRoms.append(rom)
        chunked[rom.cleanName] = existingRoms
        allSystems[type] = chunked
    }
    let mapped: [ROM] = allSystems.flatMap { _, chunks in
        return chunks.flatMap { key, roms in
            let sortedRoms = roms.sort(<)
            print("")
            print(key)
            print(sortedRoms.map({ $0.name }))
            return sortedRoms.first
        }
    }
    return mapped
}

// MARK: This is where the actual script starts

func input() -> String? {
    let keyboard = NSFileHandle.fileHandleWithStandardInput()
    let inputData = keyboard.availableData
    return NSString(data: inputData, encoding: NSUTF8StringEncoding) as? String
}

print("Separate by region? (y/n): ")
let userInput = input()
let separateByRegion = userInput?.lowercaseString.hasPrefix("y") ?? false


var totalTime = FunctionTimer()


let currentPath = NSFileManager.defaultManager().currentDirectoryPath
//print("currentPath: \(currentPath)")

print("Attempting to process ROMs")
let foundRoms = lookForRoms(currentPath, logPrefix: "")
let roms = removeDuplicatesByPriority(foundRoms).sort(<)
print("")

createDirectory("\(currentPath)/\(filteredDirectoryName)")

for rom in roms {
    guard let type = rom.type else {
        // only process known ROM types
        print("NOT copying \(rom.name); unknown type: \(rom.type)")
        continue
    }
    
    let destinationPath = "\(currentPath)/\(filteredDirectoryName)/\(type.directoryName)"
    createDirectory(destinationPath)
    
    let fileName = rom.gbaName ?? rom.name

    if (separateByRegion) {
        let regionDirectory = rom.region?.rawValue ?? "_unknown_region"
        let regionPath = "\(destinationPath)/\(regionDirectory)"
        createDirectory(regionPath)
        moveRom(rom.path, to: "\(regionPath)/\(fileName)")
        filteredRomCount += 1
    } else {
        moveRom(rom.path, to: "\(destinationPath)/\(fileName)")
        filteredRomCount += 1
    }
    
}

print("ALL DONE!")
print("checked \(totalRomsProcessed) ROMs, and copied \(filteredRomCount) ROMs.")
if let duration = totalTime.end() {
    print("total processing time took \(duration) seconds")
}
