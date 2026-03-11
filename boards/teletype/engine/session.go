package engine

import "sync"

// State holds shared server state (thread-safe)
type State struct {
	OnlineUsers map[string]string // addr -> username
	Mu          sync.Mutex
}

func newState() *State {
	return &State{
		OnlineUsers: make(map[string]string),
	}
}

// UserCount returns the number of online users in a thread-safe manner
func (st *State) UserCount() int {
	st.Mu.Lock()
	defer st.Mu.Unlock()
	return len(st.OnlineUsers)
}

// Snapshot returns a thread-safe copy of the online users map
func (st *State) Snapshot() map[string]string {
	st.Mu.Lock()
	defer st.Mu.Unlock()
	snap := make(map[string]string)
	for k, v := range st.OnlineUsers {
		snap[k] = v
	}
	return snap
}

// Session represents an active user connection
type Session struct {
	State    *State
	Printer  *Printer
	Username string
	Addr     string
	Lang     T
	Quit     bool
}
