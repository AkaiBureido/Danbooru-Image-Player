//
//  DanooruImageDelegate.m
//  DabooruImagePlay
//
//  Created by Oleg Utkin on 2/15/13.
//  Copyright (c) 2013 Oleg Utkin. All rights reserved.
//

#import "DanooruImageDelegate.h"

@implementation DanooruImageDelegate

@synthesize tags;
@synthesize current_image;

- (id)init
{
    self = [super init];
    if (self) {
        images_per_page = 100;
        timer = nil;
        countdown = nil;
        delay = 10;
        
        countdownView.intValue = 1;
        [countdownView setTitle:@"--:--"];
        [_pause_continue_button setTitle:@"Pause"];
        
        post_page_cache = [[NSMutableDictionary alloc]init];
        base_request_url = [NSURL URLWithString:[NSString stringWithFormat: @"http://konachan.com/post.xml"]];
        
        [image_view setImageScaling:NSScaleProportionally];
        [image_view setAllowsCutCopyPaste:YES];
        
    }
    return self;
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

-(CXMLDocument*)fetch_xml_for:(NSString*)query {
    NSURL *current_request = [NSURL URLWithString:query relativeToURL:base_request_url];
    NSData *xml_data = [[NSData alloc] initWithContentsOfURL:current_request];
    
    if (xml_data) {
        CXMLDocument *doc = [[CXMLDocument alloc] initWithData:xml_data options:0 error:nil];
        return doc;
    } else {
        return nil;
    }

}

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

-(void)fetch_image_from_post:(NSDictionary*)post {
        NSLog(@"Fetching image...");
        NSString *url = [post objectForKey:@"jpeg_url"];
    
        //NSLog(post);
    
        NSURL *request_url = [NSURL URLWithString:url];
        
        current_image = [[NSImage alloc] initWithContentsOfURL:request_url];
}

-(void)refresh_countdown:(NSTimer*)timer_n {
    date = [date dateByAddingTimeInterval:-1];
    NSDateFormatter *min_sec = [[NSDateFormatter alloc]init];
    [min_sec setDateFormat:@"mm:ss"];
    
    NSLog(@"%@",[min_sec stringFromDate:date]);
    [countdownView setTitle:[min_sec stringFromDate:date]];
}

-(void)refresh_image:(NSTimer*)timer_n {
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
        
        if (current_image) {;
            
            NSSize imageSize;
            imageSize.width =  [[current_image bestRepresentationForDevice:nil] pixelsWide];
            imageSize.height = [[current_image bestRepresentationForDevice:nil] pixelsHigh];
            [current_image setScalesWhenResized:YES];
            [current_image setSize:imageSize];
            
            [image_view setImage:current_image];
        }
        
        [url_field setStringValue:[NSString stringWithFormat:@"http://konachan.com/post/show/%@",[post objectForKey:@"id"]]];
        
        date = [NSDate dateWithString:@"2013-02-16 00:00:00 +0000"];
        date = [date dateByAddingTimeInterval:delay];
        
        countdown =  [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(refresh_countdown:) userInfo:nil repeats:YES];
        timer     =  [NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(refresh_image:) userInfo:nil repeats:YES];
    }
    [swirlie setHidden:YES];
    [swirlie stopAnimation:self];
}

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
    [self refresh_image:nil];
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
        [self refresh_image:nil];
    }
}

- (IBAction)update_delay:(id)sender {
    delay = [countdown_delay_field integerValue];
    [countdownView setState:0];
    [countdown_popover close];
}


@end
