package lib

import (
	"bytes"
	"fmt"
	"net"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"
)

// ANSI Colors
const (
	R   = "\033[0m"
	B   = "\033[1m"
	DIM = "\033[2m"
	CY  = "\033[1;36m"
	YL  = "\033[1;33m"
	GR  = "\033[1;32m"
	RD  = "\033[1;31m"
	MG  = "\033[1;35m"
	WH  = "\033[1;37m"
	BL  = "\033[1;34m"
	GY  = "\033[0;37m"
)

const W = 70

type Message struct {
	User      string
	Timestamp string
	Text      string
}

type Printer struct {
	Conn net.Conn
}

func NewPrinter(conn net.Conn) *Printer {
	return &Printer{Conn: conn}
}

func (p *Printer) Send(text string) {
	normalized := strings.ReplaceAll(text, "\r\n", "\n")
	normalized = strings.ReplaceAll(normalized, "\n", "\r\n")
	p.Conn.Write([]byte(normalized))
}

func (p *Printer) ReadLine() (string, error) {
	var buf bytes.Buffer
	for {
		b := make([]byte, 1)
		_, err := p.Conn.Read(b)
		if err != nil {
			return "", err
		}
		ch := b[0]

		if ch == 255 {
			cmd := make([]byte, 2)
			_, err := p.Conn.Read(cmd)
			if err != nil {
				return "", err
			}
			if cmd[0] == 250 {
				for {
					tmp := make([]byte, 1)
					_, err := p.Conn.Read(tmp)
					if err != nil || tmp[0] == 240 {
						break
					}
				}
			}
			continue
		}

		if ch == '\r' || ch == '\n' {
			res := buf.String()
			p.Send("\r\n")
			return res, nil
		}

		if ch == 8 || ch == 127 {
			if buf.Len() > 0 {
				curr := buf.Bytes()
				buf.Reset()
				buf.Write(curr[:len(curr)-1])
				p.Send("\b \b")
			}
			continue
		}

		if ch >= 32 && ch < 127 {
			buf.WriteByte(ch)
			p.Send(string(ch))
		}
	}
}

func (p *Printer) Pause(lang T) {
	p.Send(fmt.Sprintf("\r\n%s  [ %s ]%s ", GY, lang["Pause"], R))
	p.ReadLine()
}

func (p *Printer) VisibleLen(s string) int {
	re := regexp.MustCompile(`\033\[[0-9;]*m`)
	return utf8.RuneCountInString(re.ReplaceAllString(s, ""))
}

func (p *Printer) PadLine(content string, width int) string {
	vLen := p.VisibleLen(content)
	padding := width - vLen
	if padding < 0 {
		padding = 0
	}
	return content + strings.Repeat(" ", padding)
}

func (p *Printer) BoxHeader(title string, color string) {
	line := strings.Repeat("═", W)
	titleLen := utf8.RuneCountInString(title)
	padding := (W - 2 - titleLen) / 2
	if padding < 0 {
		padding = 0
	}
	inner := strings.Repeat(" ", padding) + title + strings.Repeat(" ", W-2-titleLen-padding)
	p.Send(fmt.Sprintf(
		"\n%s%s%s\n%s║%s %s%s%s %s║%s\n%s%s%s\n",
		color, line, R,
		color, R, B, inner, R, color, R,
		color, line, R,
	))
}

func (p *Printer) HR(char string, color string) {
	p.Send(fmt.Sprintf("%s%s%s", color, strings.Repeat(char, W), R))
}

func (p *Printer) FmtDate(s string) string {
	t, err := time.Parse(time.RFC3339, strings.Replace(s, "Z", "+00:00", 1))
	if err != nil {
		if len(s) >= 10 {
			return s[:10]
		}
		return "–"
	}
	return t.Format("2006-01-02")
}

func (p *Printer) StripMD(text string) string {
	reImg := regexp.MustCompile(`!\[.*?\]\(.*?\)|\[(.*?)\]\(.*?\)|#{1,6}\s*|[*_` + "`" + `~>|]`)
	text = reImg.ReplaceAllStringFunc(text, func(s string) string {
		if strings.HasPrefix(s, "[") {
			sub := regexp.MustCompile(`\[(.*?)\]\(.*?\)` )
			matches := sub.FindStringSubmatch(s)
			if len(matches) > 1 {
				return matches[1]
			}
		}
		if strings.HasPrefix(s, "!") || strings.HasPrefix(s, "#") || strings.ContainsAny(s, "*_`~>|") {
			return ""
		}
		return s
	})
	return strings.TrimSpace(text)
}

func (p *Printer) Wrapped(text string, indent int, maxChars int) string {
	if len(text) > maxChars {
		text = text[:maxChars]
	}
	text = p.StripMD(text)
	prefix := strings.Repeat(" ", indent)
	var lines []string

	paras := strings.Split(text, "\n")
	for _, para := range paras {
		para = strings.TrimSpace(para)
		if para == "" {
			lines = append(lines, "")
			continue
		}
		
		words := strings.Fields(para)
		if len(words) == 0 {
			continue
		}
		
		currentLine := prefix + words[0]
		for _, word := range words[1:] {
			if len(currentLine)+1+len(word) > W {
				lines = append(lines, currentLine)
				currentLine = prefix + word
			} else {
				currentLine += " " + word
			}
		}
		lines = append(lines, currentLine)
	}
	return strings.Join(lines, "\r\n")
}
