//
//  main.swift
//  PreBuild
//
//  Created by Niklas Saers on 24/06/15.
//  Copyright © 2015 Niklas Saers. All rights reserved.
//  Licensed under the 3-clause BSD license - http://opensource.org/licenses/BSD-3-Clause
//

import Foundation

enum CommandFailModes : ErrorType {
    case MissingConfigFile
}

print("Niklas Saers iOS PreBuild")

let cli = CommandLine()

let configPath = MultiStringOption(shortFlag: "c", longFlag: "config", required: false,
    helpMessage: "Path to the configuration file")

let fallbackConfigPath = StringOption(shortFlag: "f", longFlag: "fallbackConfig", required: false,
    helpMessage: "Path to the fallback configuration file")

let dumpConfig = CounterOption(shortFlag: "d", longFlag: "dumpConfig",
    helpMessage: "Dump merged config and environment variables to screen and exit")


let version = BoolOption(shortFlag: "V", longFlag: "version",
    helpMessage: "Shows version information")
let help = BoolOption(shortFlag: "h", longFlag: "help",
    helpMessage: "Prints a help message.")
let verbosity = BoolOption(shortFlag: "v", longFlag: "verbose",
    helpMessage: "Be more verbose")

cli.addOptions(configPath, fallbackConfigPath, version, help, verbosity)

do {
    try cli.parse()
} catch {
    cli.printUsage(error)
    exit(EX_USAGE)
}

if version.value == true {
    print("v0.1")
    exit(EX_OK)
}

if help.value == true {
    cli.printUsage()
    exit(EX_OK)
}

guard let configPathValue = configPath.value else {
    cli.printUsage(CommandFailModes.MissingConfigFile)
    exit(EX_USAGE)
}

if configPath.value!.count == 0 {
    cli.printUsage(CommandFailModes.MissingConfigFile)
    exit(EX_USAGE)
}

let preBuilder = PreBuilder(configFiles: configPath.value!, fallbackConfigFile: fallbackConfigPath.value)

if verbosity.value == true {
    preBuilder.verbose = true
}

if dumpConfig.value > 0 {
    print(preBuilder.dumpConfig())
    exit(EX_OK)
}

preBuilder.run()

