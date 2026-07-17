# App Review Notes

Do not store credentials, private contact details, or other secrets in this
file.

## Version 2.11 - macOS

Thank you for reviewing Beauty of Fractals.

- No account, sign-in, subscription, or purchase is required.
- The app does not use advertising, analytics, tracking, or a
  developer-operated backend.
- Fractal rendering and PNG export are performed locally.
- Favorites can sync through the user's Apple iCloud account. This uses the
  configured iCloud container only for the favorites feature.
- Version 2.11 adds guarded Extreme Precision based on 6xDouble reference
  calculations, adaptive reference anchor selection, and coverage repair.
- Automatic Deep mode can raise the effective iteration budget from the center
  orbit plus a reserve; manual Deep mode supports up to 250,000 iterations.
- Selected Mandelbrot views around 10^50x are reachable at suitable locations.
  Deeper views are labeled experimental because quality depends on the selected
  location and iteration budget.
- Use the controls at the bottom of the window to select a fractal mode,
  palette, render quality, and iteration depth.
- Select Power of n from the fractal menu, then use the Power slider to choose
  an integer exponent from 2 through 12.
- Zoom by clicking the magnifying-glass controls or by interacting directly with
  the fractal. Pan by dragging.
- Press Command-Shift-C, or choose Fractal > Show / Hide Controls, to toggle the
  controls.
- Press Command-Shift-P, use the gauge button, or choose Fractal > Show / Hide
  Render Status to toggle the render status panel.
- The compact control bar includes direct buttons for render status,
  diagnostics, favorites, and export.
- Export options are available from the Export menu in the controls. Deep-zoom
  exports are recalculated locally at the selected target resolution.
- During PNG export, the Export button changes to an hourglass and remains
  unavailable until rendering completes.

## Version 2.11 - iPhone, iPad, and Apple Watch

Thank you for reviewing Beauty of Fractals.

- No account, sign-in, subscription, or purchase is required.
- The app does not use advertising, analytics, tracking, or a
  developer-operated backend.
- Fractal rendering and PNG export are performed locally on the device.
- Favorites can sync through the user's Apple iCloud account. New favorites can
  appear across iPhone, iPad, and Mac when iCloud is available.
- The Apple Watch companion receives render progress, preview images, and zoom
  values from the paired iPhone through Apple WatchConnectivity.
- Version 2.11 brings the current guarded 6xDouble deep-zoom renderer,
  adaptive reference anchor selection, and automatic iteration budgeting to
  iPhone and iPad.
- Manual Deep mode supports up to 250,000 iterations.
- Selected Mandelbrot views around 10^50x are reachable at suitable locations.
  Deeper views are experimental and can depend strongly on the selected
  location and iteration budget.
- Use the controls to select a fractal mode, palette, render quality, and
  iteration depth.
- Navigate with standard touch and pinch gestures.
- The controls can be collapsed to provide an unobstructed fractal view.
- Export options are available from the Export control. Deep-zoom exports are
  recalculated locally at the selected target resolution.
- Longer high-precision renders display progress and may be cancelled from the
  render status interface.
