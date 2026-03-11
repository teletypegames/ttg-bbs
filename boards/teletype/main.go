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
		m.Item("1", "Message Board", engine.GR, messageBoardIndexHandler.Handle)
		m.Item("N", "New Message", engine.WH, messageBoardNewHandler.Handle)
		m.Item("2", "Blog Posts", engine.BL, blogHandler.Handle)
		m.Item("3", "HowTo Guides", engine.MG, howtoHandler.Handle)
		m.Item("4", "Game Catalog", engine.YL, catalogHandler.Handle)
		m.Item("5", "Online Users", engine.CY, onlineHandler.Handle)
		m.Item("6", "System Info", engine.GY, sysinfoHandler.Handle)
		m.Item("Q", "Exit", engine.RD, engine.Exit)
	})

	bbs.Start()
}
