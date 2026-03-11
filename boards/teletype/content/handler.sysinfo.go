package content

import (
	"bbs-server/engine"
	"fmt"
	"runtime"
)

// SysinfoHandler displays system information
type SysinfoHandler struct {
	board *MessageBoard
}

func NewSysinfoHandler(board *MessageBoard) *SysinfoHandler {
	return &SysinfoHandler{board: board}
}

func (h *SysinfoHandler) Handle(s *engine.Session) {
	s.Printer.BoxHeader(s.Lang["SysTitle"], engine.COLOR_GRAY)

	s.Printer.Send(fmt.Sprintf("  %s%-15s%s %d\r\n", engine.COLOR_GRAY, s.Lang["SysUsers"], engine.COLOR_RESET, s.State.UserCount()))
	s.Printer.Send(fmt.Sprintf("  %s%-15s%s %d\r\n", engine.COLOR_GRAY, s.Lang["SysMessages"], engine.COLOR_RESET, h.board.Count()))
	s.Printer.Send(fmt.Sprintf("  %s%-15s%s %s\r\n", engine.COLOR_GRAY, s.Lang["SysOS"], engine.COLOR_RESET, runtime.GOOS))
	s.Printer.Send(fmt.Sprintf("  %s%-15s%s %s\r\n", engine.COLOR_GRAY, s.Lang["SysArch"], engine.COLOR_RESET, runtime.GOARCH))

	s.Printer.Pause(s.Lang)
}
