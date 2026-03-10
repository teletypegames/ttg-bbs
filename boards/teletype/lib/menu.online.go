package lib

import (
	"fmt"
	"sort"
)

func (s *Session) ShowOnline() {
	s.Printer.BoxHeader(s.Lang["OnlineTitle"], CY)
	s.BBS.Mu.Lock()
	snap := make(map[string]string)
	for k, v := range s.BBS.OnlineUsers {
		snap[k] = v
	}
	s.BBS.Mu.Unlock()

	keys := make([]string, 0, len(snap))
	for k := range snap {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	for _, addr := range keys {
		user := snap[addr]
		marker := ""
		if addr == s.Addr {
			marker = fmt.Sprintf("  %s%s%s", GR, s.Lang["OnlineYou"], R)
		}
		s.Printer.Send(fmt.Sprintf("  %s•%s  %s%s%s%s\r\n", CY, R, WH, user, R, marker))
	}
	s.Printer.Send(fmt.Sprintf("\r\n  %s%s\r\n", GY, fmt.Sprintf(s.Lang["OnlineTotal"], WH, len(snap), GY, R)))
	s.Printer.Pause(s.Lang)
}
