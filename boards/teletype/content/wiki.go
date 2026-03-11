package content

import (
	"bbs-server/engine"
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"
)

const WikiJSBaseURL = "https://wiki.teletype.hu"

type wikiPage struct {
	ID          interface{} `json:"id"`
	Path        string      `json:"path"`
	Title       string      `json:"title"`
	Description string      `json:"description"`
	CreatedAt   string      `json:"createdAt"`
	UpdatedAt   string      `json:"updatedAt"`
	Locale      string      `json:"locale"`
}

type wikiRepository struct {
	token string
}

func (r *wikiRepository) graphql(query string) (map[string]interface{}, error) {
	payload := map[string]string{"query": query}
	data, _ := json.Marshal(payload)

	req, err := http.NewRequest("POST", WikiJSBaseURL+"/graphql", bytes.NewBuffer(data))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	if r.token != "" {
		req.Header.Set("Authorization", "Bearer "+r.token)
	}

	client := &http.Client{Timeout: 12 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	return result, nil
}

func (r *wikiRepository) fetchList(tag string) ([]wikiPage, error) {
	q := fmt.Sprintf(`{ pages { list(orderBy: CREATED, orderByDirection: DESC, tags: ["%s"]) { id path title description createdAt updatedAt locale } } }`, tag)
	res, err := r.graphql(q)
	if err != nil {
		return nil, err
	}

	data, ok := res["data"].(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("invalid response format")
	}
	pages, ok := data["pages"].(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("invalid response format")
	}
	listRaw, ok := pages["list"].([]interface{})
	if !ok {
		return nil, fmt.Errorf("invalid response format")
	}

	var list []wikiPage
	jsonBytes, _ := json.Marshal(listRaw)
	json.Unmarshal(jsonBytes, &list)
	return list, nil
}

func (r *wikiRepository) fetchContent(pageID interface{}) (string, error) {
	var idStr string
	switch v := pageID.(type) {
	case string:
		idStr = v
	case float64:
		idStr = fmt.Sprintf("%.0f", v)
	default:
		idStr = fmt.Sprintf("%v", v)
	}

	q := fmt.Sprintf(`{ pages { single(id: %s) { content } } }`, idStr)
	res, err := r.graphql(q)
	if err != nil {
		return "", err
	}

	data := res["data"].(map[string]interface{})
	pages := data["pages"].(map[string]interface{})
	single := pages["single"].(map[string]interface{})
	return single["content"].(string), nil
}

// WikiHandler renders Wiki.js content in the BBS
type WikiHandler struct {
	repo *wikiRepository
}

func NewWikiHandler(token string) *WikiHandler {
	return &WikiHandler{repo: &wikiRepository{token: token}}
}

// List returns a HandlerFunc that lists pages with the given tag
func (h *WikiHandler) List(tag, title, color string) engine.HandlerFunc {
	return func(s *engine.Session) {
		s.Printer.BoxHeader(title, color)
		s.Printer.Send(fmt.Sprintf("  %s%s%s\r\n", engine.GY, s.Lang["WikiLoading"], engine.R))

		pages, err := h.repo.fetchList(tag)
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
		pageContent, err := h.repo.fetchContent(page.ID)
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
}
