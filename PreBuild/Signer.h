//
//  Signer.h
//  PreBuild
//
//  Created by Niklas Saers on 02/07/15.
//  Copyright © 2015 Niklas Saers. All rights reserved.
//  Licensed under the 3-clause BSD license - http://opensource.org/licenses/BSD-3-Clause
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>

@interface Signer : NSObject

+ (void) sign:(NSString*)inFile outfile:(NSString*)outFile label:(NSString*)labelText x:(NSNumber*)x y:(NSNumber*)y textSize:(NSNumber*)textSize;

@end
