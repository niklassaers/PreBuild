//
//  Signer.m
//  PreBuild
//
//  Created by Niklas Saers on 02/07/15.
//  Copyright © 2015 Niklas Saers. All rights reserved.
//  Licensed under the 3-clause BSD license - http://opensource.org/licenses/BSD-3-Clause
//

#import "Signer.h"

@implementation Signer

+ (void) sign:(NSString*)inFile outfile:(NSString*)outFile label:(NSString*)labelText x:(NSNumber*)x y:(NSNumber*)y textSize:(NSNumber*)textSize {
    
    
    NSImage *infile = [[NSImage alloc] initWithData:[NSData dataWithContentsOfFile:inFile]];
    
    NSTextView *textView = [[NSTextView alloc] initWithFrame:CGRectMake(x.floatValue, y.floatValue, infile.size.width - x.floatValue, infile.size.height - y.floatValue)];
    [textView insertText: labelText];
    textView.font = [NSFont systemFontOfSize:textSize.floatValue];
    textView.backgroundColor = [NSColor clearColor];
    textView.textColor = [NSColor whiteColor];
    textView.alignment = NSCenterTextAlignment;
    [textView setNeedsDisplay:YES];
    
    NSImage *newImage = [[NSImage alloc] initWithSize:infile.size];
    [newImage lockFocus];
    [infile drawInRect: NSMakeRect(0, 0, infile.size.width, infile.size.height)
              fromRect: NSMakeRect(0, 0, infile.size.width, infile.size.height)
             operation: NSCompositeSourceOver fraction: 1.0];
    [textView drawRect:textView.bounds];
    [newImage unlockFocus];
    
    NSData *imageData = [newImage TIFFRepresentation];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
    NSDictionary *imageProps = @{ NSImageCompressionFactor: @1.0f };
    imageData = [imageRep representationUsingType:NSPNGFileType properties:imageProps];
    [imageData writeToFile:outFile atomically:YES];
    
}

@end
