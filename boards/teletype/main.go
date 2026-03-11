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

                ░░  BBS  v2.0  ░░  teletype.hu  ░░
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

	wiki  := content.NewWikiHandler(wikiToken)
	cat   := content.NewCatalogHandler()
	board := content.NewMessageBoard(boardPath)

	bbs := engine.New(engine.Config{
		Host:   "0.0.0.0",
		Port:   "2323",
		Banner: banner,
		Lang:   engine.En,
	})

	bbs.Menu(func(m *engine.Menu) {
		m.Title("MAIN MENU")
		m.Item("1", "Message Board", engine.GR, board.Show)
		m.Item("2", "Blog Posts",    engine.BL, wiki.List("blog",  "Blog Posts",   engine.BL))
		m.Item("3", "HowTo Guides",  engine.MG, wiki.List("howto", "HowTo Guides", engine.MG))
		m.Item("4", "Game Catalog",  engine.YL, cat.Show)
		m.Item("5", "Online Users",  engine.CY, content.Online)
		m.Item("6", "System Info",   engine.GY, content.Sysinfo(board))
		m.Item("Q", "Exit",          engine.RD, engine.Exit)
	})

	bbs.Start()
}
