package engine

import (
	"fmt"
	"net"
	"os"
	"strings"
)

// Config holds the BBS server configuration
type Config struct {
	Host   string
	Port   string
	Banner string
	Lang   T
}

// BBS is the main server struct
type BBS struct {
	config Config
	state  *State
	menu   *Menu
}

// New creates a new BBS server with the given configuration
func New(cfg Config) *BBS {
	return &BBS{
		config: cfg,
		state:  newState(),
		menu:   &Menu{},
	}
}

// State returns the shared server state (for use by content handlers)
func (b *BBS) State() *State {
	return b.state
}

// Menu configures the main menu using the DSL
func (b *BBS) Menu(fn func(*Menu)) {
	fn(b.menu)
}

// Start launches the TCP server and blocks waiting for connections
func (b *BBS) Start() {
	ln, err := net.Listen("tcp", b.config.Host+":"+b.config.Port)
	if err != nil {
		fmt.Printf("Server start error: %v\n", err)
		os.Exit(1)
	}
	defer ln.Close()

	fmt.Printf("BBS running → telnet localhost %s\n", b.config.Port)
	fmt.Println("Stop: Ctrl+C")

	for {
		conn, err := ln.Accept()
		if err != nil {
			fmt.Printf("Accept error: %v\n", err)
			continue
		}
		fmt.Printf("[+] Connected: %s\n", conn.RemoteAddr().String())
		go b.handleClient(conn)
	}
}

func (b *BBS) handleClient(conn net.Conn) {
	defer conn.Close()
	addr := conn.RemoteAddr().String()
	lang := b.config.Lang
	printer := NewPrinter(conn)

	// Telnet negotiation (IAC WILL ECHO, IAC WILL SGA, IAC WONT LINEMODE)
	printer.Send("\xff\xfb\x01\xff\xfb\x03\xff\xfe\x22")

	printer.Send(COLOR_CYAN + b.config.Banner + COLOR_RESET)
	printer.Send(fmt.Sprintf("\n%s%s%s ", COLOR_WHITE, lang["AskName"], COLOR_RESET))

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

	b.state.Mu.Lock()
	b.state.OnlineUsers[addr] = username
	b.state.Mu.Unlock()

	defer func() {
		b.state.Mu.Lock()
		delete(b.state.OnlineUsers, addr)
		b.state.Mu.Unlock()
	}()

	printer.Send(fmt.Sprintf("\r\n%s%s%s\r\n", COLOR_GREEN, fmt.Sprintf(lang["Greeting"], COLOR_WHITE, username, COLOR_GREEN), COLOR_RESET))

	session := &Session{
		State:    b.state,
		Printer:  printer,
		Username: username,
		Addr:     addr,
		Lang:     lang,
	}

	for !session.Quit {
		printer.Send(b.menu.Render(printer, lang, username))
		choice, err := printer.ReadLine()
		if err != nil {
			break
		}
		b.menu.Dispatch(session, choice)
	}

	if session.Quit {
		printer.Send(fmt.Sprintf("\r\n%s%s%s\r\n\r\n", COLOR_RED, fmt.Sprintf(lang["Goodbye"], username), COLOR_RESET))
	}
}
