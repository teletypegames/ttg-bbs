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
	renderWikiList(s, h.repo, "blog", "Blog Posts", engine.BL)
}

// renderWikiList is a helper used by wiki-based handlers
func renderWikiList(s *engine.Session, repo *wikiRepository, tag, title, color string) {
	s.Printer.BoxHeader(title, color)
	s.Printer.Send(fmt.Sprintf("  %s%s%s\r\n", engine.GY, s.Lang["WikiLoading"], engine.R))

	pages, err := repo.fetchList(tag)
	if err != nil {
		s.Printer.Send(fmt.Sprintf("\r\n%s%s: %v%s\r\n", engine.RD, s.Lang["WikiConnError"], err, engine.R))
		s.Printer.Pause(s.Lang)
		return
	}

	s.Printer.Send("\r\033[A\033[2K")

	if len(pages) == 0 {
		s.Printer.Send(fmt.Sprintf("  %s%s%s\r\n", engine.GY, fmt.Sprintf(s.Lang["WikiNoResults"], tag), engine.R))
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
		s.Printer.Send(fmt.Sprintf("  %s%2d%s  %s%s%s\r\n", color, i+1, engine.R, engine.WH, titleP, engine.R))
		if desc != "" {
			s.Printer.Send(fmt.Sprintf("      %s%s  %s%s%s\r\n", engine.GY, date, engine.DIM, desc, engine.R))
		} else {
			s.Printer.Send(fmt.Sprintf("      %s%s%s\r\n", engine.GY, date, engine.R))
		}
	}

	s.Printer.Send(fmt.Sprintf("\r\n%s%s%s ", engine.GY, s.Lang["WikiEnterNum"], engine.R))
	choice, _ := s.Printer.ReadLine()
	choice = strings.TrimSpace(choice)
	idx, err := strconv.Atoi(choice)
	if err != nil || idx < 1 || idx > len(pages) {
		return
	}

	page := pages[idx-1]
	s.Printer.Send(fmt.Sprintf("\r\n%s%s%s", engine.GY, s.Lang["WikiFetchContent"], engine.R))
	pageContent, err := repo.fetchContent(page.ID)
	if err != nil {
		s.Printer.Send(fmt.Sprintf("\r\n%sHiba: %v%s\r\n", engine.RD, err, engine.R))
		s.Printer.Pause(s.Lang)
		return
	}

	s.Printer.Send("\r\033[A\033[2K")
	s.Printer.Send("\r\n")
	s.Printer.HR("═", color)
	s.Printer.Send("\r\n")
	s.Printer.Send(fmt.Sprintf("  %s%s%s%s\r\n", engine.WH, engine.B, page.Title, engine.R))
	url := fmt.Sprintf("%s/%s/%s", WikiJSBaseURL, page.Locale, page.Path)
	s.Printer.Send(fmt.Sprintf("  %s%s   %s%s%s\r\n", engine.GY, s.Printer.FmtDate(page.CreatedAt), engine.DIM, url, engine.R))
	s.Printer.HR("─", engine.GY)
	s.Printer.Send("\r\n\r\n")

	body := s.Printer.Wrapped(pageContent, 2, 5000)
	for _, line := range strings.Split(body, "\r\n") {
		s.Printer.Send(line + "\r\n")
	}

	s.Printer.Send("\r\n")
	s.Printer.HR("─", engine.GY)
	s.Printer.Send("\r\n")
	s.Printer.Pause(s.Lang)
}
