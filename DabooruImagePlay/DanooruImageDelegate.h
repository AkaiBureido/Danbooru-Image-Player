//
//  DanooruImageDelegate.h
//  DabooruImagePlay
//
//  Created by Oleg Utkin on 2/15/13.
//  Copyright (c) 2013 Oleg Utkin. All rights reserved.
//

#include <stdlib.h>

#import <Foundation/Foundation.h>
#import "TouchXML.h"

@interface DanooruImageDelegate : NSObject{
    NSMutableDictionary *post_page_cache;
    NSInteger            max_posts;
    NSInteger            images_per_page;
    NSMutableString     *tags;
    NSImage             *current_image;
    
    NSInteger delay;
    NSDate    *date;
    
    NSTimer   *countdown;
    NSTimer   *timer;
    
    NSMutableArray *random_correct;
    NSURL *base_request_url;
    
    __weak NSButton *_pause_continue_button;
    IBOutlet NSProgressIndicator *swirlie;
    
    IBOutlet NSImageView *image_view;
    IBOutlet NSSearchField *tag_field;
    IBOutlet NSTextField *url_field;
    
    IBOutlet NSButton *countdownView;
    IBOutlet NSTextField *countdown_delay_field;
    IBOutlet NSPopover *countdown_popover;
}

@property NSMutableString     *tags;
@property NSImage             *current_image;

- (BOOL)request_image_list;
- (void)fetch_image_from_list_at:(int)number;
- (IBAction)start_slideshow:(id)sender;
- (IBAction)display_popover:(id)sender;
- (IBAction)pause_slideshow:(id)sender;
- (IBAction)update_delay:(id)sender;


@property (weak) IBOutlet NSButton *pause_continue_button;

@end
