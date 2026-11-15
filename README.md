# Baggy

All your bags in one window, plus your bank and every character's items, in the spirit of Bagnon. For the 1.12 client (OctoWoW).

## Install
Put the `Baggy` folder in `Interface\AddOns\`. Turn off any other bag addon (Bagnon, OneBag, etc.) so you don't get two windows.

## Use
- Press **B** or click your bags as usual; Baggy opens instead of the Blizzard bags
- At a banker, the bank opens in its own Baggy window next to your bags
- `/baggy` opens the options window (or click the gear on either window)
- Drag a window by its title or background. Tick "Lock window positions" when you're happy with it

## Features
- **One window for all bags**, one for the bank. The number at the bottom left is used/total slots
- **Bag bar** (bag icon), at the top or bottom of the window: click a bag to hide or show its slots, hover it to highlight its items, drag bags in and out. At a banker, click the red slot to buy the next bank bag slot
- **Search box**: dims everything that doesn't match by name, type or subtype (`cloth`, `potion`, `armor`, `recipe`...)
- **Other characters**: click a window's title to see any character's bags or bank on this realm. Each character is saved when you log in on it, and its bank is saved when you visit a banker. You can open your bank anywhere with the chest button on the bags window
- **Item counts in tooltips**: every item tooltip shows how many each character has, split into bags, bank and equipped, with a total
- **Money**: hover the gold at the bottom right to see every character's money and the realm total (can be turned off)
- **Sort** (bag button): stacks partial stacks and sorts your normal bags (Hearthstone first, then gear, consumables, trade goods... junk last). Special bags (soul, herb, ammo) are left alone. Sort the bank while at a banker
- Quality borders, yellow borders on quest items, tinted empty slots in soul / herb / ammo bags
- Keyring can be shown inside the bags window (your keyring button toggles it). Its slots sit on their own row with a gold frame and a faded key in empty slots
- **Slot style**: Blizzard, Flat, or Flat without borders, with your own color for flat slots and for the keyring frame
- Opens itself at vendors, the mailbox, the auction house and when trading, and closes again afterwards if it opened itself. Each can be turned off

## Commands
`/baggy` options · `/baggy bags` · `/baggy bank` · `/baggy sort` · `/baggy sortbank` · `/baggy keyring` · `/baggy lock` · `/baggy unlock` · `/baggy resetpos` · `/baggy forget <name>` · `/baggy reset`
