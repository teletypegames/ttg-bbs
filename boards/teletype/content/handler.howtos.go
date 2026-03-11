package content

import "bbs-server/engine"

// HowToHandler handles the HowTo Guides menu item
type HowToHandler struct {
	repo *wikiRepository
}

func NewHowToHandler(token string) *HowToHandler {
	return &HowToHandler{repo: &wikiRepository{token: token}}
}

func (h *HowToHandler) Handle(s *engine.Session) {
	renderWikiList(s, h.repo, "howto", "HowTo Guides", engine.COLOR_MAGENTA)
}
