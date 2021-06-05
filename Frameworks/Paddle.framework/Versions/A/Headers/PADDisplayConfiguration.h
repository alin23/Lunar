//
//  PADDisplayConfiguration.h
//  Paddle
//
//  Created by Paddle on 09/10/2017.
//  Introduced in v4.0.
//  Copyright © 2018 Paddle. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

/**
 * @discussion The following constants describe the possible ways in which Paddle UI
 * elements may be displayed.
 */
typedef NS_ENUM(NSInteger, PADDisplayType) {
    /**
     * @discussion Display the dialog as a window.
     */
    PADDisplayTypeWindow,

    /**
     * @discussion Display the dialog as a sheet.
     */
    PADDisplayTypeSheet,

    /**
     * @discussion Display the dialog as an alert.
     */
    PADDisplayTypeAlert,

    /**
     * @discussion Display the dialog using a custom method.
     */
    PADDisplayTypeCustom,

    /**
     * @discussion Display the dialog in an external browser.
     */
    PADDisplayTypeExternalBrowser
};

/**
 * @discussion PADDisplayConfiguration is used to specify how a Paddle dialog should be displayed
 */
@interface PADDisplayConfiguration : NSObject

/**
 * @discussion Indicate how the Paddle UI element should be displayed.
 */
@property (readonly) PADDisplayType displayType;

/**
 * @brief Specifies which window the sheet should be attached to.
 * @discussion The parent window is only required if the display type is PADDisplayTypeSheet.
 */
@property (nullable, assign, readonly) NSWindow *parentWindow;

/**
 * @brief Hide buttons on dialogs that navigate to other dialogs. By default this option
 * is disabled.
 */
@property (readonly) BOOL hideNavigationButtons;

/**
 * @discussion Initialize the display configuration with type and optional parent window.
 */
- (nullable instancetype)initWithDisplayType:(PADDisplayType)displayType
                       hideNavigationButtons:(BOOL)hideNavigationButtons
                                parentWindow:(NSWindow *_Nullable)parentWindow;

/**
 * @discussion Initialize a new display configuration with type and optional parent window.
 */
+ (nullable instancetype)configuration:(PADDisplayType)displayType
                 hideNavigationButtons:(BOOL)hideNavigationButtons
                          parentWindow:(NSWindow *_Nullable)parentWindow;

/**
 * @discussion Initialize a new display configuration with the custom display type. The other
 * options are not used as this display type requires you to show the dialog with custom UI elements.
 */
+ (nullable instancetype)displayCustom;

@end
