package content

import (
	"bbs-server/engine"
	"fmt"
	"strconv"
	"time"
)

// Sysinfo returns a HandlerFunc that displays system information
func Sysinfo(board *MessageBoard) engine.HandlerFunc {
	return func(s *engine.Session) {
		s.Printer.BoxHeader(s.Lang["SysInfoTitle"], engine.GY)

		now := time.Now().Format("2006-01-02 15:04:05")

		rows := [][]string{
			{s.Lang["SysServerTime"], now},
			{s.Lang["SysOnlineUsers"], strconv.Itoa(s.State.UserCount())},
			{s.Lang["SysMsgCount"], strconv.Itoa(board.Count())},
			{s.Lang["SysWikiURL"], WikiJSBaseURL},
			{s.Lang["SysGamesAPI"], GamesAPIURL},
			{s.Lang["SysPlatform"], "Go BBS v2.0"},
		}

		for _, row := range rows {
			s.Printer.Send(fmt.Sprintf("  %s%-18s%s  %s%s%s\r\n",
				engine.GY, row[0], engine.R, engine.WH, row[1], engine.R))
		}
		s.Printer.Pause(s.Lang)
	}
}
