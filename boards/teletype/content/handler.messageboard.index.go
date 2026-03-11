package content

import (
	"bbs-server/engine"
	"fmt"
)

// MessageBoardIndexHandler displays the message board posts
type MessageBoardIndexHandler struct {
	board *MessageBoard
}

func NewMessageBoardIndexHandler(board *MessageBoard) *MessageBoardIndexHandler {
	return &MessageBoardIndexHandler{board: board}
}

func (h *MessageBoardIndexHandler) Handle(s *engine.Session) {
	s.Printer.BoxHeader(s.Lang["MsgBoardTitle"], engine.GR)

	h.board.mu.Lock()
	snap := make([]message, len(h.board.messages))
	copy(snap, h.board.messages)
	h.board.mu.Unlock()

	if len(snap) == 0 {
		s.Printer.Send(fmt.Sprintf("  %s%s%s\r\n", engine.GY, s.Lang["MsgNoMessages"], engine.R))
	} else {
		start := 0
		if len(snap) > 30 {
			start = len(snap) - 30
		}
		for i, msg := range snap[start:] {
			s.Printer.Send(fmt.Sprintf("  %s%02d%s %s%s%s  %s%s:%s %s\r\n",
				engine.GR, i+1, engine.R,
				engine.GY, msg.Timestamp, engine.R,
				engine.WH, msg.User, engine.R, msg.Text))
		}
	}
	s.Printer.Pause(s.Lang)
}
