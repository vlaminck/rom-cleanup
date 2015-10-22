#!/usr/bin/xcrun swift -i

import Foundation

enum RomType: String, CustomStringConvertible {
    case NES = ".nes"
    case SNES = ".smc"
    case Genesis = ".gen"
    case N64 = ".z64"
    
    var description: String {
        switch self {
        case .NES: return "NES"
        case .SNES: return "SNES"
        case .Genesis: return "Genesis"
        case .N64: return "N64"
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

enum RomState {
    case InRegion       // The ROM is in the specified region and is Verified Good [!]
    case NotInRegion    // Not in the desired region, but is Verified Good [!]
    case Unknown        // The region is not clearly specified, but the ROM is Verified Good [!]
    case NotVerified    // don't bother with ROMs that aren't Verified Good [!]
}

struct ROM {
    let name: String
    let path: String
    let state: RomState
    let region: String
    var type: RomType? {
        get {
            return RomType(fromName: name)
        }
    }
    var cleanName: String {
        // TODO: Make this less nasty... at the very least make it more performant
        get {
            // Unknown ROM type. just return the name
            guard let type = type else { return name }

            // strip the file extension. We'll add it back later
            var cleanName = name.stringByReplacingOccurrencesOfString(type.rawValue, withString: "")
            
            // remove known codes
            cleanName = cleanName.stringByReplacingOccurrencesOfString("(\(region))", withString: "")
            cleanName = cleanName.stringByReplacingOccurrencesOfString("[!]", withString: "")
            
            // strip whitespace
            cleanName = cleanName.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())

            // remove extra whitespace in the middle of the name
            let c: [Character] = cleanName.characters.reduce([]) { (var all, c) in
                if let previous = all.last where previous == " " && c == " " {
                    // the previous character is whitespace and so is this one. Skip it
                    return all
                }
                all.append(c)
                return all
            }
            cleanName = String(c)
            
            // put the file extension back on
            cleanName.appendContentsOf(type.rawValue)
            return cleanName
        }
    }
}

func checkName(name: String, forRegion region: String) -> RomState {
    
    // only look for verified good ROMs
    guard name.containsString("[!]") else { return .NotVerified }
    
    let regionPattern = "(?<=\\()(.*?)(?=\\))" // Looking for all strings withing parenthases like "U" in the string "Metroid (U) [!].nes"
    guard let regex = try? NSRegularExpression(pattern: regionPattern, options: NSRegularExpressionOptions.CaseInsensitive) else { return .NotVerified }
    
    let range = NSRange(location: 0, length: name.characters.count)
    var regionState: RomState = .NotInRegion
    regex.enumerateMatchesInString(name, options: NSMatchingOptions.ReportCompletion, range: range) { (result, _, _) in
        
        guard regionState != .InRegion else { return }  // we already know it's in the region. move on
        guard let result = result else { return }       // we need a result to evaluate
        
        let subRange = result.rangeAtIndex(0)
        let substring = (name as NSString).substringWithRange(subRange)
        
        if substring == region {
            regionState = .InRegion
        } else if substring.containsString(region) {
            regionState = .Unknown
        }
    }
    return regionState
}


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

        // make sure it's a known ROM type
        guard let _ = RomType(fromName: contentItem) else { return roms }
        
        let romState = checkName(contentItem, forRegion: region)
        if romState == .InRegion || romState == .Unknown {
            let rom = ROM(name: contentItem, path: itemPath, state: romState, region: region)
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


/// This is where the actual script starts


let region = "U"
let currentPath = NSFileManager.defaultManager().currentDirectoryPath
//print("currentPath: \(currentPath)")

print("Attempting to find all Verified Good [!] titles in region (\(region))")
let roms = lookForRoms(currentPath, logPrefix: "")
print("")

for rom in roms {
    guard let type = rom.type else { continue } // only process known ROM types
    let directoryRegion = rom.state == .InRegion ? rom.region : "Unknown region)"
    let directoryName = "\(type) (\(directoryRegion)) [!]"
    let destinationPath = "\(currentPath)/\(directoryName)"
    createDirectory(destinationPath)
    moveRom(rom.path, to: "\(destinationPath)/\(rom.cleanName)")
}

print("ALL DONE")
