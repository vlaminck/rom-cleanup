#!/usr/bin/xcrun swift -i

import Foundation

enum RomType: String {
    case NES = "NES"
    case SNES = "SNES"
    case Genesis = "Genesis"
    case N64 = "N64"
    
    var fileExtension: String {
        switch self {
        case .NES: return ".nes"
        case .SNES: return ".smc"
        case .Genesis: return ".gen"
        case .N64: return ".z64"
        }
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
    let type: RomType
    let state: RomState
    let region: String
    var cleanName: String {
        get {
            var cleanName = name.stringByReplacingOccurrencesOfString("(\(region))", withString: "")
            cleanName = cleanName.stringByReplacingOccurrencesOfString("[!]", withString: "")
            
            let c: [Character] = cleanName.characters.reduce([]) { (var all, c) in
                if let previous = all.last where previous == " " && c == " " {
                    // the previous character is whitespace and so is this one. Skip it
                    return all
                }
                all.append(c)
                return all
            }
            
            cleanName = String(c)
            cleanName = cleanName.stringByReplacingOccurrencesOfString(type.fileExtension, withString: "")
            cleanName = cleanName.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            cleanName.appendContentsOf(type.fileExtension)
            return cleanName
        }
    }
}

let romType: RomType = .NES
let region = "U"
let currentPath = NSFileManager.defaultManager().currentDirectoryPath
//print("currentPath: \(currentPath)")


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


func lookForRoms(directory: String, logPrefix: String, var paths: [ROM]) -> [ROM] {
    guard let contentsAtPath = try? NSFileManager.defaultManager().contentsOfDirectoryAtPath(directory) else {
        print("\(logPrefix)NOT A DIRECTORY: \(directory)")
        return paths
    }
    
    if let lastDirectoryComponent = directory.componentsSeparatedByString("/").last {
        print("\(logPrefix)Checking: \(lastDirectoryComponent)")
    }
    
    for contentItem in contentsAtPath {
        let itemPath: String = "\(directory)/\(contentItem)"
        
        if let _ = try? NSFileManager.defaultManager().contentsOfDirectoryAtPath(itemPath) {
            // it's a directory, check everything in it
            paths = lookForRoms(itemPath, logPrefix: "\(logPrefix) ", paths: paths)
            continue
        }
        
        guard contentItem.hasSuffix(romType.fileExtension) else { continue }
        
        let romState = checkName(contentItem, forRegion: region)
        if romState == .InRegion || romState == .Unknown {
            let rom = ROM(name: contentItem, path: itemPath, type: romType, state: romState, region: region)
            paths.append(rom)
        }
    }
    
    return paths
}

func moveRom(path: String, to toPath: String) {
    let itemUrl = NSURL(fileURLWithPath: path)
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
    do {
        let _ = try NSFileManager.defaultManager().createDirectoryAtPath(path, withIntermediateDirectories: false, attributes: nil)
        print("created directory: \(path)")
    } catch {
        // already exists
    }
}

print("Attempting to find all Verified Good [!] titles in region (U)")
let roms = lookForRoms(currentPath, logPrefix: "", paths: [])
print("")

for rom in roms {
    let directoryRegion = rom.state == .InRegion ? rom.region : "Unknown region)"
    let directoryName = "\(rom.type.rawValue) (\(directoryRegion)) [!]"
    let destinationPath = "\(currentPath)/\(directoryName)"
    createDirectory(destinationPath)
    moveRom(rom.path, to: "\(destinationPath)/\(rom.cleanName)")
}

print("ALL DONE")

















