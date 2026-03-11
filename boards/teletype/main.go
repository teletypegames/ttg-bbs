package main

import (
	"bbs-server/content"
	"bbs-server/engine"
	"fmt"
	"os"
)

const banner = `
  ████████╗███████╗██╗     ███████╗████████╗██╗   ██╗██████╗ ███████╗
     ██╔══╝██╔════╝██║     ██╔════╝╚══██╔══╝╚██╗ ██╔╝██╔══██╗██╔════╝
     ██║   █████╗  ██║     █████╗     ██║    ╚████╔╝ ██████╔╝█████╗
     ██║   ██╔══╝  ██║     ██╔══╝     ██║     ╚██╔╝  ██╔═══╝ ██╔══╝
     ██║   ███████╗███████╗███████╗   ██║      ██║   ██║     ███████╗
     ╚═╝   ╚══════╝╚══════╝╚══════╝   ╚═╝      ╚═╝   ╚═╝     ╚══════╝

     ██████╗  █████╗ ███╗   ███╗███████╗███████╗
    ██╔════╝ ██╔══██╗████╗ ████║██╔════╝██╔════╝
    ██║  ███╗███████║██╔████╔██║█████╗  ███████╗
    ██║   ██║██╔══██║██║╚██╔╝██║██╔══╝  ╚════██║
    ╚██████╔╝██║  ██║██║ ╚═╝ ██║███████╗███████║
     ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚══════╝

                ░░  BBS  v2.0  ░░  games.teletype.hu  ░░
          Welcome to the Teletype community bulletin board!
`

func main() {
	wikiToken := os.Getenv("WEBAPP_WIKIJS_TOKEN")

	boardPath := os.Getenv("MESSAGES_PATH")
	if boardPath == "" {
		boardPath = "messages.dat"
	}

	tokenStatus := "✗ not set"
	if wikiToken != "" {
		tokenStatus = "✓ set"
	}
	fmt.Printf("Wiki:      %s\n", content.WikiJSBaseURL)
	fmt.Printf("Games API: %s\n", content.GamesAPIURL)
	fmt.Printf("Token:     %s\n", tokenStatus)

	messageBoard := content.NewMessageBoard(boardPath)
	blogHandler := content.NewBlogHandler(wikiToken)
	howtoHandler := content.NewHowToHandler(wikiToken)
	catalogHandler := content.NewCatalogHandler()
	messageBoardIndexHandler := content.NewMessageBoardIndexHandler(messageBoard)
	messageBoardNewHandler := content.NewMessageBoardNewHandler(messageBoard)
	onlineHandler := content.NewOnlineHandler()
	sysinfoHandler := content.NewSysinfoHandler(messageBoard)

	bbs := engine.New(engine.Config{
		Host:   "0.0.0.0",
		Port:   "2323",
		Banner: banner,
		Lang:   engine.En,
	})

	bbs.Menu(func(m *engine.Menu) {
		m.Title("MAIN MENU")
		m.Item("1", "Message Board", engine.COLOR_GREEN, messageBoardIndexHandler.Handle)
		m.Item("N", "New Message", engine.COLOR_WHITE, messageBoardNewHandler.Handle)
		m.Item("2", "Blog Posts", engine.COLOR_BLUE, blogHandler.Handle)
		m.Item("3", "HowTo Guides", engine.COLOR_MAGENTA, howtoHandler.Handle)
		m.Item("4", "Game Catalog", engine.COLOR_YELLOW, catalogHandler.Handle)
		m.Item("5", "Online Users", engine.COLOR_CYAN, onlineHandler.Handle)
		m.Item("6", "System Info", engine.COLOR_GRAY, sysinfoHandler.Handle)
		m.Item("Q", "Exit", engine.COLOR_RED, engine.Exit)
	})

	bbs.Start()
}
