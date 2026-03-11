package content

import "bbs-server/engine"

// Handler is the common interface for all BBS menu handlers
type Handler interface {
	Handle(s *engine.Session)
}
