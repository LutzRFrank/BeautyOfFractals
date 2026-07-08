# BeautyOfFractals Codex Instructions

This repository uses a macOS parent project with an iOS submodule.

## Do not modify unless explicitly requested

Do not modify these files unless the user explicitly asks for versioning, project configuration, scheme, signing, target membership, or release preparation changes:

- BeautyOfFractals.xcodeproj/project.pbxproj
- BeautyOfFractals.xcodeproj/xcshareddata/xcschemes/*.xcscheme
- Any Info.plist or generated Info.plist build setting
- Version numbers / MARKETING_VERSION / CURRENT_PROJECT_VERSION
- Signing, bundle identifiers, entitlements, deployment targets
- Target membership or synchronized file exceptions

In particular:

- Do not change the iOS Run scheme build configuration between Debug and Release.
- Do not change shared Xcode schemes as a side effect of building or testing.
- If Xcode changes an .xcscheme file during a run, report it as an incidental local change and revert it unless explicitly instructed otherwise.

## Submodule workflow

For iOS source changes:

1. Commit and push inside BeautyOfFractals-iOS first.
2. Then commit the updated submodule pointer in the parent repository.
3. Do not mix unrelated parent project changes with iOS source commits.

## Normal validation

Before reporting completion:

- Run git diff --check in the relevant repository.
- Build the relevant target.
- Report changed files exactly.
- Do not commit unless explicitly asked.
