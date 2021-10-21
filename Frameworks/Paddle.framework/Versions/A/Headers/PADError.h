//
//  PADError.h
//  Paddle
//
//  Created by Paddle on 31/01/2018.
//  Introduced in v4.0.
//  Copyright © 2018 Paddle. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * @discussion The error domain of general Paddle SDK errors.
 */
FOUNDATION_EXPORT NSString *const PADErrorDomain;

/**
 * @discussion The error domain of general Paddle API errors.
 */
FOUNDATION_EXPORT NSString *const PADAPIErrorDomain;

/**
 * @discussion The following constants describe all possible general Paddle SDK errors.
 */
typedef NS_ENUM(NSInteger, PADErrorCode) {
    /**
     * @discussion Specifies that we were unable to complete the license activation of a product.
     */
    PADErrorLicenseActivationFailed = -100,

    /**
     * @discussion Specifies that we were unable to verify the license activation of a product.
     */
    PADErrorActivationVerificationFailed = -101,

    /**
     * @discussion Specifies that we were unable to complete the license deactivation of a product.
     */
    PADErrorLicenseDeactivationFailed = -102,

    /**
     * @discussion Specifies that we were unable to complete the migration of the license activation.
     */
    PADErrorLicenseMigrationFailed = -103,

    /**
     * @brief Specifies that the display type of the Paddle UI did not match.
     * @discussion Not all dialogs cannot be displayed by all available display types.
     */
    PADErrorUITypeMismatch = -104,

    /**
     * @discussion Specifies that we were unable to retrieve the requested product.
     */
    PADErrorProductNotFound = -105,

    /**
     * @brief Specifies that we were unable to retrieve the most recent data of a product.
     * @discussion This error may indicate network connectivity issues.
     */
    PADErrorUnableToFetchProductData = -106,

    /**
     * @discussion Specifies that we were unable to complete the activation of the product.
     */
    PADErrorUnableToActivate = -107,

    /**
     * @discussion Specifies that we were unable to verify the license activation of a product.
     */
    PADErrorUnableToVerifyActivation = -108,

    /**
     * @discussion Specifies that we were unable to complete the license deactivation of a product.
     */
    PADErrorUnableToDeactivate = -109,

    /**
     * @brief Specifies that a call to the Paddle API resulted in an error.
     * @discussion The API call will have been made and result in a valid API response, but the response
     * will have indicated that the requested action could not be completed.
     */
    PADErrorApiResponseNotSuccess = -110,

    /**
     * @brief Specifies that the product appears to be unreleased or incomplete in the Paddle dashboard.
     * @discussion This error is generated when the product data is refreshed and the remote product data
     * indicates that the product has not been configured completely.
     */
    PADErrorUnreleasedProductFromAPI = -112,

    /**
     * @discussion Specifies that the response from the Paddle API was incorrect, which may indicate tampering
     * or a Paddle server error.
     */
    PADErrorInvalidApiResponse = -113,

    /**
     * @discussion Specifies that we were unable to recover the user's license. This may be caused by the user
     * entering an invalid email or a network error.
     */
    PADErrorUnableToRecoverLicense = -114,

    /**
     * @discussion Specifies that a product was not set when attempting to start analytics tracking.
     */
    PADErrorAnalyticsProductNotSet = -115,

    /**
     * @discussion Specifies that we could not create or find the application support directory used by the SDK.
     * This may be due to an entitlements exception.
     * @discussion Without this directory the SDK cannot store licenses, product data, analytics data, etc. We
     * would not be able to retain licensing information, for instance, which means users would have to activate
     * the product on every launch. See the separate file failures for further examples of possible failures.
     */
    PADErrorSupportDirectoryFailure = -116,

    /**
     * @discussion Specifies that we could not manipulate the analytics file. This may indicate a permissions
     * issue.
     * @discussion Without this file we cannot retain analytics events. If we are unable to send the events before
     * your app is closed, the recorded events will be lost.
     */
    PADErrorAnalyticsFileFailure = -117,

    /**
     * @discussion Specifies that we could not manipulate the product file. This may indicate a permissions
     * issue.
     * @discussion Without the product file we cannot retain information about your product. As a result the
     * reported product information may differ between app launches, because we are limited to the local product
     * configuration until the product data is successfully refreshed from the remote configuration. On the next
     * app launch the same process would take place.
     */
    PADErrorProductFileFailure = -118,

    /**
     * @discussion Specifies that we could not manipulate the license file. This may indicate a permissions
     * issue.
     * @discussion Without the license file we cannot retain licensing information across app launches. This can
     * cause users to have to activate the app on each launch, and the trial may reset on every app launch.
     */
    PADErrorLicenseFileFailure = -119,

    /**
     * @discussion Specifies that we could not read the v3 license file as part of the migration process.
     * @discussion Without the v3 license file we cannot migrate the license of your previous app. If this error
     * is reported, the file will at least exist but may not be readable to the current app.
     */
    PADErrorV3LicenseFileFailure = -120,

    /**
     * @brief Specifies that we were unable to retrieve the localized pricing data for a product.
     * @discussion This error may indicate network connectivity issues.
     */
    PADErrorUnableToFetchPricingData = -121,

    /**
     * @brief Specifies that the license code has been activated too many times.
     */
    PADErrorLicenseCodeUtilized = -122,

    PADErrorLicenseExpired = -123,
    
    PADErrorLicenseCodeDoesNotMatchProduct = -124,
    
    PADErrorInvalidEmail = -125,
    
    PADErrorTooManyActivationsOrExpired = -126,
};

/**
 * @discussion The following constants describe all possible general Paddle API errors.
 */
typedef NS_ENUM(NSInteger, PADAPIErrorCode) {
    /**
     * @discussion Specifies that the license code does not exist.
     */
    PADAPIErrorBadLicense = 100,

    /**
     * @discussion Specifies that the API key used to make the request does not match your vendor ID.
     */
    PADAPIErrorBadAPIKey = 102,

    /**
     * @brief Specifies that the license code has reached its maximum number of uses.
     * @discussion The number of uses can be reduced by deactivating the product.
     */
    PADAPIErrorLicenseCodeUtilized = 104,

    /**
     * @brief Specifies that the license code has been disabled and cannot be used to activate the product.
     * @discussion The user may need to purchase a new license code if they wish to activate the product.
     */
    PADAPIErrorLicenseNotActive = 105,

    /**
     * @brief Specifies that we were unable to perform the requested action on the license activation.
     * @discussion This may indicate tampering or a request to deactivate the license was made before the license
     * was activated.
     */
    PADAPIErrorBadActivation = 106,

    /**
     * @discussion Specifies that the action could not be completed because a resource of a different entity
     * (vendor, user, etc.) was specified.
     */
    PADAPIErrorAccessDenied = 107,

    /**
     * @discussion Specifies that the product of the action was not found.
     */
    PADAPIErrorBadProduct = 108,

    /**
     * @discussion Specifies that the currency of the requested price is not allowed.
     */
    PADAPIErrorBadCurrency = 109,

    /**
     * @discussion Specifies that the activation could not be completed as the specified license is for a different product.
     */
    PADAPIErrorLicenseDoesNotMatchProduct = 138,

    /**
     * @discussion Specifies that the license has expired.
     */
    PADAPIErrorLicenseExpired = 140
};
