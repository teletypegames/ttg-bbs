package engine

// T is the i18n dictionary type
type T map[string]string

// En is the default English dictionary
var En = T{
	"AskName":          "Enter your name:",
	"Greeting":         "Hello, %s%s%s! Welcome to Teletype BBS!",
	"Goodbye":          "Goodbye, %s! 👋",
	"Pause":            "Press ENTER...",
	"Choice":           "Choice: ",
	"MsgBoardTitle":    "📋  MESSAGE BOARD",
	"MsgNoMessages":    "(No messages yet — be the first!)",
	"MsgNew":           "Write new message",
	"MsgBack":          "Back",
	"MsgEnterText":     "Message text:",
	"MsgSent":          "✓ Sent!",
	"MsgEmpty":         "(Empty – not sent)",
	"WikiLoading":      "Loading...",
	"WikiConnError":    "Connection error",
	"WikiNoResults":    "No results for tag '%s'.",
	"WikiEnterNum":     "Enter number to open, ENTER to go back:",
	"WikiFetchContent": "Fetching content...",
	"CatTitle":         "🎮  GAME CATALOG",
	"CatNoGames":       "No games available.",
	"CatLatest":        "Latest",
	"CatVersions":      "%d versions available",
	"CatFull":          "Full catalog",
	"OnlineTitle":      "👥  ONLINE USERS",
	"OnlineYou":        "← you",
	"OnlineTotal":      "Total: %s%d%s users online",
	"SysInfoTitle":     "ℹ  SYSTEM INFO",
	"SysServerTime":    "Server time",
	"SysOnlineUsers":   "Online users",
	"SysMsgCount":      "Message count",
	"SysWikiURL":       "Wiki URL",
	"SysGamesAPI":      "Games API",
	"SysPlatform":      "Platform",
}
