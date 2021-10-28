//
//  Extensions.h
//
//  Created by Alin Panaitiu on 15.10.2021.
//

#ifndef Extensions_h
#define Extensions_h

#import <AppKit/NSBezierPath.h>
#import <ApplicationServices/ApplicationServices.h>

typedef NS_OPTIONS(NSUInteger, OFRectCorner) {
    OFRectCornerMinXMinY = 1 << 0,
    OFRectCornerMaxXMinY = 1 << 1,
    OFRectCornerMaxXMaxY = 1 << 2,
    OFRectCornerMinXMaxY = 1 << 3,
    OFRectCornerAllCorners = ~0UL
};

typedef NS_OPTIONS(NSUInteger, OFRectEdge) {
    OFRectEdgeMinX = 1 << 0,
    OFRectEdgeMaxX = 1 << 1,
    OFRectEdgeMinY = 1 << 2,
    OFRectEdgeMaxY = 1 << 3,
    OFRectEdgeAllEdges = ~0UL
};

@interface NSBezierPath (OAExtensions)

+ (instancetype)bezierPathWithRoundedRectangle:(NSRect)rect byRoundingCorners:(OFRectCorner)corners withRadius:(CGFloat)radius;
+ (instancetype)bezierPathWithRoundedRectangle:(NSRect)rect byRoundingCorners:(OFRectCorner)corners withRadius:(CGFloat)radius includingEdges:(OFRectEdge)edges;

- (void)appendBezierPathWithRoundedRectangle:(NSRect)rect withRadius:(CGFloat)radius;
- (void)appendBezierPathWithLeftRoundedRectangle:(NSRect)rect withRadius:(CGFloat)radius;
- (void)appendBezierPathWithRightRoundedRectangle:(NSRect)rect withRadius:(CGFloat)radius;

- (void)appendBezierPathWithRoundedRectangle:(NSRect)rect byRoundingCorners:(OFRectCorner)corners withRadius:(CGFloat)radius includingEdges:(OFRectEdge)edges;
@end

#endif /* Extensions_h */
