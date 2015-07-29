// Copyright (C) 2013 Paul Evans
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.

#import <PEObjc-Commons/PEUIUtils.h>
#import <PEObjc-Commons/PEUtils.h>
#import <FlatUIKit/UIColor+FlatUI.h>
#import <PEFuelPurchase-Model/FPCoordinatorDao.h>
#import <UICKeyChainStore/UICKeyChainStore.h>
#import "FPAppDelegate.h"
#import <PEFuelPurchase-Model/FPUser.h>
#import "FPQuickActionMenuController.h"
#import <IQKeyboardManager/IQKeyboardManager.h>
#import <PEObjc-Commons/PEUIToolkit.h>
#import "FPUtils.h"
#import "FPSettingsController.h"
#import "FPEditsInProgressController.h"
#import "FPScreenToolkit.h"
#import "FPLogging.h"
#import "FPAppNotificationNames.h"

#ifdef FP_DEV
  #import <PEDev-Console/PDVScreen.h>
  #import <PEDev-Console/PDVScreenGroup.h>
  #import <PEDev-Console/PDVNotificationNames.h>
  #import <PEDev-Console/PDVUtils.h>
  #import <PEDev-Console/PDVUIWindow.h>
  #import <PEFuelPurchase-Model/FPUser.h>
#endif

id (^bundleVal)(NSString *) = ^(NSString *key) {
  return [[NSBundle mainBundle] objectForInfoDictionaryKey:key];
};

int (^intBundleVal)(NSString *) = ^(NSString *key) {
  return [(NSNumber *)bundleVal(key) intValue];
};

BOOL (^boolBundleVal)(NSString *) = ^(NSString *key) {
  return [bundleVal(key) boolValue];
};

// Keys in app plist
NSString * const FPRestServiceTimeoutKey                 = @"timeout";
NSString * const FPRestServicePreferredCharsetKey        = @"FP REST service preferred charset";
NSString * const FPRestServicePreferredLanguageKey       = @"FP REST service preferred language";
NSString * const FPRestServicePreferredFormatKey         = @"FP REST service preferred format";
NSString * const FPRestServiceMtVersionKey               = @"FP REST service mt-version";
NSString * const FPAuthenticationSchemeKey               = @"FP Authentication scheme";
NSString * const FPAuthenticationTokenNameKey            = @"FP Authentication token param name";
NSString * const FPErrorMaskHeaderNameKey                = @"FP error mask header name";
NSString * const FPTransactionIdHeaderNameKey            = @"FP transaction id header name";
NSString * const FPEstablishSessionHeaderNameKey         = @"FP establish session header name";
NSString * const FPUserAgentDeviceMakeHeaderNameKey      = @"FP user agent device make header name";
NSString * const FPUserAgentDeviceOsHeaderNameKey        = @"FP user agent device os header name";
NSString * const FPUserAgentDeviceOsVersionHeaderNameKey = @"FP user agent device os version header name";
NSString * const FPAuthTokenResponseHeaderNameKey        = @"FP auth token response header name";
NSString * const FPIfUnmodifiedSinceHeaderNameKey        = @"FP if-unmodified-since header name";
NSString * const FPLoginFailedReasonHeaderNameKey        = @"FP login failed reason header name";
NSString * const FPAccountClosedReasonHeaderNameKey      = @"FP account closed reason header name";
NSString * const FPTimeoutForCoordDaoMainThreadOpsKey    = @"FP timeout for main thread coordinator dao operations";
NSString * const FPTimeIntervalForFlushToRemoteMasterKey = @"FP time interval for flush to remote master";
NSString * const FPIsUserLoggedInIndicatorKey            = @"FP is user logged in indicator";

#ifdef FP_DEV
  NSString * const FPAPIResourceFileName = @"fpapi-resource.localdev";
#else
  NSString * const FPAPIResourceFileName = @"fpapi-resource";
#endif

NSString * const FPDataFileExtension = @"data";
NSString * const FPLocalSqlLiteDataFileName = @"local-sqlite-datafile";

// Keychain service names
NSString * const FPAppKeychainService = @"fp-app";

@implementation FPAppDelegate {
  CGFloat _userAuthenticationStrength;
  MBProgressHUD *_HUD;
  NSString *_authToken;
  FPCoordinatorDao *_coordDao;
  PEUIToolkit *_uitoolkit;
  FPScreenToolkit *_screenToolkit;
  CLLocationManager *_locationManager;
  NSMutableArray *_locations;
  UICKeyChainStore *_keychainStore;
  UITabBarController *_tabBarController;
  FPUser *_user;

  #ifdef FP_DEV
    PDVUtils *_pdvUtils;
  #endif
}

#pragma mark - Methods

- (CLLocation *)latestLocation {
  if ([_locations count] > 0) {
    return [_locations lastObject];
  }
  return nil;
}

#pragma mark - Location Manager Delegate

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray *)locations {
  DDLogDebug(@"current locations: [%@]", locations);
  [_locations removeAllObjects]; // discard old entries
  [_locations addObjectsFromArray:locations];
}

- (void)locationManager:(CLLocationManager *)manager
didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
  BOOL authorized = NO;
  switch (status) {
    case kCLAuthorizationStatusNotDetermined:
      DDLogDebug(@"locationManager auth status: Not Determined");
      break;
    case kCLAuthorizationStatusRestricted:
      DDLogDebug(@"locationManager auth status: Restricted");
      break;
    case kCLAuthorizationStatusDenied:
      DDLogDebug(@"locationManager auth status: Denied");
      break;
    case kCLAuthorizationStatusAuthorizedAlways:
      authorized = YES;
      DDLogDebug(@"locationManager auth status: Always Authorized");
      break;
    case kCLAuthorizationStatusAuthorizedWhenInUse:
      authorized = YES;
      DDLogDebug(@"locationManager auth status: When-in-use Authorized");
      break;
  }
  if (authorized) {
    [_locationManager setDesiredAccuracy:kCLLocationAccuracyBest];
    [_locationManager setDistanceFilter:500]; // 500 meters
    [_locationManager startUpdatingLocation];
  }
}

#pragma mark - Application Lifecycle

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [self initializeLocationTracking];
  [FPLogging initializeLogging];
  [self initializeStoreCoordinator];
  _uitoolkit = [FPAppDelegate defaultUIToolkit];
  _screenToolkit = [[FPScreenToolkit alloc] initWithCoordinatorDao:_coordDao
                                                         uitoolkit:_uitoolkit
                                                             error:[FPUtils localFetchErrorHandlerMaker]()];
  [_coordDao globalCancelSyncInProgressWithError:[FPUtils localSaveErrorHandlerMaker]()];
  [_coordDao pruneAllSyncedEntitiesWithError:[FPUtils localSaveErrorHandlerMaker]()];
  _keychainStore = [UICKeyChainStore keyChainStoreWithService:@"name.paulevans.fpauth-token"];
  _user = [_coordDao userWithError:[FPUtils localFetchErrorHandlerMaker]()];
  if (_user) {
    _authToken = [self storedAuthenticationTokenForUser:_user];
    if (_authToken) {
      [_coordDao setAuthToken:_authToken];
    }
  } else {
    _user = [_coordDao newLocalUserWithError:[FPUtils localSaveErrorHandlerMaker]()];
  }
  NSLog(@"in startup, user: %@", _user);
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  // Setup notification observing
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(resetUserInterface)
                                               name:FPAppDeleteAllDataNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(resetUserInterface)
                                               name:FPAppLogoutNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(resetUserInterface)
                                               name:FPAppAccountCreationNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(resetUserInterface)
                                               name:FPAppLoginNotification
                                             object:nil];
  
  if ([self isUserLoggedIn]) {
    if ([self doesUserHaveValidAuthToken]) {
      DDLogVerbose(@"User is logged in and has a valid authentication token.");
      _tabBarController = (UITabBarController *)[_screenToolkit newTabBarHomeLandingScreenMakerIsLoggedIn:YES](_user);
      [[self window] setRootViewController:_tabBarController];
    } else {
      DDLogVerbose(@"User is logged in and does NOT have a valid authentication token.");
      _tabBarController = (UITabBarController *)[_screenToolkit newTabBarHomeLandingScreenMakerIsLoggedIn:YES](_user);
      [[self window] setRootViewController:_tabBarController];
    }
  } else {
    DDLogVerbose(@"User is NOT logged in.");
     _tabBarController = (UITabBarController *)[_screenToolkit newTabBarHomeLandingScreenMakerIsLoggedIn:NO](_user);
    [[self window] setRootViewController:_tabBarController];
  }
  if ([self isUserLoggedIn] && ![self doesUserHaveValidAuthToken]) {
    [_tabBarController.tabBar.items[1] setBadgeValue:@"1"];
  }
  [_tabBarController setDelegate:self];
  [self refreshTabs];
  [self.window setBackgroundColor:[UIColor whiteColor]];
  [self.window makeKeyAndVisible];
  return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
  [_locationManager stopUpdatingLocation];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  [_locationManager stopUpdatingLocation];
  [self refreshTabs];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
  [_locationManager startUpdatingLocation];
  [self refreshTabs];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  [_locationManager startUpdatingLocation];
}

- (void)applicationWillTerminate:(UIApplication *)application {
  [_coordDao pruneAllSyncedEntitiesWithError:[FPUtils localSaveErrorHandlerMaker]()];
  [_locationManager stopUpdatingLocation];
}

#pragma mark - Refresh Tabs

- (void)refreshTabs {
  dispatch_async(dispatch_get_main_queue(), ^{
    void (^clearBadge)(void) = ^{
      [_tabBarController.tabBar.items[2] setBadgeValue:nil];
    };
    NSArray *controllers = [_tabBarController viewControllers];
    if ([self isUserLoggedIn]) {
      if ([controllers count] == 2) {
        // need to add 'unsynced edits' controller
        [_tabBarController setViewControllers:@[controllers[0], controllers[1], [_screenToolkit unsynedEditsViewControllerForUser:_user]]
                                     animated:YES];
      }
      if (_user) {
        NSInteger totalNumUnsyncedEdits = [_coordDao numUnsyncedVehiclesForUser:_user] +
        [_coordDao numUnsyncedFuelStationsForUser:_user] +
        [_coordDao numUnsyncedFuelPurchaseLogsForUser:_user] +
        [_coordDao numUnsyncedEnvironmentLogsForUser:_user];
        if (totalNumUnsyncedEdits > 0) {
          [_tabBarController.tabBar.items[2] setBadgeValue:[NSString stringWithFormat:@"%ld", (long)totalNumUnsyncedEdits]];
        } else {
          clearBadge();
        }
      } else {
        clearBadge();
      }
    } else {
      [_tabBarController.tabBar.items[1] setBadgeValue:nil];
      if ([controllers count] == 3) {
        // need to remove 'unsynced edits' controller
        [_tabBarController setViewControllers:@[controllers[0], controllers[1]]
                                     animated:YES];
      }
    }
  });
}

#pragma mark - Resetting the user interface and tab bar delegate

- (void)resetUserInterface {
  NSArray *controllers = [_tabBarController viewControllers];
  [controllers[0] popToRootViewControllerAnimated:NO];
  if ([controllers count] == 3) {
    [controllers[2] popToRootViewControllerAnimated:NO];
  }
  [self refreshTabs];
}

- (BOOL)tabBarController:(UITabBarController *)tabBarController
shouldSelectViewController:(UIViewController *)viewController {
  return YES;
}

- (void)tabBarController:(UITabBarController *)tabBarController
 didSelectViewController:(UIViewController *)viewController {
  NSArray *controllers = [_tabBarController viewControllers];
  if ([controllers count] == 3) {
    // the following ensures that an entity cannot be displayed in 2 different list
    // or add/view/edit controllers simultaneously (i.e., a controller rooted from
    // the quick action screen, or a controller root from the unsynced edits screen).
    UINavigationController *navController = (UINavigationController *)viewController;
    if ([[navController topViewController] isKindOfClass:[FPQuickActionMenuController class]]) {
      [controllers[2] popToRootViewControllerAnimated:NO];
    } else if ([[navController topViewController] isKindOfClass:[FPEditsInProgressController class]]) {
      // there's no need to pop to root if the unsynced-edits root is just the
      // info-message screen that there aren't any unsynced edits
      if ([_coordDao totalNumUnsyncedEntitiesForUser:_user] > 0) {
        [controllers[0] popToRootViewControllerAnimated:NO];
      }
    }
  }
}

#pragma mark - Initialization helpers

- (void)initializeLocationTracking {
  _locations = [NSMutableArray array];
  _locationManager = [[CLLocationManager alloc] init];
  [_locationManager setDelegate:self];
  [_locationManager requestWhenInUseAuthorization];
}

+ (NSString *)language {
  return bundleVal(FPRestServicePreferredLanguageKey);
}

+ (HCCharset *)charset {
  return [[HCCharset alloc] initWithEncoding:NSUTF8StringEncoding
                                 description:@"UTF-8"];
}

- (void)initializeStoreCoordinator {
  NSBundle *mainBundle = [NSBundle mainBundle];
  NSFileManager *fileMgr = [NSFileManager defaultManager];
  NSURL *localSqlLiteDataFileUrl =
      [[fileMgr URLForDirectory:NSLibraryDirectory
                       inDomain:NSUserDomainMask
              appropriateForURL:nil
                         create:YES
                          error:nil]
        URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@",
                                     FPLocalSqlLiteDataFileName,
                                     FPDataFileExtension]];
  DDLogDebug(@"About to load local database from: [%@]", [localSqlLiteDataFileUrl absoluteString]);
  _coordDao =
    [[FPCoordinatorDao alloc]
      initWithSqliteDataFilePath:[localSqlLiteDataFileUrl absoluteString]
      localDatabaseCreationError:[FPUtils localDatabaseCreationErrorHandlerMaker]()
  timeoutForMainThreadOperations:intBundleVal(FPTimeoutForCoordDaoMainThreadOpsKey)
                   acceptCharset:[HCCharset UTF8]
                  acceptLanguage:[FPAppDelegate language]
              contentTypeCharset:[HCCharset UTF8]
                      authScheme:bundleVal(FPAuthenticationSchemeKey)
              authTokenParamName:bundleVal(FPAuthenticationTokenNameKey)
                       authToken:nil
             errorMaskHeaderName:bundleVal(FPErrorMaskHeaderNameKey)
      establishSessionHeaderName:bundleVal(FPEstablishSessionHeaderNameKey)
     authTokenResponseHeaderName:bundleVal(FPAuthTokenResponseHeaderNameKey)
     ifUnmodifiedSinceHeaderName:bundleVal(FPIfUnmodifiedSinceHeaderNameKey)
     loginFailedReasonHeaderName:bundleVal(FPLoginFailedReasonHeaderNameKey)
   accountClosedReasonHeaderName:bundleVal(FPAccountClosedReasonHeaderNameKey)
    bundleHoldingApiJsonResource:mainBundle
       nameOfApiJsonResourceFile:FPAPIResourceFileName
                 apiResMtVersion:bundleVal(FPRestServiceMtVersionKey)
                userResMtVersion:bundleVal(FPRestServiceMtVersionKey)
             vehicleResMtVersion:bundleVal(FPRestServiceMtVersionKey)
         fuelStationResMtVersion:bundleVal(FPRestServiceMtVersionKey)
     fuelPurchaseLogResMtVersion:bundleVal(FPRestServiceMtVersionKey)
      environmentLogResMtVersion:bundleVal(FPRestServiceMtVersionKey)
               authTokenDelegate:self
        allowInvalidCertificates:YES];
  [_coordDao initializeLocalDatabaseWithError:[FPUtils localSaveErrorHandlerMaker]()];
}

#pragma mark - FPAuthTokenDelegate protocol

- (void)didReceiveNewAuthToken:(NSString *)authToken
       forUserGlobalIdentifier:(NSString *)userGlobalIdentifier {
  DDLogDebug(@"Received new authentication token: [%@].  About to store in \
keychain under key: [%@].  Is main thread? %@", authToken, userGlobalIdentifier,
             [PEUtils yesNoFromBool:[NSThread isMainThread]]);
  [_keychainStore setString:authToken forKey:userGlobalIdentifier];
  [_tabBarController.tabBar.items[1] setBadgeValue:nil];

  //[_keychainStore removeItemForKey:FPAuthenticationRequiredAtKey];
  // FYI, the reason we don't set the authToken on our _coordDao object is because
  // it is doing it itself; i.e., because the auth token is received THROUGH the
  // _coordDao, the _coordDao updates itself as it arrives.
}

- (void)authRequired:(HCAuthentication *)authentication {
  DDLogDebug(@"Notified that 'auth required' from some remote operation.  Therefore \
I'm going to insert this knowledge into the keychian so the app knows it's currently \
in an unauthenticated state.  Is main thread?  %@", [PEUtils yesNoFromBool:[NSThread isMainThread]]);
  [_keychainStore removeAllItems];
  if ([self isUserLoggedIn]) {
    [_tabBarController.tabBar.items[1] setBadgeValue:@"!"];
  }
}

#pragma mark - Security and User-related

- (void)clearKeychain {
  [_keychainStore removeAllItems];
}

- (BOOL)isUserLoggedIn {
  FPUser *user = [_coordDao userWithError:[FPUtils localFetchErrorHandlerMaker]()];
  if (user) {
    if ([user globalIdentifier]) {
      return YES;
    }
  }
  return NO;
}

- (BOOL)doesUserHaveValidAuthToken {
  FPUser *user = [_coordDao userWithError:[FPUtils localFetchErrorHandlerMaker]()];
  if ([self storedAuthenticationTokenForUser:user]) {
    return YES;
  }
  return NO;
}

- (NSString *)storedAuthenticationTokenForUser:(FPUser *)user {
  NSString *globalIdentifier = [user globalIdentifier];
  NSString *authToken = nil;
  if (globalIdentifier) {
    authToken = [_keychainStore stringForKey:globalIdentifier];
  }
  return authToken;
}

- (UIViewController *)goalEstablishingHeightenedAuthentication {
  return nil; // todo
}

#pragma mark - UI Toolkit maker

+ (PEUIToolkit *)defaultUIToolkit {
  UIColor *fpBlue = [UIColor colorFromHexCode:@"0E51A7"];
  [[UITabBarItem appearance] setTitleTextAttributes:@{ NSForegroundColorAttributeName : fpBlue }
                                           forState:UIControlStateSelected];
  return [[PEUIToolkit alloc]
           initWithColorForContentPanels:fpBlue
              colorForNotificationPanels:[UIColor orangeColor]
                         colorForWindows:[UIColor cloudsColor]
        topBottomPaddingForContentPanels:15
                             accentColor:[UIColor colorFromHexCode:@"FFBF40"]
                          fontForButtons:[UIFont systemFontOfSize:[UIFont buttonFontSize]]
                  cornerRadiusForButtons:3
               verticalPaddingForButtons:30
             horizontalPaddingForButtons:25
                bgColorForWarningButtons:[UIColor carrotColor]
              textColorForWarningButtons:[UIColor whiteColor]
                bgColorForPrimaryButtons:[UIColor colorFromHexCode:@"05326D"]
              textColorForPrimaryButtons:[UIColor whiteColor]
                 bgColorForDangerButtons:[UIColor alizarinColor]
               textColorForDangerButtons:[UIColor whiteColor]
                    fontForHeader1Labels:[UIFont boldSystemFontOfSize:24]
                   colorForHeader1Labels:[UIColor whiteColor]
                   fontForHeaders2Labels:[UIFont boldSystemFontOfSize:18]
                   colorForHeader2Labels:[UIColor whiteColor]
                       fontForTextfields:[UIFont systemFontOfSize:18]
                      colorForTextfields:[UIColor whiteColor]
               heightFactorForTextfields:1.7
            leftViewPaddingForTextfields:10
                  fontForTableCellTitles:[UIFont systemFontOfSize:16]
                 colorForTableCellTitles:[UIColor blackColor]
               fontForTableCellSubtitles:[UIFont systemFontOfSize:10]
              colorForTableCellSubtitles:[UIColor grayColor]
               durationForFrameAnimation:0.5
             durationForFadeOutAnimation:2.0
              downToYForFromTopAnimation:40];
}

#ifdef FP_DEV

#pragma mark - PDVDevEnabled protocol

- (NSDictionary *)screenNamesForViewControllers {
    return @{
    NSStringFromClass([FPQuickActionMenuController class]) : @"authenticated-landing-screen"
  };
}

- (PDVUtils *)pdvUtils {
  return _pdvUtils;
}

#pragma mark - Dev

- (NSArray *)screenGroups {
  PDVScreenGroup *createAcctScreenGroup =
    [[PDVScreenGroup alloc]
      initWithName:@"Create Account"
           screens:@[
      // Authenticated landing screen
      [[PDVScreen alloc] initWithDisplayName:@"Authenticated Landing"
                                 description:@"Authenticated landing screen of pre-existing user with resident auth token."
                         viewControllerMaker:^{return [_screenToolkit newTabBarHomeLandingScreenMakerIsLoggedIn:NO]([_coordDao userWithError:nil]);}],
      [[PDVScreen alloc] initWithDisplayName:@"Authenticated Landing"
                                 description:@"Authenticated landing screen which occurs when a user creates an account."
                         viewControllerMaker:^{return [_screenToolkit newTabBarHomeLandingScreenMakerIsLoggedIn:NO]([_coordDao userWithError:nil]);}]]];
  return @[ createAcctScreenGroup ];
}

#endif

@end
