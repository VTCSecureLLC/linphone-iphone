//
//  LinphoneLocationManager.m
//
//  Created by Christophe Deschamps on June 9th 2014
//


#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)


#import "LinphoneLocationManager.h"



@interface LinphoneLocationManager()

@property(nonatomic,strong)CLLocationManager* locationManager;
@property(nonatomic)dispatch_semaphore_t phoneReportToTheApp;
@property(nonatomic)BOOL serviceStarted;

@end


@implementation LinphoneLocationManager

- (id)init
{
    self = [super init];
    if (self) {
        self.locationManager = [[CLLocationManager alloc]init];
        self.locationManager.delegate = self;
    }
    return self;
    self.serviceStarted = false;
}


- (void)stopMonitoring{
    [self.locationManager stopMonitoringSignificantLocationChanges];
    self.serviceStarted = false;
    
}

- (void)startMonitoring{
    self.serviceStarted = true;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        [self.locationManager requestWhenInUseAuthorization];
    }
    [self.locationManager startMonitoringSignificantLocationChanges];
    if ([CLLocationManager significantLocationChangeMonitoringAvailable]) {
        [self.locationManager startMonitoringSignificantLocationChanges];
    } else {
        [self.locationManager startUpdatingLocation];
    }
}

- (CLLocation*)recentLocation{
    return self.locationManager.location;
}

-(BOOL)isAuthorized:(BOOL)askUserIfUnknown  {
    
    int status = CLLocationManager.authorizationStatus;
    
    if (status == kCLAuthorizationStatusNotDetermined){ // If we don't know, we then need to know ...
        if (!askUserIfUnknown) return NO;
        self.phoneReportToTheApp = dispatch_semaphore_create(0);// Means service is not started yet
        [self startMonitoring]; // Will ask user
        while (CLLocationManager.authorizationStatus == kCLAuthorizationStatusNotDetermined) {sleep(500);};
    } else { // We know so we assume service is needed to start it of not started yet
        if (!self.serviceStarted) {
            [self startMonitoring];
        }
    }
    if (status == kCLAuthorizationStatusNotDetermined) status = CLLocationManager.authorizationStatus; // need to re-fetch if we didn't know.
    
    BOOL result = false;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
         result = (status == kCLAuthorizationStatusAuthorizedAlways) || (status == kCLAuthorizationStatusAuthorizedWhenInUse);
    } else {
        result = status == kCLAuthorizationStatusAuthorized;
    }
    
    return result;
}



- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{
    if (self.phoneReportToTheApp != nil) dispatch_semaphore_signal(self.phoneReportToTheApp);
    if ([[error domain] isEqualToString: kCLErrorDomain] && [error code] == kCLErrorDenied) {
        NSLog(@"locationManager didFailWithError: kCLErrorDenied");
    }
}


-(BOOL)locationPlausible {
    return self.locationManager != nil && self.locationManager.location != nil && self.locationManager.location.coordinate.latitude != 0 && self.locationManager.location.coordinate.longitude != 0;
}

#pragma mark -
#pragma mark Singleton instance

+(LinphoneLocationManager *)sharedManager {
    static dispatch_once_t pred;
    static LinphoneLocationManager *shared = nil;
    
    dispatch_once(&pred, ^{
        shared = [[LinphoneLocationManager alloc] init];
    });
    return shared;
}

@end

