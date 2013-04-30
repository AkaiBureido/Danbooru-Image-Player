//
//  DanooruImageDelegate.m
//  DabooruImagePlay
//
//  Created by Oleg Utkin on 2/15/13.
//  Copyright (c) 2013 Oleg Utkin. All rights reserved.
//

#import "DanooruImageDelegate.h"
#import "Base64.h"

@implementation DanooruImageDelegate

@synthesize tags;
@synthesize current_image;

- (id)init
{
    self = [super init];
    if (self) {
        super_lock = [[NSLock alloc]init];
        
        images_per_page = 100;
        timer = nil;
        countdown = nil;
        delay = 10;
        
        queue = [[NSOperationQueue alloc]init];
        
        countdownView.intValue = 1;
        [countdownView setTitle:@"--:--"];
        [_pause_continue_button setTitle:@"Pause"];
        
        post_page_cache = [[NSMutableDictionary alloc]init];
        base_request_url = [NSURL URLWithString:[NSString stringWithFormat: @"http://konachan.com/post.xml"]];
        //base_request_url = [NSURL URLWithString:[NSString stringWithFormat: @"http://danbooru.donmai.us/posts.xml"]];
        
        [image_view setImageScaling:NSScaleProportionally];
        [image_view setAllowsCutCopyPaste:YES];
        
    }
    return self;
}
-(void)awakeFromNib {
    [countdownView setTitle:@"--:--"];
    [_pause_continue_button setTitle:@"Pause"];
}




#pragma mark - Network Fetchers

-(CXMLDocument*)fetch_xml_for:(NSString*)query {
    NSLog(@"Fetching xml...");
    
    //    NSString *loginString = [NSString stringWithFormat:@"c2VtZmVyb246dmFzaWxpc2EK"];
    //    NSString *encodedLoginData = [loginString base64EncodedString];
    //    NSString *base64LoginData = [NSString stringWithFormat:@"Basic %@",encodedLoginData];
    
    NSURL *current_request = [NSURL URLWithString:query relativeToURL:base_request_url];
    
    //    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:current_request
    //                                                           cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
    //                                                       timeoutInterval:10.0];
    //
    //    [request setHTTPMethod:@"POST"];
    //    [request setValue:base64LoginData forHTTPHeaderField:@"Authorization"];
    
    NSData *xml_data = [[NSData alloc] initWithContentsOfURL:current_request];
    
    //    NSError *error;
    //    NSURLResponse* responce;
    //
    //    NSData *xml_data = [NSURLConnection sendSynchronousRequest:(NSURLRequest *)request
    //                                             returningResponse:(NSURLResponse **)&responce
    //                                                         error:(NSError **)&error];
    
    if (xml_data) {
        CXMLDocument *doc = [[CXMLDocument alloc] initWithData:xml_data options:0 error:nil];
        return doc;
    } else {
        return nil;
    }
    
}

-(NSDictionary*)fetch_post:(NSInteger)post_num{
    NSLog(@"Fetching post...");
    NSDictionary *post_location = [self calculate_page:post_num];
    
    if (post_location) {
        NSNumber *page_number = [post_location objectForKey:@"page"];
        NSNumber *offset = [post_location objectForKey:@"offset"];
        
        NSLog(@"page:%@,ossfet:%@,number:%ld",page_number,offset,post_num);
        
        NSMutableArray *page = [post_page_cache objectForKey:page_number];
        
        if (!page) {
            
            NSString *query = [self forge_query_with_tags:tags
                                                    limit:images_per_page
                                                  at_page:[page_number integerValue]];
            
            CXMLDocument *doc = [self fetch_xml_for:query];
            
            if (doc) {
                page = [[NSMutableArray alloc]init];
                
                NSArray *nodes = [doc nodesForXPath:@"//post" error:nil];
                
                for (CXMLElement *node in nodes) {
                    NSMutableDictionary *post = [[NSMutableDictionary alloc]init];
                    
                    for (CXMLNode *attribute in [node attributes]) {
                        [post setObject:[attribute stringValue]
                                 forKey:[attribute name]];
                    }
                    
                    [page addObject:post];
                }
                
                [post_page_cache setObject:page forKey:page_number];
            }
        }
        return [[post_page_cache objectForKey:page_number ] objectAtIndex:[offset integerValue]];
    } else {
        return nil;
    }

}

-(void)fetch_image_from_post:(NSDictionary*)post {
    NSLog(@"Fetching image...");
    NSString *url = [post objectForKey:@"jpeg_url"];
    
    //NSLog(post);
    
    NSURL *request_url = [NSURL URLWithString:url];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:request_url];
    
    //current_image = [[NSImage alloc] initWithContentsOfURL:request_url];
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *responce, NSData *data, NSError *error) {
        if (data) {
            current_image = [[NSImage alloc] initWithData:data];
        }
        [self refresh_image:nil from_post:post withImageReady:YES];
    }];
}

#pragma mark - Utilities and helpers

-(NSString*)forge_query_with_tags:(NSString*)user_tags limit:(NSInteger)limit at_page:(NSInteger)at_page {
    NSLog(@"Forging query...");
    // Format the tags so that they are ok to use in a query string
    NSMutableString *formatted_tags = [NSMutableString stringWithString:user_tags];
    [formatted_tags replaceOccurrencesOfString: @" "
                                    withString: @"+"
                                       options: NSLiteralSearch
                                         range: NSMakeRange(0, [formatted_tags length])];
    
    return [NSString stringWithFormat: @"?tags=%@&limit=%ld&page=%ld",formatted_tags,limit,at_page];
}

-(BOOL)count_posts {
    NSLog(@"Counting posts...");
    if ([tags length] > 0) {
        
        //Build the string using base url with the tag query to determine how many posts we have
        NSString *query = [self forge_query_with_tags:tags limit:1 at_page:0];
        
        //Fetch the xml for the request
        CXMLDocument *doc = [self fetch_xml_for:query];
        if (doc) {
            //Count posts
            NSArray *header = NULL;
            header = [doc nodesForXPath:@"//posts" error:nil];
            max_posts = [[[[header objectAtIndex:0] attributeForName:@"count"] stringValue] integerValue];
            return true;
        } else {
            return false;
        }
    } else {
        return false;
    }
}


-(NSDictionary*)calculate_page:(NSInteger)number {
    NSLog(@"Calculating page...");
    
    if (number == 0 && max_posts > 0) {
        return [NSDictionary dictionaryWithObjectsAndKeys:
                   [NSNumber numberWithInteger: 0], @"page",
                   [NSNumber numberWithInteger: 0], @"offset",
                   nil];
    } else if (number < max_posts && max_posts > 0) {
        double pages = images_per_page;
        double selection = number;
        
        NSNumber *_page = [NSNumber numberWithDouble:(selection/pages)];
        
        NSNumberFormatter *round_up = [[NSNumberFormatter alloc]init];
        [round_up setMaximumFractionDigits:0];
        [round_up setRoundingMode:NSNumberFormatterRoundCeiling];
        
        NSInteger page = [[round_up stringFromNumber:_page] integerValue];
        NSInteger offset = number-images_per_page*(page - 1);
        
        return [NSDictionary dictionaryWithObjectsAndKeys:
                [NSNumber numberWithInteger: page  ], @"page",
                [NSNumber numberWithInteger: offset], @"offset",
                nil];
    } else {
        return nil;
    }
}



-(NSInteger)give_me_random_post {
    NSLog(@"Calculating random number...");
    NSNumber *random = NULL;
    
    while (true && max_posts > 0) {
        if ([random_correct count] >= max_posts) {
            [random_correct removeAllObjects];
        }
        
        random = [ NSNumber numberWithInt: (arc4random() % (max_posts-1)) ];
        
        if (![random_correct containsObject:random]) {
            [random_correct addObject:random];
            break;
        }
    }
    
    return [random integerValue];
}





#pragma mark - Timer Routines

-(void)setTimer {
    NSLog(@"Timer set...");
    countdown = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(refresh_countdown:) userInfo:nil repeats:YES];
    timer = [NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(refresh_image_kludge:) userInfo:nil repeats:YES];
}

-(void)resetTimer {
    NSLog(@"Timer reset...");
    [timer invalidate];
    [countdown invalidate];
}

-(void)refresh_countdown:(NSTimer*)timer_n {
    date = [date dateByAddingTimeInterval:-1];
    NSDateFormatter *min_sec = [[NSDateFormatter alloc]init];
    [min_sec setDateFormat:@"mm:ss"];
    
    NSLog(@"%@",[min_sec stringFromDate:date]);
    [countdownView setTitle:[min_sec stringFromDate:date]];
}

#pragma mark - Interface Actions

-(IBAction)start_slideshow:(id)sender {
    [_pause_continue_button setEnabled:YES];
    
    [timer invalidate];
    [countdown invalidate];
    timer = nil;
    countdown = nil;
    
    tags = [NSMutableString stringWithString:[tag_field stringValue]];
    
    [post_page_cache removeAllObjects];
    [random_correct removeAllObjects];
    
    [self count_posts];
    [self refresh_image:nil from_post:nil withImageReady:NO];
}

- (IBAction)display_popover:(id)sender {
    NSLog(@"text pressed.");
    int test = countdownView.intValue;
    
    if(countdownView.intValue == 1){
        [countdown_delay_field setIntegerValue:delay];
        
        [countdown_popover showRelativeToRect:[countdownView bounds]
                                       ofView:countdownView
                                preferredEdge:NSMaxYEdge];
        
    } else {
        [countdown_popover close];
    }
    
}

- (IBAction)pause_slideshow:(id)sender {
    
    NSLog(@"%@", [_pause_continue_button title]);
    
    if ( [_pause_continue_button title] == @"Pause" ) {
        [timer invalidate];
        [countdown invalidate];
        timer = nil;
        countdown = nil;
        
        [_pause_continue_button setTitle:@"Play"];
        [countdownView setTitle:@"--:--"];
    } else {
        [_pause_continue_button setTitle:@"Pause"];
        [self refresh_image:nil from_post:nil withImageReady:NO];
    }
}

- (IBAction)update_delay:(id)sender {
    delay = [countdown_delay_field integerValue];
    [countdownView setState:0];
    [countdown_popover close];
}

#pragma mark - Interface Controllers

//To use with sheduler
-(void)refresh_image_kludge:(NSTimer*)timer_n {
    [self refresh_image:nil from_post:nil withImageReady:NO];
}

// Horrible unforgivable mess of a function that tries to be soething it is not
// The weird structure comes from the  fact that I want to call this function from another thread
// Why not write another function?! The answer is I should but I did not... Maybe later...
-(void)refresh_image:(NSTimer*)timer_n from_post:(NSDictionary*)post withImageReady:(BOOL)imageReady {
    if (!imageReady) {
        [_pause_continue_button setEnabled:YES];
        [swirlie setHidden:NO];
        [swirlie startAnimation:self];
        
        [timer invalidate];
        [countdown invalidate];
        
        timer = nil;
        countdown = nil;
        
        NSLog(@"tick");
        NSDictionary *post = [self fetch_post:[self give_me_random_post]];
        
        if (post) {
            [self fetch_image_from_post:post];
        }
    } else {
        
        if (current_image) {;
            
            NSSize imageSize;
            imageSize.width =  [[current_image bestRepresentationForDevice:nil] pixelsWide];
            imageSize.height = [[current_image bestRepresentationForDevice:nil] pixelsHigh];
            [current_image setScalesWhenResized:YES];
            [current_image setSize:imageSize];
            
            [image_view setImage:current_image];
        }
        
        NSString* post_url_string = [NSString stringWithFormat:@"http://konachan.com/post/show/%@",[post objectForKey:@"id"]];
        
        [url_field setAllowsEditingTextAttributes:YES];
        [url_field setSelectable:YES];
        
        NSURL* post_url = [NSURL URLWithString:post_url_string];
        NSMutableAttributedString* string = [[NSMutableAttributedString alloc] init];
        [string appendAttributedString: [self hyperlinkFromString:post_url_string withURL:post_url]];
        
        [url_field setTextColor:[NSColor whiteColor]];
        [url_field setAttributedStringValue:string];
        
        date = [NSDate dateWithString:@"2013-02-16 00:00:00 +0000"];
        date = [date dateByAddingTimeInterval:delay];
        
        NSLog(@"Will set countdowns");
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setTimer];
            
            [swirlie setHidden:YES];
            [swirlie stopAnimation:self];
        });
        
        
    }
}

#pragma mark - Utility functions

- (id)hyperlinkFromString:(NSString*)inString withURL:aURL {
    NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString: inString];
    NSRange range = NSMakeRange(0, [attrString length]);
    
    [attrString beginEditing];
    
    
    [attrString addAttribute:NSLinkAttributeName value:[aURL absoluteString] range:range];
    
    // make the text appear in blue
    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor] range:range];
    
    // next make the text appear with an underline
    
    [attrString addAttribute:
    NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSSingleUnderlineStyle] range:range];

    NSMutableParagraphStyle* centered = [[NSMutableParagraphStyle alloc]init];
    [centered setAlignment:NSCenterTextAlignment];
    
    [attrString addAttribute:NSParagraphStyleAttributeName value:centered range:range];
    
    NSFont *font = [NSFont fontWithName:@"Helvetica" size:(CGFloat)13.0];
    [attrString addAttribute:NSFontAttributeName value:font range:range];
    
    [attrString endEditing];
    
    return attrString;
}


@end
