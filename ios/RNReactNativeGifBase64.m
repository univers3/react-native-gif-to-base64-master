
#import "RNReactNativeGifBase64.h"
#import "YYImage.h"

@interface RNReactNativeGifBase64()
@property(nonatomic,strong) RCTResponseSenderBlock callback;
@end

@implementation RNReactNativeGifBase64

RCT_EXPORT_MODULE()
RCT_EXPORT_METHOD(getBase64String:(NSDictionary *)options callback:(RCTResponseSenderBlock)callback)
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        
        self.callback = callback;
        
        NSArray *gifArray = [options objectForKey:@"gifArr"];
        NSArray *facesArray = [options objectForKey:@"faceArr"];
        
        if(gifArray.count > 0 && facesArray.count >0){
            NSDictionary *base64 = [self convertNewGIF:gifArray faces:facesArray];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self.callback(@[base64]);
            });
            
        }else{
            
            [self sendError:@"Please send valid paramters on key 'gifArr' , 'faceArr'"];
        }
        
    });
    
}
-(void)sendError:(NSString*)error{
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.callback(@[@{@"error":error}]);
    });
}

-(NSDictionary*)convertNewGIF:(NSArray*)gifArray faces:(NSArray*)faceArray{
    
    NSDictionary *gifJSON = gifArray.firstObject;
    
    NSString *gifURL = [gifJSON valueForKey:@"url_gif"];
    NSString *gif_id = [gifJSON valueForKey:@"giphy_id"];
    
    NSData *gifdata = [self downloadGIFfromServer:gifURL withID:gif_id];
    NSArray *faceImages = [self downloadFaceImagesFromServer:faceArray];
    
    if (gifdata!=nil && faceImages.count >0){
        
        NSArray *mapper = [gifJSON objectForKey:@"maps"];
        CGFloat ratio = [[gifJSON valueForKey:@"ratio"] floatValue];
        
        NSDictionary *result = [self createNewGif:gifdata faceImages:faceImages mapping:mapper ratioValue:ratio gifID:gif_id];
        
        if (result != nil){
            return result;
        }else{
            NSString *error = [NSString stringWithFormat:@"Unable to get create base64 for gif-id %@",gif_id];
            return @{@"error":error};
        }
        
    }else{
        NSString *error = [NSString stringWithFormat:@"Unable to get data for gif-id %@",gif_id];
        return @{@"error":error};
    }
    
}

- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                   inDomains:NSUserDomainMask] lastObject];
}

-(NSData*)downloadGIFfromServer:(NSString*)url withID:(NSString*)gif_id{
    
    NSData *gifdata;
    
    NSURL *documentURL = [self applicationDocumentsDirectory];
    NSString *fileName = [NSString stringWithFormat:@"%@.gif",gif_id];
    documentURL = [documentURL URLByAppendingPathComponent:fileName];
    
    if ([[NSFileManager defaultManager]fileExistsAtPath:documentURL.path]){
        
        gifdata = [NSData dataWithContentsOfURL:documentURL];
        
    }else{
        
        gifdata = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
        
        if (gifdata != nil) {
            [gifdata writeToFile:documentURL.path atomically:YES];
        }else{
            NSString *error = [NSString stringWithFormat:@"Unable to get gif for %@",url];
            [self sendError:error];
        }
    }
    
    return gifdata;
}

-(NSArray *)downloadFaceImagesFromServer:(NSArray*)facesArr{
    
    NSMutableArray *faces = [NSMutableArray array];
    
    for(NSDictionary *dict in facesArr){
        
        UIImage *faceImg;
        
        NSString *urlString = [dict valueForKey:@"url"];
        
        NSURL *url = [NSURL URLWithString:urlString];
        
        
        NSData *imgData = [NSData dataWithContentsOfURL:url];
        
        if (imgData != nil) {
            faceImg = [UIImage imageWithData:imgData];
        }else{
            NSLog(@"Unable to get image for %@",url);
        }
        
        if(faceImg != nil){
            [faces addObject:faceImg];
        }
    }
    
    return faces;
}

-(NSDictionary*)createNewGif:(NSData*)gif_data faceImages:(NSArray*)faceImagesArr mapping:(NSArray*)mapping ratioValue:(CGFloat)ratio gifID:(NSString*)gif_id{
    
    YYImageDecoder *decoder = [YYImageDecoder decoderWithData:gif_data scale:1.0];
    
    UIImage *_originalImage = [decoder frameAtIndex:0 decodeForDisplay:NO].image;
    
    UIGraphicsBeginImageContextWithOptions(_originalImage.size, NO, 1.0);
    
    YYImageEncoder *webpEncoder = [[YYImageEncoder alloc] initWithType:YYImageTypeWebP];
    webpEncoder.loopCount = 0;
    //    webpEncoder.quality = 1.0;
    
    NSNumber *maxNumber = [mapping valueForKeyPath:@"@max.frame_number"];
    
    for(int i=0; i<maxNumber.intValue; i++){
        
        UIImage *_originalImage = [decoder frameAtIndex:i decodeForDisplay:NO].image;
        
        [_originalImage drawInRect:CGRectMake(0.f, 0.f, _originalImage.size.width, _originalImage.size.height)];
        
        NSPredicate *bPredicate = [NSPredicate predicateWithFormat:@"SELF.frame_number == %d",i];
        
        NSArray *facesArr = [mapping filteredArrayUsingPredicate:bPredicate];
        
        for (NSDictionary* data in facesArr){
            
            int faceNumber = [[data valueForKey:@"face_number"] intValue];
            
            if (faceImagesArr.count > faceNumber){
                
                CGFloat x = [[data valueForKey:@"x"] floatValue];
                CGFloat y = [[data valueForKey:@"y"] floatValue];
                
                CGFloat zoom = [[data valueForKey:@"zoom"] floatValue];
                CGFloat angle = [[data valueForKey:@"angle"] floatValue];
                
                CGFloat newWidth = 400 * ratio * (zoom/100);
                CGFloat newHeight = 400 * ratio * (zoom/100);
                
                x = x - (newWidth / 2);
                y = y - (newHeight / 2);
                
                UIImage *logo = [self imageWithImage:faceImagesArr[faceNumber] convertToSize:CGSizeMake(newWidth, newHeight) rotationAngle:angle];
                
                [logo drawInRect:CGRectMake(x, y, newWidth, newHeight)];
            }
        }
        
        NSTimeInterval timeinterval = [decoder frameDurationAtIndex:i];
        
        // store the image
        UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
        
        [webpEncoder addImage:newImage duration:timeinterval];
    }
    
    UIGraphicsEndImageContext();
    
    NSData *webpData = [webpEncoder encode];
    
    NSString *base64 =  [webpData base64EncodedStringWithOptions:0];
    
    NSURL *documentURL = [self applicationDocumentsDirectory];
    NSString *fileName = [NSString stringWithFormat:@"%@.gif",gif_id];
    documentURL = [documentURL URLByAppendingPathComponent:fileName];
    
    if (webpData != nil) {
        BOOL saved = [webpData writeToFile:documentURL.path atomically:YES];
        
        if (saved){
            return @{@"path":documentURL.path,@"base64":base64};
        }
    }
    
    return @{@"error":@"Error"};
}

- (UIImage *)imageWithImage:(UIImage *)image convertToSize:(CGSize)size rotationAngle:(CGFloat)degrees {
    
    CGFloat radian = degrees * (M_PI/ 180);
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM( context, 0.5f * size.width, 0.5f * size.height ) ;
    CGContextRotateCTM( context,radian) ;
    CGContextTranslateCTM( context, -0.5f * size.width, -0.5f * size.height ) ;
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *destImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return destImage;
}
@end

