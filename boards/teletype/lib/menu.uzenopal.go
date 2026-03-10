package lib

import (
	"fmt"
	"strings"
	"time"
)

func (s *Session) ShowUzenopal() {
	s.Printer.BoxHeader(s.Lang["MsgBoardTitle"], GR)
	s.BBS.Mu.Lock()
	snap := make([]Message, len(s.BBS.Messages))
	copy(snap, s.BBS.Messages)
	s.BBS.Mu.Unlock()

	if len(snap) == 0 {
		s.Printer.Send(fmt.Sprintf("  %s%s%s\r\n", GY, s.Lang["MsgNoMessages"], R))
	} else {
		start := 0
		if len(snap) > 30 {
			start = len(snap) - 30
		}
		for i, msg := range snap[start:] {
			s.Printer.Send(fmt.Sprintf("  %s%02d%s %s%s%s  %s%s:%s %s\r\n", GR, i+1, R, GY, msg.Timestamp, R, WH, msg.User, R, msg.Text))
		}
	}

	s.Printer.Send(fmt.Sprintf("\r\n%s[N]%s %s  %s[ENTER]%s %s → ", GY, R, s.Lang["MsgNew"], GY, R, s.Lang["MsgBack"]))
	choice, _ := s.Printer.ReadLine()
	if strings.ToUpper(strings.TrimSpace(choice)) == "N" {
		s.Printer.Send(fmt.Sprintf("\r\n%s%s%s ", WH, s.Lang["MsgEnterText"], R))
		msgText, _ := s.Printer.ReadLine()
		msgText = strings.TrimSpace(msgText)
		if msgText != "" {
			if len(msgText) > 200 {
				msgText = msgText[:200]
			}
			ts := time.Now().Format("01-02 15:04")
			s.BBS.Mu.Lock()
			s.BBS.Messages = append(s.BBS.Messages, Message{User: s.Username, Timestamp: ts, Text: msgText})
			s.BBS.Mu.Unlock()
			s.Printer.Send(fmt.Sprintf("\r\n%s%s%s\r\n", GR, s.Lang["MsgSent"], R))
		} else {
			s.Printer.Send(fmt.Sprintf("\r\n%s%s%s\r\n", GY, s.Lang["MsgEmpty"], R))
		}
	}
}
