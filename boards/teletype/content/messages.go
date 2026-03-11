package content

import (
	"bbs-server/engine"
	"encoding/csv"
	"fmt"
	"os"
	"strings"
	"sync"
	"time"
)

type message struct {
	Timestamp string
	User      string
	Text      string
}

// MessageBoard holds message board data and its handler
type MessageBoard struct {
	messages []message
	mu       sync.Mutex
	path     string
}

// NewMessageBoard loads messages from the given .dat file (if it exists)
func NewMessageBoard(path string) *MessageBoard {
	b := &MessageBoard{path: path}
	b.load()
	return b
}

func (b *MessageBoard) load() {
	f, err := os.Open(b.path)
	if err != nil {
		return // file does not exist yet, start empty
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

// Count returns the number of messages in a thread-safe manner
func (b *MessageBoard) Count() int {
	b.mu.Lock()
	defer b.mu.Unlock()
	return len(b.messages)
}

// Show displays the message board and handles new message input
func (b *MessageBoard) Show(s *engine.Session) {
	s.Printer.BoxHeader(s.Lang["MsgBoardTitle"], engine.GR)

	b.mu.Lock()
	snap := make([]message, len(b.messages))
	copy(snap, b.messages)
	b.mu.Unlock()

	if len(snap) == 0 {
		s.Printer.Send(fmt.Sprintf("  %s%s%s\r\n", engine.GY, s.Lang["MsgNoMessages"], engine.R))
	} else {
		start := 0
		if len(snap) > 30 {
			start = len(snap) - 30
		}
		for i, msg := range snap[start:] {
			s.Printer.Send(fmt.Sprintf("  %s%02d%s %s%s%s  %s%s:%s %s\r\n",
				engine.GR, i+1, engine.R,
				engine.GY, msg.Timestamp, engine.R,
				engine.WH, msg.User, engine.R, msg.Text))
		}
	}

	s.Printer.Send(fmt.Sprintf("\r\n%s[N]%s %s  %s[ENTER]%s %s → ",
		engine.GY, engine.R, s.Lang["MsgNew"],
		engine.GY, engine.R, s.Lang["MsgBack"]))

	choice, _ := s.Printer.ReadLine()
	if strings.ToUpper(strings.TrimSpace(choice)) == "N" {
		s.Printer.Send(fmt.Sprintf("\r\n%s%s%s ", engine.WH, s.Lang["MsgEnterText"], engine.R))
		msgText, _ := s.Printer.ReadLine()
		msgText = strings.TrimSpace(msgText)
		if msgText != "" {
			if len(msgText) > 200 {
				msgText = msgText[:200]
			}
			ts := time.Now().Format("01-02 15:04")
			msg := message{Timestamp: ts, User: s.Username, Text: msgText}
			b.mu.Lock()
			b.messages = append(b.messages, msg)
			b.mu.Unlock()
			b.append(msg)
			s.Printer.Send(fmt.Sprintf("\r\n%s%s%s\r\n", engine.GR, s.Lang["MsgSent"], engine.R))
		} else {
			s.Printer.Send(fmt.Sprintf("\r\n%s%s%s\r\n", engine.GY, s.Lang["MsgEmpty"], engine.R))
		}
	}
}
