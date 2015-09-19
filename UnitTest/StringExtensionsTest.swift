//
//  StringExtensionsTest.swift
//  PreBuild
//
//  Created by Niklas Saers on 19/09/15.
//  Copyright © 2015 Niklas Saers. All rights reserved.
//  Licensed under the 3-clause BSD license - http://opensource.org/licenses/BSD-3-Clause
//

import XCTest

class StringExtensionsTest: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testSubstring() {
        let testSubject = "Hello World"
        XCTAssert(testSubject.substringToIndex(5) == "Hello")
    }

}
