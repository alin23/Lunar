//
//  PADAlert.h
//  Paddle
//
//  Created by Paddle on 31/01/2018.
//  Introduced in v4.0.
//  Copyright © 2018 Paddle. All rights reserved.
//

#import "PADProduct.h"
#import <Foundation/Foundation.h>

/**
 * @discussion The following constants describe the possible types of alerts.
 */
typedef NS_ENUM(NSInteger, PADAlertType) {
    /**
     * @discussion Specify that an action has successfully been completed.
     */
    PADAlertSuccess,

    /**
     * @discussion Specify that an action has not successfully been completed.
     */
    PADAlertError,

    /**
     * @discussion Specify that an action has not been completely successful, or that
     * there may be unexpected side-effects.
     */
    PADAlertWarning
};

/**
 * @discussion PADAlert represents a message the SDK would show to the Buyer. These can be suppressed via the Paddle delegate.
 */
@interface PADAlert : NSObject

/**
 * @discussion The type of the alert, which influences the style of the displayed alert.
 */
@property (readonly, assign) PADAlertType alertType;

/**
 * @discussion The main heading text of the alert.
 */
@property (nonnull, readonly, copy) NSString *title;

/**
 * @discussion The body of the alert.
 */
@property (nonnull, readonly, copy) NSString *message;

/**
 * @discussion The product that was relevant when the alert was created. The product is included
 * so that it can be passed to UI control methods.
 */
@property (nonnull, readonly, nonatomic) PADProduct *product;

/**
 * @discussion Create a new PADAlert with all properties specified.
 */
- (nullable instancetype)init:(PADAlertType)alertType title:(nonnull NSString *)title message:(nonnull NSString *)message product:(nonnull PADProduct *)product;

/**
 * @brief Display the alert to the user.
 * @discussion The alert is only displayed if the delegate either does not respond to willShowPaddleAlert:
 * or if the delegate returns YES from willShowPaddleAlert: for this alert. This allows the delegate to
 * disable specific alerts.
 * @discussion Because the alert is a UI element, this method must be called on the main dispatch queue.
 */
- (void)show;

@end
