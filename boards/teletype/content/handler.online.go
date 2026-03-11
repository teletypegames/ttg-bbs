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
	s.Printer.BoxHeader(s.Lang["OnlineTitle"], engine.COLOR_YELLOW)

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
			marker = fmt.Sprintf("  %s%s%s", engine.COLOR_GREEN, s.Lang["OnlineYou"], engine.COLOR_RESET)
		}
		s.Printer.Send(fmt.Sprintf("  %s•%s  %s%s%s%s\r\n", engine.COLOR_YELLOW, engine.COLOR_RESET, engine.COLOR_WHITE, user, engine.COLOR_RESET, marker))
	}

	s.Printer.Send(fmt.Sprintf("\r\n  %s%s\r\n", engine.COLOR_GRAY,
		fmt.Sprintf(s.Lang["OnlineTotal"], engine.COLOR_WHITE, len(snap), engine.COLOR_GRAY, engine.COLOR_RESET)))
	s.Printer.Pause(s.Lang)
}
