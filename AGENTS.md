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
- Ensure the working tree contains only the expected changes.
- Build the relevant target.
- Report changed files exactly.
- Do not commit unless explicitly asked.

## Build Destination

Prefer building and testing on a connected physical Apple device whenever possible.

Do not change the selected Run Destination unless explicitly requested.

Do not automatically switch to a Simulator unless:

- explicitly requested by the user, or
- no suitable physical device is available.

If a Simulator must be used, explain why.

## Simulator

Prefer physical Apple devices over Simulator whenever possible.

Do NOT:

- repeatedly boot or recreate simulators
- switch from a physical device to Simulator automatically
- create additional simulator instances
- repeatedly retry failed simulator launches

If the same Simulator operation fails twice:

- stop
- explain the failure
- propose manual next steps

## Xcode Automation

Avoid repeated retries.

If Xcode, Device Hub, Preview, Asset Catalog compilation, Icon Composer, or Simulator appears stuck:

- wait for completion
- retry once if appropriate
- otherwise stop and explain

Do not spend excessive time attempting to recover automatically.

After a successful build or test run:

- stop unless additional work was explicitly requested
- report the result

## Assets

For App Icons:

- generate assets once
- verify the result
- stop if Asset Catalog or Icon Composer hangs

Do not repeatedly regenerate identical assets.

## Video Analysis

When analyzing uploaded videos:

- attempt decoding once
- retry with one alternative method if appropriate

If decoding still fails:

- stop
- report the codec/container issue
- suggest exporting as H.264 MP4 or providing screenshots

Do not spend long periods repeatedly attempting to decode unsupported media.

## Token Usage

Prefer efficient execution.

Avoid loops that repeatedly perform nearly identical actions.

When progress stalls:

- summarize findings
- ask for guidance

rather than consuming large amounts of context or tokens.

## Build & Tests

Avoid repeated build cycles.

If the same build fails twice for the same reason:

- stop
- explain the root cause
- suggest a fix

## Git

Do NOT:

- force push
- rewrite history
- rebase
- delete branches

unless explicitly requested.

Always describe commits before creating them.

## User Preference

The user values:

- deterministic behavior
- minimal project changes
- preserving repository structure
- explicit explanations over repeated automated retries
- physical device testing whenever practical

When in doubt, stop and ask rather than making assumptions.

## Safety First

Never modify Apple-managed development infrastructure unless explicitly requested by the user.

This includes, but is not limited to:

- CoreSimulator
- Simulator devices and runtimes
- DeviceSupport
- Provisioning Profiles
- Xcode UserData
- Xcode preferences

Default behavior:

- Analyze ✔
- Report ✔
- Recommend ✔
- Modify ✘

Only modify these locations after an explicit user instruction.

This rule takes precedence over general cleanup requests. If a cleanup request could affect any of the locations above, analyze and report only unless the user explicitly authorizes the modification.
