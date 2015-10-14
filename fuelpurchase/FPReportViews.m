//
//  FPReportViews.m
//  PEFuelPurchase-App
//
//  Created by Paul Evans on 10/10/15.
//  Copyright © 2015 Paul Evans. All rights reserved.
//

#import "FPReportViews.h"
#import "FPUtils.h"
#import <PEObjc-Commons/PEUtils.h>
#import <PEObjc-Commons/PEUIUtils.h>
#import "NSDate+PEAdditions.h"
#import <FlatUIKit/UIColor+FlatUI.h>

NSString * const FPOdometerLogFunFactIndexDefaultsKey = @"FPOdometerLogFunFactIndex";
NSString * const FPGasLogFunFactIndexDefaultsKey = @"FPGasLogFunFactIndex";

@implementation FPReportViews {
  FPReports *_reports;
  NSArray *_odometerLogFunFacts;
  NSArray *_gasLogFunFacts;
}

#pragma mark - Initializers

- (id)initWithReports:(FPReports *)reports {
  self = [super init];
  if (self) {
    _reports = reports;
    _odometerLogFunFacts = [self odometerLogFunFacts];
    _gasLogFunFacts = [self gasLogFunFacts];
  }
  return self;
}

#pragma mark - Helpers

- (NSAttributedString *)gallonPriceOfFplog:(FPFuelPurchaseLog *)fplog
                        comparedToAvgPrice:(NSDecimalNumber *)avgPrice
                         currencyFormatter:(NSNumberFormatter *)numFormatter
                          avgQualifierText:(NSString *)avgQualifierText {
  NSAttributedString *funFact;
  NSDecimalNumber *diff = [fplog.gallonPrice decimalNumberBySubtracting:avgPrice];
  if ([diff compare:[NSDecimalNumber zero]] == NSOrderedDescending) {
    // diff is positive and thus fplog.gallonPrice is HIGHER than YTD average
    NSString *templateText = [NSString stringWithFormat:@"The gallon-price of this purchase is HIGHER than the %@ average by %@.", avgQualifierText, @"%@"];
    funFact = [PEUIUtils attributedTextWithTemplate:templateText
                                       textToAccent:[numFormatter stringFromNumber:diff]
                                     accentTextFont:[UIFont boldSystemFontOfSize:[UIFont systemFontSize]]
                                    accentTextColor:[UIColor pomegranateColor]];
  } else if ([diff compare:[NSDecimalNumber zero]] == NSOrderedAscending) {
    // diff is negative and thus fplog.gallonPrice is LOWER than YTD average
    diff = [diff decimalNumberByMultiplyingBy:[[NSDecimalNumber alloc] initWithInteger:-1]];
    NSString *templateText = [NSString stringWithFormat:@"The gallon-price of this purchase is LOWER than the %@ average by %@.", avgQualifierText, @"%@"];
    funFact = [PEUIUtils attributedTextWithTemplate:templateText
                                       textToAccent:[numFormatter stringFromNumber:diff]
                                     accentTextFont:[UIFont boldSystemFontOfSize:[UIFont systemFontSize]]
                                    accentTextColor:[UIColor nephritisColor]];
  } else {
    // diff is zero
    funFact = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"The gallon-price of this log entry is exacty equal to the %@ average.", avgQualifierText]];
  }
  return funFact;
}

- (NSNumberFormatter *)currencyFormatter {
  NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
  [formatter setNumberStyle:NSNumberFormatterCurrencyStyle];
  return formatter;
}

#pragma mark - Gas Log Fun Facts

- (FPFunFact)yearToDateAvgPricePerGallonForUserFunFact {
  return ^JGActionSheetSection *(NSArray *logVehFs, FPUser *user, UIView *relativeToView) {
    FPFuelPurchaseLog *fplog = logVehFs[0];
    NSNumberFormatter *currencyFormatter = [self currencyFormatter];
    NSDecimalNumber *avgPrice = [_reports yearToDateAvgPricePerGallonForUser:user octane:fplog.octane];
    if (avgPrice) {
      NSAttributedString *funFactPart = [PEUIUtils attributedTextWithTemplate:@"So far this year, you've paid an average of %@ per gallon"
                                                                 textToAccent:[currencyFormatter stringFromNumber:avgPrice]
                                                               accentTextFont:[UIFont boldSystemFontOfSize:[UIFont systemFontSize]]];
      NSAttributedString *funFactPart2 = [PEUIUtils attributedTextWithTemplate:@" for %@ gas.  "
                                                                  textToAccent:[NSString stringWithFormat:@"%@ octane", [fplog.octane description]]
                                                                accentTextFont:[UIFont boldSystemFontOfSize:[UIFont systemFontSize]]];
      NSAttributedString *funFactPart3 = [self gallonPriceOfFplog:fplog comparedToAvgPrice:avgPrice currencyFormatter:currencyFormatter avgQualifierText:@"YTD"];
      NSMutableAttributedString *funFact = [[NSMutableAttributedString alloc] initWithAttributedString:funFactPart];
      [funFact appendAttributedString:funFactPart2];
      [funFact appendAttributedString:funFactPart3];
      return [PEUIUtils infoAlertSectionWithTitle:@"Fun Fact" alertDescription:funFact relativeToView:relativeToView];
    }
    return nil;
  };
}

- (FPFunFact)totalSpentOnGasForFuelStationFunFact {
  return ^JGActionSheetSection *(NSArray *logVehFs, FPUser *user, UIView *relativeToView) {
    FPFuelStation *fuelstation = logVehFs[2];
    NSDecimalNumber *spentOnGas = [_reports totalSpentOnGasForFuelstation:fuelstation];
    NSNumberFormatter *currencyFormatter = [self currencyFormatter];
    NSAttributedString *funFactPart = [PEUIUtils attributedTextWithTemplate:@"Since recording, you've spent %@ on gas"
                                                               textToAccent:[currencyFormatter stringFromNumber:spentOnGas]
                                                             accentTextFont:[UIFont boldSystemFontOfSize:[UIFont systemFontSize]]];
    NSMutableAttributedString *funFact = [[NSMutableAttributedString alloc] initWithAttributedString:funFactPart];
    [funFact appendAttributedString:[PEUIUtils attributedTextWithTemplate:@" at gas station: %@."
                                                             textToAccent:[fuelstation name]
                                                           accentTextFont:[UIFont boldSystemFontOfSize:[UIFont systemFontSize]]]];
    return [PEUIUtils infoAlertSectionWithTitle:@"Fun Fact" alertDescription:funFact relativeToView:relativeToView];
  };
}

- (FPFunFact)totalSpentOnGasForVehicleFunFact {
  return ^JGActionSheetSection *(NSArray *logVehFs, FPUser *user, UIView *relativeToView) {
    FPVehicle *vehicle = logVehFs[1];
    NSDecimalNumber *spentOnGas = [_reports totalSpentOnGasForVehicle:vehicle];
    NSNumberFormatter *currencyFormatter = [self currencyFormatter];
    NSAttributedString *funFactPart = [PEUIUtils attributedTextWithTemplate:@"Since recording, you've spent %@ on gas"
                                                               textToAccent:[currencyFormatter stringFromNumber:spentOnGas]
                                                             accentTextFont:[UIFont boldSystemFontOfSize:[UIFont systemFontSize]]];
    NSMutableAttributedString *funFact = [[NSMutableAttributedString alloc] initWithAttributedString:funFactPart];
    [funFact appendAttributedString:[PEUIUtils attributedTextWithTemplate:@" for your %@."
                                                             textToAccent:[vehicle name]
                                                           accentTextFont:[UIFont boldSystemFontOfSize:[UIFont systemFontSize]]]];
    return [PEUIUtils infoAlertSectionWithTitle:@"Fun Fact" alertDescription:funFact relativeToView:relativeToView];
  };
}

- (FPFunFact)totalSpentOnGasForUserFunFact {
  return ^JGActionSheetSection *(NSArray *logVehFs, FPUser *user, UIView *relativeToView) {
    NSDecimalNumber *spentOnGas = [_reports totalSpentOnGasForUser:user];
    NSNumberFormatter *currencyFormatter = [self currencyFormatter];
    NSAttributedString *funFact = [PEUIUtils attributedTextWithTemplate:@"Since recording, you've spent %@ on gas across all your vehicles."
                                                           textToAccent:[currencyFormatter stringFromNumber:spentOnGas]
                                                         accentTextFont:[UIFont boldSystemFontOfSize:[UIFont systemFontSize]]];
    return [PEUIUtils infoAlertSectionWithTitle:@"Fun Fact" alertDescription:funFact relativeToView:relativeToView];
  };
}

- (FPFunFact)yearToDateSpentOnGasForFuelstationFunFact {
  return ^JGActionSheetSection *(NSArray *logVehFs, FPUser *user, UIView *relativeToView) {
    FPFuelStation *fuelstation = logVehFs[2];
    NSNumberFormatter *currencyFormatter = [self currencyFormatter];
    NSDecimalNumber *spentOnGas = [_reports yearToDateSpentOnGasForFuelstation:fuelstation];
    NSAttributedString *funFactPart = [PEUIUtils attributedTextWithTemplate:@"So far this year you've spent %@ on gas"
                                                               textToAccent:[currencyFormatter stringFromNumber:spentOnGas]
                                                             accentTextFont:[UIFont boldSystemFontOfSize:[UIFont systemFontSize]]];
    NSMutableAttributedString *funFact = [[NSMutableAttributedString alloc] initWithAttributedString:funFactPart];
    [funFact appendAttributedString:[PEUIUtils attributedTextWithTemplate:@" at gas station: %@."
                                                             textToAccent:[fuelstation name]
                                                           accentTextFont:[UIFont boldSystemFontOfSize:[UIFont systemFontSize]]]];
    return [PEUIUtils infoAlertSectionWithTitle:@"Fun Fact" alertDescription:funFact relativeToView:relativeToView];
  };
}

- (FPFunFact)yearToDateSpentOnGasForVehicleFunFact {
  return ^JGActionSheetSection *(NSArray *logVehFs, FPUser *user, UIView *relativeToView) {
    FPVehicle *vehicle = logVehFs[1];
    NSNumberFormatter *currencyFormatter = [self currencyFormatter];
    NSDecimalNumber *spentOnGas = [_reports yearToDateSpentOnGasForVehicle:vehicle];
    NSAttributedString *funFactPart = [PEUIUtils attributedTextWithTemplate:@"So far this year you've spent %@ on gas"
                                                               textToAccent:[currencyFormatter stringFromNumber:spentOnGas]
                                                             accentTextFont:[UIFont boldSystemFontOfSize:[UIFont systemFontSize]]];
    NSMutableAttributedString *funFact = [[NSMutableAttributedString alloc] initWithAttributedString:funFactPart];
    [funFact appendAttributedString:[PEUIUtils attributedTextWithTemplate:@" for your %@."
                                                             textToAccent:[vehicle name]
                                                           accentTextFont:[UIFont boldSystemFontOfSize:[UIFont systemFontSize]]]];
    return [PEUIUtils infoAlertSectionWithTitle:@"Fun Fact"
                               alertDescription:funFact
                                 relativeToView:relativeToView];
  };
}

- (FPFunFact)yearToDateSpentOnGasForUserFunFact {
  return ^JGActionSheetSection *(NSArray *logVehFs, FPUser *user, UIView *relativeToView) {
    NSDecimalNumber *spentOnGas = [_reports yearToDateSpentOnGasForUser:user];
    NSNumberFormatter *currencyFormatter = [self currencyFormatter];
    NSAttributedString *funFact = [PEUIUtils attributedTextWithTemplate:@"So far this year you've spent %@ on gas across all your vehicles."
                                                           textToAccent:[currencyFormatter stringFromNumber:spentOnGas]
                                                         accentTextFont:[UIFont boldSystemFontOfSize:[UIFont systemFontSize]]];
    return [PEUIUtils infoAlertSectionWithTitle:@"Fun Fact" alertDescription:funFact relativeToView:relativeToView];
  };
}

#pragma mark - Odometer Log Fun Facts

- (FPFunFact)milesDrivenSinceLastOdometerLogAndLogFunFact {
  return ^JGActionSheetSection *(FPEnvironmentLog *odometerLog, FPUser *user, UIView *relativeToView) {
    NSDecimalNumber *milesDrivenSinceLastLog = [_reports milesDrivenSinceLastOdometerLogAndLog:odometerLog user:user];
    if (milesDrivenSinceLastLog) {
      NSAttributedString *funFact = [PEUIUtils attributedTextWithTemplate:@"You have driven %@ miles since your last odometer log was recorded."
                                                             textToAccent:[milesDrivenSinceLastLog description]
                                                           accentTextFont:[UIFont boldSystemFontOfSize:[UIFont systemFontSize]]];
      return [PEUIUtils infoAlertSectionWithTitle:@"Fun Fact" alertDescription:funFact relativeToView:relativeToView];
    }
    return nil;
  };
}

- (FPFunFact)daysSinceLastOdometerLogAndLogFunFact {
  return ^JGActionSheetSection *(FPEnvironmentLog *odometerLog, FPUser *user, UIView *relativeToView) {
    NSNumber *daysSinceLastLog = [_reports daysSinceLastOdometerLogAndLog:odometerLog user:user];
    if (daysSinceLastLog) {
      NSAttributedString *funFact = [PEUIUtils attributedTextWithTemplate:@"It has been %@ days since your last odometer log was recorded."
                                                             textToAccent:[daysSinceLastLog description]
                                                           accentTextFont:[UIFont boldSystemFontOfSize:[UIFont systemFontSize]]];
      return [PEUIUtils infoAlertSectionWithTitle:@"Factoid" alertDescription:funFact relativeToView:relativeToView];
    }
    return nil;
  };
}

- (FPFunFact)temperatureLastYearFromLogFunFact {
  return ^JGActionSheetSection *(FPEnvironmentLog *odometerLog, FPUser *user, UIView *relativeToView) {
    NSNumber *temperateLastYear = [_reports temperatureLastYearFromLog:odometerLog user:user];
    if (temperateLastYear) {
      NSAttributedString *funFact = [PEUIUtils attributedTextWithTemplate:@"A year ago the temperature was %@ degrees."
                                                             textToAccent:[temperateLastYear description]
                                                           accentTextFont:[UIFont boldSystemFontOfSize:[UIFont systemFontSize]]];
      NSNumber *temperature = [odometerLog reportedOutsideTemp];
      if (temperature) {
        NSInteger temperatureDifference = labs(temperateLastYear.integerValue - odometerLog.reportedOutsideTemp.integerValue);
        NSMutableAttributedString *funFactMore = [[NSMutableAttributedString alloc] initWithAttributedString:funFact];
        if (temperatureDifference == 0) {
          [funFactMore appendAttributedString:[[NSAttributedString alloc] initWithString:@"  The temperature last year was exactly the same as it is today.  How about that?"]];
        } else {
          [funFactMore appendAttributedString:[PEUIUtils attributedTextWithTemplate:@"  That's a difference of %@ degrees."
                                                                       textToAccent:[NSString stringWithFormat:@"%ld", (long)temperatureDifference]
                                                                     accentTextFont:[UIFont boldSystemFontOfSize:[UIFont systemFontSize]]]];
        }
        return [PEUIUtils infoAlertSectionWithTitle:@"Fun Fact" alertDescription:funFactMore relativeToView:relativeToView];
      } else {
        return [PEUIUtils infoAlertSectionWithTitle:@"Factoid" alertDescription:funFact relativeToView:relativeToView];
      }
    }
    return nil;
  };
}

#pragma mark - Fun Fact Iteration Helpers

- (NSArray *)odometerLogFunFacts {
  FPFunFact f1 = [self milesDrivenSinceLastOdometerLogAndLogFunFact];
  FPFunFact f2 = [self daysSinceLastOdometerLogAndLogFunFact];
  FPFunFact f3 = [self temperatureLastYearFromLogFunFact];
  return @[f1, f2, f3];
}

- (NSArray *)gasLogFunFacts {
  
  /*- <DONE> (NSDecimalNumber *)yearToDateSpentOnGasForUser:(FPUser *)user;
   - <DONE> (NSDecimalNumber *)yearToDateSpentOnGasForVehicle:(FPVehicle *)vehicle;
   - <DONE> (NSDecimalNumber *)yearToDateSpentOnGasForFuelstation:(FPFuelStation *)vehicle;
   - <DONE> (NSDecimalNumber *)totalSpentOnGasForUser:(FPUser *)user;
   - <DONE> (NSDecimalNumber *)totalSpentOnGasForVehicle:(FPVehicle *)vehicle;
   - <DONE> (NSDecimalNumber *)totalSpentOnGasForFuelstation:(FPFuelStation *)vehicle;
   - <DONE> (NSDecimalNumber *)yearToDateAvgPricePerGallonForUser:(FPUser *)user octane:(NSNumber *)octane;
   - (NSDecimalNumber *)yearToDateAvgPricePerGallonForVehicle:(FPVehicle *)vehicle octane:(NSNumber *)octane;
   - (NSDecimalNumber *)yearToDateAvgPricePerGallonForFuelstation:(FPFuelStation *)fuelstation octane:(NSNumber *)octane;
   - (NSDecimalNumber *)overallAvgPricePerGallonForUser:(FPUser *)user octane:(NSNumber *)octane;
   - (NSDecimalNumber *)overallAvgPricePerGallonForVehicle:(FPVehicle *)vehicle octane:(NSNumber *)octane;
   - (NSDecimalNumber *)overallAvgPricePerGallonForFuelstation:(FPFuelStation *)fuelstation octane:(NSNumber *)octane;
   - (NSDecimalNumber *)yearToDateMaxPricePerGallonForUser:(FPUser *)user octane:(NSNumber *)octane;
   - (NSDecimalNumber *)yearToDateMaxPricePerGallonForVehicle:(FPVehicle *)vehicle octane:(NSNumber *)octane;
   - (NSDecimalNumber *)yearToDateMaxPricePerGallonForFuelstation:(FPFuelStation *)fuelstation octane:(NSNumber *)octane;
   - (NSDecimalNumber *)overallMaxPricePerGallonForUser:(FPUser *)user octane:(NSNumber *)octane;
   - (NSDecimalNumber *)overallMaxPricePerGallonForVehicle:(FPVehicle *)vehicle octane:(NSNumber *)octane;
   - (NSDecimalNumber *)overallMaxPricePerGallonForFuelstation:(FPFuelStation *)fuelstation octane:(NSNumber *)octane;*/
  FPFunFact f7 = [self yearToDateAvgPricePerGallonForUserFunFact];
  FPFunFact f6 = [self totalSpentOnGasForFuelStationFunFact];
  FPFunFact f5 = [self totalSpentOnGasForVehicleFunFact];
  FPFunFact f4 = [self totalSpentOnGasForUserFunFact];
  FPFunFact f3 = [self yearToDateSpentOnGasForFuelstationFunFact];
  FPFunFact f2 = [self yearToDateSpentOnGasForVehicleFunFact];
  FPFunFact f1 = [self yearToDateSpentOnGasForUserFunFact];
  return @[f1, f2, f3, f4, f5, f6, f7];
}

+ (NSNumber *)nextIndexForUserDefaultsKey:(NSString *)userDefaultsIndexKey
                                 funFacts:(NSArray *)funFacts {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSNumber *funFactIndex = [defaults objectForKey:userDefaultsIndexKey];
  if ([PEUtils isNil:funFactIndex]) {
    funFactIndex = @(0);
  } else {
    if ((funFactIndex.integerValue + 1) >= [funFacts count]) {
      funFactIndex = @(0);
    } else {
      funFactIndex = @(funFactIndex.integerValue + 1);
    }
  }
  [defaults setObject:funFactIndex forKey:userDefaultsIndexKey];
  return funFactIndex;
}

#pragma mark - Odometer Log Fun Fact Iteration

- (NSInteger)numOdometerFunFacts {
  return [_odometerLogFunFacts count];
}

- (FPFunFact)nextOdometerFunFact {
  NSNumber *odometerFunFactIndex = [FPReportViews nextIndexForUserDefaultsKey:FPOdometerLogFunFactIndexDefaultsKey funFacts:_odometerLogFunFacts];
  return _odometerLogFunFacts[odometerFunFactIndex.integerValue];
}

#pragma mark - Gas Log Fun Fact Iteration

- (NSInteger)numGasFunFacts {
  return [_gasLogFunFacts count];
}

- (FPFunFact)nextGasFunFact {
  NSNumber *gasFunFactIndex = [FPReportViews nextIndexForUserDefaultsKey:FPGasLogFunFactIndexDefaultsKey funFacts:_gasLogFunFacts];
  return _gasLogFunFacts[gasFunFactIndex.integerValue];
}

@end