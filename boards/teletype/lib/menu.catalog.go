package lib

import (
	"fmt"
	"strings"
)

func (s *Session) ShowGames() {
	s.Printer.BoxHeader(s.Lang["CatTitle"], YL)
	s.Printer.Send(fmt.Sprintf("  %s%s%s\r\n", GY, s.Lang["WikiLoading"], R))
	
	softwares, err := s.BBS.CatalogRepo.FetchGames()
	if err != nil {
		s.Printer.Send(fmt.Sprintf("\r\n%s%s: %v%s\r\n", RD, s.Lang["WikiConnError"], err, R))
		s.Printer.Pause(s.Lang)
		return
	}

	s.Printer.Send("\r\033[A\033[2K")

	if len(softwares) == 0 {
		s.Printer.Send(fmt.Sprintf("  %s%s%s\r\n", GY, s.Lang["CatNoGames"], R))
		s.Printer.Pause(s.Lang)
		return
	}

	base := "https://games.teletype.hu"

	for i, entry := range softwares {
		sw := entry.Software
		lr := entry.LatestRelease

		s.Printer.Send(fmt.Sprintf("\r\n  %s%s%s\r\n", YL, strings.Repeat("─", W-4), R))
		s.Printer.Send(fmt.Sprintf("  %s%2d.%s  %s%s%s%s  %s[%s]  by %s%s\r\n", YL, i+1, R, WH, B, sw.Title, R, GY, sw.Platform, sw.Author, R))

		if sw.Desc != "" {
			wrappedDesc := s.Printer.Wrapped(sw.Desc, 7, 1000)
			for _, line := range strings.Split(wrappedDesc, "\r\n") {
				s.Printer.Send(fmt.Sprintf("%s%s\r\n", GY, line))
			}
		}

		if lr != nil {
			badges := []string{}
			if lr.HTMLFolderPath != "" {
				badges = append(badges, fmt.Sprintf("%s[▶ Play]%s", GR, R))
			}
			if lr.CartridgePath != "" {
				badges = append(badges, fmt.Sprintf("%s[⬇ Download]%s", BL, R))
			}
			if lr.SourcePath != "" {
				badges = append(badges, fmt.Sprintf("%s[Source]%s", MG, R))
			}
			if lr.DocsFolderPath != "" {
				badges = append(badges, fmt.Sprintf("%s[Docs]%s", YL, R))
			}

			badgeStr := "–"
			if len(badges) > 0 {
				badgeStr = strings.Join(badges, "  ")
			}
			s.Printer.Send(fmt.Sprintf("       %s%s: v%s%s  %s\r\n", GY, s.Lang["CatLatest"], lr.Version, R, badgeStr))

			if lr.HTMLFolderPath != "" {
				url := base + lr.HTMLFolderPath
				s.Printer.Send(fmt.Sprintf("       %s▶ %s%s\r\n", DIM, url, R))
			}
		}
		s.Printer.Send(fmt.Sprintf("       %s%s%s\r\n", GY, fmt.Sprintf(s.Lang["CatVersions"], len(entry.Releases)), R))
	}

	s.Printer.HR("─", YL)
	s.Printer.Send("\r\n")
	s.Printer.Send(fmt.Sprintf("  %s%s: %s%s\r\n", GY, s.Lang["CatFull"], base, R))
	s.Printer.Pause(s.Lang)
}
