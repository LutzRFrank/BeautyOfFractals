# App Store Release Notes

## Version 2.11

### macOS

- Added guarded Extreme Precision with 6xDouble reference rendering for much
  deeper Mandelbrot exploration.
- Added adaptive reference anchor selection and coverage repair for difficult
  deep-zoom viewports.
- Automatic mode now raises the iteration budget from the center escape value
  plus a reserve, so slow-escape views resolve more reliably.
- The manual Deep iteration range now reaches 250,000 iterations.
- Favorites now preserve the effective iteration count used for automatic deep
  renders.
- Render diagnostics now expose the selected reference strategy, automatic
  iteration budget, reserve, anchors, and coverage details.

### iPhone, iPad, and Apple Watch

- Brought the current guarded deep-zoom renderer to iPhone and iPad.
- Added the same adaptive reference anchor selection and automatic iteration
  budgeting used on Mac.
- The manual Deep iteration range now reaches 250,000 iterations.
- Improved iCloud favorite synchronization with Mac, including newer deep-zoom
  favorites and effective iteration counts.
- Apple Watch now shows render progress while the paired iPhone renders, then
  displays the finished preview with the current zoom value.
