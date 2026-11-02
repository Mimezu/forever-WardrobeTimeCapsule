# Wardrobe Time Capsule - Forever

A separate Forever edition of the retail addon: a look journal for the journey from level 1 to 60. Uses Forever's native Legacy metal window frame, leather panels, gold headings and compact matching buttons. There are no expansion tabs or mount records.

Open with `/looks` or `/wtc`; the journal opens on your most recent memory with its level range selected. Choose **Save this look** to record equipped items, level, date and location, then add a title and caption. `/looks save` records without opening the album. Browse in level order using the level-range filters and Previous/Next; the memory list scrolls with the mouse wheel or its scroll bar; drag the model to rotate and scroll to zoom. **Fit** resets full-body framing. The enlarged preview uses more of the journal; long captions scroll with the mouse wheel. Hover equipment icons for item tooltips. Remove asks for confirmation: click it a second time within three seconds (1.2.4 replaced the Blizzard popup, which runs gamepad binding code under addon taint, with this in-window confirmation).

**Transmog.** Each memory stores both the real equipped items and the transmog shown on them (appearance, hidden slots, secondary shoulder and weapon illusion), including the transmog outfit you are wearing and its name. Forever's outfit API does not expose every slot, so right after saving, a hidden player model is loaded and its drawn appearances are recorded (about a second). That also captures hidden slots and appearances shown over empty slots. The journal replays the look as it was worn; **Show real gear** (under the model) swaps the model and slot icons to the items underneath, and **Show transmog** switches back. Transmogged slot tooltips show the appearance item plus the real item it was applied to. Memories saved before 1.0.5 only recorded real items; they show real gear and the toggle is greyed out with "No transmog recorded". `/wtc debug` prints the raw transmog readings for each equipped slot.

**Save a look on each level up** is on by default for new characters and new installs, and can be turned off per character. When enabled, it records once per new level after a short equipment-loading delay. Manual saves allow multiple memories at the same level. Each character has a separate album. Your journal starts with looks you save now; past leveling outfits cannot be recovered automatically.

These are saved equipment snapshots replayed on your character model, not image files or screenshots. Facial/body customization uses your current character. Mounts, pets, poses, scenery and temporary visual effects are not stored. Head/cloak visibility is recorded when the client exposes those settings. Client-specific dress-up behavior, including ranged and off-hand display, still needs in-game verification.

## Persistence on this installation

Albums load through native SavedVariables (`WardrobeTimeCapsuleDB`); the former `_SavedVariables.local` junction and save-loader bridge are retired. The first install has no saved file until the first normal logout or reload. The album lives under `WardrobeTimeCapsuleDB.forever` and preserves any other database fields.

## Validation

The journal uses a taller 780×750 layout with nine memories per list page and
a 430×450 character viewport. Hunters with a summoned pet see that live pet
alongside the character; calling, dismissing or changing the pet updates the
preview while the window is open. Pet appearance is not stored in historical
outfits. Other classes keep the centered solo preview. Hunter preview behavior
is covered by mocked tests; pet size and framing still need in-game verification.

**Styles** (top of the journal) switches the journal's composition; the choice is saved:
- **Current**: the Legacy metal-and-leather journal (the Skin lab recolors this one).
- **Character Sheet**: Forever's character window art. Your race's dressing-room scene behind the model, native gear-slot frames, outfit cards for memories, class art behind the list.
- **Adventurer's Tome**: the Forever spellbook spread, with memories on the left page and your look on the right, in ink and Morpheus lettering.
- **Scrapbook**: quest parchment pages. Your look is a sepia photograph of your dressing room, mounted with dark paper album corners.

**Backdrop scenes follow the memory.** Character Sheet and Scrapbook show a race dressing-room scene chosen by where the memory was saved: each race's scene shows its homeland (Orgrimmar and Durotar get the Orc scene, Tirisfal and Silverpine the Forsaken scene, Elwynn the Human scene, and so on). Zones without a homeland scene use their continent's capital for your faction when the continent is known (recorded on saves from 1.2.0); otherwise your own race's scene. Scenes missing from the client fall back to your own.

Styles only change presentation; saved memories are untouched. Art is looked up at runtime and falls back to plain panels if an atlas is missing in a later build.

**Skin lab** offers ten complete journal treatments inspired by native Legacy,
character and dialog windows. Minimal Legacy is the default; paper options
have been removed. Variants coordinate shell materials, metal trim, panel
insets, buttons, headings, selected rows and equipment-slot decorations.
The character backdrop stays neutral leather in every variant.
Use **Set A** and **Set B** to bookmark choices, then **A / B** to alternate.
Click **Skin lab** again to hide the menu. The selected skin survives reloads;
A/B bookmarks last for the session. Saved looks are untouched.

From the client root: `lua Interface/AddOns/WardrobeTimeCapsule/tests/Behavior.lua`. Lua 5.1 syntax and mocked behavioral checks cover capture, item-loading failures, replay clearing, hidden headgear, off-hand routing, character isolation, level boundaries, captions, deletion and level-up deduplication. These checks do not verify the live rendered UI.

In game: open `/looks`, save a look, change equipment and reopen the original entry. Confirm empty slots remain empty and the saved outfit is restored; check rotation and tooltips. Save another entry and filter/page through the album. Reload and verify both memories and captions persist. Enable level-up saving and check the next level produces one entry. Fully restart the client if it has not discovered the new addon.
