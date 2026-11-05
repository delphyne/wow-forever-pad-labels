# WoW Controller Labels

A tiny addon for **World of Warcraft: Forever** that changes which button glyphs the game draws on controller prompts: Xbox letters, PlayStation shapes, Switch letters, or generic numbers.

It never changes a bind. If you use a Switch-style controller (Pro Controller, 8BitDo in Switch mode, etc.) the game labels prompts B/A/Y/X. This addon lets you see A/B/X/Y or the PlayStation shapes instead while every button keeps doing exactly what it did before.

## Install

Copy or symlink this folder into the Forever AddOns directory:

```
/Applications/World of Warcraft/_forever_/Interface/AddOns/WowControllerLabels
```

On macOS with the game in the default location, `make install` creates the symlink for you. `make uninstall` removes it.

## Use

In chat:

```
/padlabels xbox          Xbox glyphs  (A B X Y)
/padlabels playstation   PlayStation glyphs (cross circle square triangle)
/padlabels switch        Switch glyphs (B A Y X)
/padlabels generic       numbered buttons
/padlabels auto          back to whatever the game picks for your controller
/padlabels               show the current setting
```

There is also a dropdown under Options > AddOns > Controller Labels. The choice is saved account-wide. After changing it, press any controller button and the prompts redraw.

## How it works

Every controller has a gamepad config inside the engine (the same data you can see in `WTF/GamePadConfig_Default.json`). One field of that config, `labelStyle`, is what Blizzard's UI reads to pick glyph art: `Letters`, `Shapes`, `Reverse`, or `Generic`.

The addon copies the connected controller's existing config, changes only `labelStyle`, and hands it back through the public `C_GamePad.SetConfig` and `C_GamePad.ApplyConfigs` API. Button and axis mappings are copied verbatim, so the controller behaves exactly as before. The engine stores the result in `WTF/GamePadConfig_AddOns.json`.

The addon never hooks or calls Blizzard UI code. An earlier version replaced a Blizzard lookup function instead, which tainted the secure gamepad UI and produced the "blocked from an action only available to the Blizzard UI" popup.

The UI re-reads the style when you switch between keyboard and controller, so after changing the setting press any controller button and the prompts redraw.

`/padlabels auto` puts back the style the game chose on its own. The addon remembers that original style per controller the first time it sees one.
