//
//  FPRecordsController.m
//  PEFuelPurchase-App
//
//  Created by Paul Evans on 9/13/15.
//  Copyright (c) 2015 Paul Evans. All rights reserved.
//

#import "FPRecordsController.h"
#import <PEObjc-Commons/PEUIUtils.h>
#import <BlocksKit/UIControl+BlocksKit.h>
#import <BlocksKit/UIView+BlocksKit.h>
#import "FPUIUtils.h"
#import "FPUtils.h"
#import "UIColor+FPAdditions.h"

@implementation FPRecordsController {
  FPCoordinatorDao *_coordDao;
  PEUIToolkit *_uitoolkit;
  FPUser *_user;
  FPScreenToolkit *_screenToolkit;
  UIView *_msgPanel;
  UIButton *_vehiclesBtn;
  UIButton *_fuelstationsBtn;
  UIButton *_fplogsBtn;
  UIButton *_envlogsBtn;
  UIButton *_unsyncedEditsBtn;
}

#pragma mark - Initializers

- (id)initWithStoreCoordinator:(FPCoordinatorDao *)coordDao
                          user:(FPUser *)user
                     uitoolkit:(PEUIToolkit *)uitoolkit
                 screenToolkit:(FPScreenToolkit *)screenToolkit {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _user = user;
    _coordDao = coordDao;
    _uitoolkit = uitoolkit;
    _screenToolkit = screenToolkit;
  }
  return self;
}

#pragma mark - View Controller Lifecycle

- (void)viewDidLoad {
  [super viewDidLoad];
  [[self view] setBackgroundColor:[_uitoolkit colorForWindows]];
  UINavigationItem *navItem = [self navigationItem];
  [navItem setTitle:@"Data Records"];
  
  CGFloat leftPadding = 8.0;
  _msgPanel =  [PEUIUtils leftPadView:[PEUIUtils labelWithKey:@"\
From here you can drill into all of your data records."
                                                         font:[UIFont systemFontOfSize:[UIFont systemFontSize]]
                                              backgroundColor:[UIColor clearColor]
                                                    textColor:[UIColor darkGrayColor]
                                          verticalTextPadding:3.0
                                                   fitToWidth:self.view.frame.size.width - (leftPadding + 3.0)]
                              padding:leftPadding];
  [PEUIUtils placeView:_msgPanel
               atTopOf:self.view
         withAlignment:PEUIHorizontalAlignmentTypeLeft
              vpadding:75.0
              hpadding:0.0];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [_vehiclesBtn removeFromSuperview];
  [_fuelstationsBtn removeFromSuperview];
  [_fplogsBtn removeFromSuperview];
  [_envlogsBtn removeFromSuperview];
  _vehiclesBtn = [FPUIUtils buttonWithLabel:@"Vehicles"
                                   badgeNum:[_coordDao numVehiclesForUser:_user error:[FPUtils localFetchErrorHandlerMaker]()]
                                 badgeColor:[UIColor fpAppBlue]
                             badgeTextColor:[UIColor whiteColor]
                          addDisclosureIcon:YES
                                    handler:^{
                                      [PEUIUtils displayController:[_screenToolkit newViewVehiclesScreenMaker](_user)
                                                    fromController:self
                                                          animated:YES];
                                    }
                                  uitoolkit:_uitoolkit
                             relativeToView:self.view];
  _fuelstationsBtn = [FPUIUtils buttonWithLabel:@"Fuel stations"
                                       badgeNum:[_coordDao numFuelStationsForUser:_user error:[FPUtils localFetchErrorHandlerMaker]()]
                                     badgeColor:[UIColor fpAppBlue]
                                 badgeTextColor:[UIColor whiteColor]
                              addDisclosureIcon:YES
                                        handler:^{
                                          [PEUIUtils displayController:[_screenToolkit newViewFuelStationsScreenMaker](_user)
                                                        fromController:self
                                                              animated:YES];
                                        }
                                      uitoolkit:_uitoolkit
                                 relativeToView:self.view];
  _fplogsBtn = [FPUIUtils buttonWithLabel:@"Gas logs"
                                 badgeNum:[_coordDao numFuelPurchaseLogsForUser:_user error:[FPUtils localFetchErrorHandlerMaker]()]
                               badgeColor:[UIColor fpAppBlue]
                           badgeTextColor:[UIColor whiteColor]
                        addDisclosureIcon:YES
                                  handler:^{
                                    [PEUIUtils displayController:[_screenToolkit newViewFuelPurchaseLogsScreenMaker](_user)
                                                  fromController:self
                                                        animated:YES];
                                  }
                                uitoolkit:_uitoolkit
                           relativeToView:self.view];
  _envlogsBtn = [FPUIUtils buttonWithLabel:@"Odometer logs"
                                  badgeNum:[_coordDao numEnvironmentLogsForUser:_user error:[FPUtils localFetchErrorHandlerMaker]()]
                                badgeColor:[UIColor fpAppBlue]
                            badgeTextColor:[UIColor whiteColor]
                         addDisclosureIcon:YES
                                   handler:^{
                                    [PEUIUtils displayController:[_screenToolkit newViewEnvironmentLogsScreenMaker](_user)
                                                  fromController:self
                                                        animated:YES];
                                  }
                                 uitoolkit:_uitoolkit
                            relativeToView:self.view];
  [PEUIUtils placeView:_vehiclesBtn
                 below:_msgPanel
                  onto:self.view
         withAlignment:PEUIHorizontalAlignmentTypeLeft
              vpadding:10.0
              hpadding:0.0];
  [PEUIUtils placeView:_fuelstationsBtn
                 below:_vehiclesBtn
                  onto:self.view
         withAlignment:PEUIHorizontalAlignmentTypeLeft
              vpadding:10.0
              hpadding:0.0];
  [PEUIUtils placeView:_fplogsBtn
                 below:_fuelstationsBtn
                  onto:self.view
         withAlignment:PEUIHorizontalAlignmentTypeLeft
              vpadding:10.0
              hpadding:0.0];
  [PEUIUtils placeView:_envlogsBtn
                 below:_fplogsBtn
                  onto:self.view
         withAlignment:PEUIHorizontalAlignmentTypeLeft
              vpadding:10.0
              hpadding:0.0];
  
  [_unsyncedEditsBtn removeFromSuperview];
  if ([APP isUserLoggedIn]) {
    NSInteger numUnsynced = [_coordDao totalNumUnsyncedEntitiesForUser:_user];
    if (numUnsynced > 0) {
      _unsyncedEditsBtn = [self unsyncedEditsButtonWithBadgeNum:numUnsynced];
      [PEUIUtils placeView:_unsyncedEditsBtn
                atBottomOf:self.view
             withAlignment:PEUIHorizontalAlignmentTypeLeft
                  vpadding:self.view.frame.size.height * 0.275
                  hpadding:0.0];
    }
  }
}

#pragma mark - Helpers

- (UIButton *)unsyncedEditsButtonWithBadgeNum:(NSInteger)numUnsynced {
  return [FPUIUtils buttonWithLabel:@"Unsynced Edits"
                           badgeNum:numUnsynced
                         badgeColor:[UIColor redColor]
                     badgeTextColor:[UIColor whiteColor]
                  addDisclosureIcon:YES
                            handler:^{
                              [PEUIUtils displayController:[_screenToolkit newViewUnsyncedEditsScreenMaker](_user)
                                            fromController:self
                                                  animated:YES];
                            }
                          uitoolkit:_uitoolkit
                     relativeToView:self.view];
}

@end
