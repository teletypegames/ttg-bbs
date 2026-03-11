package content

import (
	"bbs-server/engine"
	"fmt"
	"strconv"
	"strings"
)

// BlogHandler handles the Blog Posts menu item
type BlogHandler struct {
	repo *wikiRepository
}

func NewBlogHandler(token string) *BlogHandler {
	return &BlogHandler{repo: &wikiRepository{token: token}}
}

func (h *BlogHandler) Handle(s *engine.Session) {
	renderWikiList(s, h.repo, "blog", "Blog Posts", engine.COLOR_BLUE)
}

// renderWikiList is a helper used by wiki-based handlers
func renderWikiList(s *engine.Session, repo *wikiRepository, tag, title, color string) {
	s.Printer.BoxHeader(title, color)
	s.Printer.Send(fmt.Sprintf("  %s%s%s\r\n", engine.COLOR_GRAY, s.Lang["WikiLoading"], engine.COLOR_RESET))

	pages, err := repo.fetchList(tag)
	if err != nil {
		s.Printer.Send(fmt.Sprintf("\r\n%s%s: %v%s\r\n", engine.COLOR_RED, s.Lang["WikiConnError"], err, engine.COLOR_RESET))
		s.Printer.Pause(s.Lang)
		return
	}

	s.Printer.Send("\r\033[A\033[2K")

	if len(pages) == 0 {
		s.Printer.Send(fmt.Sprintf("  %s%s%s\r\n", engine.COLOR_GRAY, fmt.Sprintf(s.Lang["WikiNoResults"], tag), engine.COLOR_RESET))
		s.Printer.Pause(s.Lang)
		return
	}

	maxIdx := 25
	if len(pages) < maxIdx {
		maxIdx = len(pages)
	}

	for i, p := range pages[:maxIdx] {
		date := s.Printer.FmtDate(p.CreatedAt)
		if date == "–" {
			date = s.Printer.FmtDate(p.UpdatedAt)
		}
		titleP := p.Title
		if titleP == "" {
			titleP = p.Path
		}
		if len(titleP) > 55 {
			titleP = titleP[:55]
		}
		desc := p.Description
		if len(desc) > 60 {
			desc = desc[:60]
		}
		s.Printer.Send(fmt.Sprintf("  %s%2d%s  %s%s%s\r\n", color, i+1, engine.COLOR_RESET, engine.COLOR_WHITE, titleP, engine.COLOR_RESET))
		if desc != "" {
			s.Printer.Send(fmt.Sprintf("      %s%s  %s%s%s\r\n", engine.COLOR_GRAY, date, engine.COLOR_DIM, desc, engine.COLOR_RESET))
		} else {
			s.Printer.Send(fmt.Sprintf("      %s%s%s\r\n", engine.COLOR_GRAY, date, engine.COLOR_RESET))
		}
	}

	s.Printer.Send(fmt.Sprintf("\r\n%s%s%s ", engine.COLOR_GRAY, s.Lang["WikiEnterNum"], engine.COLOR_RESET))
	choice, _ := s.Printer.ReadLine()
	choice = strings.TrimSpace(choice)
	idx, err := strconv.Atoi(choice)
	if err != nil || idx < 1 || idx > len(pages) {
		return
	}

	page := pages[idx-1]
	s.Printer.Send(fmt.Sprintf("\r\n%s%s%s", engine.COLOR_GRAY, s.Lang["WikiFetchContent"], engine.COLOR_RESET))
	pageContent, err := repo.fetchContent(page.ID)
	if err != nil {
		s.Printer.Send(fmt.Sprintf("\r\n%sHiba: %v%s\r\n", engine.COLOR_RED, err, engine.COLOR_RESET))
		s.Printer.Pause(s.Lang)
		return
	}

	s.Printer.Send("\r\033[A\033[2K")
	s.Printer.Send("\r\n")
	s.Printer.HR("═", color)
	s.Printer.Send("\r\n")
	s.Printer.Send(fmt.Sprintf("  %s%s%s%s\r\n", engine.COLOR_WHITE, engine.COLOR_BOLD, page.Title, engine.COLOR_RESET))
	url := fmt.Sprintf("%s/%s/%s", WikiJSBaseURL, page.Locale, page.Path)
	s.Printer.Send(fmt.Sprintf("  %s%s   %s%s%s\r\n", engine.COLOR_GRAY, s.Printer.FmtDate(page.CreatedAt), engine.COLOR_DIM, url, engine.COLOR_RESET))
	s.Printer.HR("─", engine.COLOR_GRAY)
	s.Printer.Send("\r\n\r\n")

	body := s.Printer.Wrapped(pageContent, 2, 5000)
	for _, line := range strings.Split(body, "\r\n") {
		s.Printer.Send(line + "\r\n")
	}

	s.Printer.Send("\r\n")
	s.Printer.HR("─", engine.COLOR_GRAY)
	s.Printer.Send("\r\n")
	s.Printer.Pause(s.Lang)
}
