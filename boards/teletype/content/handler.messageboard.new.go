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
	s.Printer.Send(fmt.Sprintf("\r\n%s%s%s ", engine.COLOR_WHITE, s.Lang["MsgEnterText"], engine.COLOR_RESET))
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
		s.Printer.Send(fmt.Sprintf("\r\n%s%s%s\r\n", engine.COLOR_GREEN, s.Lang["MsgSent"], engine.COLOR_RESET))
	} else {
		s.Printer.Send(fmt.Sprintf("\r\n%s%s%s\r\n", engine.COLOR_GRAY, s.Lang["MsgEmpty"], engine.COLOR_RESET))
	}
	s.Printer.Pause(s.Lang)
}
