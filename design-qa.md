# Design QA — Profile, Settings, and Accounts

## Reference

- `IMG_9436.PNG` and `IMG_9437.PNG` supplied by the user.
- Compared against iPhone 17 Pro simulator captures for Profile, Settings, and Accounts.

## Results

- Profile uses the reference's lightweight hierarchy: centred identity, one large rounded action card, icon-free rows without dividers or chevrons, and separate destructive-action cards.
- Settings uses one large rounded route card containing all eight settings destinations, without section headers, icons, dividers, or chevrons.
- A physical simulator tap on Appearance successfully pushed to the Appearance destination. All eight rows share the same direct-navigation implementation.
- The Accounts carousel gives the avatar explicit horizontal and vertical clearance and disables scroll-content clipping. The simulator capture shows the full circle and shadow at both edges.
- Revolut-specific premium branding and promotional content were intentionally not copied; New Money retains its own content and visual identity.

## Verification

- Focused SwiftUI navigation and layout tests: 3 passed, 0 failed.
- Profile, Settings, and Accounts inspected at iPhone 17 Pro portrait size.
- No P0, P1, or P2 visual issues remain in the requested scope.

final result: passed
