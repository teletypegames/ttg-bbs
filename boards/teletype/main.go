package main

import (
	"bbs-server/lib"
	"fmt"
	"net"
	"os"
	"strings"
)

const (
	Host = "0.0.0.0"
	Port = "2323"
)

var bbs *lib.BBS

func main() {
	wikiToken := os.Getenv("WEBAPP_WIKIJS_TOKEN")
	bbs = lib.NewBBS(wikiToken)

	ln, err := net.Listen("tcp", Host+":"+Port)
	if err != nil {
		fmt.Printf("Hiba a szerver indításakor: %v\n", err)
		os.Exit(1)
	}
	defer ln.Close()

	fmt.Printf("Teletype BBS running → telnet localhost %s\n", Port)
	fmt.Printf("Wiki: %s\n", lib.WikiJSBaseURL)
	fmt.Printf("Games API: %s\n", lib.GamesAPIURL)
	tokenStatus := "✗ not set"
	if wikiToken != "" {
		tokenStatus = "✓ set"
	}
	fmt.Printf("Token: %s\n", tokenStatus)
	fmt.Println("Stop: Ctrl+C")

	for {
		conn, err := ln.Accept()
		if err != nil {
			fmt.Printf("Error accepting connection: %v\n", err)
			continue
		}
		fmt.Printf("[+] Connected: %s\n", conn.RemoteAddr().String())
		go handleClient(conn)
	}
}

func handleClient(conn net.Conn) {
	defer conn.Close()
	addr := conn.RemoteAddr().String()

	printer := lib.NewPrinter(conn)
	lang := lib.En
	ui := lib.NewUI(printer, lang)

	// Telnet negotiation
	printer.Send("\xff\xfb\x01\xff\xfb\x03\xff\xfe\x22")

	printer.Send(lib.CY + lib.Banner + lib.R)
	printer.Send(fmt.Sprintf("\n%s%s%s ", lib.WH, lang["AskName"], lib.R))

	username, err := printer.ReadLine()
	if err != nil {
		return
	}
	username = strings.TrimSpace(username)
	if username == "" {
		username = "Anonymous"
	}
	if len(username) > 20 {
		username = username[:20]
	}

	bbs.Mu.Lock()
	bbs.OnlineUsers[addr] = username
	bbs.Mu.Unlock()

	defer func() {
		bbs.Mu.Lock()
		delete(bbs.OnlineUsers, addr)
		bbs.Mu.Unlock()
	}()

	printer.Send(fmt.Sprintf("\r\n%s%s%s\r\n", lib.GR, fmt.Sprintf(lang["Greeting"], lib.WH, username, lib.GR), lib.R))

	session := lib.NewSession(bbs, printer, username, addr, lang)

	for {
		printer.Send(ui.MainMenu(username))
		choice, err := printer.ReadLine()
		if err != nil {
			break
		}
		c := strings.ToUpper(strings.TrimSpace(choice))

		switch c {
		case "1":
			session.ShowUzenopal()
		case "2":
			session.ShowWikiList("blog", lib.BL, lang["MenuBlog"])
		case "3":
			session.ShowWikiList("howto", lib.MG, lang["MenuHowto"])
		case "4":
			session.ShowGames()
		case "5":
			session.ShowOnline()
		case "6":
			session.ShowSysinfo()
		case "Q":
			printer.Send(fmt.Sprintf("\r\n%s%s%s\r\n\r\n", lib.RD, fmt.Sprintf(lang["Goodbye"], username), lib.R))
			return
		}
	}
}
