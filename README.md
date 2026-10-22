# Beauty of Fractals

Beauty of Fractals is a fast Mandelbrot and fractal explorer for Mac, iPhone,
iPad, and Apple Watch. It combines Metal rendering, precise CPU deep zooms,
iCloud-synced favorite spots, local PNG export, and a small Watch companion for
following long renders.

## Current release candidate: 2.30 (build 75)

The shared Mac and iOS release introduces native action toolbars and two compact
settings popovers: Fractal, Skin & Quality and Iterations & Effects. The fractal
canvas stays unobstructed until settings are opened. iPhone Duo uses adaptive
side bars in supported layouts; the Watch companion retains render mirroring.

Release texts and validation handoff: [AppStore/Release-2.30.md](AppStore/Release-2.30.md).

## Deep-zoom engine

Version 2.11 extends the Mandelbrot deep-zoom engine with guarded 6xDouble
reference rendering, adaptive anchor selection, automatic iteration budgeting,
and a higher manual iteration range up to 250,000. On suitable locations the app
can now explore selected views around 10^50x; the frontier beyond that remains
experimental and depends strongly on the chosen location.

## Highlights

- Mandelbrot, Power of n, Julia, Burning Ship, Tricorn, Celtic, Newton,
  Kleinian, Mandelbrot Relief, Mandelbulb 3D, Mandelbox 3D, and Eight Rainbows
- Automatic precision selection for normal views, high precision views, and CPU
  deep zooms
- Extreme Precision with guarded 6xDouble reference orbits and adaptive anchors
- Automatic iteration target based on the center orbit plus a reserve
- Favorites with precise viewport data, thumbnails, effective iterations, and
  iCloud sync across Mac, iPhone, and iPad
- Apple Watch companion with render progress, final preview, and zoom display
- Local PNG export; exported images contain the fractal only, not the UI

The app has no account system, advertising, analytics, or developer-operated
backend. Optional iCloud sync and Watch communication use Apple system services.
