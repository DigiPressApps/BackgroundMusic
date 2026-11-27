// This file is part of Background Music.
//
// Background Music is free software: you can redistribute it and/or
// modify it under the terms of the GNU General Public License as
// published by the Free Software Foundation, either version 2 of the
// License, or (at your option) any later version.
//
// Background Music is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Background Music. If not, see <http://www.gnu.org/licenses/>.

//
//  BGMAppVolumesController.mm
//  BGMApp
//
//  Copyright © 2017, 2018 Kyle Neideck
//  Copyright © 2017 Andrew Tonner
//  Copyright © 2021 Marcus Wu
//

// Self Include
#import "BGMAppVolumesController.h"

// Local Includes
#import "BGM_Types.h"
#import "BGM_Utils.h"
#import "BGMAppVolumes.h"
#import "BGMUserDefaults.h"

// PublicUtility Includes
#import "CACFArray.h"
#import "CACFDictionary.h"
#import "CACFString.h"

// System Includes
#include <libproc.h>
#include <CoreAudio/AudioHardware.h>

static NSTimeInterval const kVolumeRestoreRetryDebounceSec = 0.15;
// Follow-up pushes for HAL clients (e.g. Quick Look helpers) that register after IO starts.
static NSTimeInterval const kVolumeRestoreRetryDelaysSec[] = { 0.05, 0.2, 0.45 };
static size_t const kVolumeRestoreRetryDelaysCount =
        sizeof(kVolumeRestoreRetryDelaysSec) / sizeof(kVolumeRestoreRetryDelaysSec[0]);
// Brief 'silt' notifications during playback should not look like a full stop/start cycle.
static NSTimeInterval const kVolumeRestoreAudibleSilentConfirmSec = 0.35;
// Audible-edge reapply is a backup for IO; skip rapid repeats after IO or a recent audible restore.
static NSTimeInterval const kVolumeRestoreAudibleReapplyCooldownSec = 2.0;

#pragma clang assume_nonnull begin

@implementation BGMAppVolumesController {
    // The App Volumes UI.
    BGMAppVolumes* appVolumes;
    BGMAudioDeviceManager* audioDevices;
    BGMUserDefaults* userDefaults;

    dispatch_queue_t volumeRestoreListenerQueue;
    AudioObjectPropertyListenerBlock volumeRestoreListenerBlock;
    BOOL volumeRestoreListenerEnabled;
    // Bumped when a new debounced restore is requested; cancels an in-flight retry batch.
    uint64_t volumeRestoreDebounceGeneration;
    // Bumped when a new retry batch starts; cancels in-flight retry callbacks.
    uint64_t volumeRestoreRetryGeneration;
    BGMDeviceAudibleState volumeRestoreLastAudibleState;
    BOOL volumeRestoreLastOtherAppIO;
    uint64_t volumeRestoreSilentConfirmGeneration;
    NSTimeInterval volumeRestoreLastAudibleEdgeReapplyTime;
}

#pragma mark Initialisation

- (id) initWithMenu:(NSMenu*)menu
      appVolumeView:(NSView*)view
       audioDevices:(BGMAudioDeviceManager*)devices
       userDefaults:(BGMUserDefaults*)defaults {
    if ((self = [super init])) {
        audioDevices = devices;
        userDefaults = defaults;
        appVolumes = [[BGMAppVolumes alloc] initWithController:self
                                                       bgmMenu:menu
                                                 appVolumeView:view];

        // Create the menu items for controlling app volumes.
        NSArray<NSRunningApplication*>* apps = [[NSWorkspace sharedWorkspace] runningApplications];
        [self insertMenuItemsForApps:apps pushInitialVolumesToDriver:NO];

        // Register for notifications when the user opens or closes apps, so we can update the menu.
        auto opts = NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld;
        [[NSWorkspace sharedWorkspace] addObserver:self
                                        forKeyPath:@"runningApplications"
                                           options:opts
                                           context:nil];

        [self initVolumeRestoreListener];
        [self enableVolumeRestoreListener];
    }

    return self;
}

- (void) initVolumeRestoreListener {
    volumeRestoreListenerEnabled = NO;
    volumeRestoreDebounceGeneration = 0;
    volumeRestoreRetryGeneration = 0;
    volumeRestoreLastAudibleState = kBGMDeviceIsSilent;
    volumeRestoreLastOtherAppIO = NO;
    volumeRestoreSilentConfirmGeneration = 0;
    volumeRestoreLastAudibleEdgeReapplyTime = 0;

    dispatch_queue_attr_t attr;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    if (&dispatch_queue_attr_make_with_qos_class) {
        attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,
                                                       QOS_CLASS_UTILITY,
                                                       0);
    } else {
        attr = DISPATCH_QUEUE_SERIAL;
    }
#pragma clang diagnostic pop

    volumeRestoreListenerQueue =
        dispatch_queue_create("com.bearisdriving.BGM.AppVolumes.RestoreListener", attr);

    __unsafe_unretained BGMAppVolumesController* weakSelf = self;
    volumeRestoreListenerBlock =
        ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress* inAddresses) {
            if (!weakSelf) {
                return;
            }

            for (UInt32 i = 0; i < inNumberAddresses; i++) {
                if (inAddresses[i].mSelector ==
                    kAudioDeviceCustomPropertyDeviceIsRunningSomewhereOtherThanBGMApp) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf handleOtherAppIOChangeForVolumeRestore];
                    });
                } else if (inAddresses[i].mSelector ==
                           kAudioDeviceCustomPropertyDeviceAudibleState) {
                    BGMDeviceAudibleState audibleState =
                        [weakSelf currentAudibleStateForVolumeRestore];

#if DEBUG
                    const char audibleStateStr[5] = CA4CCToCString(audibleState);
                    DebugMsg("BGMAppVolumesController::volumeRestoreListener: audible state '%s'",
                             audibleStateStr);
#endif

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf handleAudibleStateChangeForVolumeRestore:audibleState];
                    });
                }
            }
        };
}

- (void) handleOtherAppIOChangeForVolumeRestore {
    BOOL isRunningElsewhere = [self isBGMDeviceRunningSomewhereOtherThanBGMApp];

    if (!isRunningElsewhere) {
        volumeRestoreLastOtherAppIO = NO;
        return;
    }

    if (volumeRestoreLastOtherAppIO) {
        return;
    }

    volumeRestoreLastOtherAppIO = YES;

#if DEBUG
    DebugMsg("BGMAppVolumesController::handleOtherAppIOChangeForVolumeRestore: "
             "Other app IO started; restoring volumes");
#endif

    [self scheduleReapplySavedVolumesToDriver];
}

- (BOOL) shouldScheduleVolumeRestoreFromAudibleEdge {
    if (volumeRestoreLastAudibleEdgeReapplyTime <= 0) {
        return YES;
    }

    NSTimeInterval elapsed =
        [NSDate timeIntervalSinceReferenceDate] - volumeRestoreLastAudibleEdgeReapplyTime;
    return elapsed >= kVolumeRestoreAudibleReapplyCooldownSec;
}

- (void) confirmAudibleSilentStateForVolumeRestore:(uint64_t)confirmGeneration {
    if (confirmGeneration != volumeRestoreSilentConfirmGeneration) {
        return;
    }

    if ([self currentAudibleStateForVolumeRestore] != kBGMDeviceIsSilent) {
        return;
    }

    volumeRestoreLastAudibleState = kBGMDeviceIsSilent;
}

- (BOOL) isBGMDeviceRunningSomewhereOtherThanBGMApp {
    CFTypeRef propertyDataRef =
        [audioDevices bgmDevice].GetPropertyData_CFType(kBGMRunningSomewhereOtherThanBGMAppAddress);

    if (!propertyDataRef) {
        return NO;
    }

    if (CFGetTypeID(propertyDataRef) != CFBooleanGetTypeID()) {
        CFRelease(propertyDataRef);
        return NO;
    }

    BOOL isRunning = CFBooleanGetValue(static_cast<CFBooleanRef>(propertyDataRef));
    CFRelease(propertyDataRef);
    return isRunning;
}

- (void) handleAudibleStateChangeForVolumeRestore:(BGMDeviceAudibleState)audibleState {
    if (audibleState == kBGMDeviceIsSilent) {
        uint64_t confirmGeneration = ++volumeRestoreSilentConfirmGeneration;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(kVolumeRestoreAudibleSilentConfirmSec *
                                               NSEC_PER_SEC)),
                       dispatch_get_main_queue(),
                       ^{
                           [self confirmAudibleSilentStateForVolumeRestore:confirmGeneration];
                       });
        return;
    }

    // Non-silent: cancel a pending silent confirmation (brief 'silt' flicker during playback).
    ++volumeRestoreSilentConfirmGeneration;

    BGMDeviceAudibleState previousState = volumeRestoreLastAudibleState;

    BOOL shouldRestoreVolumes = NO;
    if (previousState == kBGMDeviceIsSilent && audibleState != kBGMDeviceIsSilent) {
        shouldRestoreVolumes = YES;
    } else if (previousState == kBGMDeviceIsSilentExceptMusic &&
               audibleState == kBGMDeviceIsAudible) {
        shouldRestoreVolumes = YES;
    }

    volumeRestoreLastAudibleState = audibleState;

    if (shouldRestoreVolumes && [self shouldScheduleVolumeRestoreFromAudibleEdge]) {
#if DEBUG
        DebugMsg("BGMAppVolumesController::handleAudibleStateChangeForVolumeRestore: "
                 "Audible edge; restoring volumes");
#endif
        volumeRestoreLastAudibleEdgeReapplyTime = [NSDate timeIntervalSinceReferenceDate];
        [self scheduleReapplySavedVolumesToDriver];
    }
}

- (void) enableVolumeRestoreListener {
    if (!volumeRestoreListenerEnabled) {
        [audioDevices bgmDevice].AddPropertyListenerBlock(kBGMAudibleStateAddress,
                                                          volumeRestoreListenerQueue,
                                                          volumeRestoreListenerBlock);
        [audioDevices bgmDevice].AddPropertyListenerBlock(kBGMRunningSomewhereOtherThanBGMAppAddress,
                                                          volumeRestoreListenerQueue,
                                                          volumeRestoreListenerBlock);
        volumeRestoreListenerEnabled = YES;
    }
}

- (void) disableVolumeRestoreListener {
    if (volumeRestoreListenerEnabled) {
        [audioDevices bgmDevice].RemovePropertyListenerBlock(kBGMAudibleStateAddress,
                                                             volumeRestoreListenerQueue,
                                                             volumeRestoreListenerBlock);
        [audioDevices bgmDevice].RemovePropertyListenerBlock(kBGMRunningSomewhereOtherThanBGMAppAddress,
                                                             volumeRestoreListenerQueue,
                                                             volumeRestoreListenerBlock);
        volumeRestoreListenerEnabled = NO;
    }
}

- (BGMDeviceAudibleState) currentAudibleStateForVolumeRestore {
    return [audioDevices bgmDevice].GetAudibleState();
}

- (void) dealloc {
    [self disableVolumeRestoreListener];
    [[NSWorkspace sharedWorkspace] removeObserver:self
                                       forKeyPath:@"runningApplications"
                                          context:nil];
}

// Adds a volume control menu item for each given app.
- (void) insertMenuItemsForApps:(NSArray<NSRunningApplication*>*)apps {
    [self insertMenuItemsForApps:apps pushInitialVolumesToDriver:NO];
}

- (void) insertMenuItemsForApps:(NSArray<NSRunningApplication*>*)apps
       pushInitialVolumesToDriver:(BOOL)pushInitialVolumesToDriver {
    NSAssert([NSThread isMainThread], @"insertMenuItemsForApps is not thread safe");

    // TODO: Handle the C++ exceptions this method can throw. They can cause crashes because this
    //       method is called in a KVO handler.

    // Get the app volumes currently set on the device
    CACFArray volumesFromBGMDevice([audioDevices bgmDevice].GetAppVolumes(), false);

    for (NSRunningApplication* app in apps) {
        if ([self shouldBeIncludedInMenu:app]) {
            BGMAppVolumeAndPan initial = [self getVolumeAndPanForApp:app
                                                         fromVolumes:volumesFromBGMDevice];
            [appVolumes insertMenuItemForApp:app
                               initialVolume:initial.volume
                                  initialPan:initial.pan];
            if (pushInitialVolumesToDriver) {
                [self applyVolumeAndPanToDriver:initial forApp:app];
            }
        }
    }
}

// Pushes saved volumes immediately, then retries for late HAL clients (debounced).
- (void) scheduleReapplySavedVolumesToDriver {
    NSAssert([NSThread isMainThread], @"scheduleReapplySavedVolumesToDriver is not thread safe");

    ++volumeRestoreRetryGeneration;

    uint64_t debounceGeneration = ++volumeRestoreDebounceGeneration;

    [self reapplySavedVolumesToDriver];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(kVolumeRestoreRetryDebounceSec * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   ^{
                       if (debounceGeneration != self->volumeRestoreDebounceGeneration) {
                           return;
                       }
                       [self executeVolumeRestoreRetries];
                   });
}

- (void) executeVolumeRestoreRetries {
    NSAssert([NSThread isMainThread], @"executeVolumeRestoreRetries is not thread safe");

    uint64_t retryGeneration = ++volumeRestoreRetryGeneration;

    for (size_t i = 0; i < kVolumeRestoreRetryDelaysCount; i++) {
        NSTimeInterval delaySec = kVolumeRestoreRetryDelaysSec[i];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delaySec * NSEC_PER_SEC)),
                       dispatch_get_main_queue(),
                       ^{
                           if (retryGeneration != self->volumeRestoreRetryGeneration) {
                               return;
                           }
                           [self reapplySavedVolumesToDriver];
                       });
    }
}

- (void) reapplySavedVolumesToDriver {
    NSAssert([NSThread isMainThread], @"reapplySavedVolumesToDriver is not thread safe");

    for (NSRunningApplication* app in [[NSWorkspace sharedWorkspace] runningApplications]) {
        if (![self shouldBeIncludedInMenu:app]) {
            continue;
        }

        BGMAppVolumeAndPan volumeAndPan = [appVolumes getVolumeAndPanForApp:app];
        [self mergeSavedVolumeAndPan:&volumeAndPan forApp:app];

        if (volumeAndPan.volume == -1 && volumeAndPan.pan == kAppPanNoValue) {
            continue;
        }

        [self pushVolumeAndPanToDriver:volumeAndPan forApp:app];
    }

    DebugMsg("BGMAppVolumesController::reapplySavedVolumesToDriver: finished");
}

- (void) pushVolumeAndPanToDriver:(BGMAppVolumeAndPan)volumeAndPan
                            forApp:(NSRunningApplication*)app {
    if (volumeAndPan.volume != -1) {
        audioDevices.bgmDevice.SetAppVolume(volumeAndPan.volume,
                                            app.processIdentifier,
                                            (__bridge_retained CFStringRef)app.bundleIdentifier);

        if ([app.bundleIdentifier isEqual:@"com.apple.FaceTime"]) {
            [self setAvconferencedVolume:volumeAndPan.volume];
        }
    }
    if (volumeAndPan.pan != kAppPanNoValue) {
        audioDevices.bgmDevice.SetAppPanPosition(volumeAndPan.pan,
                                                 app.processIdentifier,
                                                 (__bridge_retained CFStringRef)app.bundleIdentifier);
    }
}

- (void) applyVolumeAndPanToDriver:(BGMAppVolumeAndPan)volumeAndPan
                            forApp:(NSRunningApplication*)app {
    if (volumeAndPan.volume != -1) {
        [self setVolume:volumeAndPan.volume
      forAppWithProcessID:app.processIdentifier
                 bundleID:app.bundleIdentifier];
    }
    if (volumeAndPan.pan != kAppPanNoValue) {
        [self setPanPosition:volumeAndPan.pan
           forAppWithProcessID:app.processIdentifier
                      bundleID:app.bundleIdentifier];
    }
}

- (BGMAppVolumeAndPan) getVolumeAndPanForApp:(NSRunningApplication *)app {
    return [appVolumes getVolumeAndPanForApp:app];
}

- (void) setVolumeAndPan:(BGMAppVolumeAndPan)volumeAndPan forApp:(NSRunningApplication*)app {
    [appVolumes setVolumeAndPan:volumeAndPan forApp:app];
    if (volumeAndPan.volume != -1) {
        [self setVolume:volumeAndPan.volume forAppWithProcessID:app.processIdentifier bundleID:app.bundleIdentifier];
    }
    if (volumeAndPan.pan != kAppPanNoValue) {
        [self setPanPosition:volumeAndPan.pan forAppWithProcessID:app.processIdentifier bundleID:app.bundleIdentifier];
    }
}

- (BGMAppVolumeAndPan) getVolumeAndPanForApp:(NSRunningApplication*)app
                                 fromVolumes:(const CACFArray&)volumes {
    BGMAppVolumeAndPan volumeAndPan = {
        .volume = -1,
        .pan = kAppPanNoValue
    };

    for (UInt32 i = 0; i < volumes.GetNumberItems(); i++) {
        CACFDictionary appVolume(false);
        volumes.GetCACFDictionary(i, appVolume);

        // Match the app to the volume/pan by pid or bundle ID.
        CACFString bundleID;
        bundleID.DontAllowRelease();
        appVolume.GetCACFString(CFSTR(kBGMAppVolumesKey_BundleID), bundleID);

        pid_t pid;
        appVolume.GetSInt32(CFSTR(kBGMAppVolumesKey_ProcessID), pid);

        if ((app.processIdentifier == pid) ||
            [app.bundleIdentifier isEqualToString:(__bridge NSString*)bundleID.GetCFString()]) {
            // Found a match, so read the volume and pan.
            appVolume.GetSInt32(CFSTR(kBGMAppVolumesKey_RelativeVolume), volumeAndPan.volume);
            appVolume.GetSInt32(CFSTR(kBGMAppVolumesKey_PanPosition), volumeAndPan.pan);
            break;
        }
    }

    [self mergeSavedVolumeAndPan:&volumeAndPan forApp:app];

    return volumeAndPan;
}

- (void) mergeSavedVolumeAndPan:(BGMAppVolumeAndPan*)volumeAndPan
                         forApp:(NSRunningApplication*)app {
    if (!userDefaults || !app.bundleIdentifier.length) {
        return;
    }

    SInt32 savedVolume = INT_MIN;
    SInt32 savedPan = INT_MIN;
    if (![userDefaults savedAppVolume:&savedVolume
                                  pan:&savedPan
                         forBundleID:app.bundleIdentifier]) {
        return;
    }

    if (volumeAndPan->volume == -1 && savedVolume != INT_MIN) {
        volumeAndPan->volume = savedVolume;
    }
    if (volumeAndPan->pan == kAppPanNoValue && savedPan != INT_MIN) {
        volumeAndPan->pan = savedPan;
    }
}

- (BOOL) shouldBeIncludedInMenu:(NSRunningApplication*)app {
    // Ignore hidden apps and Background Music itself.
    // TODO: Would it be better to only show apps that are registered as HAL clients?
    BOOL isHidden = app.activationPolicy != NSApplicationActivationPolicyRegular &&
                    app.activationPolicy != NSApplicationActivationPolicyAccessory;

    NSString* bundleID = app.bundleIdentifier;
    BOOL isBGMApp = bundleID && [@kBGMAppBundleID isEqualToString:BGMNN(bundleID)];

    return !isHidden && !isBGMApp;
}

- (void) removeMenuItemsForApps:(NSArray<NSRunningApplication*>*)apps {
    NSAssert([NSThread isMainThread], @"removeMenuItemsForApps is not thread safe");

    for (NSRunningApplication* app in apps) {
        [appVolumes removeMenuItemForApp:app];
    }
}

#pragma mark Accessors

- (void)  setVolume:(SInt32)volume
forAppWithProcessID:(pid_t)processID
           bundleID:(NSString* __nullable)bundleID {
    // Update the app's volume.
    audioDevices.bgmDevice.SetAppVolume(volume, processID, (__bridge_retained CFStringRef)bundleID);

    if (userDefaults && bundleID.length) {
        [userDefaults setSavedAppVolume:volume
                                    pan:INT_MIN
                           forBundleID:bundleID];
    }

    // If this volume is for FaceTime, set the volume for the avconferenced process as well. This
    // works around FaceTime not playing its own audio. It plays UI sounds through
    // systemsoundserverd and call audio through avconferenced.
    //
    // This isn't ideal because other apps might play audio through avconferenced, but I don't see a
    // good way we could find out which app is actually playing the audio. We could probably figure
    // it out from reading avconferenced's logs, at least, if it turns out to be important. See
    // https://github.com/kyleneideck/BackgroundMusic/issues/139.
    if ([bundleID isEqual:@"com.apple.FaceTime"]) {
        [self setAvconferencedVolume:volume];
    }
}

- (void) setAvconferencedVolume:(SInt32)volume {
    // TODO: This volume will be lost if avconferenced is restarted.
    pid_t pids[1024];
    size_t procCount = proc_listallpids(pids, 1024);
    char path[PROC_PIDPATHINFO_MAXSIZE];

    for (int i = 0; i < procCount; i++) {
        pid_t pid = pids[i];

        if (proc_pidpath(pid, path, sizeof(path)) > 0 &&
            strncmp(path, "/usr/libexec/avconferenced", sizeof(path)) == 0) {
            DebugMsg("Setting avconferenced volume: %d", volume);
            audioDevices.bgmDevice.SetAppVolume(volume, pid, nullptr);
            return;
        }
    }

    LogWarning("Failed to set avconferenced volume.");
}

- (void) setPanPosition:(SInt32)pan
    forAppWithProcessID:(pid_t)processID
               bundleID:(NSString* __nullable)bundleID {
    audioDevices.bgmDevice.SetAppPanPosition(pan,
                                             processID,
                                             (__bridge_retained CFStringRef)bundleID);

    if (userDefaults && bundleID.length) {
        [userDefaults setSavedAppVolume:INT_MIN
                                    pan:pan
                           forBundleID:bundleID];
    }
}

#pragma mark KVO

- (void) observeValueForKeyPath:(NSString* __nullable)keyPath
                       ofObject:(id __nullable)object
                         change:(NSDictionary* __nullable)change
                        context:(void* __nullable)context
{
    #pragma unused (object, context)

    // KVO callback for the apps currently running on the system. Adds/removes the associated menu
    // items.
    if (keyPath && change && [keyPath isEqualToString:@"runningApplications"]) {
        NSArray<NSRunningApplication*>* newApps = change[NSKeyValueChangeNewKey];
        NSArray<NSRunningApplication*>* oldApps = change[NSKeyValueChangeOldKey];

        int changeKind = [change[NSKeyValueChangeKindKey] intValue];

        switch (changeKind) {
            case NSKeyValueChangeInsertion:
                [self insertMenuItemsForApps:newApps pushInitialVolumesToDriver:YES];
                [self scheduleReapplySavedVolumesToDriver];
                break;

            case NSKeyValueChangeRemoval:
                [self removeMenuItemsForApps:oldApps];
                break;

            case NSKeyValueChangeReplacement:
                [self removeMenuItemsForApps:oldApps];
                [self insertMenuItemsForApps:newApps pushInitialVolumesToDriver:NO];
                break;

            case NSKeyValueChangeSetting:
                [appVolumes removeAllAppVolumeMenuItems];
                [self insertMenuItemsForApps:newApps pushInitialVolumesToDriver:NO];
                break;
        }
    }
}

@end

#pragma clang assume_nonnull end
