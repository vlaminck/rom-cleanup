#!/usr/bin/xcrun swift -i

import Foundation

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
    
    var description: String {
        switch self {
        case .NES: return "NES"
        case .SNES: return "SNES"
        case .Genesis: return "Genesis"
        case .N64: return "N64"
        case .GB: return "Gameboy"
        case .GBC: return "Gameboy Color"
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
    let name: String
    let path: String
    var region: RomRegion? {
        return RomRegion(fromName: name)
    }
    var type: RomType? {
        return RomType(fromName: name)
    }
    var code: RomCode? {
        return RomCode(fromName: name)
    }
    var cleanName: String {
        guard let region = region, regionRange = name.rangeOfString(region.rawValue) else {
            // can't clean name without a known region
            return name
        }
        return name.substringToIndex(regionRange.startIndex).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
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
    
    if x.code == y.code && x.region == y.region {
        // same code and region
        if x.name.characters.count == y.name.characters.count {
            // name lengths are the same. order alphabetically
            // assert "1943 (U) (PRG0) [!]" < "1943 (U) (PRG1) [!]"
            return x.name < y.name
        }
        
        // name lengths are not the same, order by suffix simplicity
        // assert "1943 (U) [!]" < "1943 (U) [f][!]"
        return x.name.characters.count < y.name.characters.count
    }
    
    if x.code == y.code {
        // code is the same, order by region
        return x.region < y.region
    }
    
    // codes are not equal, order by code
    if x.code == nil {
        return false
    }
    if y.code == nil {
        return true
    }
    
    return x.code < y.code
}

// MARK: function declarations


func lookForRoms(directory: String, logPrefix: String) -> [ROM] {
    guard let contentsAtPath = try? NSFileManager.defaultManager().contentsOfDirectoryAtPath(directory) else {
        print("\(logPrefix)NOT A DIRECTORY: \(directory)")
        return []
    }
    
    if let lastDirectoryComponent = directory.componentsSeparatedByString("/").last {
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
        if let _ = rom.code {
            // only process specific codes
            roms.append(rom)
        }
        
        return roms
    }
}

func moveRom(fromPath: String, to toPath: String) {
    let itemUrl = NSURL(fileURLWithPath: fromPath)
    do {
        let destinationUrl = NSURL.fileURLWithPath(toPath, isDirectory: true)
        if let destinationName = destinationUrl.lastPathComponent {
            print("copying \(destinationName)")
        }
        try NSFileManager.defaultManager().copyItemAtURL(itemUrl, toURL: destinationUrl)
    } catch(let error) {
        print(error)
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
    return roms.reduce([String: [ROM]]()) { (var all: [String: [ROM]], current: ROM) in
        if var existingRoms = all[current.cleanName] {
            existingRoms.append(current)
            all[current.cleanName] = existingRoms
        } else {
            all[current.cleanName] = [current]
        }
        return all
        }.map { _, roms in
            return roms.sort(<).first
        }.flatMap { $0 }
}


// MARK: This is where the actual script starts


let currentPath = NSFileManager.defaultManager().currentDirectoryPath
//print("currentPath: \(currentPath)")

print("Attempting to process ROMs")
let foundRoms = lookForRoms(currentPath, logPrefix: "")
let roms = removeDuplicatesByPriority(foundRoms).sort(<)
print("")

let filteredDirectoryName = "filtered"
createDirectory("\(currentPath)/\(filteredDirectoryName)")

for rom in roms {
    guard let type = rom.type else {
        // only process known ROM types
        continue
    }
    guard let code = rom.code else {
        // only process roms that have codes that we care about
        continue
    }
    let destinationPath = "\(currentPath)/\(filteredDirectoryName)/\(type)"
    createDirectory(destinationPath)
    moveRom(rom.path, to: "\(destinationPath)/\(rom.name)")
}

print("ALL DONE")
