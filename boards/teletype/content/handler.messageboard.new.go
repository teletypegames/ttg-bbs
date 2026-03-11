package content

import (
	"bbs-server/engine"
	"fmt"
	"strings"
	"time"
)

// MessageBoardNewHandler handles posting new messages to the board
type MessageBoardNewHandler struct {
	board *MessageBoard
}

func NewMessageBoardNewHandler(board *MessageBoard) *MessageBoardNewHandler {
	return &MessageBoardNewHandler{board: board}
}

func (h *MessageBoardNewHandler) Handle(s *engine.Session) {
	s.Printer.Send(fmt.Sprintf("\r\n%s%s%s ", engine.WH, s.Lang["MsgEnterText"], engine.R))
	msgText, _ := s.Printer.ReadLine()
	msgText = strings.TrimSpace(msgText)
	if msgText != "" {
		if len(msgText) > 200 {
			msgText = msgText[:200]
		}
		ts := time.Now().Format("01-02 15:04")
		msg := message{Timestamp: ts, User: s.Username, Text: msgText}
		h.board.mu.Lock()
		h.board.messages = append(h.board.messages, msg)
		h.board.mu.Unlock()
		h.board.append(msg)
		s.Printer.Send(fmt.Sprintf("\r\n%s%s%s\r\n", engine.GR, s.Lang["MsgSent"], engine.R))
	} else {
		s.Printer.Send(fmt.Sprintf("\r\n%s%s%s\r\n", engine.GY, s.Lang["MsgEmpty"], engine.R))
	}
	s.Printer.Pause(s.Lang)
}
