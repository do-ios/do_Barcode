//
//  do_BarcodeView_View.m
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//
#import <AVFoundation/AVFoundation.h>
#import "do_BarcodeView_UIView.h"

#import "doInvokeResult.h"
#import "doUIModuleHelper.h"
#import "doScriptEngineHelper.h"
#import "doIScriptEngine.h"
#import "doJsonHelper.h"
#import "doQRView.h"
#import "doTextHelper.h"
#import "doServiceContainer.h"
#import "doILogEngine.h"
#import "doBarMBProgressHUD.h"

#define  isIPad [[UIDevice currentDevice]userInterfaceIdiom] == UIUserInterfaceIdiomPad

@interface do_BarcodeView_UIView()<AVCaptureMetadataOutputObjectsDelegate>
{
    BOOL isLigthOn;
    BOOL isStart;
}

@property (nonatomic,strong) AVCaptureSession *session;
@property (nonatomic,strong) AVCaptureVideoPreviewLayer * Videolayer;
@property (nonatomic,strong) AVCaptureDevice *device;
@property (nonatomic, strong) UIImageView * line;
@property (nonatomic,assign) BOOL upOrdown;
@property (nonatomic,assign) int num;
@property (nonatomic,strong) UIImageView *boardImage;
@property (nonatomic,weak) id<doIScriptEngine> tempScriptEngine;
@property (nonatomic,copy) NSString *tempCallBackName;
@property (nonatomic,assign) CGFloat scanAreaW;
@property (nonatomic,assign) CGFloat scanAreaH;
@property (nonatomic,assign) CGFloat scanAreaX;
@property (nonatomic,assign) CGFloat scanAreaY;
@property (nonatomic,strong) doBarMBProgressHUD *hud;
@property (nonatomic,strong) doQRView *qrView;
@end

@implementation do_BarcodeView_UIView
#pragma mark - doIUIModuleView协议方法（必须）
//引用Model对象
- (void) LoadView: (doUIModule *) _doUIModule
{
    _model = (typeof(_model)) _doUIModule;
    self.scanAreaW = _model.RealWidth / 2;
    self.scanAreaH = _model.RealHeight / 2;
    self.scanAreaX = _model.RealWidth / 2 - self.scanAreaW / 2;
    self.scanAreaY = _model.RealHeight / 2 - self.scanAreaH / 2;
    self.backgroundColor = [UIColor clearColor];
    doQRView *qrView = [[doQRView alloc]initWithFrame:CGRectMake(0, 0, _model.RealWidth, _model.RealHeight)];
    qrView.backgroundColor = [UIColor blackColor];
    qrView.transparentArea = CGRectMake(self.scanAreaX, self.scanAreaY, self.scanAreaW, self.scanAreaH);
    self.qrView = qrView;
    [self addSubview:qrView];
    
    doBarMBProgressHUD *hud = [[doBarMBProgressHUD alloc]initWithWindow:[UIApplication sharedApplication].keyWindow];
    
    [self addSubview:hud];
    self.hud = hud;
    [hud show:YES];
    [self startScan];
    
    //进入后台通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    __weak __typeof(self) weakSelf = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureInputPortFormatDescriptionDidChangeNotification
                                                      object:nil
                                                       queue:[NSOperationQueue currentQueue]
                                                  usingBlock: ^(NSNotification *_Nonnull note) {
                                                      AVCaptureMetadataOutput *captureOut=[weakSelf.session.outputs lastObject];
                                                      captureOut.rectOfInterest = [weakSelf.Videolayer metadataOutputRectOfInterestForRect:CGRectMake(weakSelf.scanAreaX, weakSelf.scanAreaY, weakSelf.scanAreaW, weakSelf.scanAreaH)];
                                                  }];
}
//销毁所有的全局对象
- (void) OnDispose
{
    //自定义的全局属性,view-model(UIModel)类销毁时会递归调用<子view-model(UIModel)>的该方法，将上层的引用切断。所以如果self类有非原生扩展，需主动调用view-model(UIModel)的该方法。(App || Page)-->强引用-->view-model(UIModel)-->强引用-->view
    _model = nil;
    [self.Videolayer removeFromSuperlayer];
    self.Videolayer = nil;
    [self.hud removeFromSuperview];
    self.hud = nil;
    [self.qrView removeFromSuperview];
    self.qrView = nil;
//    for (AVCaptureInput *input in self.session.inputs) {
//        [self.session removeInput:input];
//    }
//    for (AVCaptureOutput *output in self.session.outputs) {
//        [self.session removeOutput:output];
//    }
    [self.session stopRunning];
    self.session = nil;
    [_line.layer removeAllAnimations];
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}
//实现布局
- (void) OnRedraw
{
    //实现布局相关的修改,如果添加了非原生的view需要主动调用该view的OnRedraw，递归完成布局。view(OnRedraw)<显示布局>-->调用-->view-model(UIModel)<OnRedraw>
    
    //重新调整视图的x,y,w,h
    [doUIModuleHelper OnRedraw:_model];
    self.qrView.transparentArea =  CGRectMake(self.scanAreaX, self.scanAreaY, self.scanAreaW, self.scanAreaH);
}

#pragma mark - TYPEID_IView协议方法（必须）
#pragma mark - Changed_属性
/*
 如果在Model及父类中注册过 "属性"，可用这种方法获取
 NSString *属性名 = [(doUIModule *)_model GetPropertyValue:@"属性名"];
 
 获取属性最初的默认值
 NSString *属性名 = [(doUIModule *)_model GetProperty:@"属性名"].DefaultValue;
 */
- (void)change_scanArea:(NSString *)newValue
{
    if (newValue.length > 0) {
        NSArray *parmas = [newValue componentsSeparatedByString:@","];
        if (parmas.count < 4) {
            return;
        }
        //空值处理
        if (![((NSString *)[parmas objectAtIndex:0]) isEqualToString:@""]) {
            self.scanAreaX = [[doTextHelper Instance]StrToFloat:[parmas objectAtIndex:0] :self.scanAreaX ] * _model.XZoom;
        }
        else
        {
            self.scanAreaX = _model.RealWidth / 2 - self.scanAreaW / 2;
        }
        if (![((NSString *)[parmas objectAtIndex:1]) isEqualToString:@""]) {
            self.scanAreaY = [[doTextHelper Instance]StrToFloat:[parmas objectAtIndex:1] :self.scanAreaY ] * _model.YZoom;
        }
        else
        {
            self.scanAreaY = _model.RealHeight / 2 - self.scanAreaH / 2;
        }
        if (![((NSString *)[parmas objectAtIndex:2]) isEqualToString:@""]) {
            self.scanAreaW = [[doTextHelper Instance]StrToFloat:[parmas objectAtIndex:2] :self.scanAreaW ] * _model.XZoom;
            if ((self.scanAreaW + self.scanAreaX) > _model.RealWidth) {
                self.scanAreaW = (self.scanAreaW - (self.scanAreaW + self.scanAreaX - _model.RealWidth));
                
            }
        }
        else
        {
            self.scanAreaW = _model.RealWidth / 2;
        }
        if (![((NSString *)[parmas objectAtIndex:3]) isEqualToString:@""]) {
            self.scanAreaH = [[doTextHelper Instance]StrToFloat:[parmas objectAtIndex:3] :self.scanAreaH ] * _model.YZoom;
            if ((self.scanAreaH + self.scanAreaY) > _model.Height) {
                self.scanAreaH = self.scanAreaH - (self.scanAreaH + self.scanAreaY - _model.RealHeight);
            }
            
        }
        else
        {
            self.scanAreaH = _model.RealHeight / 2;
        }
    }
    [self.line.layer removeAllAnimations];
    self.qrView.transparentArea =  CGRectMake(self.scanAreaX, self.scanAreaY, self.scanAreaW, self.scanAreaH);
    [self InitImage];
    [[NSNotificationCenter defaultCenter]postNotificationName:AVCaptureInputPortFormatDescriptionDidChangeNotification object:@"BarcodeView"];
}
- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    //进入前台时调用此函数
    if (isStart) {
        [self start:nil];
    }
}
#pragma mark -
#pragma mark - 同步异步方法的实现
/*
 1.参数节点
 doJsonNode *_dictParas = [parms objectAtIndex:0];
 在节点中，获取对应的参数
 NSString *title = [_dictParas GetOneText:@"title" :@"" ];
 说明：第一个参数为对象名，第二为默认值
 
 2.脚本运行时的引擎
 id<doIScriptEngine> _scritEngine = [parms objectAtIndex:1];
 
 同步：
 3.同步回调对象(有回调需要添加如下代码)
 doInvokeResult *_invokeResult = [parms objectAtIndex:2];
 回调信息
 如：（回调一个字符串信息）
 [_invokeResult SetResultText:((doUIModule *)_model).UniqueKey];
 异步：
 3.获取回调函数名(异步方法都有回调)
 NSString *_callbackName = [parms objectAtIndex:2];
 在合适的地方进行下面的代码，完成回调
 新建一个回调对象
 doInvokeResult *_invokeResult = [[doInvokeResult alloc] init];
 填入对应的信息
 如：（回调一个字符串）
 [_invokeResult SetResultText: @"异步方法完成"];
 [_scritEngine Callback:_callbackName :_invokeResult];
 */
- (AVCaptureDevice *)device
{
    if (!_device) {
        _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    return _device;
}
//同步
- (void)flash:(NSArray *)parms
{
    NSDictionary *_dictParams = [parms objectAtIndex:0];
    NSString *_status = [doJsonHelper GetOneText:_dictParams :@"status" :@""];
    if([_status isEqualToString:@"on"])
    {
        isLigthOn = YES;
    }
    
    else if([_status isEqualToString:@"off"])
    {
        isLigthOn = NO;
    }
    if (self.session.isRunning) {
        [self configureCameraForHighestFrameRate:self.device];
    }
}

//异步
- (void)start:(NSArray *)parms
{
    //该方法已在非UI线程，不需要开启异步线程
    self.tempScriptEngine = [parms objectAtIndex:1];
    //自己的代码实现
    self.tempCallBackName = [parms objectAtIndex:2];
    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self InitImage];
        [self startAnimation];
        if (!weakSelf.session.isRunning) {
            [weakSelf.session startRunning];
        }
        weakSelf.line.hidden = NO;
    });
    isStart = YES;
    
    if ( [self.device lockForConfiguration:NULL] == YES ) {
        if ([self.device isTorchModeSupported:AVCaptureTorchModeOn]) {
            if (isLigthOn) {
                [self.device setTorchMode:AVCaptureTorchModeOn];
            }
            else
            {
                [self.device setTorchMode:AVCaptureTorchModeOff];
            }
        }
        [self.device unlockForConfiguration];
    }
}

#pragma -mark - 私有方法

- (void) InitImage
{
    if (self.line == nil) {
        self.line = [[UIImageView alloc]init];
        self.line.image = [UIImage imageNamed:@"do_Barcode.bundle/line.png"];
        [self addSubview:self.line];
        self.line.hidden = NO;
    }
    self.line.frame = CGRectMake(self.scanAreaX, self.scanAreaY,  self.scanAreaW, 2);
}

- (void)startAnimation
{
    float imageH = self.scanAreaH;
    CABasicAnimation *anim;
    CGPoint startPoint = CGPointMake(_line.layer.position.x, _line.layer.position.y);
    CGPoint endPoint = CGPointMake(_line.layer.position.x, _line.layer.position.y+imageH);
    anim = (CABasicAnimation *)[_line.layer animationForKey:@"lineAnimation"];
    if (!anim) {
        anim = [CABasicAnimation animationWithKeyPath:@"position"];
        anim.fromValue = [NSValue valueWithCGPoint:startPoint];
        anim.toValue = [NSValue valueWithCGPoint:endPoint];
        
        anim.repeatCount = MAXFLOAT;
        anim.duration = 2.0f;
        anim.autoreverses = YES;
        anim.beginTime = CACurrentMediaTime();
        [_line.layer addAnimation:anim forKey:@"lineAnimation"];
    }
}

- (void)startScan
{
    __weak __typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (weakSelf.session == nil) {
            //隐私里设置
            AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
            if (authStatus == AVAuthorizationStatusDenied) {
                [[doServiceContainer Instance].LogEngine WriteInfo:@"请在设备的设置-隐私-相机中允许访问相机" :@""];
                return;
            }
            else
            {
                weakSelf.session = [[AVCaptureSession alloc]init];
                [weakSelf.session beginConfiguration];
                [weakSelf configureCameraForHighestFrameRate:self.device];
                AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
                [weakSelf.session addInput:captureInput];
                AVCaptureMetadataOutput *captureOut = [[AVCaptureMetadataOutput alloc]init];
                [weakSelf.session addOutput:captureOut];
                [captureOut setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
                [captureOut setMetadataObjectTypes:[NSArray arrayWithObjects:AVMetadataObjectTypeQRCode,AVMetadataObjectTypeCode128Code,AVMetadataObjectTypeEAN8Code,AVMetadataObjectTypeUPCECode,AVMetadataObjectTypeCode39Code,AVMetadataObjectTypePDF417Code,AVMetadataObjectTypeAztecCode,AVMetadataObjectTypeCode93Code,AVMetadataObjectTypeEAN13Code,AVMetadataObjectTypeCode39Mod43Code, nil]];
                [weakSelf.session commitConfiguration];
                weakSelf.Videolayer = [[AVCaptureVideoPreviewLayer alloc]initWithSession:self.session];
                weakSelf.Videolayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
                CGRect layerFrame = CGRectMake(_model.RealX, _model.RealY, _model.RealWidth, _model.RealHeight);
                [self.Videolayer setFrame:layerFrame];
                self.clipsToBounds = YES;
                [self.layer insertSublayer:self.Videolayer atIndex:0];
                [self.hud hide:NO];
                self.qrView.backgroundColor = [UIColor clearColor];
                [self.session startRunning];
            }
        }
        
    });
}

- (void)configureCameraForHighestFrameRate:(AVCaptureDevice *)device
{
    AVCaptureDeviceFormat *bestFormat = nil;
    AVFrameRateRange *bestFrameRateRange = nil;
    for ( AVCaptureDeviceFormat *format in [device formats] ) {
        for ( AVFrameRateRange *range in format.videoSupportedFrameRateRanges ) {
            bestFormat = format;
            bestFrameRateRange = range;
        }
    }
    if ( bestFormat ) {
        if ( [device lockForConfiguration:NULL] == YES ) {
            device.activeFormat = bestFormat;
            if ([device isTorchModeSupported:AVCaptureTorchModeOn]) {
                if (isLigthOn) {
                    [device setTorchMode:AVCaptureTorchModeOn];
                }
                else
                {
                    [device setTorchMode:AVCaptureTorchModeOff];
                }
                
            }
            device.activeVideoMinFrameDuration = bestFrameRateRange.minFrameDuration;
            device.activeVideoMaxFrameDuration = bestFrameRateRange.maxFrameDuration;
            [device unlockForConfiguration];
        }
    }
}
#pragma -mark - AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    isStart = NO;
    if (metadataObjects != nil && [metadataObjects count] > 0) {
        AVMetadataMachineReadableCodeObject *metadataObj = [metadataObjects objectAtIndex:0];
        doInvokeResult *_invokeResult = [[doInvokeResult alloc] init:_model.UniqueKey];
        
        NSData *data=[metadataObj.stringValue dataUsingEncoding:NSUTF8StringEncoding];
        NSStringEncoding encode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
        NSString *string = [[NSString alloc] initWithData:data encoding:encode];
        
        NSString *result = @"";
        if (string)
        {
            NSInteger max = [metadataObj.stringValue length];
            char *nbytes = malloc(max + 1);
            NSUInteger i = 0;
            for (; i < max; i++)
            {
                unichar ch = [metadataObj.stringValue characterAtIndex:i];
                nbytes[i] = (char) ch;
            }
            nbytes[max] = '\0';
            result=[NSString stringWithCString:nbytes encoding:encode];
        }else
            result = metadataObj.stringValue;
        
        
        //完成_invokeResult回调对象信息
        NSMutableDictionary *resultDict = [NSMutableDictionary dictionary];
        [resultDict setValue:[metadataObj type] forKey:@"code"];
        [resultDict setValue:result forKey:@"value"];
        
        [_invokeResult SetResultNode:resultDict];
        [self.tempScriptEngine Callback:self.tempCallBackName :_invokeResult];
        [self.session stopRunning];
        dispatch_async(dispatch_get_main_queue(), ^{
            [_line.layer removeAllAnimations];
            self.line.hidden = YES;
        });
    }
}

#pragma mark - doIUIModuleView协议方法（必须）<大部分情况不需修改>
- (BOOL) OnPropertiesChanging: (NSMutableDictionary *) _changedValues
{
    //属性改变时,返回NO，将不会执行Changed方法
    return YES;
}
- (void) OnPropertiesChanged: (NSMutableDictionary*) _changedValues
{
    //_model的属性进行修改，同时调用self的对应的属性方法，修改视图
    [doUIModuleHelper HandleViewProperChanged: self :_model : _changedValues ];
}
- (BOOL) InvokeSyncMethod: (NSString *) _methodName : (NSDictionary *)_dicParas :(id<doIScriptEngine>)_scriptEngine : (doInvokeResult *) _invokeResult
{
    //同步消息
    return [doScriptEngineHelper InvokeSyncSelector:self : _methodName :_dicParas :_scriptEngine :_invokeResult];
}
- (BOOL) InvokeAsyncMethod: (NSString *) _methodName : (NSDictionary *) _dicParas :(id<doIScriptEngine>) _scriptEngine : (NSString *) _callbackFuncName
{
    //异步消息
    return [doScriptEngineHelper InvokeASyncSelector:self : _methodName :_dicParas :_scriptEngine: _callbackFuncName];
}
- (doUIModule *) GetModel
{
    //获取model对象
    return _model;
}

@end
