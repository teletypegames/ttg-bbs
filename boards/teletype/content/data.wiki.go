package content

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
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

	if errorsRaw, ok := res["errors"].([]interface{}); ok && len(errorsRaw) > 0 {
		if firstErr, ok := errorsRaw[0].(map[string]interface{}); ok {
			if msg, ok := firstErr["message"].(string); ok {
				return nil, fmt.Errorf("wiki error: %s", msg)
			}
		}
		return nil, fmt.Errorf("wiki returned an error")
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

	if errorsRaw, ok := res["errors"].([]interface{}); ok && len(errorsRaw) > 0 {
		if firstErr, ok := errorsRaw[0].(map[string]interface{}); ok {
			if msg, ok := firstErr["message"].(string); ok {
				return "", fmt.Errorf("wiki error: %s", msg)
			}
		}
		return "", fmt.Errorf("wiki returned an error")
	}

	data, ok := res["data"].(map[string]interface{})
	if !ok {
		return "", fmt.Errorf("invalid response format: missing data")
	}
	pages, ok := data["pages"].(map[string]interface{})
	if !ok {
		return "", fmt.Errorf("invalid response format: missing pages")
	}
	single, ok := pages["single"].(map[string]interface{})
	if !ok {
		return "", fmt.Errorf("page not found")
	}
	content, ok := single["content"].(string)
	if !ok {
		return "", fmt.Errorf("invalid response format: missing content")
	}
	return content, nil
}
