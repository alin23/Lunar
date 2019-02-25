#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// The top level Firebase Analytics singleton that provides methods for logging events and setting
/// user properties. See <a href="http://goo.gl/gz8SLz">the developer guides</a> for general
/// information on using Firebase Analytics in your apps.
@interface FIRAnalytics : NSObject

/// Logs an app event. The event can have up to 25 parameters. Events with the same name must have
/// the same parameters. Up to 500 event names are supported. Using predefined events and/or
/// parameters is recommended for optimal reporting.
///
/// The following event names are reserved and cannot be used:
/// <ul>
///     <li>app_clear_data</li>
///     <li>app_remove</li>
///     <li>app_update</li>
///     <li>error</li>
///     <li>first_open</li>
///     <li>in_app_purchase</li>
///     <li>notification_dismiss</li>
///     <li>notification_foreground</li>
///     <li>notification_open</li>
///     <li>notification_receive</li>
///     <li>os_update</li>
///     <li>session_start</li>
///     <li>user_engagement</li>
/// </ul>
///
/// @param name The name of the event. Should contain 1 to 40 alphanumeric characters or
///     underscores. The name must start with an alphabetic character. Some event names are
///     reserved. See FIREventNames.h for the list of reserved event names. The "firebase_" prefix
///     is reserved and should not be used. Note that event names are case-sensitive and that
///     logging two events whose names differ only in case will result in two distinct events.
/// @param parameters The dictionary of event parameters. Passing nil indicates that the event has
///     no parameters. Parameter names can be up to 40 characters long and must start with an
///     alphabetic character and contain only alphanumeric characters and underscores. Only NSString
///     and NSNumber (signed 64-bit integer and 64-bit floating-point number) parameter types are
///     supported. NSString parameter values can be up to 100 characters long. The "firebase_"
///     prefix is reserved and should not be used for parameter names.
+ (void)logEventWithName:(NSString *)name
              parameters:(nullable NSDictionary<NSString *, id> *)parameters;

/// Log internal events, applying only internal validation.
+ (void)logInternalEventWithOrigin:(NSString *)origin
                              name:(NSString *)name
                        parameters:(NSDictionary *)parameters;

@end

NS_ASSUME_NONNULL_END
