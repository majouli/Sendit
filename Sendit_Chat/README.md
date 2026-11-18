# Sendit Chat

A calm, reliable chat for WoW Forever: movable windows with detachable tabs,
and whispers in one messenger window.

## Chat windows

- Drag the header to move a window, drag the bottom-right corner to resize it.
- The lock icon locks every window in place (no moving, no resizing).
- The minimize icon collapses a window onto its header.
- Drag a tab out of its window (or right-click it, "Detach") to give it a window
  of its own. Drop it on another window, or use "Back to the main window", to dock it.
- The gear opens the Chat page of the Sendit window: font size, background, border,
  lock, chat, whisper and loot options.
- Mouse wheel scrolls, Shift + wheel scrolls a page, Ctrl + wheel jumps to the top/bottom.
- Press Enter to type: the normal chat input sits right under the main window.
- Web addresses become links: click one to copy it.
- Your chat survives /reload and logging out: the last lines of every tab come
  back, under a line "earlier session".
- Channel names are short: "[1. General - Elwynn Forest]" becomes "[1. General]".
- When someone writes your name, it shows in gold, the tab gets a dot and a
  soft sound plays.
- Right-click a tab, "Copy text": its lines in a box for Ctrl+A / Ctrl+C; the chat header and the messenger have the same as a button.
- The look follows Sendit's Design page: the palette (Dusk, Light, Wood) and the
  frame style - Modern, or Azeroth with the game's gold-edged borders, a header
  banner and a seal on the messages window.
- The messages window fades in gliding up and fades out sinking a little
  (can be switched off: Design page, Animations).
- Own tabs: "+" beside the tabs (or Settings > Chat > "Own tabs") picks a name
  and the channels / message kinds it takes out of General; right-click it to
  change or delete it.
- The combat log is a tab too. Its strip switches Blizzard's quick filters
  ("My actions", "What happened to me?"); the gear opens Blizzard's combat log
  menu with the full settings (Blizzard's own window - only it may change them).

## Messages

- One window, like WhatsApp on the desktop: your conversations on the left
  (newest first, unread counter), the chosen one on the right as bubbles.
  The speech bubble icon in the main chat opens it. Type a name at the top
  left to start a new conversation: suggestions come from your conversations,
  friends, Battle.net friends, guild and group (Up / Down to pick, Tab
  completes, Enter opens).
- Typing `/w name` in the normal chat input opens that conversation in the
  messenger (can be switched off: "/w opens Messages").
- A new whisper shows as a small bubble right above the main chat, like a
  message notification on a phone: who, the latest message, how many are
  unread. Click it to open the conversation, right-click to dismiss it; it
  fades by itself after a few seconds. (Settings, "New whisper": bubble,
  open Messages directly, or only the counter.)
- With the window open in another conversation it stays there; the new one
  lights up in the list. Shift-click an item, spell or quest while typing
  to link it.
- Unread messages make the window breathe. A conversation counts as read
  once you click into it or close the window; minimizing keeps it unread.
  The speech bubble in the main chat shows how many conversations are unread.
- The header tells who you talk to: a character with its realm, or a
  Battle.net friend (cyan, BattleTag, and the character they play). Right-click
  the header for the usual player menu (invite, add friend, ignore, who, report).
- Click a player name in the chat to whisper them. "Whisper" in the friends
  list (Battle.net friends too) or in a player's menu opens the window on
  them as well (in boss fights the game's own input takes it instead).
- Drag the window by either header; its lock icon pins it (separate from the
  chat's lock).
- Middle-click a conversation (or right-click, "Archive") to archive it. The
  "Archive" tab above the list keeps archived chats for 30 days, then they are
  deleted for good; each row tells how long it has left. There, middle-click
  restores a chat, right-click restores it or deletes it for good. A new
  message from that person brings the chat back by itself.
- Conversations are saved per character (the last 200 messages each).
- The friends list sits right beside the messages window (the people icon in its
  header, or the one in the main chat, opens it): Battle.net and character friends,
  online first with zone and level, offline folded away. Click a friend to whisper,
  right-click for the player menu. Settings: "Friends beside Messages".

## Loot

- Your own loot replaces the standard line: the count in green (+1, +5),
  the item's icon, the link and what it is (slot/type like "Head · Plate",
  otherwise its category like "Cloth").
  Money shows as coins. Other players' loot stays as the game writes it.
- Rare or better (adjustable) also glides in as a card above the chat: big
  icon in a glowing quality frame; epic and better breathe. Hover for the
  tooltip, Shift-click to link it, Ctrl-click to try it on, right-click to dismiss.
- Loot rolls are summed up into one line per item, its result: choices,
  rolls and the "X receives loot" line right after it give way. The line
  names everyone who took part, highest roll first ("Bob 92 Need · You 45
  Need · Ann Greed"), the winner in white. Won: gold, plus a gold card.
  Lost: red, plus a grey card. Items you passed on: one quiet line.
  Your won item does not get a second line or card when it lands in your bags.
- All of it can be switched off in the settings ("Sum up loot rolls" shows
  every roll line again).

## Boss fights and instances

There the game locks chat for addons: message texts become unreadable to
addons, and messages sent by addons are refused. Sendit Chat still shows every
line, because it displays what the game's own chat receives, and the main
input is the game's own, so typing there works as always. What does not
work there: whispers do not go into the conversation list (they stay in the
main chat), and the small chat windows cannot send. They tell you so; reply
with R in the main chat.

## Commands

- `/chat` opens the conversation list.
- `/chat reset` puts all windows back to their default places.
- `/chat off` / `/chat on` turns Sendit Chat off or on (after `/reload`).

## Notes

- Sendit Chat replaces EllesmereUI Chat; disable EllesmereUI Chat to use it.
- With Fade: pressing Enter shows the chat while you type ("Typing" trigger);
  party, raid and loot messages show it for a moment ("Group chat" and "Loot" triggers).
