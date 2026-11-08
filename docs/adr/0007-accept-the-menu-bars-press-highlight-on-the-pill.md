# Accept the menu bar's press highlight on the Pill

On macOS 27 each status item is hosted by the system's menu bar process, which draws a rounded
highlight behind the item on mouse-down, before the app sees the press. While the Pill had a ▶/⏸ square
that started and paused the Selected Project, that highlight behind the whole Pill looked like a
glitch (#28). #28 first tried to stop it from inside the app: dropping the mouse-down, a custom view
instead of the button, a disabled button, and the expanded-interface delegate. None worked, because
the highlight is drawn in another process. So #28 added a cover: an invisible window of the app's own,
raised over the Pill while the pointer was on it, that took the press before the menu bar could, and
stood in for the button's action on its mouse-up. #44 then patched the cases it missed: a press before
the pointer moved, an auto-hidden menu bar sliding in, and other apps' full-screen spaces.

Since #50 the Pill has no ▶/⏸; a click anywhere on it opens the Panel. A brief highlight on press is
what every menu bar item that opens something shows, so the cover was hiding ordinary system feedback
at a high cost: about 650 lines of window placement, system-wide pointer and modifier-key monitors,
reading the window list while the pointer was over the Pill, checks to keep it off the « overflow
chevron, neighbouring items and the band beside the camera housing, and a press rule that decided on
mouse-up whether to open the Panel and handled ⌘ itself. It still missed a second display's copy of
the Pill, could come up late, and could eat a click meant for something else. So the cover is removed,
and the status item handles a press as any menu bar item does: its button action opens the Panel.

The Panel's anchor stays. The menu bar draws its highlight for as long as a popover hangs from a view
in the status item's own window, so the Panel still hangs from an invisible, click-through window over
the Pill, and there is no highlight while it's open.

Two checks in the development copy, with synthetic clicks on macOS 27, settled what else is needed:

1. **With the Panel open, a click on the Pill doesn't reopen it.** The app gets the press's mouse-down
   and the button's action together on release, even for a press held a second. The mouse-down closes
   the transient Panel, and the action arrives while it is still closing, so `showPanel` treats it as
   a request to open an open Panel and leaves it closed.
2. **A ⌘-drag sends no action.** The menu bar moves the Pill and the app sees neither a mouse-down nor
   a button action; nor for a ⌘-press without moving.

So no press rule is kept: the press rule, its suite and the app's mouse-down monitor are deleted.

## Consequences

- A press on the Pill shows the menu bar's brief highlight, which goes on release, the same on every
  display.
- Chronobar no longer watches the pointer or modifier keys outside its own windows, and never takes a
  click meant for another item or app.
- A click with the Panel open stays closed only because its action arrives while the Panel is still
  closing. If a later macOS sends the action after the Panel has closed, the Pill would reopen it; the
  manual checklist covers this.
- There is no automated test for the Pill's press: the behaviour is the status item's own. The manual
  checklist is the check.
- Don't bring the cover back to hide the highlight without reopening this decision.
