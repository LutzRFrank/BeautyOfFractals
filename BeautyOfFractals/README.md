# Beauty of Fractals for macOS

Beauty of Fractals is an interactive Mandelbrot and fractal explorer for Mac.
It uses Metal for responsive navigation and CPU-based precision renderers for
deep Mandelbrot views.

## Version 2.30 (build 4)

Native window-toolbar actions replace the floating controls. Open Fractal, Skin
& Quality or Iterations & Effects from their toolbar icons. All existing Mac
export options, diagnostics, Iteration Journey, favorites, and navigation remain
available. Command-Shift-C toggles the selection popover.

Release metadata: `AppStore/Release-2.30.md` in the parent repository.

## Deep-zoom features

The 2.11 macOS line focuses on deep zoom quality and cross-device continuity:

- Guarded Extreme Precision based on 6xDouble reference calculations
- Adaptive reference anchor selection with coverage repair for difficult views
- Automatic iteration budgeting from the center orbit plus a reserve
- Manual Deep iteration range up to 250,000
- Practical exploration of selected Mandelbrot views around 10^50x, with deeper
  results treated as experimental
- Favorites that preserve precise coordinates, effective iterations, thumbnails,
  palette, quality, and mode
- iCloud sync with iPhone and iPad
- Apple Watch companion support through the paired iPhone app

The app renders and exports locally. It does not use accounts, ads, analytics,
or tracking.

The shared project and privacy policy are available here:
https://github.com/LutzRFrank/BeautyOfFractals
