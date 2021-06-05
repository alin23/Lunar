//
//  PADPriceOverride.h
//  Paddle
//
//  Created by Paddle on 13/02/2018.
//  Introduced in v4.0.
//  Copyright © 2018 Paddle. All rights reserved.
//

#import "PADProduct.h"
#import <Foundation/Foundation.h>

/**
 * @brief A PADPrice object describes a pre-authorized price override for the checkout.
 * @discussion The auth value should be calculated beforehand and preferably statically
 * included in the application binary to increase the difficulty of inspection.
 *
 * @discussion You'll need to supply at least one of these to \c PriceOverride if you wish
 * to override the dashboard checkout price for a product.
 */
@interface PADPrice : NSObject

/**
 * @discussion The amount of the price, e.g. @10.15
 */
@property (nonnull, nonatomic) NSNumber *price;

/**
 * @discussion The currency of the overridden price, e.g. @"USD". The specified currency must be enabled on the dashboard.
 */
@property (nonnull, copy) NSString *currency;

/**
 * @discussion The authorization string used to validate the price override, calculated ahead of time.
 */
@property (nonnull, copy) NSString *auth;

/**
 * @discussion Creates a new price with all required properties set.
 */
- (nullable instancetype)init:(nonnull NSNumber *)price currency:(nonnull NSString *)currency auth:(nonnull NSString *)auth;

@end

/**
 * @discussion PADPriceOverride collects all price overrides for the checkout.
 *
 * @discussion You must include a \c PADPrice object per currency that you wish to override
 * and pass a \c PriceOverride to \c CheckoutOptions and subsequently to the \c Checkout.
 */
@interface PADPriceOverride : NSObject

/**
 * @discussion Collection of all purchase price overrides. These prices will be used
 * to determine the price of the checkout, but not to determine the recurring price
 * of the product. For non-subscription products, this is the only collection that
 * should be added to (if necessary).
 */
@property (nonnull, readonly, nonatomic) NSMutableArray *prices;

/**
 * @discussion Collection of all recurring price overrides. These prices will be used
 * to determine the recurring price of the product and will be displayed on the checkout
 * to indicate the recurring nature of the product. These prices do not to influence the
 * price of the checkout.
 */
@property (nonnull, readonly, nonatomic) NSMutableArray *recurringPrices;

/**
 * @discussion Add a price override to the prices array.
 */
- (void)addPrice:(nonnull PADPrice *)price;

/**
 * @discussion Add a recurring price override to the recurring prices array.
 */
- (void)addRecurringPrice:(nonnull PADPrice *)price;

@end
