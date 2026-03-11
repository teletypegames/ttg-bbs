package content

import (
	"encoding/json"
	"net/http"
	"time"
)

const GamesAPIURL = "https://games.teletype.hu/api/software"

type softwareEntry struct {
	Software struct {
		Title    string `json:"title"`
		Platform string `json:"platform"`
		Author   string `json:"author"`
		Desc     string `json:"desc"`
	} `json:"software"`
	Releases      []interface{} `json:"releases"`
	LatestRelease *struct {
		Version        string `json:"version"`
		HTMLFolderPath string `json:"htmlFolderPath"`
		CartridgePath  string `json:"cartridgePath"`
		SourcePath     string `json:"sourcePath"`
		DocsFolderPath string `json:"docsFolderPath"`
	} `json:"latestRelease"`
}

type catalogRepository struct{}

func (r *catalogRepository) fetchGames() ([]softwareEntry, error) {
	client := &http.Client{Timeout: 12 * time.Second}
	resp, err := client.Get(GamesAPIURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result struct {
		Softwares []softwareEntry `json:"softwares"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	return result.Softwares, nil
}
