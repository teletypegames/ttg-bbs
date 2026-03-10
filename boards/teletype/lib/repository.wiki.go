package lib

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

const WikiJSBaseURL = "https://wiki.teletype.hu"

type WikiPage struct {
	ID          interface{} `json:"id"`
	Path        string      `json:"path"`
	Title       string      `json:"title"`
	Description string      `json:"description"`
	CreatedAt   string      `json:"createdAt"`
	UpdatedAt   string      `json:"updatedAt"`
	Locale      string      `json:"locale"`
}

type WikiRepository struct {
	Token string
}

func NewWikiRepository(token string) *WikiRepository {
	return &WikiRepository{Token: token}
}

func (r *WikiRepository) graphql(query string) (map[string]interface{}, error) {
	payload := map[string]string{"query": query}
	data, _ := json.Marshal(payload)

	req, err := http.NewRequest("POST", WikiJSBaseURL+"/graphql", bytes.NewBuffer(data))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	if r.Token != "" {
		req.Header.Set("Authorization", "Bearer "+r.Token)
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

func (r *WikiRepository) FetchList(tag string) ([]WikiPage, error) {
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

	var list []WikiPage
	jsonBytes, _ := json.Marshal(listRaw)
	json.Unmarshal(jsonBytes, &list)
	return list, nil
}

func (r *WikiRepository) FetchContent(pageID interface{}) (string, error) {
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
