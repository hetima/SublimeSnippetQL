#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <QuickLook/QuickLook.h>
#import <Foundation/Foundation.h>


OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

NSDictionary* parseStSnippet(CFURLRef url)
{
    NSMutableDictionary* result=[NSMutableDictionary dictionaryWithCapacity:4];
    
    NSXMLDocument *XMLDocument = [[NSXMLDocument alloc]initWithContentsOfURL:(__bridge NSURL*)url options:0 error:nil];
    NSXMLElement *root= [XMLDocument rootElement];
    NSArray* nodes=[root children];
    NSMutableArray* keys=[NSMutableArray arrayWithObjects:@"content", @"tabTrigger", @"scope", @"description", nil];
    for (NSXMLNode* node in nodes) {
        NSString* matchedKey=nil;
        for (NSString* key in keys) {
            if ([[node name]isEqualToString:key]) {
                matchedKey=key;
                //特にオプションなしで開始タグのみ&lt;に変換してくれる
                //<key></key>で囲まれてるけど表示は問題ないのでそのまま使う
                NSString* value=[node XMLStringWithOptions:NSXMLNodeOptionsNone];
                [result setObject:value forKey:key];
            }
        }
        if (matchedKey) {
            [keys removeObject:matchedKey];
            matchedKey=nil;
        }
    }
    return result;
}

NSDictionary* parseTmSnippet(CFURLRef url)
{
    NSMutableDictionary* result=[NSMutableDictionary dictionaryWithCapacity:4];
    
    NSData* data=[NSData dataWithContentsOfURL:(__bridge NSURL *)(url)];
    NSPropertyListFormat format;
    
    NSDictionary* plist=[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:&format error:nil];
    NSArray* keys=[NSArray arrayWithObjects:@"content", @"tabTrigger", @"scope", @"name", nil];

    for (NSString* key in keys) {
        NSString* value=[plist objectForKey:key];
        if (value) {
            value=[value stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
            [result setObject:value forKey:key];
        }
    }
    id nameValue=[result objectForKey:@"name"];
    if (nameValue) {
        [result setObject:nameValue forKey:@"description"];
    }


    return result;
}

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
    @autoreleasepool {
        
        NSString* tmplPath=[[NSBundle bundleWithIdentifier:@"com.hetima.SublimeSnippetQL"]pathForResource:@"tmpl" ofType:@"html"];
        NSMutableString* tmpl=[[NSMutableString alloc]initWithContentsOfFile:tmplPath encoding:NSUTF8StringEncoding error:nil];
        
        
        NSString* fileName=[[(__bridge NSURL*)url path]lastPathComponent];
        fileName=[fileName stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
        [tmpl replaceOccurrencesOfString:@"%title%" withString:fileName options:0 range:NSMakeRange(0, [tmpl length])];
        
        NSDictionary* dic;
        if ([@"com.hetima.sublime-snippet-ql.sublime-snippet" isEqualToString:(__bridge NSString *)(contentTypeUTI)]) {
            dic=parseStSnippet(url);
        }else if ([@"com.hetima.sublime-snippet-ql.tmsnippet" isEqualToString:(__bridge NSString *)(contentTypeUTI)]) {
            dic=parseTmSnippet(url);
        }
        NSMutableArray* keys=[NSMutableArray arrayWithObjects:@"content", @"tabTrigger", @"scope", @"description", nil];
        for (NSString* key in keys) {
            NSString* value=[dic objectForKey:key];
            if (value) {
                [tmpl replaceOccurrencesOfString:[NSString stringWithFormat:@"<%@></%@>", key, key]
                                      withString:value options:0 range:NSMakeRange(0, [tmpl length])];
            }
        }
        

        NSData* data=[tmpl dataUsingEncoding:NSUTF8StringEncoding];

        NSDictionary* option=@{(__bridge NSString*)kQLPreviewPropertyWidthKey:@720,
                               (__bridge NSString*)kQLPreviewPropertyHeightKey:@480};
        QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)data, kUTTypeHTML, (__bridge CFDictionaryRef)option);
    
    }
    
    
    return kQLReturnNoError;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)
{
    // Implement only if supported
}
