//
//  StartupHandler.h
//  Network Switcher
//
//  Created by Paulius VIndzigelskis on 10/28/16.
//  Copyright © 2016 Paulius Vindzigelskis. All rights reserved.
//  Code provided by Cătălin Stan.
//

#import <Foundation/Foundation.h>

@interface StartupHandler : NSObject

+ (BOOL)isLaunchOnLoginEnabled;
+ (void)setLaunchOnLogin:(BOOL)launchOnLogin;

@end
