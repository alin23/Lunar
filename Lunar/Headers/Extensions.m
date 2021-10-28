//
//  Extensions.m
//
//  Created by Alin Panaitiu on 15.10.2021.
//

#import "Extensions.h"

@implementation NSBezierPath (Extensions)

+ (instancetype)bezierPathWithRoundedRectangle:(NSRect)rect byRoundingCorners:(OFRectCorner)corners withRadius:(CGFloat)radius;
{
    return [self bezierPathWithRoundedRectangle:rect byRoundingCorners:corners withRadius:radius includingEdges:OFRectEdgeAllEdges];
}

+ (instancetype)bezierPathWithRoundedRectangle:(NSRect)rect byRoundingCorners:(OFRectCorner)corners withRadius:(CGFloat)radius includingEdges:(OFRectEdge)edges;
{
    NSBezierPath *path = [[self alloc] init];
    [path appendBezierPathWithRoundedRectangle:rect byRoundingCorners:corners withRadius:radius includingEdges:edges];
    return path;
}
// From Scott Anguish's Cocoa book, I believe.
- (void)appendBezierPathWithRoundedRectangle:(NSRect)aRect withRadius:(CGFloat)radius;
{
    return [self appendBezierPathWithRoundedRectangle:aRect byRoundingCorners:OFRectCornerAllCorners withRadius:radius includingEdges:OFRectEdgeAllEdges];
}

- (void)appendBezierPathWithLeftRoundedRectangle:(NSRect)aRect withRadius:(CGFloat)radius;
{
    OFRectCorner corners = (OFRectCornerMinXMinY | OFRectCornerMinXMaxY);
    return [self appendBezierPathWithRoundedRectangle:aRect byRoundingCorners:corners withRadius:radius includingEdges:OFRectEdgeAllEdges];
}

- (void)appendBezierPathWithRightRoundedRectangle:(NSRect)aRect withRadius:(CGFloat)radius;
{
    OFRectCorner corners = (OFRectCornerMaxXMinY | OFRectCornerMaxXMaxY);
    return [self appendBezierPathWithRoundedRectangle:aRect byRoundingCorners:corners withRadius:radius includingEdges:OFRectEdgeAllEdges];
}

- (void)appendBezierPathWithRoundedRectangle:(NSRect)rect byRoundingCorners:(OFRectCorner)corners withRadius:(CGFloat)radius includingEdges:(OFRectEdge)edges;
{
    // This is the value AppKit uses in -appendBezierPathWithRoundedRect:xRadius:yRadius:

    const CGFloat kControlPointMultiplier = 0.55228;

    if (NSIsEmptyRect(rect)) {
        return;
    }

    NSBezierPath *bezierPath = [[self class] bezierPath];
    NSPoint startPoint;
    NSPoint sourcePoint;
    NSPoint destPoint;
    NSPoint controlPoint1;
    NSPoint controlPoint2;

    CGFloat length = MIN(NSWidth(rect), NSHeight(rect));
    radius = MIN(radius, length / 2.0);

    // Top Left (in terms of a non-flipped view)
    BOOL includeCorner = (edges & OFRectEdgeMinX) != 0 || (edges & OFRectEdgeMinY) != 0;
    if ((corners & OFRectCornerMinXMinY) != 0) {
        sourcePoint = NSMakePoint(NSMinX(rect), NSMaxY(rect) - radius);
        startPoint = sourcePoint; // capture for "closing" path without necessarily adding a segment for the final edge

        destPoint = NSMakePoint(NSMinX(rect) + radius, NSMaxY(rect));

        if (includeCorner) {
            controlPoint1 = sourcePoint;
            controlPoint1.y += radius * kControlPointMultiplier;

            controlPoint2 = destPoint;
            controlPoint2.x -= radius * kControlPointMultiplier;

            [bezierPath moveToPoint:sourcePoint];
            [bezierPath curveToPoint:destPoint controlPoint1:controlPoint1 controlPoint2:controlPoint2];
        } else {
            [bezierPath moveToPoint:destPoint];
        }
    } else {
        startPoint = NSMakePoint(NSMinX(rect), NSMaxY(rect));  // capture for "closing" path without necessarily adding a segment for the final edge
        [bezierPath moveToPoint:startPoint];
    }

    // Top right (in terms of a flipped view)
    BOOL includeEdge = (edges & OFRectEdgeMinY) != 0;
    includeCorner = (edges & OFRectEdgeMinY) != 0 || (edges & OFRectEdgeMaxX) != 0;
    if ((corners & OFRectCornerMaxXMinY) != 0) {
        sourcePoint = NSMakePoint(NSMaxX(rect) - radius, NSMaxY(rect));
        destPoint = NSMakePoint(NSMaxX(rect), NSMaxY(rect) - radius);

        if (includeEdge) {
            [bezierPath lineToPoint:sourcePoint];
        } else {
            [bezierPath moveToPoint:sourcePoint];
        }

        if (includeCorner) {
            controlPoint1 = sourcePoint;
            controlPoint1.x += radius * kControlPointMultiplier;

            controlPoint2 = destPoint;
            controlPoint2.y += radius * kControlPointMultiplier;

            [bezierPath curveToPoint:destPoint controlPoint1:controlPoint1 controlPoint2:controlPoint2];
        } else {
            [bezierPath moveToPoint:destPoint];
        }
    } else {
        destPoint = NSMakePoint(NSMaxX(rect), NSMaxY(rect));
        if (includeEdge) {
            [bezierPath lineToPoint:destPoint];
        } else {
            [bezierPath moveToPoint:destPoint];
        }
    }

    // Bottom right (in terms of a flipped view)
    includeEdge = (edges & OFRectEdgeMaxX) != 0;
    includeCorner = (edges & OFRectEdgeMaxX) != 0 || (edges & OFRectEdgeMaxY) != 0;
    if ((corners & OFRectCornerMaxXMaxY) != 0) {
        sourcePoint = NSMakePoint(NSMaxX(rect), NSMinY(rect) + radius);
        destPoint = NSMakePoint(NSMaxX(rect) - radius, NSMinY(rect));

        if (includeEdge) {
            [bezierPath lineToPoint:sourcePoint];
        } else {
            [bezierPath moveToPoint:sourcePoint];
        }

        if (includeCorner) {
            controlPoint1 = sourcePoint;
            controlPoint1.y -= radius * kControlPointMultiplier;

            controlPoint2 = destPoint;
            controlPoint2.x += radius * kControlPointMultiplier;

            [bezierPath curveToPoint:destPoint controlPoint1:controlPoint1 controlPoint2:controlPoint2];
        } else {
            [bezierPath moveToPoint:destPoint];
        }
    } else {
        destPoint = NSMakePoint(NSMaxX(rect), NSMinY(rect));
        if (includeEdge) {
            [bezierPath lineToPoint:destPoint];
        } else {
            [bezierPath moveToPoint:destPoint];
        }
    }

    // Bottom left (in terms of a flipped view)
    includeEdge = (edges & OFRectEdgeMaxY) != 0;
    includeCorner = (edges & OFRectEdgeMaxY) != 0 || (edges & OFRectEdgeMinX) != 0;
    if ((corners & OFRectCornerMinXMaxY) != 0) {
        sourcePoint = NSMakePoint(NSMinX(rect) + radius, NSMinY(rect));
        destPoint = NSMakePoint(NSMinX(rect), NSMinY(rect) + radius);

        if (includeEdge) {
            [bezierPath lineToPoint:sourcePoint];
        } else {
            [bezierPath moveToPoint:sourcePoint];
        }

        if (includeCorner) {
            controlPoint1 = sourcePoint;
            controlPoint1.x -= radius * kControlPointMultiplier;

            controlPoint2 = destPoint;
            controlPoint2.y -= radius * kControlPointMultiplier;

            [bezierPath curveToPoint:destPoint controlPoint1:controlPoint1 controlPoint2:controlPoint2];
        } else {
            [bezierPath moveToPoint:destPoint];
        }
    } else {
        destPoint = NSMakePoint(NSMinX(rect), NSMinY(rect));
        if (includeEdge) {
            [bezierPath lineToPoint:destPoint];
        } else {
            [bezierPath moveToPoint:destPoint];
        }
    }

    // Back to top Left (in terms of a non-flipped view)
    // CONSIDER: If the top-left corner is rounded, the subpath ends at the beginning of the curve rather than at the top-left corner of the bounding rect (assuming non-flipped coordinates). Is that really what we want if using this for composite paths? Should we do an additional move to (MinX, MinY) of the bounding rect?
    includeEdge = (edges & OFRectEdgeMinX) != 0;
    if (includeEdge) {
        [bezierPath lineToPoint:startPoint];
    } else {
        [bezierPath moveToPoint:startPoint];
    }

    [self appendBezierPath: bezierPath];
}
@end
