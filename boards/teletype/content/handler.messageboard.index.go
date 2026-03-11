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
	s.Printer.BoxHeader(s.Lang["MsgBoardTitle"], engine.COLOR_GRAY)

	h.board.mu.Lock()
	snap := make([]message, len(h.board.messages))
	copy(snap, h.board.messages)
	h.board.mu.Unlock()

	if len(snap) == 0 {
		s.Printer.Send(fmt.Sprintf("  %s%s%s\r\n", engine.COLOR_GRAY, s.Lang["MsgNoMessages"], engine.COLOR_RESET))
	} else {
		start := 0
		if len(snap) > 30 {
			start = len(snap) - 30
		}
		for i, msg := range snap[start:] {
			s.Printer.Send(fmt.Sprintf("  %s%02d%s %s%s%s  %s%s:%s %s\r\n",
				engine.COLOR_GRAY, i+1, engine.COLOR_RESET,
				engine.COLOR_GRAY, msg.Timestamp, engine.COLOR_RESET,
				engine.COLOR_WHITE, msg.User, engine.COLOR_RESET, msg.Text))
		}
	}
	s.Printer.Pause(s.Lang)
}
