//
//  RouteCell.h
//  top_this
//
//  Created by Andrew Benson on 2/19/13.
//  Copyright (c) 2013 Andrew Benson. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RouteCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *routeNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *recentlyAddedLabel;
@property (weak, nonatomic) IBOutlet UILabel *ratingLabel;

@end