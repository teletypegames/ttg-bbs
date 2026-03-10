package lib

import (
	"fmt"
	"strings"
	"sync"
)

const Banner = `
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

type BBS struct {
	Messages    []Message
	OnlineUsers map[string]string // addr -> username
	Mu          sync.Mutex
	WikiToken   string
	WikiRepo    *WikiRepository
	CatalogRepo *CatalogRepository
}

func NewBBS(wikiToken string) *BBS {
	return &BBS{
		Messages:    []Message{},
		OnlineUsers: make(map[string]string),
		WikiToken:   wikiToken,
		WikiRepo:    NewWikiRepository(wikiToken),
		CatalogRepo: NewCatalogRepository(),
	}
}

type UI struct {
	Printer *Printer
	Lang    T
}

func NewUI(printer *Printer, lang T) *UI {
	return &UI{Printer: printer, Lang: lang}
}

type Session struct {
	BBS      *BBS
	Printer  *Printer
	Username string
	Addr     string
	Lang     T
}

func NewSession(bbs *BBS, printer *Printer, username string, addr string, lang T) *Session {
	return &Session{
		BBS:      bbs,
		Printer:  printer,
		Username: username,
		Addr:     addr,
		Lang:     lang,
	}
}

func (ui *UI) MainMenu(username string) string {
	headerLine := strings.Repeat("═", W)

	l1 := ui.Printer.PadLine(fmt.Sprintf("  %s%s%s  %s@%s%s", YL, ui.Lang["MainMenuTitle"], R, GY, username, R), W)
	l2 := ui.Printer.PadLine(fmt.Sprintf("  %s[1]%s %s", GR, R, ui.Lang["MenuUzenopal"]), W/2) + ui.Printer.PadLine(fmt.Sprintf("  %s[2]%s %s", BL, R, ui.Lang["MenuBlog"]), W/2)
	l3 := ui.Printer.PadLine(fmt.Sprintf("  %s[3]%s %s", MG, R, ui.Lang["MenuHowto"]), W/2) + ui.Printer.PadLine(fmt.Sprintf("  %s[4]%s %s", YL, R, ui.Lang["MenuCatalog"]), W/2)
	l4 := ui.Printer.PadLine(fmt.Sprintf("  %s[5]%s %s", CY, R, ui.Lang["MenuOnline"]), W/2) + ui.Printer.PadLine(fmt.Sprintf("  %s[6]%s %s", GY, R, ui.Lang["MenuSysinfo"]), W/2)
	l5 := ui.Printer.PadLine(fmt.Sprintf("  %s[Q]%s %s", RD, R, ui.Lang["MenuExit"]), W)

	return fmt.Sprintf(
		"\n%s╔%s╗%s\n"+
			"%s║%s%s║%s\n"+
			"%s╠%s╣%s\n"+
			"%s║%s%s║%s\n"+
			"%s║%s%s║%s\n"+
			"%s║%s%s║%s\n"+
			"%s║%s%s║%s\n"+
			"%s╚%s╝%s\n%s",
		WH, headerLine, R,
		WH, l1, WH, R,
		WH, headerLine, R,
		WH, l2, WH, R,
		WH, l3, WH, R,
		WH, l4, WH, R,
		WH, l5, WH, R,
		WH, headerLine, R,
		ui.Lang["Choice"],
	)
}
