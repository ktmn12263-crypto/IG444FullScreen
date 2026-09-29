# IG444FullScreen

Theos tweak skeleton targeting Instagram 444.0.0 on iOS 26.x.

## What it does

- Adds a small fullscreen button near the top-right when the current view controller
  looks like a Reels/video controller.
- Toggles a fullscreen state.
- Hides several generic overlay view classes while fullscreen is active.
- Attempts to expand the detected AVPlayer container to the window bounds.

## Important

Instagram's internal class/view hierarchy is private and can change between builds.
This version deliberately uses generic runtime detection rather than assuming a
specific private class name. It is therefore a starting point, not a guaranteed
drop-in implementation for every 444.0.0 build.

## Build

Copy the directory to a Theos environment and run:

    make clean package

Then install the generated package on your test/jailbroken device using your
normal package installation method.

If the button does not appear, collect the relevant Instagram view-controller
and subview class names from the running 444.0.0 process and replace the generic
Reels detection with the exact controller/container classes.
