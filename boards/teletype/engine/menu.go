package engine

import (
	"fmt"
	"strings"
)

// HandlerFunc is the handler type for a menu item
type HandlerFunc func(*Session)

// Exit is a built-in handler that terminates the session
var Exit HandlerFunc = func(s *Session) { s.Quit = true }

type menuItem struct {
	Key     string
	Label   string
	Color   string
	Handler HandlerFunc
}

// Menu defines the BBS main menu using a declarative DSL
type Menu struct {
	title string
	items []menuItem
}

// Title sets the menu header
func (m *Menu) Title(t string) {
	m.title = t
}

// Item adds a menu entry (key, display label, ANSI color, handler)
func (m *Menu) Item(key, label, color string, handler HandlerFunc) {
	m.items = append(m.items, menuItem{
		Key:     strings.ToUpper(key),
		Label:   label,
		Color:   color,
		Handler: handler,
	})
}

// Dispatch finds and calls the handler for the given key
func (m *Menu) Dispatch(s *Session, key string) {
	key = strings.ToUpper(strings.TrimSpace(key))
	for _, item := range m.items {
		if item.Key == key {
			item.Handler(s)
			return
		}
	}
}

// Render returns the rendered menu string
func (m *Menu) Render(p *Printer, lang T, username string) string {
	headerLine := strings.Repeat("═", W)
	l1 := p.PadLine(fmt.Sprintf("  %s%s%s  %s@%s%s", COLOR_YELLOW, m.title, COLOR_RESET, COLOR_GRAY, username, COLOR_RESET), W)

	var rows []string
	for i := 0; i < len(m.items); i += 2 {
		if i+1 < len(m.items) {
			left := p.PadLine(fmt.Sprintf("  %s[%s]%s %s", m.items[i].Color, m.items[i].Key, COLOR_RESET, m.items[i].Label), W/2)
			right := p.PadLine(fmt.Sprintf("  %s[%s]%s %s", m.items[i+1].Color, m.items[i+1].Key, COLOR_RESET, m.items[i+1].Label), W/2)
			rows = append(rows, left+right)
		} else {
			rows = append(rows, p.PadLine(fmt.Sprintf("  %s[%s]%s %s", m.items[i].Color, m.items[i].Key, COLOR_RESET, m.items[i].Label), W))
		}
	}

	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("\n%s╔%s╗%s\n", COLOR_WHITE, headerLine, COLOR_RESET))
	sb.WriteString(fmt.Sprintf("%s║%s%s║%s\n", COLOR_WHITE, l1, COLOR_WHITE, COLOR_RESET))
	sb.WriteString(fmt.Sprintf("%s╠%s╣%s\n", COLOR_WHITE, headerLine, COLOR_RESET))
	for _, row := range rows {
		sb.WriteString(fmt.Sprintf("%s║%s%s║%s\n", COLOR_WHITE, row, COLOR_WHITE, COLOR_RESET))
	}
	sb.WriteString(fmt.Sprintf("%s╚%s╝%s\n%s", COLOR_WHITE, headerLine, COLOR_RESET, lang["Choice"]))
	return sb.String()
}
