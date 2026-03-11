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
	s.Printer.BoxHeader(s.Lang["CatTitle"], engine.YL)
	s.Printer.Send(fmt.Sprintf("  %s%s%s\r\n", engine.GY, s.Lang["WikiLoading"], engine.R))

	softwares, err := h.repo.fetchGames()
	if err != nil {
		s.Printer.Send(fmt.Sprintf("\r\n%s%s: %v%s\r\n", engine.RD, s.Lang["WikiConnError"], err, engine.R))
		s.Printer.Pause(s.Lang)
		return
	}

	s.Printer.Send("\r\033[A\033[2K")

	if len(softwares) == 0 {
		s.Printer.Send(fmt.Sprintf("  %s%s%s\r\n", engine.GY, s.Lang["CatNoGames"], engine.R))
		s.Printer.Pause(s.Lang)
		return
	}

	base := "https://games.teletype.hu"

	for i, entry := range softwares {
		sw := entry.Software
		lr := entry.LatestRelease

		s.Printer.Send(fmt.Sprintf("\r\n  %s%s%s\r\n", engine.YL, strings.Repeat("─", engine.W-4), engine.R))
		s.Printer.Send(fmt.Sprintf("  %s%2d.%s  %s%s%s%s  %s[%s]  by %s%s\r\n",
			engine.YL, i+1, engine.R,
			engine.WH, engine.B, sw.Title, engine.R,
			engine.GY, sw.Platform, sw.Author, engine.R))

		if sw.Desc != "" {
			wrappedDesc := s.Printer.Wrapped(sw.Desc, 7, 1000)
			for _, line := range strings.Split(wrappedDesc, "\r\n") {
				s.Printer.Send(fmt.Sprintf("%s%s\r\n", engine.GY, line))
			}
		}

		if lr != nil {
			badges := []string{}
			if lr.HTMLFolderPath != "" {
				badges = append(badges, fmt.Sprintf("%s[▶ Play]%s", engine.GR, engine.R))
			}
			if lr.CartridgePath != "" {
				badges = append(badges, fmt.Sprintf("%s[⬇ Download]%s", engine.BL, engine.R))
			}
			if lr.SourcePath != "" {
				badges = append(badges, fmt.Sprintf("%s[Source]%s", engine.MG, engine.R))
			}
			if lr.DocsFolderPath != "" {
				badges = append(badges, fmt.Sprintf("%s[Docs]%s", engine.YL, engine.R))
			}

			badgeStr := "–"
			if len(badges) > 0 {
				badgeStr = strings.Join(badges, "  ")
			}
			s.Printer.Send(fmt.Sprintf("       %s%s: v%s%s  %s\r\n",
				engine.GY, s.Lang["CatLatest"], lr.Version, engine.R, badgeStr))

			if lr.HTMLFolderPath != "" {
				url := base + lr.HTMLFolderPath
				s.Printer.Send(fmt.Sprintf("       %s▶ %s%s\r\n", engine.DIM, url, engine.R))
			}
		}
		s.Printer.Send(fmt.Sprintf("       %s%s%s\r\n",
			engine.GY, fmt.Sprintf(s.Lang["CatVersions"], len(entry.Releases)), engine.R))
	}

	s.Printer.HR("─", engine.YL)
	s.Printer.Send("\r\n")
	s.Printer.Send(fmt.Sprintf("  %s%s: %s%s\r\n", engine.GY, s.Lang["CatFull"], base, engine.R))
	s.Printer.Pause(s.Lang)
}
