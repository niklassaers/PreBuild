//
//  String-Extensions.swift
//  PreBuild
//
//  Created by Niklas Saers on 19/09/15.
//  Copyright © 2015 Niklas Saers. All rights reserved.
//  Licensed under the 3-clause BSD license - http://opensource.org/licenses/BSD-3-Clause
//

import Foundation

extension String {
    
    func containsString(string: String) -> Bool {
        return (self as NSString).rangeOfString(string).location != NSNotFound
    }
    
}

extension String {
    
    // MARK: - sub String
    func substringToIndex(index:Int) -> String {
        let range = self.startIndex..<self.startIndex.advancedBy(index)
        return self[range]
    }
    
    func substringFromIndex(index:Int) -> String {
        let range = self.startIndex.advancedBy(index)..<self.endIndex
        return self[range]
    }
    
    func substringWithRange(range:Range<Int>) -> String {
        let start = self.startIndex.advancedBy(range.startIndex)
        let end = self.startIndex.advancedBy(range.endIndex)
        return self.substringWithRange(start..<end)
    }
    
    subscript(index:Int) -> Character{
        let start = self.startIndex.advancedBy(index)
        let end = self.startIndex.advancedBy(index + 1)
        return self.substringWithRange(start..<end).characters.first!
    }
    subscript(range:Range<Int>) -> String {
        return self.substringWithRange(range)
    }
    
    
    // MARK: - replace
    func replaceCharactersInRange(range:Range<Int>, withString: String!) -> String {
        let result : NSMutableString = NSMutableString(string: self)
        result.replaceCharactersInRange(NSRange(range), withString: withString)
        return String(result)
    }
}

