//
//  CBTrueToneClient.h
//  Shifty
//
//  Created by Nate Thompson on 9/4/18.
//

#import <Foundation/Foundation.h>

@interface CBTrueToneClient : NSObject
- (BOOL)available;
- (BOOL)supported;
- (BOOL)enabled;
- (BOOL)setEnabled:(BOOL)arg1;
@end
