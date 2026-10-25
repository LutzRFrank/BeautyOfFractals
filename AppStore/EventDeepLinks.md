# Event deep links — macOS and iOS

Both apps register the `beautyoffractals` URL scheme. The iOS target uses
`BeautyOfFractals/Info.plist` from the parent project, alongside its generated
platform-specific Info.plist keys.

## Prepared destinations

| URL | Destination |
| --- | --- |
| `beautyoffractals://event/explore` | Mandelbrot, Deep Blue |
| `beautyoffractals://event/julia` | Julia, Solar Pop |
| `beautyoffractals://event/burning-ship` | Burning Ship, Deep Blue |
| `beautyoffractals://event/eight-rainbows` | Eight Rainbows, Rainbows |

Each accepted link selects the fractal, resets its viewport and iteration setting
through the existing mode-selection action, and dismisses help/favorites/control
sheets so the destination is visible. On macOS it also stops any iteration journey
and expands the selection bar. Reopening the same link resets the destination
again. Favorites are not modified. Unknown routes, credentials, ports, query
parameters, and fragments are ignored without changing the current view.

The route parser is intentionally identical in the two app entry-point files;
keep them in sync when adding destinations.

## Using a link for an App Store event

Apple documents App Store In-App Events for iOS and iPadOS. Choose the URL whose
destination matches the actual event content and enter it in the **Event Deep
Link** field in App Store Connect. For example, a Julia event can use:

```
beautyoffractals://event/julia
```

These routes prepare navigation only: opening a link does not create, publish,
schedule, or notify users about an event. The event itself, dates, metadata, and
review submission are configured separately in App Store Connect. Release an app
version containing this handler before relying on these links; previous versions
do not register the scheme. Match the advertised event to the actual in-app
experience; the generic explore destination alone does not add event content.

The macOS app supports the same routes as direct campaign links, for example from
a website or email. This does not imply availability of App Store event cards in
the Mac App Store.

This implementation uses a custom URL scheme. It requires an installed compatible
app and has no web/download fallback. Universal links would require a controlled
web domain, an apple-app-site-association file, and associated-domain entitlements.
If both the native Mac app and an iOS app running on Mac register this scheme,
macOS may choose either handler; custom schemes do not uniquely identify an app.

## Manual acceptance check before publishing

1. Install the new build on a physical iPhone/iPad or Mac.
2. Put each URL into Notes and open it. Test once with the app closed and once
   while it is already running on a different fractal or with Favorites open.
3. Confirm the expected fractal, palette, default viewport, and 300 base iterations.
4. Zoom, then reopen the same link and confirm the viewport resets again.
5. Open an unknown route such as `beautyoffractals://event/unknown` and confirm
   that the current fractal view is preserved.
6. Confirm normal navigation and saved favorites remain available afterward.

On macOS, an installed build can also be opened from Terminal:

```sh
open 'beautyoffractals://event/julia'
```

## Apple references

- [In-App Events and event deep links](https://developer.apple.com/app-store/in-app-events/)
- [Registering and handling a custom URL scheme](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
