# iOS 2.20 — Release preparation

Prepared: 22 October 2026. Status: local release candidate; not uploaded or submitted.

## Version and scope

- iPhone/iPad app and embedded Watch companion: version 2.20, build 3 (Debug and Release).
- Mac version remains 2.14, build 2.
- The previous project version was 2.14. Version 2.20 advances that version; 2.2 would compare lower.
- This update adds initial compatibility for the fully opened Duo display. Do not claim dedicated partially folded layouts or validation of every pose.
- Existing rendering, palettes, favorites, export, and Watch features remain part of the app description; they are not advertised as new in 2.20.

The sections below are ready to copy into the corresponding App Store Connect fields. Copy field contents without Markdown headings or code fences.

## Deutsch (de-DE)

### Name

Beauty of Fractals

### Untertitel

Fraktale für iPhone Duo

### Werbetext

Entdecke Fraktale auf dem vollständig geöffneten iPhone Duo – mit anpassbaren Bedienelementen, ausdrucksstarken Farbwelten, präzisen Tiefenzooms und PNG-Export.

### Keywords

Mandelbrot,Julia,Mathematik,Kunst,Zoom,Geometrie,Farben,Visualisierung,PNG

### Beschreibung

Beauty of Fractals bringt die Fraktal-Erkundung auf das vollständig geöffnete Display des iPhone Duo – mit einer Bedienleiste, die sich an die verfügbare Breite anpasst. Version 2.20 ergänzt die vertraute iPhone- und iPad-App um eine erste Duo-Unterstützung.

Erkunde die Mandelbrot-Menge und viele verwandte Fraktale mit natürlicher Touch-Bedienung, schnellem Metal-Rendering, präzisen CPU-Tiefenzooms, ausdrucksstarken Farbpaletten und abstrakten Darstellungsstilen. Sichere Lieblingsorte mit iCloud-Synchronisierung, exportiere PNG-Bilder und verfolge Berechnungen auf deiner Apple Watch.

FUNKTIONEN

• Entdecke Mandelbrot, Potenzen von 2 bis 12, Julia, Burning Ship, Tricorn, Celtic, Newton, Kleinian, Mandelbrot Relief, Mandelbulb 3D, Mandelbox 3D und Eight Rainbows.
• Navigiere mit Touch-Gesten und Pinch-Zoom.
• Nutze das vollständig geöffnete iPhone-Duo-Display mit einer Bedienleiste, die sich an die verfügbare Breite anpasst, und Statusanzeigen, die sichere Displaybereiche berücksichtigen.
• Wechsle mit automatischer Präzisionswahl von schnellen interaktiven Ansichten bis zur abgesicherten Extreme Precision.
• Erkunde geeignete Mandelbrot-Strukturen bei etwa 10^50-facher Vergrößerung. Noch tiefere Ansichten sind experimentell.
• Berechne anspruchsvolle Tiefenzooms mit adaptiven Referenzpunkten und Reparatur unvollständiger Bildbereiche.
• Lass die App das Iterationsbudget anhand der zentralen Bahn mit zusätzlicher Reserve wählen oder stelle manuell bis zu 250.000 Iterationen ein.
• Speichere präzise Lieblingsorte mit Vorschaubild, Farbpalette, Qualität, Fraktaltyp und effektiver Iterationszahl.
• Synchronisiere Favoriten über iCloud zwischen iPhone, iPad und Mac.
• Sieh Renderfortschritt, fertige Vorschaubilder und den aktuellen Zoom auf der Apple Watch.
• Gestalte abstrakte Welten mit Metallic Dreams, Embossed Metal, Guilloché, Spheroid Glass, Quantum Glass, Quantum Traps und Orbital Waves.
• Passe die Darstellungsstile mit ihren eigenen Touch-Reglern an.
• Wähle weitere ausdrucksstarke Farbpaletten wie Aurora, Auric, Pearl, Rainbows und Deep Current.
• Exportiere PNG-Bilder, die lokal für die gewählte Ausgabegröße neu berechnet werden.
• Klappe die Bedienleiste ein, um das Fraktal ungestört zu betrachten.
• Verfolge längere Berechnungen mit Fortschrittsanzeige und Diagnoseinformationen.

Beauty of Fractals lädt zum Entdecken ein. Es gibt keine Benutzerkonten, Werbung, Analysefunktionen oder Tracking. Rendering und Export erfolgen lokal auf deinem Gerät. Die optionale iCloud-Synchronisierung und die Kommunikation mit der Apple Watch verwenden Apple-Systemdienste.

### Was ist neu in Version 2.20

Erste Unterstützung für das vollständig geöffnete Display des iPhone Duo:

• Die einklappbare Bedienleiste nutzt die verfügbare Breite auf größeren iPhone-Ansichten.
• Zoom- und Statusanzeigen berücksichtigen die sicheren Displaybereiche.
• Beim Ändern der Fenstergröße wird der vorübergehende Gestenzustand zurückgesetzt. Mittelpunkt und Zoom des Fraktals bleiben erhalten.

### TestFlight — Was getestet werden soll

Im Mittelpunkt von Version 2.20 steht die erste Unterstützung für das vollständig geöffnete iPhone Duo. Bitte prüfe dort besonders die Bedienleiste und Menüs in Hoch- und Querformat sowie die Darstellung auf bisherigen iPhones und iPads. Achte darauf, dass sich Fraktaltyp, Farbpalette und Qualität auswählen lassen und lange Menüs scrollbar sind.

Teste das Ein- und Ausklappen der Bedienleiste, das Aufziehen eines Zoom-Rechtecks mit einem Finger, Doppeltippen zum Zoomen, Zweifinger-Verschieben und Pinch-Zoom. Prüfe bei einer Größenänderung, ob Mittelpunkt und Zoom erhalten bleiben und keine Auswahlmarkierung stehen bleibt.

Teste außerdem einen gespeicherten Favoriten, einen tiefen Zoom mit Renderfortschritt und einen PNG-Export. Falls eine gekoppelte Apple Watch vorhanden ist, prüfe Fortschritt und Vorschaubild.

Im Duo-Simulator wurde unzuverlässiges Trackpad-Scrollen beobachtet. Bitte solche Probleme zusätzlich per Touch auf einem physischen Gerät prüfen und Gerät, Betriebssystem sowie Eingabeart im Feedback nennen. Teilgefaltete Ansichten haben in dieser Version kein eigenes Layout.

### Optionale Screenshot-Texte

1. Fraktale auf dem geöffneten iPhone Duo
2. Anpassbare Bedienleiste für iPhone Duo
3. Präzise Tiefenzooms erkunden
4. Eigene Farbwelten gestalten
5. Lieblingsorte sichern und Bilder exportieren

## English (en-US)

### Name

Beauty of Fractals

### Subtitle

Fractals for iPhone Duo

### Promotional text

Explore fractals across the fully opened iPhone Duo display, with adaptive controls, expressive palettes, precise deep zooms, and local PNG export.

### Keywords

Mandelbrot,Julia,math,art,zoom,geometry,palettes,visualization,PNG,patterns

### Description

Beauty of Fractals brings fractal exploration to the fully opened iPhone Duo
display, with controls that adapt to the available width. Version 2.20 adds
initial Duo support alongside the familiar iPhone and iPad experience.

Explore the Mandelbrot set and a diverse collection of related fractals with
natural touch navigation, fast Metal rendering, precise CPU deep zooms,
expressive palettes and abstract rendering styles, iCloud-synced favorite
spots, PNG export, and Apple Watch render mirroring.

FEATURES

- Explore Mandelbrot, Power of n (2-12), Julia, Burning Ship, Tricorn, Celtic,
  Newton, Kleinian, Mandelbrot Relief, Mandelbulb 3D, Mandelbox 3D, and Eight
  Rainbows
- Navigate naturally with pinch-to-zoom and touch gestures
- Explore the fully opened iPhone Duo display with controls that adapt to the
  available width and status labels that respect safe areas
- Use Automatic precision selection from fast interactive views through guarded
  Extreme Precision
- Reveal selected Mandelbrot structures around 10^50x, with deeper views
  available as an experimental frontier
- Render difficult deep zooms with adaptive reference anchors and coverage
  repair
- Let the app choose an iteration budget from the center orbit plus a reserve,
  or select up to 250,000 iterations manually
- Save and revisit precise favorite spots with thumbnails, palette, quality,
  mode, and effective iteration counts
- Sync favorites through iCloud across iPhone, iPad, and Mac
- See render progress, final previews, and the current zoom on Apple Watch
- Create abstract worlds with Metallic Dreams, Embossed Metal, Guilloché,
  Spheroid Glass, Quantum Glass, Quantum Traps, and Orbital Waves
- Shape each new style with its dedicated touch control
- Choose from additional expressive color palettes, including Aurora, Auric,
  Pearl, Rainbows, and Deep Current
- Export PNG images recalculated locally for the selected output size
- Collapse the controls for an unobstructed view of the fractal
- Follow longer calculations with clear render status and diagnostics

Beauty of Fractals is designed for exploration. There are no accounts,
advertisements, analytics, or tracking. Rendering and export happen locally on
your device. Optional iCloud sync and Apple Watch communication use Apple
system services.

### What’s New in Version 2.20

Initial support for the fully opened iPhone Duo display:

• The collapsible controls expand to use the available width on larger iPhone layouts.
• Zoom and status labels adapt to the display’s safe areas.
• Resizing clears temporary gesture state while keeping your fractal’s center and zoom.

### TestFlight — What to Test

Version 2.20 focuses on initial support for the fully opened iPhone Duo display. Please prioritize its controls and menus in portrait and landscape, and also check the layout on existing iPhones and iPads. Verify that fractal mode, palette, and quality can be selected and that long menus scroll.

Test collapsing and expanding the controls, one-finger drag to draw a zoom selection, double-tap zoom, two-finger pan, and pinch zoom. When resizing, check that the fractal center and zoom are preserved and no selection outline remains stuck onscreen.

Also test a saved favorite, a deep zoom with render progress, and a PNG export. If a paired Apple Watch is available, check its progress display and preview image.

Unreliable trackpad scrolling has been observed in the Duo simulator. Please also check affected interactions using touch on a physical device and include the device, OS, and input method in feedback. Dedicated partially folded layouts are not included in this version.

### Optional screenshot captions

1. Explore fractals on the opened iPhone Duo
2. Adaptive controls for iPhone Duo
3. Discover precise deep zooms
4. Create expressive color worlds
5. Save favorite places and export images

## App Review notes (English)

Thank you for reviewing Beauty of Fractals 2.20, featuring initial support for
the fully opened iPhone Duo display. Please check the adaptive controls and
safe-area placement in portrait and landscape. Dedicated partially folded
layouts are outside this release’s scope.

- No account, sign-in, subscription, or purchase is required.
- The app does not use advertising, analytics, tracking, or a
  developer-operated backend.
- Fractal rendering and PNG export are performed locally on the device.
- Favorites can sync through the user's Apple iCloud account. New favorites can
  appear across iPhone, iPad, and Mac when iCloud is available.
- The Apple Watch companion receives render progress, preview images, and zoom
  values from the paired iPhone through Apple WatchConnectivity.
- Version 2.20 adds initial compatibility for the fully opened iPhone Duo
  display. The collapsible phone controls expand with the available width;
  zoom and status labels respect the current safe areas.
- Resizing clears transient gesture state while preserving the fractal center
  and zoom. Dedicated partially folded layouts are not part of this release.
- Artistic orbit details now remain stable between progressive previews and
  full-size PNG exports. At extreme depths, the app falls back to stable
  iteration coloring when decorative orbit coordinates are no longer reliable.
- Abstract styles are available for Mandelbrot, Julia, and Power fractals and
  expose the same dedicated style controls as the Mac version.
- Favorites preserve the selected abstract style. Local PNG export reproduces
  its current custom setting.
- Manual Deep mode supports up to 250,000 iterations.
- Selected Mandelbrot views around 10^50x are reachable at suitable locations.
  Deeper views are experimental and can depend strongly on the selected
  location and iteration budget.
- Use the controls to select a fractal mode, palette, render quality, and
  iteration depth.
- Drag with one finger to draw a zoom selection; double-tap to zoom at a point.
  Use two fingers to pan and pinch to zoom. Zoom buttons are also available.
- The controls can be collapsed to provide an unobstructed fractal view.
- Export options are available from the Export control. Deep-zoom exports are
  recalculated locally at the selected target resolution.
- Longer high-precision renders display progress and may be cancelled from the
  render status interface.

## Store links and shared fields

Use the existing copyright and review contact from App Store Connect; private contact details are not stored here. No sign-in credentials are required.

Existing website URLs from the repository (confirm they are reachable before submission):

| Field | Deutsch | English |
| --- | --- | --- |
| Marketing URL | https://lutzrfrank.github.io/BeautyOfFractals/ | https://lutzrfrank.github.io/BeautyOfFractals/index-en.html |
| Support URL | https://lutzrfrank.github.io/BeautyOfFractals/support.html | https://lutzrfrank.github.io/BeautyOfFractals/support-en.html |
| Privacy Policy URL | https://lutzrfrank.github.io/BeautyOfFractals/privacy.html | https://lutzrfrank.github.io/BeautyOfFractals/privacy-en.html |

The existing privacy policy describes local rendering/export, optional iCloud favorites, and WatchConnectivity. This layout update introduces no additional data collection.

## Submission handoff

- Local unsigned Release build validates compilation only; it is not an uploadable distribution archive.
- Confirm that 2.20 and build 3 have not already been used for this app in App Store Connect; the account has not been inspected here.
- Complete touch interaction checks on a physical iPhone and opened Duo validation, including long-menu scrolling and resize/fold transitions. Dedicated partially folded layouts remain outside the advertised scope.
- Retain existing asset edits for owner review. The current asset catalog reports that AccentColor is missing; this predates this release preparation.
- Capture current iPhone, iPad, and Duo screenshots from the final candidate. The two chat screenshots are visual references, not a complete submission set.
- Archive and validate the signed iOS app with its embedded Watch companion using the existing signing configuration. No signing/provisioning settings were changed here.
- Upload the approved build, add version 2.20 and the localized metadata above, confirm existing privacy/age-rating/contact fields, then select the desired release timing.
- No upload, submission, commit, or push is performed as part of this local preparation.
- When commits are requested: commit and push iOS source/README changes in the submodule first, then commit the updated pointer and release metadata/version settings in the parent. Review unrelated staged asset edits separately.

## Metadata limits

Checked against Apple’s [product page guidance](https://developer.apple.com/app-store/product-page/) and [platform version fields](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/): name/subtitle at most 30 characters, promotional text at most 170 characters, keywords at most 100 UTF-8 bytes, description and What’s New at most 4,000 characters each.
