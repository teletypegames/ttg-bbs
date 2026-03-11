package content

import (
	"bbs-server/engine"
	"fmt"
	"sort"
)

// OnlineHandler displays currently logged-in users
type OnlineHandler struct{}

func NewOnlineHandler() *OnlineHandler {
	return &OnlineHandler{}
}

func (h *OnlineHandler) Handle(s *engine.Session) {
	s.Printer.BoxHeader(s.Lang["OnlineTitle"], engine.CY)

	snap := s.State.Snapshot()
	keys := make([]string, 0, len(snap))
	for k := range snap {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	for _, addr := range keys {
		user := snap[addr]
		marker := ""
		if addr == s.Addr {
			marker = fmt.Sprintf("  %s%s%s", engine.GR, s.Lang["OnlineYou"], engine.R)
		}
		s.Printer.Send(fmt.Sprintf("  %s•%s  %s%s%s%s\r\n", engine.CY, engine.R, engine.WH, user, engine.R, marker))
	}

	s.Printer.Send(fmt.Sprintf("\r\n  %s%s\r\n", engine.GY,
		fmt.Sprintf(s.Lang["OnlineTotal"], engine.WH, len(snap), engine.GY, engine.R)))
	s.Printer.Pause(s.Lang)
}
