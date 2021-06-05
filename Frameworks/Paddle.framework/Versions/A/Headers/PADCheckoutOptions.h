//
//  PADCheckoutOptions.h
//  Paddle
//
//  Created by Paddle on 09/10/2017.
//  Introduced in v4.0.
//  Copyright © 2018 Paddle. All rights reserved.
//

#import "PADPriceOverride.h"
#import <Foundation/Foundation.h>

/**
 * @brief PADCheckoutOptions describes the options that can be passed to the
 * Paddle checkout.
 * @discussion This interface contains the most common options to customize the checkout.
 * To specify additional options, add them to the \c additionalCheckoutParameters property.
 * See the reference documentation for Paddle.js for all possible checkout configuration options.
 */
@interface PADCheckoutOptions : NSObject

/**
 * @discussion The user's email address.
 */
@property (copy, nullable) NSString *email;

/**
 * @discussion The country of the user represented as a ISO 3166-1 alpha-2 country code,
 * e.g. @"US".
 */
@property (copy, nullable) NSString *country;

/**
 * @discussion The postcode of the user.
 */
@property (copy, nullable) NSString *postcode;

/**
 * @discussion The number of the same product that the user wishes to buy.
 */
@property (copy, nullable) NSNumber *quantity;

/**
 * @discussion Specifies whether the user can change the quantity on the checkout.
 * By default this property is set to YES.
 */
@property BOOL allowQuantity;

/**
 * @discussion The domain from which the checkout is started.
 */
@property (copy, nullable) NSString *referringDomain;

/**
 * @discussion Specifies that users should be not be able to log out on the checkout,
 * preventing them from changing the email on checkout. By default this option is set
 * to NO.
 */
@property BOOL disableLogout;

/**
 * @discussion The opaque value that we pass through the checkout process.
 */
@property (copy, nullable) NSString *passthrough;

/**
 * @discussion The coupon code to use on the checkout.
 */
@property (copy, nullable) NSString *coupon;

/**
 * @discussion The locale code of the user, if you would prefer to override the checkout's auto-detection.
 */
@property (copy, nullable) NSString *locale;

/**
 * @discussion The short title of the checkout, typically the product name.
 */
@property (copy, nullable) NSString *title;

/**
 * @discussion The message of the checkout, typically a short description of
 * the product.
 */
@property (copy, nullable) NSString *message;

/**
 * @discussion The price overrides of the checkout.
 */
@property (nonatomic, nullable) PADPriceOverride *priceOverride;

/**
 * @discussion The additional checkout options.
 */
@property (nonatomic, nullable) NSDictionary *additionalCheckoutParameters;

/**
 * @discussion The checkout options prepared for transmission to the checkout
 * window or UI element.
 */
@property (readonly, nonnull) NSDictionary *formattedOptions;

/**
 * @brief Create an empty checkout options object.
 */
+ (nullable instancetype)options;

@end
