# Bug report: Maul reports "in range" at any distance

**Client:** World of Warcraft (forever), version 1.60.1.71037, EU, Interface 16001
**Date found:** 2026-11-24

## Summary

In Bear Form, Maul is always reported as in range of the current target, even when the target is about 30 yards away. Swipe, which also has a melee range of 0 yards, is reported correctly. The wrong answer comes from every range source the UI can read, including the out-of-range indicator on the action button.

## Spells involved

| Spell | Spell ID (Classic Era rank 1, for reference) | Range | Behaviour |
|---|---|---|---|
| Maul | [6807](https://www.wowhead.com/classic/spell=6807) | 0–0 yd, flag "On next swing" | **Wrong:** in range at any distance |
| Swipe | [779](https://www.wowhead.com/classic/spell=779) | 0–0 yd | Correct |
| Moonfire | [8921](https://www.wowhead.com/classic/spell=8921) | 0–30 yd | Correct (control) |

No public spell database covers World of Warcraft (forever), so these IDs are the Classic Era rank 1 IDs from Wowhead, for reference. The forever client may use other IDs or ranks.

## Steps to reproduce

1. Play a Druid and put Maul and Swipe on the action bar.
2. Shift into Bear Form.
3. Target a hostile NPC about 30 yards away (tested on Windfury Sorceress).
4. Check the range of both action slots, or look at their range indicators.
5. Walk up to the target into melee range.

**Expected:** Maul is out of range until you're in melee range, like Swipe.
**Actual:** Maul is in range from any distance. Swipe correctly becomes in range only in melee.

## Measurements

Logged in game every 0.25 s while walking from about 30 yards to melee, target far away:

| Source | Maul | Swipe | Moonfire (beyond 30 yd) |
|---|---|---|---|
| `C_ActionBar.IsActionInRange(slot, "target")` | true | false | false |
| `ACTION_RANGE_CHECK_UPDATE` (isInRange, checksRange) | true, true | false | false |
| `C_Spell.IsSpellInRange(spellID, "target")` | true | false | false |
| `C_Spell.SpellHasRange(spellID)` | true | true | true |
| `C_Spell.GetSpellInfo(spellID)` min–max range | 0–0 yd | 0–0 yd | 0–30 yd |
| `CheckInteractDistance("target", 3)` (about 10 yd) | false | false | false |

`CheckInteractDistance` confirms the target is beyond 10 yards while Maul says in range. In one of three logs the range event answered Maul correctly; the other two sources were wrong every time. Maul is the only spell on the bars with this problem. Maul is flagged "On next swing", which may be the cause: other on-next-swing abilities (Heroic Strike, Cleave, Raptor Strike) may do the same.

## Impact

- The action button's range indicator is wrong for Maul.
- Addons that read the game's range APIs or range event to judge distance to the target get a wrong answer.
