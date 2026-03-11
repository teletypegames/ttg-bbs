package content

import (
	"bbs-server/engine"
	"fmt"
	"strings"
)

// CatalogHandler handles the Game Catalog menu item
type CatalogHandler struct {
	repo *catalogRepository
}

func NewCatalogHandler() *CatalogHandler {
	return &CatalogHandler{repo: &catalogRepository{}}
}

func (h *CatalogHandler) Handle(s *engine.Session) {
	s.Printer.BoxHeader(s.Lang["CatTitle"], engine.COLOR_YELLOW)
	s.Printer.Send(fmt.Sprintf("  %s%s%s\r\n", engine.COLOR_GRAY, s.Lang["WikiLoading"], engine.COLOR_RESET))

	softwares, err := h.repo.fetchGames()
	if err != nil {
		s.Printer.Send(fmt.Sprintf("\r\n%s%s: %v%s\r\n", engine.COLOR_RED, s.Lang["WikiConnError"], err, engine.COLOR_RESET))
		s.Printer.Pause(s.Lang)
		return
	}

	s.Printer.Send("\r\033[A\033[2K")

	if len(softwares) == 0 {
		s.Printer.Send(fmt.Sprintf("  %s%s%s\r\n", engine.COLOR_GRAY, s.Lang["CatNoGames"], engine.COLOR_RESET))
		s.Printer.Pause(s.Lang)
		return
	}

	base := "https://games.teletype.hu"

	for i, entry := range softwares {
		sw := entry.Software
		lr := entry.LatestRelease

		s.Printer.Send(fmt.Sprintf("\r\n  %s%s%s\r\n", engine.COLOR_YELLOW, strings.Repeat("─", engine.W-4), engine.COLOR_RESET))
		s.Printer.Send(fmt.Sprintf("  %s%2d.%s  %s%s%s%s  %s[%s]  by %s%s\r\n",
			engine.COLOR_YELLOW, i+1, engine.COLOR_RESET,
			engine.COLOR_WHITE, engine.COLOR_BOLD, sw.Title, engine.COLOR_RESET,
			engine.COLOR_GREEN, sw.Platform, sw.Author, engine.COLOR_RESET))

		if sw.Desc != "" {
			wrappedDesc := s.Printer.Wrapped(sw.Desc, 7, 1000)
			for _, line := range strings.Split(wrappedDesc, "\r\n") {
				s.Printer.Send(fmt.Sprintf("%s%s\r\n", engine.COLOR_GRAY, line))
			}
		}

		if lr != nil {
			badges := []string{}
			if lr.HTMLFolderPath != "" {
				badges = append(badges, fmt.Sprintf("%s[▶ Play]%s", engine.COLOR_GREEN, engine.COLOR_RESET))
			}
			if lr.CartridgePath != "" {
				badges = append(badges, fmt.Sprintf("%s[⬇ Download]%s", engine.COLOR_BLUE, engine.COLOR_RESET))
			}
			if lr.SourcePath != "" {
				badges = append(badges, fmt.Sprintf("%s[Source]%s", engine.COLOR_MAGENTA, engine.COLOR_RESET))
			}
			if lr.DocsFolderPath != "" {
				badges = append(badges, fmt.Sprintf("%s[Docs]%s", engine.COLOR_YELLOW, engine.COLOR_RESET))
			}

			badgeStr := "–"
			if len(badges) > 0 {
				badgeStr = strings.Join(badges, "  ")
			}
			s.Printer.Send(fmt.Sprintf("       %s%s: v%s%s  %s\r\n",
				engine.COLOR_GRAY, s.Lang["CatLatest"], lr.Version, engine.COLOR_RESET, badgeStr))

			if lr.HTMLFolderPath != "" {
				url := base + lr.HTMLFolderPath
				s.Printer.Send(fmt.Sprintf("       %s▶ %s%s\r\n", engine.COLOR_DIM, url, engine.COLOR_RESET))
			}
		}
		s.Printer.Send(fmt.Sprintf("       %s%s%s\r\n",
			engine.COLOR_GRAY, fmt.Sprintf(s.Lang["CatVersions"], len(entry.Releases)), engine.COLOR_RESET))
	}

	s.Printer.HR("─", engine.COLOR_YELLOW)
	s.Printer.Send("\r\n")
	s.Printer.Send(fmt.Sprintf("  %s%s: %s%s\r\n", engine.COLOR_GREEN, s.Lang["CatFull"], base, engine.COLOR_RESET))
	s.Printer.Pause(s.Lang)
}
