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

#import <ReactiveCocoa/UITextField+RACSignalSupport.h>
#import <ReactiveCocoa/RACSubscriptingAssignmentTrampoline.h>
#import <ReactiveCocoa/RACSignal+Operations.h>
#import <PEObjc-Commons/PEUIUtils.h>
#import <PEFuelPurchase-Model/FPErrorDomainsAndCodes.h>
#import "FPReauthenticateController.h"
#import "FPAuthenticationAssertionSerializer.h"
#import "FPUserSerializer.h"
#import "FPAuthenticationAssertion.h"
#import "FPQuickActionMenuController.h"
#import "FPUtils.h"
#import "NSObject+appdelegate.h"
#import "FPAppNotificationNames.h"
#import "FPNames.h"

#ifdef FP_DEV
  #import <PEDev-Console/UIViewController+PEDevConsole.h>
#endif

@interface FPReauthenticateController ()
@property (nonatomic) NSInteger formStateMaskForLightLogin;
@end

@implementation FPReauthenticateController {
  FPCoordinatorDao *_coordDao;
  UITextField *_passwordTf;
  CGFloat animatedDistance;
  PEUIToolkit *_uitoolkit;
  FPScreenToolkit *_screenToolkit;
  FPUser *_user;
}

#pragma mark - Initializers

- (id)initWithStoreCoordinator:(FPCoordinatorDao *)coordDao
                          user:(FPUser *)user
                     uitoolkit:(PEUIToolkit *)uitoolkit
                 screenToolkit:(FPScreenToolkit *)screenToolkit {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _coordDao = coordDao;
    _user = user;
    _uitoolkit = uitoolkit;
    _screenToolkit = screenToolkit;
  }
  return self;
}

#pragma mark - View Controller Lifecyle

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [_passwordTf becomeFirstResponder];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  #ifdef FP_DEV
    [self pdvDevEnable];
  #endif
  [[self view] setBackgroundColor:[_uitoolkit colorForWindows]];
  [PEUIUtils placeView:[self panelForAccountCreation]
               atTopOf:[self view]
         withAlignment:PEUIHorizontalAlignmentTypeLeft
              vpadding:100.0
              hpadding:0.0];
  UINavigationItem *navItem = [self navigationItem];
  [navItem setTitle:@"Re-authenticate"];
  [navItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                               target:self
                                                                               action:@selector(handleLightLogin)]];
}

#pragma mark - GUI construction (making panels)

- (UIView *)panelForAccountCreation {
  UIView *reauthPnl = [PEUIUtils panelWithWidthOf:1.0
                                          andHeightOf:1.0
                                       relativeToView:[self view]];
  [PEUIUtils setFrameHeightOfView:reauthPnl ofHeight:0.5 relativeTo:[self view]];
  TextfieldMaker tfMaker = [_uitoolkit textfieldMakerForWidthOf:1.0 relativeTo:reauthPnl];
  _passwordTf = tfMaker(@"unauth.start.ca.pwdtf.pht");
  [_passwordTf setSecureTextEntry:YES];
  [PEUIUtils placeView:_passwordTf
               atTopOf:reauthPnl
         withAlignment:PEUIHorizontalAlignmentTypeLeft
              vpadding:0.0
              hpadding:0.0];
  RAC(self, formStateMaskForLightLogin) =
    [RACSignal combineLatest:@[_passwordTf.rac_textSignal]
                      reduce:^(NSString *password) {
        NSUInteger reauthErrMask = 0;
        if ([password length] == 0) {
          reauthErrMask = reauthErrMask | FPSignInPasswordNotProvided | FPSignInAnyIssues;
        }
        return @(reauthErrMask);
      }];
  return reauthPnl;
}

#pragma mark - Login event handling

- (void)handleLightLogin {
  [[self view] endEditing:YES];
  if (!([self formStateMaskForLightLogin] & FPSignInAnyIssues)) {
    __block MBProgressHUD *HUD;
    void (^nonLocalSyncSuccessBlk)(void) = ^{
      dispatch_async(dispatch_get_main_queue(), ^{
        [HUD hide:YES];
        NSString *msg = @"You're authenticated again.";
        [PEUIUtils showSuccessAlertWithMsgs:nil
                                      title:@"Success."
                           alertDescription:[[NSAttributedString alloc] initWithString:msg]
                                buttonTitle:@"Okay."
                               buttonAction:^{
                                 [[NSNotificationCenter defaultCenter] postNotificationName:FPAppLoginNotification
                                                                                     object:nil
                                                                                   userInfo:nil];
                                 [[self navigationController] popViewControllerAnimated:YES];
                               }
                             relativeToView:self.tabBarController.view];
      });
    };
    ErrMsgsMaker errMsgsMaker = ^ NSArray * (NSInteger errCode) {
      return [FPUtils computeSignInErrMsgs:errCode];
    };
    void (^doLightLogin)(BOOL) = ^ (BOOL syncLocalEntities) {
      void (^successBlk)(void) = nil;
      if (syncLocalEntities) {
        successBlk = ^{
          [[NSNotificationCenter defaultCenter] postNotificationName:FPAppLoginNotification
                                                              object:nil
                                                            userInfo:nil];
          dispatch_async(dispatch_get_main_queue(), ^{
            HUD.labelText = @"Proceeding to sync records...";
            HUD.mode = MBProgressHUDModeDeterminate;
          });
          __block NSInteger numEntitiesSynced = 0;
          __block BOOL receivedUnauthedError = NO;
          __block NSInteger syncAttemptErrors = 0;
          __block float overallSyncProgress = 0.0;
          [_coordDao flushAllUnsyncedEditsToRemoteForUser:_user
                                               successBlk:^(float progress) {
                                                 numEntitiesSynced++;
                                                 overallSyncProgress += progress;
                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                   [HUD setProgress:overallSyncProgress];
                                                 });
                                               }
                                       remoteStoreBusyBlk:^(float progress, NSDate *retryAfter) {
                                         syncAttemptErrors++;
                                         overallSyncProgress += progress;
                                         dispatch_async(dispatch_get_main_queue(), ^{
                                           [HUD setProgress:overallSyncProgress];
                                         });
                                       }
                                       tempRemoteErrorBlk:^(float progress) {
                                         syncAttemptErrors++;
                                         overallSyncProgress += progress;
                                         dispatch_async(dispatch_get_main_queue(), ^{
                                           [HUD setProgress:overallSyncProgress];
                                         });
                                       }
                                           remoteErrorBlk:^(float progress, NSInteger errMask) {
                                             syncAttemptErrors++;
                                             overallSyncProgress += progress;
                                             dispatch_async(dispatch_get_main_queue(), ^{
                                               [HUD setProgress:overallSyncProgress];
                                             });
                                           }
                                          authRequiredBlk:^(float progress) {
                                            overallSyncProgress += progress;
                                            receivedUnauthedError = YES;
                                            dispatch_async(dispatch_get_main_queue(), ^{
                                              [HUD setProgress:overallSyncProgress];
                                            });
                                          }
                                                  allDone:^{
                                                    if (syncAttemptErrors == 0 && !receivedUnauthedError) {
                                                      // 100% sync success
                                                      dispatch_async(dispatch_get_main_queue(), ^{
                                                        [HUD hide:YES];
                                                        [PEUIUtils showSuccessAlertWithMsgs:nil
                                                                                      title:@"Authentication Success."
                                                                           alertDescription:[[NSAttributedString alloc] initWithString:@"You have become authenticated again and\nyour records have been synced."]
                                                                                buttonTitle:@"Okay."
                                                                               buttonAction:^{ [[self navigationController] popViewControllerAnimated:YES]; }
                                                                             relativeToView:self.tabBarController.view];
                                                      });
                                                    } else {
                                                      dispatch_async(dispatch_get_main_queue(), ^{
                                                        [HUD hide:YES];
                                                        NSString *title = @"Sync problems.";
                                                        NSString *message = @"\
Although you became authenticated, there\n\
were some problems syncing all your local\n\
edits.";
                                                        NSMutableArray *sections = [NSMutableArray array];
                                                        JGActionSheetSection *becameUnauthSection = nil;
                                                        if (receivedUnauthedError) {
                                                          NSString *becameUnauthMessage = @"\
This is awkward.  While syncing your local\n\
edits, the server is asking for you to\n\
authenticate again.  Sorry about that.\n\
To authenticate, tap the Re-authenticate\n\
button.";
                                                          NSDictionary *unauthMessageAttrs = @{ NSFontAttributeName : [UIFont boldSystemFontOfSize:14.0] };
                                                          NSMutableAttributedString *attrBecameUnauthMessage = [[NSMutableAttributedString alloc] initWithString:becameUnauthMessage];
                                                          NSRange unauthMsgAttrsRange = NSMakeRange(146, 15); // 'Re-authenticate'
                                                          [attrBecameUnauthMessage setAttributes:unauthMessageAttrs range:unauthMsgAttrsRange];
                                                          becameUnauthSection = [PEUIUtils warningAlertSectionWithMsgs:nil
                                                                                                                 title:@"Authentication Failure."
                                                                                                      alertDescription:attrBecameUnauthMessage
                                                                                                        relativeToView:self.tabBarController.view];
                                                        }
                                                        JGActionSheetSection *successSection = [PEUIUtils successAlertSectionWithMsgs:nil
                                                                                                                                title:@"Authentication Success."
                                                                                                                     alertDescription:[[NSAttributedString alloc] initWithString:@"You have become authenticated again."]
                                                                                                                       relativeToView:self.tabBarController.view];
                                                        JGActionSheetSection *warningSection = nil;
                                                        if (syncAttemptErrors > 0) {
                                                          warningSection = [PEUIUtils warningAlertSectionWithMsgs:nil
                                                                                                            title:title
                                                                                                 alertDescription:[[NSAttributedString alloc] initWithString:message]
                                                                                                   relativeToView:self.tabBarController.view];
                                                        }
                                                        JGActionSheetSection *buttonsSection = [JGActionSheetSection sectionWithTitle:nil
                                                                                                                              message:nil
                                                                                                                         buttonTitles:@[@"Okay."]
                                                                                                                          buttonStyle:JGActionSheetButtonStyleDefault];
                                                        if (!receivedUnauthedError) {
                                                          [sections addObject:successSection];
                                                        }
                                                        if (warningSection) {
                                                          [sections addObject:warningSection];
                                                        }
                                                        if (becameUnauthSection) {
                                                          [sections addObject:becameUnauthSection];
                                                        }
                                                        [sections addObject:buttonsSection];
                                                        JGActionSheet *alertSheet = [JGActionSheet actionSheetWithSections:sections];
                                                        [alertSheet setButtonPressedBlock:^(JGActionSheet *sheet, NSIndexPath *indexPath) {
                                                          [sheet dismissAnimated:YES];
                                                          [[self navigationController] popViewControllerAnimated:YES];
                                                        }];
                                                        [alertSheet showInView:self.tabBarController.view animated:YES];
                                                      });
                                                    }
                                                  }
                                                    error:[FPUtils localDatabaseErrorHudHandlerMaker](HUD, self.tabBarController.view)];
        };
      } else {
        successBlk = nonLocalSyncSuccessBlk;
      }
      HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
      HUD.delegate = self;
      HUD.labelText = @"Re-authenticating...";
      [_coordDao lightLoginForUser:_user
                          password:[_passwordTf text]
                   remoteStoreBusy:[FPUtils serverBusyHandlerMakerForUI](HUD, self.tabBarController.view)
                 completionHandler:[FPUtils loginHandlerWithErrMsgsMaker:errMsgsMaker](HUD, successBlk, self.tabBarController.view)
             localSaveErrorHandler:[FPUtils localDatabaseErrorHudHandlerMaker](HUD, self.tabBarController.view)];
    };
    doLightLogin([_coordDao doesUserHaveAnyUnsyncedEntities:_user]);
  } else {
    NSArray *errMsgs = [FPUtils computeSaveUsrErrMsgs:_formStateMaskForLightLogin];
    [PEUIUtils showWarningAlertWithMsgs:errMsgs
                                  title:@"Oops"
                       alertDescription:[[NSAttributedString alloc] initWithString:@"There are some validation errors:"]
                            buttonTitle:@"Okay."
                           buttonAction:nil
                         relativeToView:self.tabBarController.view];
  }
}

@end