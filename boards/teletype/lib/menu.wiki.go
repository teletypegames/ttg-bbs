package lib

import (
	"fmt"
	"strconv"
	"strings"
)

func (s *Session) ShowWikiList(tag string, color string, title string) {
	s.Printer.BoxHeader(title, color)
	s.Printer.Send(fmt.Sprintf("  %s%s%s\r\n", GY, s.Lang["WikiLoading"], R))
	
	pages, err := s.BBS.WikiRepo.FetchList(tag)
	if err != nil {
		s.Printer.Send(fmt.Sprintf("\r\n%s%s: %v%s\r\n", RD, s.Lang["WikiConnError"], err, R))
		s.Printer.Pause(s.Lang)
		return
	}

	s.Printer.Send("\r\033[A\033[2K")

	if len(pages) == 0 {
		s.Printer.Send(fmt.Sprintf("  %s%s%s\r\n", GY, fmt.Sprintf(s.Lang["WikiNoResults"], tag), R))
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
		s.Printer.Send(fmt.Sprintf("  %s%2d%s  %s%s%s\r\n", color, i+1, R, WH, titleP, R))
		if desc != "" {
			s.Printer.Send(fmt.Sprintf("      %s%s  %s%s%s\r\n", GY, date, DIM, desc, R))
		} else {
			s.Printer.Send(fmt.Sprintf("      %s%s%s\r\n", GY, date, R))
		}
	}

	s.Printer.Send(fmt.Sprintf("\r\n%s%s%s ", GY, s.Lang["WikiEnterNum"], R))
	choice, _ := s.Printer.ReadLine()
	choice = strings.TrimSpace(choice)
	idx, err := strconv.Atoi(choice)
	if err != nil || idx < 1 || idx > len(pages) {
		return
	}

	page := pages[idx-1]
	s.Printer.Send(fmt.Sprintf("\r\n%s%s%s", GY, s.Lang["WikiFetchContent"], R))
	content, err := s.BBS.WikiRepo.FetchContent(page.ID)
	if err != nil {
		s.Printer.Send(fmt.Sprintf("\r\n%sHiba: %v%s\r\n", RD, err, R))
		s.Printer.Pause(s.Lang)
		return
	}

	s.Printer.Send("\r\033[A\033[2K")
	s.Printer.Send(fmt.Sprintf("\r\n"))
	s.Printer.HR("═", color)
	s.Printer.Send("\r\n")
	s.Printer.Send(fmt.Sprintf("  %s%s%s%s\r\n", WH, B, page.Title, R))
	url := fmt.Sprintf("%s/%s/%s", WikiJSBaseURL, page.Locale, page.Path)
	s.Printer.Send(fmt.Sprintf("  %s%s   %s%s%s\r\n", GY, s.Printer.FmtDate(page.CreatedAt), DIM, url, R))
	s.Printer.HR("─", GY)
	s.Printer.Send("\r\n\r\n")

	body := s.Printer.Wrapped(content, 2, 5000)
	for _, line := range strings.Split(body, "\r\n") {
		s.Printer.Send(line+"\r\n")
	}

	s.Printer.Send("\r\n")
	s.Printer.HR("─", GY)
	s.Printer.Send("\r\n")
	s.Printer.Pause(s.Lang)
}
