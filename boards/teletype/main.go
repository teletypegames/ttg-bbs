package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode/utf8"
)

const (
	Host          = "0.0.0.0"
	Port          = "2323"
	WikiJSBaseURL = "https://wiki.teletype.hu"
	GamesAPIURL   = "https://games.teletype.hu/api/software"
	W             = 70
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

type Message struct {
	User      string
	Timestamp string
	Text      string
}

var (
	messages    []Message
	onlineUsers = make(map[string]string) // addr -> username
	mu          sync.Mutex
	wikiToken   = os.Getenv("WEBAPP_WIKIJS_TOKEN")
)

const Banner = `
  ████████╗███████╗██╗     ███████╗████████╗██╗   ██╗██████╗ ███████╗
     ██╔══╝██╔════╝██║     ██╔════╝╚══██╔══╝╚██╗ ██╔╝██╔══██╗██╔════╝
     ██║   █████╗  ██║     █████╗     ██║    ╚████╔╝ ██████╔╝█████╗  
     ██║   ██╔══╝  ██║     ██╔══╝     ██║     ╚██╔╝  ██╔═══╝ ██╔══╝  
     ██║   ███████╗███████╗███████╗   ██║      ██║   ██║     ███████╗
     ╚═╝   ╚══════╝╚══════╝╚══════╝   ╚═╝      ╚═╝   ╚═╝     ╚══════╝

                  ░░  BBS  v2.0  ░░  teletype.hu  ░░
          Üdvözölünk a Teletype közösségi hirdetőtábláján!
`

func main() {
	ln, err := net.Listen("tcp", Host+":"+Port)
	if err != nil {
		fmt.Printf("Hiba a szerver indításakor: %v\n", err)
		os.Exit(1)
	}
	defer ln.Close()

	fmt.Printf("Teletype BBS fut → telnet localhost %s\n", Port)
	fmt.Printf("Wiki: %s\n", WikiJSBaseURL)
	fmt.Printf("Games API: %s\n", GamesAPIURL)
	tokenStatus := "✗ nincs beállítva"
	if wikiToken != "" {
		tokenStatus = "✓ beállítva"
	}
	fmt.Printf("Token: %s\n", tokenStatus)
	fmt.Println("Leállítás: Ctrl+C")

	for {
		conn, err := ln.Accept()
		if err != nil {
			fmt.Printf("Hiba a kapcsolódáskor: %v\n", err)
			continue
		}
		fmt.Printf("[+] Kapcsolódott: %s\n", conn.RemoteAddr().String())
		go handleClient(conn)
	}
}

func handleClient(conn net.Conn) {
	defer conn.Close()
	addr := conn.RemoteAddr().String()

	// Telnet negotiation:
	// IAC WILL ECHO (255, 251, 1)
	// IAC WILL SUPPRESS GO AHEAD (255, 251, 3)
	// IAC DONT LINEMODE (255, 254, 34)
	send(conn, "\xff\xfb\x01\xff\xfb\x03\xff\xfe\x22")

	send(conn, CY+Banner+R)
	send(conn, fmt.Sprintf("\n%sAdd meg a nevedet:%s ", WH, R))

	username, err := readLine(conn)
	if err != nil {
		return
	}
	username = strings.TrimSpace(username)
	if username == "" {
		username = "Névtelen"
	}
	if len(username) > 20 {
		username = username[:20]
	}

	mu.Lock()
	onlineUsers[addr] = username
	mu.Unlock()

	defer func() {
		mu.Lock()
		delete(onlineUsers, addr)
		mu.Unlock()
	}()

	send(conn, fmt.Sprintf("\r\n%sSzia, %s%s%s! Üdv a Teletype BBS-en!%s\r\n", GR, WH, username, GR, R))

	for {
		send(conn, mainMenu(username))
		choice, err := readLine(conn)
		if err != nil {
			break
		}
		c := strings.ToUpper(strings.TrimSpace(choice))

		switch c {
		case "1":
			showUzenopal(conn, username)
		case "2":
			showWikiList(conn, "blog", BL, "📰  BLOG BEJEGYZÉSEK")
		case "3":
			showWikiList(conn, "howto", MG, "📖  HOWTO ÚTMUTATÓK")
		case "4":
			showGames(conn)
		case "5":
			showOnline(conn, addr)
		case "6":
			showSysinfo(conn)
		case "Q":
			send(conn, fmt.Sprintf("\r\n%sViszlát, %s! 👋%s\r\n\r\n", RD, username, R))
			return
		}
	}
}

func visibleLen(s string) int {
	re := regexp.MustCompile(`\033\[[0-9;]*m`)
	return utf8.RuneCountInString(re.ReplaceAllString(s, ""))
}

func padLine(content string, width int) string {
	vLen := visibleLen(content)
	padding := width - vLen
	if padding < 0 {
		padding = 0
	}
	return content + strings.Repeat(" ", padding)
}

func mainMenu(username string) string {
	headerLine := strings.Repeat("═", W)

	// Sorok összeállítása pontos hosszal
	l1 := padLine(fmt.Sprintf("  %sFŐMENÜ%s  %s@%s%s", YL, R, GY, username, R), W)
	l2 := padLine(fmt.Sprintf("  %s[1]%s Üzenőfal", GR, R), W/2) + padLine(fmt.Sprintf("  %s[2]%s Blog bejegyzések", BL, R), W/2)
	l3 := padLine(fmt.Sprintf("  %s[3]%s HowTo útmutatók", MG, R), W/2) + padLine(fmt.Sprintf("  %s[4]%s Játékkatalógus", YL, R), W/2)
	l4 := padLine(fmt.Sprintf("  %s[5]%s Online felhasználók", CY, R), W/2) + padLine(fmt.Sprintf("  %s[6]%s Rendszerinfo", GY, R), W/2)
	l5 := padLine(fmt.Sprintf("  %s[Q]%s Kilépés", RD, R), W)

	return fmt.Sprintf(
		"\n%s╔%s╗%s\n"+
			"%s║%s%s║%s\n"+
			"%s╠%s╣%s\n"+
			"%s║%s%s║%s\n"+
			"%s║%s%s║%s\n"+
			"%s║%s%s║%s\n"+
			"%s║%s%s║%s\n"+
			"%s╚%s╝%s\nVálasztás: ",
		WH, headerLine, R,
		WH, l1, WH, R,
		WH, headerLine, R,
		WH, l2, WH, R,
		WH, l3, WH, R,
		WH, l4, WH, R,
		WH, l5, WH, R,
		WH, headerLine, R,
	)
}

// ── Telnet I/O ───────────────────────────────────────────────────────────────

func send(conn net.Conn, text string) {
	// Minden \n-t \r\n-re cserélünk, ha még nem az, hogy Telnet-en ne essen szét az ASCII art
	normalized := strings.ReplaceAll(text, "\r\n", "\n")
	normalized = strings.ReplaceAll(normalized, "\n", "\r\n")
	conn.Write([]byte(normalized))
}

func readLine(conn net.Conn) (string, error) {
	var buf bytes.Buffer
	for {
		b := make([]byte, 1)
		_, err := conn.Read(b)
		if err != nil {
			return "", err
		}
		ch := b[0]

		// Telnet IAC (Interpret As Command)
		if ch == 255 {
			cmd := make([]byte, 2)
			_, err := conn.Read(cmd)
			if err != nil {
				return "", err
			}
			if cmd[0] == 250 { // SB
				for {
					tmp := make([]byte, 1)
					_, err := conn.Read(tmp)
					if err != nil || tmp[0] == 240 { // SE
						break
					}
				}
			}
			continue
		}

		// Enter billentyű (Telnetnél \r\n vagy csak \r)
		if ch == '\r' || ch == '\n' {
			res := buf.String()
			send(conn, "\r\n") // Visszhangozzuk a sortörést
			return res, nil
		}

		// Backspace (8=BS, 127=DEL)
		if ch == 8 || ch == 127 {
			if buf.Len() > 0 {
				curr := buf.Bytes()
				buf.Reset()
				buf.Write(curr[:len(curr)-1])
				send(conn, "\b \b")
			}
			continue
		}

		// Csak a látható karaktereket gyűjtjük
		if ch >= 32 && ch < 127 {
			buf.WriteByte(ch)
			send(conn, string(ch))
		}
	}
}

func pause(conn net.Conn) {
	send(conn, fmt.Sprintf("\r\n%s  [ Nyomj ENTER-t... ]%s ", GY, R))
	readLine(conn)
}

// ── API hívások ───────────────────────────────────────────────────────────────

func graphql(query string) (map[string]interface{}, error) {
	payload := map[string]string{"query": query}
	data, _ := json.Marshal(payload)

	req, err := http.NewRequest("POST", WikiJSBaseURL+"/graphql", bytes.NewBuffer(data))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	if wikiToken != "" {
		req.Header.Set("Authorization", "Bearer "+wikiToken)
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

type WikiPage struct {
	ID          interface{} `json:"id"`
	Path        string      `json:"path"`
	Title       string      `json:"title"`
	Description string      `json:"description"`
	CreatedAt   string      `json:"createdAt"`
	UpdatedAt   string      `json:"updatedAt"`
	Locale      string      `json:"locale"`
}

func fetchWikiList(tag string) ([]WikiPage, error) {
	q := fmt.Sprintf(`{ pages { list(orderBy: CREATED, orderByDirection: DESC, tags: ["%s"]) { id path title description createdAt updatedAt locale } } }`, tag)
	res, err := graphql(q)
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

func fetchWikiContent(pageID interface{}) (string, error) {
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
	res, err := graphql(q)
	if err != nil {
		return "", err
	}

	data := res["data"].(map[string]interface{})
	pages := data["pages"].(map[string]interface{})
	single := pages["single"].(map[string]interface{})
	return single["content"].(string), nil
}

type SoftwareEntry struct {
	Software struct {
		Title    string `json:"title"`
		Platform string `json:"platform"`
		Author   string `json:"author"`
		Desc     string `json:"desc"`
	} `json:"software"`
	Releases      []interface{} `json:"releases"`
	LatestRelease *struct {
		Version         string `json:"version"`
		HTMLFolderPath  string `json:"htmlFolderPath"`
		CartridgePath   string `json:"cartridgePath"`
		SourcePath      string `json:"sourcePath"`
		DocsFolderPath  string `json:"docsFolderPath"`
	} `json:"latestRelease"`
}

func fetchGames() ([]SoftwareEntry, error) {
	client := &http.Client{Timeout: 12 * time.Second}
	resp, err := client.Get(GamesAPIURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result struct {
		Softwares []SoftwareEntry `json:"softwares"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	return result.Softwares, nil
}

// ── Szöveg segédek ────────────────────────────────────────────────────────────

func boxHeader(title string, color string) string {
	line := strings.Repeat("═", W)
	titleLen := utf8.RuneCountInString(title)
	padding := (W - 2 - titleLen) / 2
	if padding < 0 {
		padding = 0
	}
	inner := strings.Repeat(" ", padding) + title + strings.Repeat(" ", W-2-titleLen-padding)
	return fmt.Sprintf(
		"\n%s%s%s\n%s║%s %s%s%s %s║%s\n%s%s%s\n",
		color, line, R,
		color, R, B, inner, R, color, R,
		color, line, R,
	)
}

func hr(char string, color string) string {
	return fmt.Sprintf("%s%s%s", color, strings.Repeat(char, W), R)
}

func fmtDate(s string) string {
	t, err := time.Parse(time.RFC3339, strings.Replace(s, "Z", "+00:00", 1))
	if err != nil {
		if len(s) >= 10 {
			return s[:10]
		}
		return "–"
	}
	return t.Format("2006-01-02")
}

func stripMD(text string) string {
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

func wrapped(text string, indent int, maxChars int) string {
	if len(text) > maxChars {
		text = text[:maxChars]
	}
	text = stripMD(text)
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

// ── Menük ─────────────────────────────────────────────────────────────────────

func showUzenopal(conn net.Conn, username string) {
	send(conn, boxHeader("📋  ÜZENŐFAL", GR))
	mu.Lock()
	snap := make([]Message, len(messages))
	copy(snap, messages)
	mu.Unlock()

	if len(snap) == 0 {
		send(conn, fmt.Sprintf("  %s(Még nincs üzenet — legyél az első!)%s\r\n", GY, R))
	} else {
		start := 0
		if len(snap) > 30 {
			start = len(snap) - 30
		}
		for i, msg := range snap[start:] {
			send(conn, fmt.Sprintf("  %s%02d%s %s%s%s  %s%s:%s %s\r\n", GR, i+1, R, GY, msg.Timestamp, R, WH, msg.User, R, msg.Text))
		}
	}

	send(conn, fmt.Sprintf("\r\n%s[N]%s Új üzenet írása  %s[ENTER]%s Vissza → ", GY, R, GY, R))
	choice, _ := readLine(conn)
	if strings.ToUpper(strings.TrimSpace(choice)) == "N" {
		send(conn, fmt.Sprintf("\r\n%sÜzenet szövege:%s ", WH, R))
		msgText, _ := readLine(conn)
		msgText = strings.TrimSpace(msgText)
		if msgText != "" {
			if len(msgText) > 200 {
				msgText = msgText[:200]
			}
			ts := time.Now().Format("01-02 15:04")
			mu.Lock()
			messages = append(messages, Message{User: username, Timestamp: ts, Text: msgText})
			mu.Unlock()
			send(conn, fmt.Sprintf("\r\n%s✓ Elküldve!%s\r\n", GR, R))
		} else {
			send(conn, fmt.Sprintf("\r\n%s(Üres – nem küldtük el)%s\r\n", GY, R))
		}
	}
}

func showWikiList(conn net.Conn, tag string, color string, title string) {
	send(conn, boxHeader(title, color))
	send(conn, fmt.Sprintf("  %sTöltés folyamatban...%s\r\n", GY, R))
	
	pages, err := fetchWikiList(tag)
	if err != nil {
		send(conn, fmt.Sprintf("\r\n%sKapcsolati hiba: %v%s\r\n", RD, err, R))
		pause(conn)
		return
	}

	// clear "Töltés" line
	send(conn, "\r\033[A\033[2K")

	if len(pages) == 0 {
		send(conn, fmt.Sprintf("  %sNincs találat a '%s' tag-re.%s\r\n", GY, tag, R))
		pause(conn)
		return
	}

	maxIdx := 25
	if len(pages) < maxIdx {
		maxIdx = len(pages)
	}

	for i, p := range pages[:maxIdx] {
		date := fmtDate(p.CreatedAt)
		if date == "–" {
			date = fmtDate(p.UpdatedAt)
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
		send(conn, fmt.Sprintf("  %s%2d%s  %s%s%s\r\n", color, i+1, R, WH, titleP, R))
		if desc != "" {
			send(conn, fmt.Sprintf("      %s%s  %s%s%s\r\n", GY, date, DIM, desc, R))
		} else {
			send(conn, fmt.Sprintf("      %s%s%s\r\n", GY, date, R))
		}
	}

	send(conn, fmt.Sprintf("\r\n%sSzám a tartalom megnyitásához, ENTER a visszalépéshez:%s ", GY, R))
	choice, _ := readLine(conn)
	choice = strings.TrimSpace(choice)
	idx, err := strconv.Atoi(choice)
	if err != nil || idx < 1 || idx > len(pages) {
		return
	}

	page := pages[idx-1]
	send(conn, fmt.Sprintf("\r\n%sTartalom betöltése...%s", GY, R))
	content, err := fetchWikiContent(page.ID)
	if err != nil {
		send(conn, fmt.Sprintf("\r\n%sHiba: %v%s\r\n", RD, err, R))
		pause(conn)
		return
	}

	send(conn, "\r\033[A\033[2K")
	send(conn, fmt.Sprintf("\r\n%s\r\n", hr("═", color)))
	send(conn, fmt.Sprintf("  %s%s%s%s\r\n", WH, B, page.Title, R))
	url := fmt.Sprintf("%s/%s/%s", WikiJSBaseURL, page.Locale, page.Path)
	send(conn, fmt.Sprintf("  %s%s   %s%s%s\r\n", GY, fmtDate(page.CreatedAt), DIM, url, R))
	send(conn, fmt.Sprintf("%s\r\n\r\n", hr("─", GY)))

	body := wrapped(content, 2, 5000)
	for _, line := range strings.Split(body, "\r\n") {
		send(conn, line+"\r\n")
	}

	send(conn, fmt.Sprintf("\r\n%s\r\n", hr("─", GY)))
	pause(conn)
}

func showGames(conn net.Conn) {
	send(conn, boxHeader("🎮  JÁTÉKKATALÓGUS", YL))
	send(conn, fmt.Sprintf("  %sTöltés folyamatban...%s\r\n", GY, R))
	
	softwares, err := fetchGames()
	if err != nil {
		send(conn, fmt.Sprintf("\r\n%sKapcsolati hiba: %v%s\r\n", RD, err, R))
		pause(conn)
		return
	}

	send(conn, "\r\033[A\033[2K")

	if len(softwares) == 0 {
		send(conn, fmt.Sprintf("  %sNincs elérhető játék.%s\r\n", GY, R))
		pause(conn)
		return
	}

	base := "https://games.teletype.hu"

	for i, entry := range softwares {
		sw := entry.Software
		lr := entry.LatestRelease

		send(conn, fmt.Sprintf("\r\n  %s%s%s\r\n", YL, strings.Repeat("─", W-4), R))
		send(conn, fmt.Sprintf("  %s%2d.%s  %s%s%s%s  %s[%s]  by %s%s\r\n", YL, i+1, R, WH, B, sw.Title, R, GY, sw.Platform, sw.Author, R))

		if sw.Desc != "" {
			wrappedDesc := wrapped(sw.Desc, 7, 1000)
			for _, line := range strings.Split(wrappedDesc, "\r\n") {
				send(conn, fmt.Sprintf("%s%s\r\n", GY, line))
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
			send(conn, fmt.Sprintf("       %sLegújabb: v%s%s  %s\r\n", GY, lr.Version, R, badgeStr))

			if lr.HTMLFolderPath != "" {
				url := base + lr.HTMLFolderPath
				send(conn, fmt.Sprintf("       %s▶ %s%s\r\n", DIM, url, R))
			}
		}
		send(conn, fmt.Sprintf("       %s%d verzió elérhető%s\r\n", GY, len(entry.Releases), R))
	}

	send(conn, fmt.Sprintf("\r\n%s\r\n", hr("─", YL)))
	send(conn, fmt.Sprintf("  %sTeljes katalógus: %s%s\r\n", GY, base, R))
	pause(conn)
}

func showOnline(conn net.Conn, myAddr string) {
	send(conn, boxHeader("👥  ONLINE FELHASZNÁLÓK", CY))
	mu.Lock()
	snap := make(map[string]string)
	for k, v := range onlineUsers {
		snap[k] = v
	}
	mu.Unlock()

	keys := make([]string, 0, len(snap))
	for k := range snap {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	for _, addr := range keys {
		user := snap[addr]
		marker := ""
		if addr == myAddr {
			marker = fmt.Sprintf("  %s← te%s", GR, R)
		}
		send(conn, fmt.Sprintf("  %s•%s  %s%s%s%s\r\n", CY, R, WH, user, R, marker))
	}
	send(conn, fmt.Sprintf("\r\n  %sÖsszesen: %s%d%s fő online%s\r\n", GY, WH, len(snap), GY, R))
	pause(conn)
}

func showSysinfo(conn net.Conn) {
	send(conn, boxHeader("ℹ  RENDSZERINFO", GY))
	mu.Lock()
	uc := len(onlineUsers)
	mc := len(messages)
	mu.Unlock()

	now := time.Now().Format("2006-01-02 15:04:05")
	rows := [][]string{
		{"Szerver ideje", now},
		{"Online userek", strconv.Itoa(uc)},
		{"Üzenetek száma", strconv.Itoa(mc)},
		{"Wiki URL", WikiJSBaseURL},
		{"Games API", GamesAPIURL},
		{"Token beállítva", func() string {
			if wikiToken != "" {
				return "igen"
			}
			return "nem"
		}()},
		{"Platform", "Go BBS v2.0"},
	}

	for _, row := range rows {
		send(conn, fmt.Sprintf("  %s%-18s%s  %s%s%s\r\n", GY, row[0], R, WH, row[1], R))
	}
	pause(conn)
}
