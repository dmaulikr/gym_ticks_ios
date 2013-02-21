//
//  RoutesTableViewController.m
//  top_this
//
//  Created by Andrew Benson on 2/1/13.
//  Copyright (c) 2013 Andrew Benson. All rights reserved.
//

#import "RoutesTableViewController.h"
#import <RestKit/RestKit.h>
#import "Route.h"
#import "MappingProvider.h"
#import "RouteDetailViewController.h"
#import "Global.h"
#import "AddRouteViewController.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "RouteCell.h"
#import "RouteCompletion.h"

@interface RoutesTableViewController ()
@property (strong, nonatomic) NSArray *routes;
@property (strong, nonatomic) Route *selectedRoute;
@property (strong, nonatomic) Global *globals;
@property (strong, nonatomic) RKObjectManager *objectManager;
@property (strong, nonatomic) NSMutableArray *boulderProblems;
@property (strong, nonatomic) NSMutableArray *verticalRoutes;
@property (strong, nonatomic) NSArray *userCompletions;

@end

@implementation RoutesTableViewController
@synthesize routes = _routes;
@synthesize gym = _gym;
@synthesize globals = _globals;
@synthesize objectManager = _objectManager;
@synthesize boulderProblems = _boulderProblems;
@synthesize verticalRoutes = _verticalRoutes;
@synthesize userCompletions = _userCompletions;


- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
        self.globals = [Global getInstance];
        self.objectManager = [RKObjectManager sharedManager];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        // Custom initialization
        self.globals = [Global getInstance];
        self.objectManager = [RKObjectManager sharedManager];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.globals = [Global getInstance];
    }
    return self;
}

-(void)viewWillAppear:(BOOL)animated{
    if (![self userIsGymAdmin]) {
        self.navigationItem.rightBarButtonItems = nil;
    }
    
    [self loadRoutes];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = [NSString stringWithFormat:@"%@", self.gym.name];
    UIImageView *tempImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"wall.jpg"]];
    [tempImageView setFrame:self.tableView.frame];
    [tempImageView setAlpha:0.25f];
    self.tableView.backgroundView = tempImageView;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadRoutes
{
    [SVProgressHUD showWithStatus:@"Loading routes..."];
    NSDictionary *params = @{@"gym_id": self.gym.gymId};
    [self.objectManager getObjectsAtPath:@"routes" parameters:params success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
        self.routes = mappingResult.array;
        [self correctRouteDates];
        [self sortRoutes];
        [self loadCurrentUserCompletions];
    } failure:^(RKObjectRequestOperation *operation, NSError *error) {
        NSLog(@"ERROR: %@", error);
        NSLog(@"Response: %@", operation.HTTPRequestOperation.responseString);
        [SVProgressHUD showErrorWithStatus:@"Unable to load routes"];
    }];
}

-(void)loadCurrentUserCompletions{
    [self.objectManager getObjectsAtPath:@"route_completions" parameters:@{@"user_id":self.globals.currentUser.userId} success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
        self.userCompletions = mappingResult.array;
        [self.tableView reloadData];
        [SVProgressHUD dismiss];
    } failure:^(RKObjectRequestOperation *operation, NSError *error) {
        NSLog(@"ERROR: %@", error);
        NSLog(@"Response: %@", operation.HTTPRequestOperation.responseString);
         [SVProgressHUD showErrorWithStatus:@"Unable to load user completions"];
    }];
}

-(void)sortRoutes{
    self.boulderProblems = [NSMutableArray array];
    self.verticalRoutes = [NSMutableArray array];
 
    int i = 0;
    for (i=0; i<self.routes.count; i++) {
        Route *currentRoute = [self.routes objectAtIndex:i];
        if ([currentRoute.routeType isEqualToString:@"Boulder"]) {
            [self.boulderProblems addObject:currentRoute];
        }
        else if ([currentRoute.routeType isEqualToString:@"Vertical"]){
            [self.verticalRoutes addObject:currentRoute];
        }
    }
        
    //sort ratings using nsdescriptors
    // first the vertical
    NSSortDescriptor *ratingNumberSorter = [[NSSortDescriptor alloc] initWithKey:@"ratingNumber" ascending:YES];
    NSSortDescriptor *ratingLetterSorter = [[NSSortDescriptor alloc] initWithKey:@"ratingLetter" ascending:YES];
    NSSortDescriptor *ratingArrowSorter = [[NSSortDescriptor alloc] initWithKey:@"ratingArrow" ascending:NO];
    NSSortDescriptor *nameSorter = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
    
    NSArray *verticalDescriptors = @[ratingNumberSorter, ratingLetterSorter, ratingArrowSorter, nameSorter];
    NSArray *boulderingDescriptors = @[ratingNumberSorter, ratingArrowSorter, nameSorter];
    self.verticalRoutes = [[NSMutableArray alloc] initWithArray:[self.verticalRoutes sortedArrayUsingDescriptors:verticalDescriptors]];
    self.boulderProblems = [[NSMutableArray alloc] initWithArray:[self.boulderProblems sortedArrayUsingDescriptors:boulderingDescriptors]];
}

-(void)correctRouteDates{
    NSTimeInterval sixHours = 6*60*60;
    int i;
    for (i = 0; i < self.routes.count; i++) {
        //add 6 hours to the set date
        Route *currentRoute = [self.routes objectAtIndex:i];
        currentRoute.setDate = [currentRoute.setDate dateByAddingTimeInterval:sixHours];
        //add to retirement date if not nil
        if (currentRoute.retirementDate != nil){
            currentRoute.retirementDate = [currentRoute.retirementDate dateByAddingTimeInterval:sixHours];
        }
    }
}

-(BOOL)userIsGymAdmin{
    return ([self.globals.currentUser.adminId integerValue] == -1 || [self.globals.currentUser.adminId integerValue] == [self.gym.gymId integerValue]);
}

-(BOOL)userHasSentRoute:(Route *)route{
    //only returns true if the user has SENT the route.  returns false for piecewises.
    int i;
    for (i=0; i < self.userCompletions.count; i++) {
        RouteCompletion *currentCompletion = [self.userCompletions objectAtIndex:i];
        if ([currentCompletion.route.routeId integerValue] == [route.routeId integerValue]) {
            if ([currentCompletion.completionType isEqualToString:@"Piecewise"] ||
              [currentCompletion.completionType isEqualToString:@"PIECEWISE"]){
                return false;
            }
            else{
                return true;
            }
        }
    }
    return false;
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return self.boulderProblems.count;
    }
    else if (section == 1){
        return self.verticalRoutes.count;
    }
    else{
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"RouteCell";
    RouteCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    // Configure the cell...
    Route *theRoute;
    if (indexPath.section == 0){
        theRoute = [self.boulderProblems objectAtIndex:indexPath.row];
    }
    else if (indexPath.section == 1){
        theRoute = [self.verticalRoutes objectAtIndex:indexPath.row];
    }
    cell.routeNameLabel.text = [theRoute name];
    cell.ratingLabel.text = [theRoute rating];
    
    ////calculate how recently the route was added
    //   all the routes have a created time stamp at midnight for the day they were created (the midnight before they were created).  So we just create the timestamp for the previous midnight from now and then take the date components from a calendar to get the time difference between the two times.  this way there is no time during the day when the 'time ago' will be off.
    NSDate *thePreviousMidnight = [NSDate date];
    NSCalendar *calendar = [NSCalendar autoupdatingCurrentCalendar];
    NSUInteger preservedComponents = (NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit);
    thePreviousMidnight = [calendar dateFromComponents:[calendar components:preservedComponents fromDate:thePreviousMidnight]];

    NSDateComponents *components = [calendar components:NSDayCalendarUnit | NSSecondCalendarUnit
                                               fromDate:theRoute.setDate
                                                 toDate:thePreviousMidnight
                                                options:0];
    NSInteger daysAgoFromPreviousMidnight = components.day;
    if (daysAgoFromPreviousMidnight < 1){
        cell.recentlyAddedLabel.text = @"added today";
        cell.recentlyAddedLabel.hidden = NO;
    }
    else if (daysAgoFromPreviousMidnight == 1){
        cell.recentlyAddedLabel.text = @"added yesterday";
        cell.recentlyAddedLabel.hidden = NO;
    }
    else if (daysAgoFromPreviousMidnight > 1 && daysAgoFromPreviousMidnight < 7){
        cell.recentlyAddedLabel.text = [NSString stringWithFormat:@"added %d days ago", daysAgoFromPreviousMidnight];
        cell.recentlyAddedLabel.hidden = NO;
    }
    else if (daysAgoFromPreviousMidnight > 7){
        cell.recentlyAddedLabel.hidden = YES;
    }
    
    if (![self userHasSentRoute:theRoute]) {
        cell.alreadySentLabel.hidden = true;
    }
    else{
        cell.alreadySentLabel.hidden = false;
    }
        
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return @"Boulder Problems";
            break;
        case 1:
            return @"Vertical Routes";
            break;
        default:
            return @"Accident";
            break;
    }
    
}



#pragma mark - Table view delegate

-(UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath{
    if ([self userIsGymAdmin]) {
        return UITableViewCellEditingStyleDelete;
    }
    else{
        return UITableViewCellEditingStyleNone;
    }
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath{
//    NSUInteger row = [indexPath row];
    
    //attempt to update route retirement date on server
//    Route *routeToRetire = [self.routes objectAtIndex:row];
//    routeToRetire.retirementDate = [NSDate date];
//    NSString *path = [NSString stringWithFormat:@"routes/%d", [routeToRetire.routeId integerValue]];
//    [self.objectManager putObject:routeToRetire path:path parameters:nil success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
//        NSLog(@"Successfully deleted gym!");
//        [self loadRoutes];
//        [self.tableView reloadData];
//    } failure:^(RKObjectRequestOperation *operation, NSError *error) {
//        NSLog(@"ERROR: %@", error);
//        NSLog(@"Response: %@", operation.HTTPRequestOperation.responseString);
//    }];
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"showRouteDetails"]){
        RouteDetailViewController *routeDetailViewController = segue.destinationViewController;
        
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        if(indexPath.section == 0){
            self.selectedRoute = [self.boulderProblems objectAtIndex:indexPath.row];
        }
        else{
            self.selectedRoute = [self.verticalRoutes objectAtIndex:indexPath.row];
        }
        routeDetailViewController.theRoute = self.selectedRoute;
    }
    else if ([segue.identifier isEqualToString:@"addRoute"]){
        AddRouteViewController *addRouteController = segue.destinationViewController;
        addRouteController.gym = self.gym;
    }
}

@end
