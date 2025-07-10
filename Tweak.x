#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

static BOOL enableLogging = NO;

void logToFile(NSString *message) {
	if (!enableLogging) return;  // skip logging if disabled
	
    NSString *logPath = @"/var/mobile/Reddirect.log";
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if (!fileHandle) {
        [[NSFileManager defaultManager] createFileAtPath:logPath contents:nil attributes:nil];
        fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    }
    if (fileHandle) {
        [fileHandle seekToEndOfFile];
        NSString *timestamp = [[NSDate date] description];
        NSString *fullMessage = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];
        [fileHandle writeData:[fullMessage dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    }
}

BOOL isTweakEnabled() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/User/Library/Preferences/com.doctorpewds.reddirectprefs.plist"];
    if (prefs) {
        logToFile([NSString stringWithFormat:@"📦 Loaded Preferences:\n%@", prefs]);
    } else {
        logToFile(@"⚠️ Could not load preferences file.");
    }
    return [[prefs objectForKey:@"enabled"] boolValue];
}

static IMP original_decidePolicyIMP = NULL;

static void swizzled_decidePolicy(id self, SEL _cmd, WKWebView *webView, WKNavigationAction *navAction, void (^decisionHandler)(WKNavigationActionPolicy)) {
    @try {
        NSURL *url = navAction.request.URL;
        NSString *host = url.host.lowercaseString;

        if ([host containsString:@"reddit.com"]) {
            logToFile([NSString stringWithFormat:@"🧭 decidePolicyForNavigationAction URL: %@", url.absoluteString]);
        }

        if (([host isEqualToString:@"www.reddit.com"] || [host isEqualToString:@"reddit.com"]) && ![host isEqualToString:@"old.reddit.com"]) {
            NSString *newURLString = [url.absoluteString stringByReplacingOccurrencesOfString:@"//www.reddit.com" withString:@"//old.reddit.com"];
            newURLString = [newURLString stringByReplacingOccurrencesOfString:@"//reddit.com" withString:@"//old.reddit.com"];
            NSURL *newURL = [NSURL URLWithString:newURLString];

            if (newURL) {
                logToFile([NSString stringWithFormat:@"🔁 Redirecting navigation to %@", newURL.absoluteString]);
                decisionHandler(WKNavigationActionPolicyCancel);
                [webView loadRequest:[NSURLRequest requestWithURL:newURL]];
                return;
            }
        }

        if (original_decidePolicyIMP) {
            ((void(*)(id, SEL, WKWebView*, WKNavigationAction*, void(^)(WKNavigationActionPolicy)))original_decidePolicyIMP)(self, _cmd, webView, navAction, decisionHandler);
        } else {
            logToFile(@"⚠️ Original decidePolicy IMP missing, allowing navigation");
            decisionHandler(WKNavigationActionPolicyAllow);
        }
    }
    @catch (NSException *exception) {
        logToFile([NSString stringWithFormat:@"❌ Exception in swizzled_decidePolicy: %@", exception.reason]);
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

NSURLRequest *rewriteRedditRequestIfNeeded(NSURLRequest *request) {
    NSURL *url = request.URL;
    if (!url) return request;

    NSString *host = url.host.lowercaseString;
    if ([host isEqualToString:@"www.reddit.com"] || [host isEqualToString:@"reddit.com"]) {
        NSString *newStr = [url.absoluteString stringByReplacingOccurrencesOfString:@"//www.reddit.com" withString:@"//old.reddit.com"];
        newStr = [newStr stringByReplacingOccurrencesOfString:@"//reddit.com" withString:@"//old.reddit.com"];
        NSURL *modifiedURL = [NSURL URLWithString:newStr];
        if (modifiedURL) {
            logToFile([NSString stringWithFormat:@"🔁 Rewriting URL to: %@", modifiedURL.absoluteString]);
            return [NSURLRequest requestWithURL:modifiedURL];
        }
    }
    return request;
}

%group ReddirectHooks

%hook WKWebView

- (void)loadRequest:(NSURLRequest *)request {
    NSURLRequest *newRequest = rewriteRedditRequestIfNeeded(request);
    if (newRequest != request) {
        logToFile([NSString stringWithFormat:@"WKWebView loadRequest redirecting to %@", newRequest.URL.absoluteString]);
        %orig(newRequest);
        return;
    }
    %orig(request);
}

- (void)setNavigationDelegate:(id<WKNavigationDelegate>)delegate {
    static BOOL swizzled = NO;
    if (delegate && !swizzled) {
        Class delegateClass = [delegate class];
        SEL selector = @selector(webView:decidePolicyForNavigationAction:decisionHandler:);

        Method origMethod = class_getInstanceMethod(delegateClass, selector);
        if (origMethod && !class_getInstanceMethod(delegateClass, @selector(swizzled_webView:decidePolicyForNavigationAction:decisionHandler:))) {
            original_decidePolicyIMP = method_getImplementation(origMethod);

            BOOL didAdd = class_addMethod(delegateClass,
                                          @selector(swizzled_webView:decidePolicyForNavigationAction:decisionHandler:),
                                          (IMP)swizzled_decidePolicy,
                                          method_getTypeEncoding(origMethod));

            if (didAdd) {
                Method swizzledMethod = class_getInstanceMethod(delegateClass, @selector(swizzled_webView:decidePolicyForNavigationAction:decisionHandler:));
                method_exchangeImplementations(origMethod, swizzledMethod);
                logToFile([NSString stringWithFormat:@"🧩 Swizzled decidePolicyForNavigationAction in %@", NSStringFromClass(delegateClass)]);
                swizzled = YES;
            } else {
                logToFile(@"❌ Failed to add swizzled method");
            }
        }
    }
    %orig(delegate);
}

%end

%end

%ctor {
	if (isTweakEnabled()) {
		logToFile(@"✅ Enabling ReddirectHooks");
		%init(ReddirectHooks);
	} else {
		logToFile(@"🚫 Reddirect disabled, skipping %init");
	}
}
