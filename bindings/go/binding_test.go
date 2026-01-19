// binding_test.go
// Qompass AI - [ ]
// Copyright (C) 2026 Qompass AI, All rights reserved
// ----------------------------------------
package tree_sitter_comment_test

import (
	"testing"

	tree_sitter "github.com/tree-sitter/go-tree-sitter"
	tree_sitter_comment "github.com/oxy2dev/tree-sitter-comment/bindings/go"
)

func TestCanLoadGrammar(t *testing.T) {
	language := tree_sitter.NewLanguage(tree_sitter_comment.Language())
	if language == nil {
		t.Errorf("Error loading DocText grammar")
	}
}