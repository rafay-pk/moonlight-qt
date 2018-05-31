//
//  SettingsViewController.m
//  Moonlight
//
//  Created by Diego Waxemberg on 10/27/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "SettingsViewController.h"
#import "TemporarySettings.h"
#import "DataManager.h"

#define BITRATE_INTERVAL 500 // in kbps

@implementation SettingsViewController {
    NSInteger _bitrate;
    Boolean _adjustedForSafeArea;
}
static NSString* bitrateFormat = @"Bitrate: %.1f Mbps";

-(void)viewDidLayoutSubviews {
    // On iPhone layouts, this view is rooted at a ScrollView. To make it
    // scrollable, we'll update content size here.
    if (self.scrollView != nil) {
        CGFloat highestViewY = 0;
        
        // Enumerate the scroll view's subviews looking for the
        // highest view Y value to set our scroll view's content
        // size.
        for (UIView* view in self.scrollView.subviews) {
            // UIScrollViews have 2 default UIImageView children
            // which represent the horizontal and vertical scrolling
            // indicators. Ignore these when computing content size.
            if ([view isKindOfClass:[UIImageView class]]) {
                continue;
            }
            
            CGFloat currentViewY = view.frame.origin.y + view.frame.size.height;
            if (currentViewY > highestViewY) {
                highestViewY = currentViewY;
            }
        }
        
        // Add a bit of padding so the view doesn't end right at the button of the display
        self.scrollView.contentSize = CGSizeMake(self.scrollView.contentSize.width,
                                                 highestViewY + 20);
    }
    
    // Adjust the subviews for the safe area on the iPhone X.
    if (!_adjustedForSafeArea) {
        if (@available(iOS 11.0, *)) {
            for (UIView* view in self.view.subviews) {
                // HACK: The official safe area is much too large for our purposes
                // so we'll just use the presence of any safe area to indicate we should
                // pad by 20.
                if (self.view.safeAreaInsets.left >= 20 || self.view.safeAreaInsets.right >= 20) {
                    view.frame = CGRectMake(view.frame.origin.x + 20, view.frame.origin.y, view.frame.size.width, view.frame.size.height);
                }
            }
        }

        _adjustedForSafeArea = true;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    DataManager* dataMan = [[DataManager alloc] init];
    TemporarySettings* currentSettings = [dataMan getSettings];
    
    // Bitrate is persisted in kbps
    _bitrate = [currentSettings.bitrate integerValue];
    NSInteger framerate = [currentSettings.framerate integerValue] == 30 ? 0 : 1;
    NSInteger resolution;
    if ([currentSettings.height integerValue] == 360) {
        resolution = 0;
    } else if ([currentSettings.height integerValue] == 720) {
        resolution = 1;
    } else if ([currentSettings.height integerValue] == 1080) {
        resolution = 2;
    } else {
        resolution = 1;
    }
    
    NSInteger onscreenControls = [currentSettings.onscreenControls integerValue];
    NSInteger streamingRemotely = [currentSettings.streamingRemotely integerValue];
    [self.remoteSelector setSelectedSegmentIndex:streamingRemotely];
    [self.resolutionSelector setSelectedSegmentIndex:resolution];
    [self.resolutionSelector addTarget:self action:@selector(newResolutionFpsChosen) forControlEvents:UIControlEventValueChanged];
    [self.framerateSelector setSelectedSegmentIndex:framerate];
    [self.framerateSelector addTarget:self action:@selector(newResolutionFpsChosen) forControlEvents:UIControlEventValueChanged];
    [self.onscreenControlSelector setSelectedSegmentIndex:onscreenControls];
    [self.bitrateSlider setValue:(_bitrate / BITRATE_INTERVAL) animated:YES];
    [self.bitrateSlider addTarget:self action:@selector(bitrateSliderMoved) forControlEvents:UIControlEventValueChanged];
    [self updateBitrateText];
    [self.remoteSelector addTarget:self action:@selector(remoteStreamingChanged) forControlEvents:UIControlEventValueChanged];
}

- (void) remoteStreamingChanged {
    // This function can be used to reconfigure the settings view to offer more remote streaming options (i.e. reduce the audio frequency to 24kHz, enable/disable the HEVC bitrate multiplier, ...)
}

- (void) newResolutionFpsChosen {
    NSInteger frameRate = [self getChosenFrameRate];
    NSInteger resHeight = [self getChosenStreamHeight];
    NSInteger defaultBitrate;
    
    // 1080p60 is 20 Mbps
    if (frameRate == 60 && resHeight == 1080) {
        defaultBitrate = 20000;
    }
    // 720p60 and 1080p30 are 10 Mbps
    else if ((frameRate == 60 && resHeight == 720) ||
             (frameRate == 30 && resHeight == 1080)) {
        defaultBitrate = 10000;
    }
    // 720p30 is 5 Mbps
    else if (resHeight == 720) {
        defaultBitrate = 5000;
    }
    // 360p60 is 2 Mbps
    else if (frameRate == 60 && resHeight == 360) {
        defaultBitrate = 2000;
    }
    // 360p30 is 1 Mbps
    else {
        defaultBitrate = 1000;
    }
    
    _bitrate = defaultBitrate;
    [self.bitrateSlider setValue:defaultBitrate / BITRATE_INTERVAL animated:YES];
    
    [self updateBitrateText];
}

- (void) bitrateSliderMoved {
    _bitrate = BITRATE_INTERVAL * (int)self.bitrateSlider.value;
    [self updateBitrateText];
}

- (void) updateBitrateText {
    // Display bitrate in Mbps
    [self.bitrateLabel setText:[NSString stringWithFormat:bitrateFormat, _bitrate / 1000.]];
}

- (NSInteger) getRemoteOptions {
    return [self.remoteSelector selectedSegmentIndex];
}

- (NSInteger) getChosenFrameRate {
    return [self.framerateSelector selectedSegmentIndex] == 0 ? 30 : 60;
}

- (NSInteger) getChosenStreamHeight {
    const int resolutionTable[] = { 360, 720, 1080 };
    return resolutionTable[[self.resolutionSelector selectedSegmentIndex]];
}

- (NSInteger) getChosenStreamWidth {
    // Assumes fixed 16:9 aspect ratio
    return ([self getChosenStreamHeight] * 16) / 9;
}

- (void) saveSettings {
    DataManager* dataMan = [[DataManager alloc] init];
    NSInteger framerate = [self getChosenFrameRate];
    NSInteger height = [self getChosenStreamHeight];
    NSInteger width = [self getChosenStreamWidth];
    NSInteger onscreenControls = [self.onscreenControlSelector selectedSegmentIndex];
    NSInteger streamingRemotely = [self.remoteSelector selectedSegmentIndex];
    [dataMan saveSettingsWithBitrate:_bitrate framerate:framerate height:height width:width onscreenControls:onscreenControls
        remote: streamingRemotely];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
}


@end