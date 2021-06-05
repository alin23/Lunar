//
//  PADProductConfiguration.h
//  Paddle
//
//  Created by Paddle on 09/10/2017.
//  Introduced in v4.0.
//  Copyright © 2018 Paddle. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * @brief The following constants describe the possible types of trial of a product.
 */
typedef NS_ENUM(NSInteger, PADProductTrialType) {
    /**
     * @brief Specifies that the product has no trial and that we should not track the trial start
     * date.
     */
    PADProductTrialNone,

    /**
     * @brief Specifies that the product trial should continue regardless of trial start date.
     */
    PADProductTrialUnlimited,

    /**
     * @brief Specifies that the product trial is limited to a fixed number of days.
     */
    PADProductTrialTimeLimited,
};

/**
 * @brief The following constants describe the possible subscription plan types. Together with the
 * subscription plan length, it describes how often the user is charged for their subscription.
 * @discussion The Paddle SDK does not charge the user on this recurring basis. This is handled by
 * the Paddle payment system. The SDK only enables the user to subscribe to the subscription.
 */
typedef NS_ENUM(NSInteger, PADSubscriptionPlanType) {
    /**
     * @brief Specifies that the subscription is charged every year or every n years.
     */
    PADSubscriptionPlanYear,

    /**
     * @brief Specifies that the subscription is charged every month or every n months.
     */
    PADSubscriptionPlanMonth,

    /**
     * @brief Specifies that the subscription is charged every week or every n weeks.
     */
    PADSubscriptionPlanWeek,

    /**
     * @brief Specifies that the subscription is charged daily or every n days.
     */
    PADSubscriptionPlanDay,
};

/**
 * @discussion PADProductConfiguration represents the configuration of
 * a product for the first launch of the app, before we are able to retrieve
 * the remote configuration of the product.
 */
@interface PADProductConfiguration : NSObject

/**
 * @brief Initialise a new product configuration object with the product and vendor name.
 */
+ (nullable instancetype)configuration:(nonnull NSString *)productName
                            vendorName:(nonnull NSString *)vendorName;

/**
 * @discussion The name of the product. This property is typically shown to users of the application.
 */
@property (copy, nonnull) NSString *productName;

/**
 * @discussion The name of the seller. This property is typically shown to users of the application.
 */
@property (copy, nonnull) NSString *vendorName;

/**
 * @discussion Specifies whether the product has a trial. If it does, we will track the start date of the trial
 * and report the number of days remaining in the trial period.
 * @discussion The type of trial as defined on the Paddle dashboard takes predence over this setting. This allows
 * for early-access products to be released with an unlimited trial and then later changed to time-limited trial.
 * @discussion By default the trial type is NONE.
 */
@property PADProductTrialType trialType;

/**
 * @brief The maximum length of the product trial.
 * @discussion The trial length only takes effect for products with time-limited trials.
 */
@property (nonatomic, nullable) NSNumber *trialLength;

/**
 * @brief Specifies the text displayed to the user of the application, explaining the trial policy of the product.
 * @discussion The trial text only takes effect for products with a trial, either limited or unlimited.
 * @discussion This trial text is only used until either the localized trial text is set or until the trial text is
 * updated to the remote configuration via `PADProduct refresh:`.
 */
@property (copy, nullable) NSString *trialText;

/**
 * @brief Specifies the localised text displayed to the user of the application, explaining the trial policy of the product.
 * @discussion The localized trial text only takes effect for products with a trial, either limited or unlimited.
 * @discussion The localized trial text takes priority over the non-localized trial text and the remote trial text.
 */
@property (copy, nullable) NSString *localizedTrialText;

/**
 * @brief The local file path of the product image. The image size must be at least 154x154 pixels.
 * @discussion When trying to display an image for the product, the local file path will be
 * loaded first. This order ensures that the user is shown a product image as soon as possible.
 * If the image URL has been retrieved from the remote configuration, then the image URL is
 * loaded next to provide an up to date version of the product image.
 */
@property (copy, nullable) NSString *imagePath;

/**
 * @discussion The base price of the product before any sales.
 * @discussion If set, this price will also be used as the current price. This ensures that the product
 * access dialog always has a price to display to the user.
 */
@property (nonatomic, nullable) NSNumber *price;

/**
 * @brief The currency of the product prices: base, current and recurring.
 * @discussion The currency should be in the ISO 4217 format.
 */
@property (copy, nullable) NSString *currency;

#pragma mark - Properties for subscription products

/**
 * @brief The recurring base price of the subscription product in the specified currency. All prices share the same
 * currency.
 * @discussion This property will be stored on the subscription product, if set. It will then be used
 * in the product access dialog to describe the recurring charge to the user.
 * @discussion The recurring price will only be used for subscription products, so make sure that you specify the
 * subscription product type when initialising the product.
 */
@property (nonatomic, nullable) NSNumber *recurringPrice;

/**
 * @brief The length of the subscription product's plan. Combined with the subscription plan type,
 * these properties describe how often the user is charged for the subscription.
 * @discussion This property will be stored on the subscription product, if set. It will then be used
 * in the product access dialog to describe the recurring charge to the user.
 * @discussion The plan length will only be used for subscription products, so make sure that you specify the
 * subscription product type when initialising the product.
 */
@property NSUInteger subscriptionPlanLength;

/**
 * @brief The type of the subscription product's plan. Combined with the subscription plan length,
 * these properties describe how often the user is charged for the subscription.
 * @discussion This property will be stored on the subscription product, if set. It will then be used
 * in the product access dialog to describe the recurring charge to the user.
 * @discussion The plan type will only be used for subscription products, so make sure that you specify the
 * subscription product type when initialising the product.
 */
@property PADSubscriptionPlanType subscriptionPlanType;

/**
 * @brief The length of the subscription trial in days. If nil or 0, the subscription has no trial.
 * @discussion This property will be stored on the subscription product, if set. It will then be used
 * in the product access dialog to describe the recurring charge to the user.
 * @discussion The subscription trial length will only be used for subscription products, so make sure that you specify the
 * subscription product type when initialising the product.
 */
@property (nullable) NSNumber *subscriptionTrialLength;

@end
