# Uncurse

Uncurse is a lightweight click-to-cure micro-frame addon for World of Warcraft
3.3.5a. It is designed for private/custom servers where cleansing spells may not
use standard spell IDs or names.

## Installation

Copy the `Uncurse` directory into:

`World of Warcraft\Interface\AddOns\`

The final path should contain `Uncurse\Uncurse.toc`. Restart the client or type
`/reload`.

## Setup

1. Open **Game Menu → Interface → AddOns → Uncurse**, click the minimap icon,
   or type `/uncurse`.
2. Enter cleansing spells exactly as their names appear in your spellbook.
3. Click **Detect** to infer cure types from each spell tooltip.
4. Verify the Magic, Curse, Disease, Poison, and Other boxes manually.
5. Unlock the frames and drag the blue `Uncurse` handle into position.
6. Lock the frames when finished.

Frames use the color of the curable debuff. Their tooltip says which mouse
binding and spell will be used. Bindings and layout changes are securely applied
after combat if WoW's combat lockdown is active.

## Commands

- `/uncurse` or `/uc` — open settings
- `/uncurse lock` — lock the frames
- `/uncurse unlock` — unlock the frames
- `/uncurse reset` — reset the frame position

## Custom-server notes

WoW reports normal aura categories through `UnitDebuff`: Magic, Curse, Disease,
or Poison. Tooltip detection is best-effort because custom servers may use
unusual or localized wording. The manual type boxes are authoritative.

The **Other** type is reserved for custom debuffs mapped by exact name on the
**Colors & Custom Debuffs** settings page.
