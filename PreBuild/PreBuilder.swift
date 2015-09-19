//
//  PreBuilder.swift
//  PreBuild
//
//  Created by Niklas Saers on 24/06/15.
//  Copyright © 2015 Niklas Saers. All rights reserved.
//  Licensed under the 3-clause BSD license - http://opensource.org/licenses/BSD-3-Clause
//

import Foundation

enum Hook {
    case Pre
    case Post
    
    func toString() -> String {
        switch self {
        case .Pre:
            return "Pre"
        case .Post:
            return "Post"
        }
    }
}

class PreBuilder {
    
    var verbose : Bool = false
    var config : NSDictionary = NSDictionary()
    
    var stdout : NSFileHandle? = nil
    var stderr : NSFileHandle? = nil
    
    
    init(configFiles: [String], fallbackConfigFile: String?) {
        
        var input : NSMutableDictionary = NSMutableDictionary()

        // Merge config files
        if configFiles.count == 1 {
            input["config"] = readFileAsJSON(configFiles.first!)
        } else {
            
            for configFile in configFiles {
                if input["default"] == nil {
                    input["default"] = readFileAsJSON(configFile)
                } else {
                    input["config"] = readFileAsJSON(configFile)
                    input = merge(input).mutableCopy() as! NSMutableDictionary
                    input["default"] = input["config"]
                }
            }
            
            input["config"] = input["default"]
            input.removeObjectForKey("defaul")
        }
        
        // Done config

        let info = NSProcessInfo.processInfo()
        input["environment"] = info.environment

        if let defaultPath = fallbackConfigFile {
            input["default"] = readFileAsJSON(defaultPath)
            input = merge(input).mutableCopy() as! NSMutableDictionary
        }
        
        // Then move it down a level
        for (key, value) in input["config"] as! [String:[String:AnyObject]] {
            input[key] = value
        }
        input.removeObjectForKey("config")

        // Finally, do specialized post-treatment
        config = supplyDefaults(input)
        input = config.mutableCopy() as! NSMutableDictionary
        config = checkProvisioingProfiles(input)
    }
    
    func configValueForKeyPath(keyPath: String) -> AnyObject? {
        return self.valueForKeyPathFromDict(self.config, keyPath: keyPath)
    }
    
    func valueForKeyPathFromDict(input: NSDictionary, keyPath: String) -> AnyObject? {
        
        let keyAr : [String] = keyPath.splitByCharacter(".")
        var slice : NSDictionary = input
        
        for index in 0..<keyAr.count {
            let key = keyAr[index]
            if index + 1 == keyAr.count {
                if let out = slice[key] {
                    return out
                } else {
                    if key.containsString(":") {
                        let ar = key.splitByCharacter(":")
                        
                        guard let first = slice[ar[0]] as? NSArray else {
                            return nil
                        }
                        
                        let idx : Int = (ar[1] as NSString).integerValue
                        if idx >= first.count {
                            return nil // Array out of bounds
                        }

                        return first[idx]
                    } else {
                        return nil
                    }
                }
            } else {
                if let newSlice = slice[key] as? [String:AnyObject] {
                    slice = newSlice
                } else {
                    
                    if key.containsString(":") {
                        let ar = key.splitByCharacter(":")
                        
                        guard let first = slice[ar[0]] as? NSArray else {
                            return nil
                        }
                        
                        let idx : Int = (ar[1] as NSString).integerValue
                        if let dict = first[idx] as? NSDictionary {
                            slice = dict
                        } else {
                            return nil
                        }
                    } else {
                        return nil
                    }
                }
            }
            
        }
        
        assert(false, "We should never get here")
        return nil
        
    }
    
    func openLog(name: String, fileKeypath: String, appendKeypath: String) -> NSFileHandle {
        guard let outPath = configValueForKeyPath(fileKeypath) as? String else {
            print("\(name) path not set at \(fileKeypath), aborting!")
            exit(EX_CONFIG)
        }
        
        let append = configValueForKeyPath(appendKeypath) as? Bool ?? false
        
        var fileHandler : NSFileHandle?
        
        if append == true {
            fileHandler = NSFileHandle(forUpdatingAtPath: outPath)
            fileHandler?.seekToEndOfFile()
        } else {
            fileHandler = NSFileHandle(forWritingAtPath: outPath)
        }

        if fileHandler == nil {
            NSFileManager.defaultManager().createFileAtPath(outPath, contents:nil, attributes:nil)
            fileHandler = NSFileHandle(forWritingAtPath: outPath)
        }

        if fileHandler == nil {
            print("\(name) path '\(outPath)' could not be opened for writing at \(fileKeypath), aborting!")
            exit(EX_CONFIG)
        }
        
        return fileHandler!
    }
    
    func logError(string: String) {
        if self.verbose {
            print(string)
        }

        if self.stderr == nil {
            self.stderr = openLog("STDERR", fileKeypath: "PreBuilder.logs.stderr.path", appendKeypath: "PreBuilder.logs.stderr.append")
        }
    }
    
    func logInfo(string: String) {
        if self.verbose {
            print(string)
        }
        
        if self.stdout == nil {
            self.stdout = openLog("STDOUT", fileKeypath: "PreBuilder.logs.stdout.path", appendKeypath: "PreBuilder.logs.stdout.append")
        }
        
        self.stdout?.writeData(string.dataUsingEncoding(NSUTF8StringEncoding)!)
    }
    
    func cleanup() {
        self.stdout?.closeFile()
        self.stderr?.closeFile()
    }
    
    func supplyDefaults(input : NSDictionary) -> NSDictionary {
        let output : NSMutableDictionary = input.mutableCopy() as! NSMutableDictionary
        
        let defaultLogFiles = [
            "stdout": [
                "path": "/tmp/PreBuilder-stdout.log",
                "append": false
            ],
            "stderr": [
                "path": "/tmp/PreBuilder-stderr.log",
                "append": false
            ]
        ]
        
        if let prebuilder = output["PreBuilder"] as? NSDictionary {
            let modifiedPrebuilder = mergeInMissingFromDict(prebuilder, key: "logs", defaults: defaultLogFiles)
            output["PreBuilder"] = modifiedPrebuilder
        } else {
            output["PreBuilder"] = [ "logs" : defaultLogFiles ]
        }
        
        return NSDictionary(dictionary: output)
        
    }
    
    func readFileAsJSON(filepath: String) -> NSDictionary {
        guard let data = NSData(contentsOfFile: filepath) else {
            print("Error: \(filepath) could not be read")
            exit(EX_USAGE)
        }
        
        do {
            let json = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) as! NSDictionary
            return json
        } catch {
            print("Error: \(filepath) could not be parsed as valid JSON: \(error)")
            exit(EX_USAGE)
        }
    }
    
    func mergeInMissingFromDict(input: NSDictionary,
        key: String,
        defaults: [String:AnyObject]) -> NSDictionary {
            
            let output : NSMutableDictionary = input.mutableCopy() as! NSMutableDictionary
            
            if let slice = output[key] as? NSDictionary {

                let mSlice = slice.mutableCopy() as! NSMutableDictionary
                
                for (defaultKey, defaultValue) in defaults {
                    if let _ = slice[defaultKey] {
                        // Value was set, so leave it be
                    } else {
                        if let newSlice : NSDictionary = slice[key] as? NSDictionary {
                            let mNewSlice : NSMutableDictionary = newSlice.mutableCopy() as! NSMutableDictionary
                            mNewSlice[defaultKey] = defaultValue
                            mSlice[key] = NSDictionary(dictionary: mNewSlice)
                        } else {
                            assert(false) // Should not happen!
                        }
                        
                    }
                }
                
                output[key] = NSDictionary(dictionary: mSlice)
                
            } else {
                output[key] = defaults
            }

            return NSDictionary(dictionary: output)
    }
    
    func merge(source : NSDictionary, overwriter: AnyObject) -> NSDictionary {
        
        let outDict : NSMutableDictionary = source.mutableCopy() as! NSMutableDictionary

        if let overwriter = overwriter as? [String:[String:AnyObject]] {
            for (key, value) in overwriter {
                if outDict[key] == nil {
                    outDict[key] = value
                } else {
                    outDict[key] = merge(outDict[key] as! NSDictionary, overwriter: value)
                }
            }
        } else if let overwriter = overwriter as? [String:AnyObject] {
            for (key, value) in overwriter {
                outDict[key] = value
            }
        } else {
            print("")
        }

        return NSDictionary(dictionary: outDict)
    }
    
    func merge(input : NSDictionary) -> NSDictionary {
        assert(input["config"] != nil)
        assert(input["default"] != nil)
        
        let config = (input["default"] as! NSDictionary).mutableCopy() as! NSMutableDictionary
        let overwrite = (input["config"] as! NSDictionary).mutableCopy() as! NSMutableDictionary
        for (key, value) in overwrite {
            if config.objectForKey(key) == nil {
                config[key as! String] = value
            } else {
                let stringKey = key as! String
                let dictVal : NSDictionary = merge(config[stringKey] as! NSDictionary, overwriter: value)
                config[stringKey] = dictVal
            }
        }
        
        let output : NSMutableDictionary = input.mutableCopy() as! NSMutableDictionary
        output.removeObjectForKey("default")
        output["config"] = config
        
        return NSDictionary(dictionary: output)
    }
    
    func dumpConfig() -> String {
        
        do {
            return try NSString(data: NSJSONSerialization.dataWithJSONObject(config, options: NSJSONWritingOptions.PrettyPrinted), encoding: NSUTF8StringEncoding) as! String
        } catch {
            return "Error parsing state"
        }
    }
    
    func run() {
        
        logInfo("Configuration: " + dumpConfig())
        
        // Create a Configuration.plist file based on config
        
        runClean()
        runAssets()
        runProvisioningProfiles()
//        runRemoveLocalizations()
//        runSignIcons()
        runSettings()
        runEditInfoPlist()
        runMakeConfigurationPlist()
        
        print("Configuration: " + dumpConfig())
    }
    
    func addDicts(dictA: [String:AnyObject], dictB: [String:AnyObject]) -> [String:AnyObject] {
        var outDict = dictA
        for (key, value) in dictB {
            outDict[key] = value
        }
        return outDict
    }
    
    func flattenKeysInDict(dict: NSDictionary, var keyPrefix: String) -> [String:AnyObject] {
        
        var result : [String:AnyObject] = [:]
        if keyPrefix != "" {
            keyPrefix += "_"
        }
        
        
        for (aKey, value) in dict {
            let key = aKey as! String
            if let value = value as? Int {
                result[keyPrefix + key] = String(value)
            } else if let value = value as? Bool {
                result[keyPrefix + key] = String(value)
            } else if let value = value as? String {
                result[keyPrefix + key] = String(value)
            } else if let value = value as? [String:AnyObject] {
                let newPrefix = keyPrefix + key
                result = addDicts(result, dictB: flattenKeysInDict(value, keyPrefix: newPrefix))
            } else {
                result[key] = String(value)
            }
        }
        
        return result
    }
    
    func environment() -> [String:String] {
        // Set up environment
        let config = self.config.mutableCopy()
        config.removeObjectForKey("environment")
        var env : [String:AnyObject] = self.config["environment"]! as! [String : AnyObject]
        env = addDicts(env, dictB: flattenKeysInDict(config as! NSDictionary, keyPrefix: ""))
        return env as! [String:String]
    }

    func task(cmd: String, args: [String]) -> String {
        return task(cmd, args: args, stdin: nil)
    }
    
    func task(cmd: String, args: [String], stdin: String?) -> String {
        
        logInfo("Running task \(cmd) with arguments \(args)")
        
        let task = NSTask()
        let stdOutPipe = NSPipe()
        let stdOutReadHandle = stdOutPipe.fileHandleForReading
        let stdErrPipe = NSPipe()
        let stdErrReadHandle = stdErrPipe.fileHandleForReading

        if let stdin = stdin {
            let stdInPipe = NSPipe()
            task.standardInput = stdInPipe
            stdInPipe.fileHandleForWriting.writeData(stdin.dataUsingEncoding(NSUTF8StringEncoding)!)
            stdInPipe.fileHandleForWriting.closeFile()
        }
        
        task.launchPath = cmd
        task.environment = self.config["environment"] as? [String:String]
        task.arguments = args
        task.standardOutput = stdOutPipe
        task.standardError = stdErrPipe
        task.launch()
        task.waitUntilExit()
        
        let out = NSString(data: stdOutReadHandle.readDataToEndOfFile(), encoding: NSUTF8StringEncoding)
        let err = NSString(data: stdErrReadHandle.readDataToEndOfFile(), encoding: NSUTF8StringEncoding)
        logInfo(out as! String)
        logError(err as! String)
        
        if let out = out {
            return out as String
        } else {
            return ""
        }
    }
    
    func hook(area: String, hook: Hook) {
        logInfo("\(area): \(hook.toString())-hook")
        
        // Get hook
        let hookCmd = configValueForKeyPath("PreBuilder.\(area).\(hook.toString())-hook.path") as? String
        let hookArgs = configValueForKeyPath("PreBuilder.\(area).\(hook.toString())-hook.arguments") as? [String]
        
        if let cmd = hookCmd, args = hookArgs {
            task(cmd, args:args)
        }
    }

    func cleanOutDir(dir: String) {
        let url = NSURL(fileURLWithPath: dir)
        
        let fileManager = NSFileManager.defaultManager()
        let enumerator = fileManager.enumeratorAtURL(url, includingPropertiesForKeys: nil, options: .SkipsSubdirectoryDescendants, errorHandler: nil)
        while let file = enumerator?.nextObject() as? NSURL {
            var isDir : ObjCBool = false
            fileManager.fileExistsAtPath(file.path!, isDirectory: &isDir)
            if isDir {
                cleanOutDir(file.path!)
            } else {
                do {
                    try fileManager.removeItemAtURL(file)
                } catch {
                    logError("Could not delete file \(file.path)")
                }
            }
        }
    }
    
    func runClean() {
        
        hook("Clean", hook: .Pre)
        
        if let paths : [String] = configValueForKeyPath("PreBuilder.Clean.Paths") as? [String] {
            for path in paths {
                cleanOutDir(path)
            }
        }
        
        hook("Clean", hook: .Post)
    }

    
    func runAssets() {

        hook("Assets", hook: .Pre)
        
        if let assetDicts = configValueForKeyPath("PreBuilder.Assets") as? NSArray {
            for asset in assetDicts {
                let source = asset["Source"] as? String
                let target = asset["Target"] as? String
                
                if var source : String = source, let target = target {
                    
                    if source[source.endIndex.predecessor()] != "/" {
                        logError("Assets path \(source) should have been \(source)/, modifying before copying files")
                        source += "/"
                    }
                    
                    logInfo("Syncing assets from \(source) into \(target)")
                    task("/usr/bin/rsync", args: [ "-av", "--ignore-times", source, target ])
                    
                } else {
                    print("Asset dictionary needs to have both 'source' and 'target' set")
                    exit(EXIT_FAILURE)
                }
            }
        }

        hook("Assets", hook: .Post)
    }
    
    func isValidUUID(uuid: String?) -> Bool {
        
        guard var theCopy : String = uuid else {
            return false
        }

        
        if theCopy.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) != 36 {
            return false
        }
        
        let ar = theCopy.componentsSeparatedByString("-")
        if ar.count != 5 {
            return false
        }
        
        if ar[0].lengthOfBytesUsingEncoding(NSUTF8StringEncoding) != 8 {
            return false
        }
        
        if ar[1].lengthOfBytesUsingEncoding(NSUTF8StringEncoding) != 4 {
            return false
        }
        
        if ar[2].lengthOfBytesUsingEncoding(NSUTF8StringEncoding) != 4 {
            return false
        }
        
        if ar[3].lengthOfBytesUsingEncoding(NSUTF8StringEncoding) != 4 {
            return false
        }
        
        if ar[4].lengthOfBytesUsingEncoding(NSUTF8StringEncoding) != 12 {
            return false
        }
        
        let validSet = "-0123456789abcdefABCDEF"
        for c in validSet.characters {
            theCopy = theCopy.stringByReplacingOccurrencesOfString(String(c), withString: "")
        }
        
        return theCopy == "";
        
    }
    
    func UUIDForProvisioningProfileAtFilePath(filePath: String?) -> String? {
        guard let filePath = filePath else {
            return nil
        }

        let plistString : String
        do {
            guard let content : NSString = try NSString(contentsOfFile: filePath, encoding: NSASCIIStringEncoding) else {
                return nil
            }
            
            let startPos = content.rangeOfString("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
            let endPos = content.rangeOfString("</plist>")
            plistString = content.substringWithRange(NSMakeRange(startPos.location, endPos.location - startPos.location + endPos.length))
        } catch {
            return nil
        }
        
        do {
            guard let data = plistString.dataUsingEncoding(NSASCIIStringEncoding) else {
                return nil
            }
            var format : NSPropertyListFormat = NSPropertyListFormat.XMLFormat_v1_0
            let plist = try NSPropertyListSerialization.propertyListWithData(data, options: .Immutable, format: &format)
            if let plist = plist as? NSDictionary {
                return plist["UUID"] as? String
            }
            
        } catch {
            
            guard let keyPos = plistString.rangeOfString("<key>UUID</key>") else {
                return nil
            }
            
            let partString = plistString.substringFromIndex((keyPos.first)!) as NSString
            let startString = partString.rangeOfString("<string>")
            let endString = partString.rangeOfString("</string>")
            let start = startString.location + startString.length
            let length = endString.location - startString.location
            let uuidString = partString.substringWithRange(NSMakeRange(start, length))
            
            return uuidString
        }
        
        return nil
    }
    
    func setValueForKeyPath(dict: NSDictionary, keyPath: String, value: String) -> NSDictionary? {
        let outDict = dict.mutableCopy() as! NSMutableDictionary
        
        var parts = keyPath.componentsSeparatedByString(".")
        if parts.count > 1 {
            let uncastSlice : NSDictionary?
            if parts.first!.containsString(":") {
                
                let ar = parts.first!.splitByCharacter(":")
                
                guard let first = dict[ar[0]] as? NSArray else {
                    return nil
                }
                
                let idx : Int = (ar[1] as NSString).integerValue
                uncastSlice = first[idx] as? NSDictionary
                
            } else {
                uncastSlice = dict[parts.first!] as? NSDictionary
            }
            
            
            guard let slice : NSDictionary = uncastSlice else {
                return nil
            }
            
            var subKeyPath = ""
            for i in (1..<parts.count) {
                if subKeyPath == "" {
                    subKeyPath = parts[i]
                } else {
                    subKeyPath += "." + parts[i]
                }
            }
            
            let newDict = setValueForKeyPath(slice, keyPath: subKeyPath, value: value)
            assert(newDict != nil)
            
            if parts.first!.containsString(":") {
                
                let ar = parts.first!.splitByCharacter(":")
                
                guard let first = dict[ar[0]] as? NSArray else {
                    return nil
                }
                
                let idx : Int = (ar[1] as NSString).integerValue
                /*guard let slice = first[idx] as? NSDictionary else {
                    print("Program should not have come this far to fail now! This test worked just a microsecond ago")
                    exit(EX_SOFTWARE)
                }*/

                let mFirst = first.mutableCopy() as! NSMutableArray
                mFirst[idx] = newDict!
                
                outDict.setValue(NSArray(array: mFirst), forKey: ar[0])
                
            } else {
                outDict.setValue(newDict, forKey: parts.first!)
            }

            
            return NSDictionary(dictionary: outDict)
        }
        

        assert(parts.count == 1)
        
        guard let leafDict : NSDictionary = outDict[parts.first!] as? NSDictionary else {
            
            if parts.first!.containsString(":") {
                
                let ar = parts.first!.splitByCharacter(":")
                
                guard let first = dict[ar[0]] as? NSArray else {
                    return nil
                }
                
                let idx : Int = (ar[1] as NSString).integerValue
//                guard let slice : AnyObject = first[idx] else {
//                    print("Program should not have come this far to fail now! This test worked just a microsecond ago")
//                    exit(EX_SOFTWARE)
//                }
                
                let mFirst = first.mutableCopy() as! NSMutableArray
                mFirst[idx] = value
                
                outDict.setValue(NSArray(array: mFirst), forKey: ar[0])
            } else {
            
                outDict.setValue(value, forKey: parts.first!)
            }
                
            return NSDictionary(dictionary: outDict)
        }

        leafDict.setValue(value, forKey: parts.last!)
        outDict.setValue(leafDict, forKey: parts.first!)
        
        return  NSDictionary(dictionary: outDict)
    }
    
    func checkProvisioingProfiles(input: NSDictionary) -> NSDictionary {
        
        // Provisioinig Profiles may be either UUIDs or filepaths. If they are a file path, convert them to UUID
        var output : NSMutableDictionary = input.mutableCopy() as! NSMutableDictionary
        
        if let targetsDict = valueForKeyPathFromDict(input, keyPath: "PreBuilder.Targets") as? NSDictionary {
            for (targetKey, targetDict) in targetsDict {
                if let configurationsDict = targetDict["Configurations"] as? NSDictionary {
                    for (configKey, configDict) in configurationsDict {
                        
                        let provisioningProfile : String? = configDict["Provisioning_Profile"] as? String
                        if(!isValidUUID(provisioningProfile)) {
                            
                            let provisioningProfile = provisioningProfile!
                            let targetDir = ("~/Library/MobileDevice/Provisioning Profiles" as NSString).stringByExpandingTildeInPath
                            
                            task("/bin/cp", args: [provisioningProfile, targetDir]) // install provisioning profile
                            
                            let provisioningProfileUUID = UUIDForProvisioningProfileAtFilePath(provisioningProfile)
                            if let uuid = provisioningProfileUUID {
                                if let newOutput = setValueForKeyPath(output, keyPath:"PreBuilder.Targets.\(targetKey).Configurations.\(configKey).Provisioning_Profile", value:uuid) {
                                    output = newOutput.mutableCopy() as! NSMutableDictionary
                                }
                            }
                        }
                        
                    }
                }
            }
        }

        return NSDictionary(dictionary: output)
    }
    
    func runProvisioningProfiles() {
    
        hook("ProvisioningProfiles", hook: .Pre)

        var count = 0
        if let targetsDict = configValueForKeyPath("PreBuilder.Targets") as? NSDictionary {
            for (_, targetDict) in targetsDict {
                if let configurationsDict = targetDict["Configurations"] as? NSDictionary {
                    for (_, _) in configurationsDict {
                        count++
                    }
                }
            }
        }
        
        if count > 0 { // Found configurations to work on
            let installDir = (configValueForKeyPath("PreBuilder.InstallDir") as? NSString)?.stringByStandardizingPath
            if installDir == nil {
                logError("Cannot resolve installdir")
                exit(EX_CONFIG)
            }
            guard let project = configValueForKeyPath("PreBuilder.Project") as? String else {
                logError("Cannot resolve xcodeproject")
                exit(EX_CONFIG)
            }
            
            let curDir = NSFileManager.defaultManager().currentDirectoryPath
            let rubyFile = ("\(curDir)/\(installDir!)/bin/setProvisioningProfiles.rb" as NSString).stringByStandardizingPath

            let theRuby = task("/bin/sh", args: ["-c", "which ruby"]).stringByReplacingOccurrencesOfString("\n", withString: "")
            task(theRuby, args: [rubyFile, project], stdin: dumpConfig() )
        }

        hook("ProvisioningProfiles", hook: .Post)
        
    }
    
    func runRemoveLocalizations() {
        
    
        hook("RemoveLocalizations", hook: .Pre)
        // Pre-hook
        // Remove localizations
        // Edit info.plist
        // Post-hook
        hook("RemoveLocalizations", hook: .Post)
        
    }
    
    func updateIdentifierInTitle(dict: NSDictionary, key: String, value: String) -> NSDictionary {
        return dict
    }

    func runSettings() {
        
        
        hook("Settings", hook: .Pre)
        
        if let settingsDict = configValueForKeyPath("PreBuilder.Settings") as? NSDictionary {
            
            guard var source = settingsDict["SourceBundle"] as? String,
                  let target = settingsDict["TargetBundle"] as? String else {
                print("Settings dictionary needs to have both 'SourceBundle' and 'TargetBundle' set")
                exit(EXIT_FAILURE)
            }
            
            if source[source.endIndex.predecessor()] != "/" {
                logError("Settings source bundle path \(source) should have been \(source)/, modifying before copying files")
                source += "/"
            }
            
            // Rsync first
            task("/usr/bin/rsync", args: [ "-av", source, target ])
            
            // Edit Settings bundle
            let plistPath = target + "/Root.plist"
            
            guard NSFileManager.defaultManager().fileExistsAtPath(plistPath) == true else {
                print("Settings needs to have a plist")
                exit(EXIT_FAILURE)
            }
            
            guard var settings = NSDictionary(contentsOfFile: plistPath) else {
                print("Could not load settings plist")
                exit(EXIT_FAILURE)
            }

            let version = configValueForKeyPath("PreBuilder.BundleShortVersionString") as? String
            if let version = version, let VersionIdentifier = configValueForKeyPath("PreBuilder.Settings.Version_Identifier") as? String {
                settings = updateIdentifierInTitle(settings, key: VersionIdentifier, value: version)
            }

            let buildNumber = task("/usr/bin/git", args: ["rev-list", "HEAD", "--count"])
            if let BuildNumberIdentifier = configValueForKeyPath("PreBuilder.Settings.BuildNumber_Identifier") as? String {
                settings = updateIdentifierInTitle(settings, key: BuildNumberIdentifier, value: buildNumber)
            }

            let commitHash = task("/usr/bin/git", args: ["rev-parse", "HEAD"])
            if let CommitHashIdentifier = configValueForKeyPath("PreBuilder.Settings.CommitHash_Identifier") as? String {
                settings = updateIdentifierInTitle(settings, key: CommitHashIdentifier, value: commitHash)
            }

            let attributionsSourceFile = configValueForKeyPath("PreBuilder.Settings.Attributions.SourceFile") as? String
            let attributionsTargetFile = configValueForKeyPath("PreBuilder.Settings.Attributions.TargetFile") as? String
            if let attributionsSourceFile = attributionsSourceFile, let attributionsTargetFile = attributionsTargetFile {
                task("/bin/cp", args: [ attributionsSourceFile, attributionsTargetFile ] )
            }
            
            settings.writeToFile(plistPath, atomically: true)
            
            
        }
        

        // Post-hook
        hook("Settings", hook: .Post)
        
    }

    func runSignIcons() {
    
        hook("SignIcons", hook: .Pre)
        // Pre-hook
        // Sign icon
        // Post-hook
        hook("SignIcons", hook: .Post)
        
    }
    
    func runEditInfoPlist() {
    
        hook("EditInfoPlist", hook: .Pre)
        
        // Pre-hook
        
        if let infoPlistFile = configValueForKeyPath("PreBuilder.InfoPList") as? String {
            
            guard var mInfoPlist = NSDictionary(contentsOfFile: infoPlistFile)?.mutableCopy() as? NSMutableDictionary else {
                print("Could not read \(infoPlistFile) as an Info.plist file")
                exit(EXIT_FAILURE)
            }
            
            mInfoPlist["CFBundleDisplayName"] = configValueForKeyPath("PreBuilder.DisplayName") as? String
            mInfoPlist["CFBundleDevelopmentRegion"] = configValueForKeyPath("PreBuilder.BundleDevelopmentRegion") as? String
            mInfoPlist["CFBundleIdentifier"] = configValueForKeyPath("PreBuilder.BundleIdentifier") as? String
            var infoPlist : NSDictionary = setValueForKeyPath(mInfoPlist, keyPath: "CFBundleURLTypes:0.CFBundleURLName", value: "$bsd.saers.${BRAND_NAME}")!
            infoPlist = setValueForKeyPath(infoPlist, keyPath: "CFBundleURLTypes:0.CFBundleURLSchemes:0", value: "$BRAND_NAME")!
            
            mInfoPlist = infoPlist.mutableCopy() as! NSMutableDictionary
            
            if let bundleVersion = configValueForKeyPath("PreBuilder.BundleVersion") as? String {
                mInfoPlist["CFBundleVersion"] = bundleVersion
            } else {
                mInfoPlist["CFBundleVersion"] = task("/usr/bin/git", args: ["rev-list", "HEAD", "--count"])
            }
            
            if let bundleVersionShort = configValueForKeyPath("PreBuilder.BundleShortVersionString") as? String {
                mInfoPlist["CFBundleShortVersionString"] = bundleVersionShort
            }
            
            mInfoPlist.writeToFile(infoPlistFile, atomically: true)
            
            // /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier bsd.saers.${BRAND_NAME}.Prod.${WIDGET_NAME}" "${SRCROOT}/${WIDGET_ROOT}/Info.plist"
            
        }

        
        // Edit info.plist
        // - Display-name
        // - BundleID
        // - Version & Build number
        
        // Post-hook
        hook("EditInfoPlist", hook: .Post)
        
    }
    
    func runMakeConfigurationPlist() {
        
        hook("MakeConfigurationPlist", hook: .Pre)
        
        // Pre-hook
        
        guard let mConfiguration = self.config.mutableCopy() as? NSMutableDictionary else {
            print("Configuration is gone!")
            exit(EXIT_FAILURE)
        }
        
        if let configurationPlistFile = configValueForKeyPath("PreBuilder.ConfigurationPList") as? String {
            mConfiguration.removeObjectForKey("environment")
            mConfiguration.removeObjectForKey("PreBuilder")
            
            let success = mConfiguration.writeToFile(configurationPlistFile, atomically: true)
            if success == false {
                print("Could not write configuration to \(configurationPlistFile)")
                exit(EXIT_FAILURE)
            }
        }

        // Post-hook
        hook("MakeConfigurationPlist", hook: .Post)
        
    }

    
}

