package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

type litellm struct {
	url       string
	masterKey string
	client    *http.Client
}

func newLiteLLM(url, masterKey string) *litellm {
	return &litellm{url: url, masterKey: masterKey, client: &http.Client{Timeout: 10 * time.Second}}
}

func (l *litellm) post(path string, body any) error {
	data, err := json.Marshal(body)
	if err != nil {
		return err
	}
	req, err := http.NewRequest("POST", l.url+path, bytes.NewReader(data))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+l.masterKey)
	req.Header.Set("Content-Type", "application/json")
	resp, err := l.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		msg, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
		return fmt.Errorf("litellm %s: %d %s", path, resp.StatusCode, msg)
	}
	return nil
}

func (l *litellm) createTeam(id, alias string) error {
	return l.post("/team/new", map[string]any{
		"team_id":    id,
		"team_alias": alias,
		"max_budget": 10,
		"rpm_limit":  60,
	})
}

func (l *litellm) deleteTeam(id string) error {
	return l.post("/team/delete", map[string]any{"team_ids": []string{id}})
}
