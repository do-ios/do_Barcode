//
//  doQRView.m
//  Do_Test
//
//  Created by yz on 15/10/23.
//  Copyright © 2015年 DoExt. All rights reserved.
//

#import "doQRView.h"

@implementation doQRView
- (instancetype)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}
- (void)setTransparentArea:(CGRect)transparentArea
{
    _transparentArea = transparentArea;
    [self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect {
    
    //整个二维码扫描界面的颜色
    //中间清空的矩形框
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [self addScreenFillRect:ctx rect:self.frame];
    
    [self addCenterClearRect:ctx rect:self.transparentArea];
    
}

- (void)addScreenFillRect:(CGContextRef)ctx rect:(CGRect)rect {
    
    CGContextSetRGBFillColor(ctx, 40 / 255.0,40 / 255.0,40 / 255.0,0.4);
    CGContextFillRect(ctx, rect);   //draw the transparent layer
}

- (void)addCenterClearRect :(CGContextRef)ctx rect:(CGRect)rect {
    CGContextClearRect(ctx, rect);  //clear the center rect  of the layer
}

@end
