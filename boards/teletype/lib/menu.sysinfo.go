package lib

import (
	"fmt"
	"strconv"
	"time"
)

func (s *Session) ShowSysinfo() {
	s.Printer.BoxHeader(s.Lang["SysInfoTitle"], GY)
	s.BBS.Mu.Lock()
	uc := len(s.BBS.OnlineUsers)
	mc := len(s.BBS.Messages)
	s.BBS.Mu.Unlock()

	now := time.Now().Format("2006-01-02 15:04:05")
	
	rows := [][]string{
		{s.Lang["SysServerTime"], now},
		{s.Lang["SysOnlineUsers"], strconv.Itoa(uc)},
		{s.Lang["SysMsgCount"], strconv.Itoa(mc)},
		{s.Lang["SysWikiURL"], WikiJSBaseURL},
		{s.Lang["SysGamesAPI"], GamesAPIURL},
		{s.Lang["SysPlatform"], "Go BBS v2.0"},
	}

	for _, row := range rows {
		s.Printer.Send(fmt.Sprintf("  %s%-18s%s  %s%s%s\r\n", GY, row[0], R, WH, row[1], R))
	}
	s.Printer.Pause(s.Lang)
}
