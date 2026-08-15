package selftest

import "testing"

func TestGreeting(t *testing.T) {
	// "de" is intentionally left uncovered so the profile is non-trivial.
	for lang, want := range map[string]string{"tr": "merhaba", "en": "hello"} {
		if got := Greeting(lang); got != want {
			t.Errorf("Greeting(%q) = %q, want %q", lang, got, want)
		}
	}
}
