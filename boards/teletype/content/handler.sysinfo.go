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
	s.Printer.BoxHeader(s.Lang["SysTitle"], engine.GY)

	s.Printer.Send(fmt.Sprintf("  %s%-15s%s %d\r\n", engine.GY, s.Lang["SysUsers"], engine.WH, s.State.UserCount()))
	s.Printer.Send(fmt.Sprintf("  %s%-15s%s %d\r\n", engine.GY, s.Lang["SysMessages"], engine.WH, h.board.Count()))
	s.Printer.Send(fmt.Sprintf("  %s%-15s%s %s\r\n", engine.GY, s.Lang["SysOS"], engine.WH, runtime.GOOS))
	s.Printer.Send(fmt.Sprintf("  %s%-15s%s %s\r\n", engine.GY, s.Lang["SysArch"], engine.WH, runtime.GOARCH))

	s.Printer.Pause(s.Lang)
}
