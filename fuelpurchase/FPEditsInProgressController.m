//
//  FPEditsInProgressController.m
//  fuelpurchase
//
//  Created by Evans, Paul on 9/15/14.
//  Copyright (c) 2014 Paul Evans. All rights reserved.
//

#import "FPEditsInProgressController.h"
#import <BlocksKit/UIControl+BlocksKit.h>
#import <PEObjc-Commons/UIView+PERoundify.h>
#import <FlatUIKit/UIColor+FlatUI.h>

#ifdef FP_DEV
  #import <PEDev-Console/UIViewController+PEDevConsole.h>
#endif

@implementation FPEditsInProgressController {
  FPCoordinatorDao *_coordDao;
  PEUIToolkit *_uitoolkit;
  FPScreenToolkit *_screenToolkit;
  FPUser *_user;
  UIView *_eipsMessagePanel;
  UIView *_noEipsMessagePanel;
  // badge panels
  UIView *_numEipVehiclesBadgePanel;
  UIView *_numEipFuelStationsBadgePanel;
  UIView *_numEipFplogsBadgePanel;
  UIView *_numEipEnvlogsBadgePanel;
  // buttons
  UIButton *_vehiclesButton;
  UIButton *_fuelStationsButton;
  UIButton *_envlogsButton;
  UIButton *_fplogsButton;
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

#pragma mark - Helpers

- (UIView *)paddedEipsInfoMessage {
  UILabel *infoMsgLabel = [PEUIUtils labelWithKey:@"\
From here you can drill into all of your\n\
items that have unsynced edits."
                                             font:[UIFont systemFontOfSize:[UIFont systemFontSize]]
                                  backgroundColor:[UIColor clearColor]
                                        textColor:[UIColor darkGrayColor]
                              verticalTextPadding:3.0];
  return [PEUIUtils leftPadView:infoMsgLabel padding:8.0];
}

- (UIView *)paddedNoEipsInfoMessage {
  UILabel *infoMsgLabel = [PEUIUtils labelWithKey:@"\
You currently have no unsynced items."
                                             font:[UIFont boldSystemFontOfSize:16.0]
                                  backgroundColor:[UIColor clearColor]
                                        textColor:[UIColor darkGrayColor]
                              verticalTextPadding:3.0];
  return [PEUIUtils leftPadView:infoMsgLabel padding:8.0];
}

- (UIView *)badgeForNumEips:(NSInteger)numEips {
  if (numEips == 0) {
    return nil;
  }
  CGFloat widthPadding = 30.0;
  CGFloat heightFactor = 1.45;
  CGFloat fontSize = [UIFont systemFontSize];
  NSString *labelText;
  if (numEips > 9999) {
    fontSize = 10.0;
    widthPadding = 10.0;
    heightFactor = 1.95;
    labelText = @"a plethora";
  } else {
    labelText = [NSString stringWithFormat:@"%ld", (long)numEips];
  }
  UILabel *label = [PEUIUtils labelWithKey:labelText
                                      font:[UIFont boldSystemFontOfSize:fontSize]
                           backgroundColor:[UIColor clearColor]
                                 textColor:[UIColor blackColor]
                       verticalTextPadding:0.0];
  UIView *badge = [PEUIUtils panelWithFixedWidth:label.frame.size.width + widthPadding fixedHeight:label.frame.size.height * heightFactor];
  [badge addRoundedCorners:UIRectCornerAllCorners
                 withRadii:CGSizeMake(20.0, 20.0)];
  badge.alpha = 0.8;
  badge.backgroundColor = [UIColor orangeColor];
  [PEUIUtils placeView:label
            inMiddleOf:badge
         withAlignment:PEUIHorizontalAlignmentTypeCenter
              hpadding:0.0];
  return badge;
}

- (UIButton *)buttonWithLabel:(NSString *)labelText
                      handler:(void(^)(void))handler {
  UIButton *button = [_uitoolkit systemButtonMaker](labelText, nil, nil);
  [[button layer] setCornerRadius:0.0];
  [PEUIUtils setFrameWidthOfView:button ofWidth:1.0 relativeTo:self.view];
  [PEUIUtils addDisclosureIndicatorToButton:button];
  [button bk_addEventHandler:^(id sender) {
    handler();
  } forControlEvents:UIControlEventTouchUpInside];
  return button;
}

- (void)placeBadge:(UIView *)badge onButton:(UIButton *)button {
  if (badge) {
    [PEUIUtils placeView:badge
              inMiddleOf:button
           withAlignment:PEUIHorizontalAlignmentTypeLeft
                hpadding:15.0];
  }
}

#pragma mark - View Controller Lifecyle

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:YES];
  
  // remove stale views
  [_eipsMessagePanel removeFromSuperview];
  [_noEipsMessagePanel removeFromSuperview];  
  [_vehiclesButton removeFromSuperview];
  [_fuelStationsButton removeFromSuperview];
  [_fplogsButton removeFromSuperview];
  [_envlogsButton removeFromSuperview];
  
  // get the EIP numbers
  NSInteger numEipVehicles = [_coordDao numUnsyncedVehiclesForUser:_user];
  NSInteger numEipFuelStations = [_coordDao numUnsyncedFuelStationsForUser:_user];
  NSInteger numEipFpLogs = [_coordDao numUnsyncedFuelPurchaseLogsForUser:_user];
  NSInteger numEipEnvLogs = [_coordDao numUnsyncedEnvironmentLogsForUser:_user];
  NSInteger totalNumEips = numEipVehicles + numEipFuelStations + numEipFpLogs + numEipEnvLogs;
  
  // create the badge panels
  _numEipVehiclesBadgePanel = [self badgeForNumEips:numEipVehicles];
  _numEipFuelStationsBadgePanel = [self badgeForNumEips:numEipFuelStations];
  _numEipFplogsBadgePanel = [self badgeForNumEips:numEipFpLogs];
  _numEipEnvlogsBadgePanel = [self badgeForNumEips:numEipEnvLogs];
  
  // place the badges
  [self placeBadge:_numEipVehiclesBadgePanel onButton:_vehiclesButton];
  [self placeBadge:_numEipFuelStationsBadgePanel onButton:_fuelStationsButton];
  [self placeBadge:_numEipFplogsBadgePanel onButton:_fplogsButton];
  [self placeBadge:_numEipEnvlogsBadgePanel onButton:_envlogsButton];
  
  // place the views
  UIView *messagePanel;
  if (totalNumEips > 0) {
    messagePanel = _eipsMessagePanel;
  } else {
    messagePanel = _noEipsMessagePanel;
  }
  [PEUIUtils placeView:messagePanel
               atTopOf:self.view
         withAlignment:PEUIHorizontalAlignmentTypeLeft
              vpadding:100
              hpadding:0.0];
  UIView *topView = messagePanel;
  if (_numEipVehiclesBadgePanel) {
    [PEUIUtils placeView:_vehiclesButton
                   below:topView
                    onto:self.view
           withAlignment:PEUIHorizontalAlignmentTypeLeft
                vpadding:7.0
                hpadding:0.0];
    topView = _vehiclesButton;
  }
  if (_numEipFuelStationsBadgePanel) {
    [PEUIUtils placeView:_fuelStationsButton
                   below:topView
                    onto:self.view
           withAlignment:PEUIHorizontalAlignmentTypeLeft
                vpadding:7.0
                hpadding:0.0];
    topView = _fuelStationsButton;
  }
  if (_numEipFplogsBadgePanel) {
    [PEUIUtils placeView:_fplogsButton
                   below:topView
                    onto:self.view
           withAlignment:PEUIHorizontalAlignmentTypeLeft
                vpadding:7.0
                hpadding:0.0];
    topView = _fplogsButton;
  }
  if (_numEipEnvlogsBadgePanel) {
    [PEUIUtils placeView:_envlogsButton
                   below:topView
                    onto:self.view
           withAlignment:PEUIHorizontalAlignmentTypeLeft
                vpadding:7.0
                hpadding:0.0];
    topView = _envlogsButton;
  }
}

- (void)viewDidLoad {
  [super viewDidLoad];
#ifdef FP_DEV
  [self pdvDevEnable];
#endif
  [[self view] setBackgroundColor:[_uitoolkit colorForWindows]];
  UINavigationItem *navItem = [self navigationItem];
  [navItem setTitle:@"Unsynced Edits"];
  
  // make the button (and message panel) views
  _eipsMessagePanel = [self paddedEipsInfoMessage];
  _noEipsMessagePanel = [self paddedNoEipsInfoMessage];
  _vehiclesButton = [self buttonWithLabel:@"Vehicles" handler:^{}];
  _fuelStationsButton = [self buttonWithLabel:@"Fuel Stations" handler:^{}];
  _fplogsButton = [self buttonWithLabel:@"Fuel Purchase Logs" handler:^{}];
  _envlogsButton = [self buttonWithLabel:@"Environment Logs" handler:^{}];
}

@end
