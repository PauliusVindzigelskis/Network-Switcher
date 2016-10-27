//
//  AppDelegate.m
//  Network Switcher
//
//  Created by Paulius Vindzigelskis on 2014-09-18.
//  Copyright (c) 2014 Paulius Vindzigelskis. All rights reserved.
//

#import "AppDelegate.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <ServiceManagement/ServiceManagement.h>

@interface AppDelegate()

@property (strong) IBOutlet NSMenu *statusMenu;
@property (strong) NSStatusItem *statusItem;
@property (weak) NSMenuItem *launchStatusItem;


@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{


}

- (NSString*) startupPlistPathWithDocumentsDirectoryPath:(NSString **)directoryPath
{
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    NSString *documentsDirectory = [@"~/Library/LaunchAgents/" stringByExpandingTildeInPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentsDirectory])
    {
        documentsDirectory = [@"~/Library/LaunchDaemons/" stringByExpandingTildeInPath];
    }
    
    if (directoryPath)
    {
        *directoryPath = documentsDirectory;
    }
    
    NSString *plistPath = [[documentsDirectory stringByAppendingPathComponent:bundleID] stringByAppendingString:@".plist"];
    
    return plistPath;
}

- (BOOL) isStartupItem
{
    return [[NSFileManager defaultManager] fileExistsAtPath:[self startupPlistPathWithDocumentsDirectoryPath:nil]];
}

- (void) setIsStartupItem:(BOOL)addStartupItem
{
    NSString *documentsDirectory;
    NSString *plistPath = [self startupPlistPathWithDocumentsDirectoryPath:&documentsDirectory];
    
    if (addStartupItem)
    {
        //add file
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSString *appPath = [[[NSBundle mainBundle] bundlePath] stringByAbbreviatingWithTildeInPath];
        NSDictionary *myDict = @{
                                 @"LaunchOnlyOnce" : @(YES),
                                 @"ProgramArguments" : @[
                                         @"/usr/bin/open",
                                         @"-n",
                                         appPath
                                         ],
                                 @"KeepAlive" : @(NO),
                                 @"Label" : bundleID
                                 };
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:documentsDirectory])
        {
            BOOL success = [myDict writeToFile:plistPath atomically: YES];
            NSLog(@"Saved startup item successfully: %@", success ? @"YES" : @"NO");
            if (success)
            {
                //change status
                self.launchStatusItem.state = 1;
            }
        }
    } else {
        //remove file
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:plistPath error:&error];
        if (!error)
        {
            //change status
            self.launchStatusItem.state = 0;
        }
    }
}

-(void)awakeFromNib
{
    [super awakeFromNib];
    //setup menulet
    NSStatusItem *statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:self.statusMenu];
    NSImage *normalImage = [NSImage imageNamed:@"icn_switcher_default"];
    [normalImage setTemplate:YES];
    [statusItem setImage:normalImage];
    [statusItem setAlternateImage:[NSImage imageNamed:@"icn_switcher_alt"]];
    [statusItem setHighlightMode:YES];
    self.statusItem = statusItem;
    [self setupNetworkList];
    
}

- (SCPreferencesRef) preferences
{
    static SCPreferencesRef preferences = nil;
    
    
    if (preferences == nil)
    {
        AuthorizationRef auth = nil;
        OSStatus authErr = noErr;
        
        AuthorizationFlags rootFlags = kAuthorizationFlagDefaults
        | kAuthorizationFlagExtendRights
        | kAuthorizationFlagInteractionAllowed
        | kAuthorizationFlagPreAuthorize;
        
        authErr = AuthorizationCreate(nil, kAuthorizationEmptyEnvironment,
                                      rootFlags, &auth);
        
        preferences = SCPreferencesCreateWithAuthorization(NULL, CFSTR("myapp"), NULL, auth);
    }
    
    return preferences;
}

- (void) setupNetworkList
{
    SCPreferencesRef preferences = [self preferences];
    SCPreferencesLock(preferences, TRUE);
    SCNetworkSetRef networkSet = SCNetworkSetCopyCurrent(preferences);
    NSArray *networkSetServices = (__bridge_transfer NSArray *) SCNetworkSetCopyServices(networkSet);
    NSArray *networkOrder = (__bridge NSArray *)(SCNetworkSetGetServiceOrder(networkSet));
    
    NSMutableArray *networkListNames = [NSMutableArray new];
    
    for (id networkID_ in networkOrder)
    {
        CFStringRef networkID = (__bridge CFStringRef)networkID_;
        SCNetworkServiceRef	selected	= NULL;
        for (id networkService_ in networkSetServices) {
            SCNetworkServiceRef networkService = (__bridge SCNetworkServiceRef) networkService_;
            
            CFStringRef serviceID = SCNetworkServiceGetServiceID(networkService);
            
            if (CFEqual(networkID, serviceID)) {
                selected = networkService;
                break;
            }
        }
        [networkListNames addObject:(__bridge NSString *)SCNetworkServiceGetName(selected)];
    }
    NSLog(@"list:\n%@",networkListNames);
    
    [self createMenuListFromStrings:[NSArray arrayWithArray:networkListNames] selected:0];
    
    SCPreferencesUnlock(preferences);
}

- (void) createMenuListFromStrings:(NSArray*)strings selected:(NSInteger)selected
{
    [self.statusMenu removeAllItems];
    for (int i = 0; i < strings.count; i++)
    {
        NSString *item = strings[i];
        NSMenuItem *menuItem = [self.statusMenu addItemWithTitle:item action:@selector(menuItemSelected:) keyEquivalent:item];
        
        if (selected == i)
        {
            [menuItem setState:1];
        }
    }
    
    //add StartupMenu status
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *startupItem = [self.statusMenu addItemWithTitle:@"Launch when Mac starts up" action:@selector(startupItemSelected:) keyEquivalent:@"StartUp"];
    startupItem.state = [self isStartupItem];
    self.launchStatusItem = startupItem;
    
    //add Credits and Quit menu
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    [self.statusMenu addItemWithTitle:@"Credits" action:@selector(aboutPressed:) keyEquivalent:@""];
    [self.statusMenu addItemWithTitle:@"Quit application" action:@selector(quitApplicationPressed) keyEquivalent:@""];
    
    
}

- (void) startupItemSelected:(id)source
{
    [self setIsStartupItem:![self isStartupItem]];
}

- (void) quitApplicationPressed
{
    [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
}

- (void) aboutPressed:(id)receiver
{
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"rtf"];
    NSData* rtfData = [[NSData alloc] initWithContentsOfFile:path];
    NSAttributedString *attString = [[NSAttributedString alloc]
                                     initWithRTF:rtfData documentAttributes:nil];
    NSString* string = [attString string];
    
    
    NSAlert *alert = [NSAlert new];
    
    alert.messageText = @"Credits:";
    alert.informativeText = string;
    
    [alert runModal];
}

- (void) menuItemSelected:(NSMenuItem*)item
{
    NSString *itemTitle = item.title;
    
    SCPreferencesRef preferences = [self preferences];
    
    Boolean success = SCPreferencesLock(preferences, YES);
    
    NSLog(@"Preferences are locked: %@", success ? @"True" : @"False");
    if (success)
    {
        SCNetworkSetRef networkSet = SCNetworkSetCopyCurrent(preferences);
        NSArray *networkSetServices = (__bridge_transfer NSArray *) SCNetworkSetCopyServices(networkSet);
        NSArray *networkOrder = (__bridge NSArray *)(SCNetworkSetGetServiceOrder(networkSet));
        
        NSMutableArray *networkListNames = [NSMutableArray new];
        
        int i=0;
        for (id networkID_ in networkOrder)
        {
            CFStringRef networkID = (__bridge CFStringRef)networkID_;
            SCNetworkServiceRef	selected	= NULL;
            for (id networkService_ in networkSetServices) {
                SCNetworkServiceRef networkService = (__bridge SCNetworkServiceRef) networkService_;
                
                CFStringRef serviceID = SCNetworkServiceGetServiceID(networkService);
                
                if (CFEqual(networkID, serviceID)) {
                    selected = networkService;
                    break;
                }
            }
            [networkListNames addObject:(__bridge NSString *)SCNetworkServiceGetName(selected)];
            i++;
        }
        NSLog(@"selected:%@, list:\n%@",itemTitle, networkListNames);
        NSUInteger selectedIndex = [networkListNames indexOfObject:itemTitle];
        
        if (selectedIndex > 0)
        {
            
            CFMutableArrayRef mutableOrder = CFArrayCreateMutableCopy(NULL, 0, (SCNetworkSetGetServiceOrder(networkSet)));
            
            NSLog(@"Order before:%@", mutableOrder);
            
            const void* data = CFArrayGetValueAtIndex(mutableOrder, selectedIndex);
            CFArrayRemoveValueAtIndex(mutableOrder, selectedIndex);
            CFArrayInsertValueAtIndex(mutableOrder, 0, data);
            
            NSLog(@"Order after:%@", mutableOrder);
            
            SCNetworkSetSetServiceOrder(networkSet, mutableOrder);
            
            
            SCPreferencesCommitChanges(preferences);
            Boolean result = SCPreferencesApplyChanges(preferences);
            SCPreferencesSynchronize(preferences);
            
            NSLog(@"Change Success: %@", result ? @"True" : @"False");
            
            SCDynamicStoreRef ds = SCDynamicStoreCreate(NULL, CFSTR("myapp"), NULL, NULL);
            CFRelease(ds);
            
            //update UI
            [networkListNames removeObjectAtIndex:selectedIndex];
            [networkListNames insertObject:itemTitle atIndex:0];
            
            [self createMenuListFromStrings:[NSArray arrayWithArray:networkListNames] selected:0];
        }
        
        Boolean unlocked = SCPreferencesUnlock(preferences);
        NSLog(@"Preferences are unlocked: %@", unlocked ? @"True" : @"False");
    } else {
        NSLog(@"Aborting operation...");
    }
}

@end
