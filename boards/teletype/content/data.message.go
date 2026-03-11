package content

import (
	"encoding/csv"
	"os"
	"sync"
)

type message struct {
	Timestamp string
	User      string
	Text      string
}

// MessageBoard holds message board data
type MessageBoard struct {
	messages []message
	mu       sync.Mutex
	path     string
}

// NewMessageBoard loads messages from the given .dat file
func NewMessageBoard(path string) *MessageBoard {
	b := &MessageBoard{path: path}
	b.load()
	return b
}

func (b *MessageBoard) load() {
	f, err := os.Open(b.path)
	if err != nil {
		return
	}
	defer f.Close()

	r := csv.NewReader(f)
	records, err := r.ReadAll()
	if err != nil {
		return
	}
	for _, row := range records {
		if len(row) != 3 {
			continue
		}
		b.messages = append(b.messages, message{Timestamp: row[0], User: row[1], Text: row[2]})
	}
}

func (b *MessageBoard) append(msg message) error {
	f, err := os.OpenFile(b.path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer f.Close()

	w := csv.NewWriter(f)
	err = w.Write([]string{msg.Timestamp, msg.User, msg.Text})
	w.Flush()
	return err
}

func (b *MessageBoard) Count() int {
	b.mu.Lock()
	defer b.mu.Unlock()
	return len(b.messages)
}
