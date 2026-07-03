# Dots Capture (Chrome)

Captures the page you're reading — logged-in, rendered, exactly as you see
it — straight into your Dots vault. Selected text additionally lands as an
extraction idea linked to the saved source. Works even when the Dots app
is closed (the native host writes the files directly).

## Install (development)

1. `chrome://extensions` → enable Developer mode → **Load unpacked** →
   pick this `apps/chrome` directory.
2. Copy the extension's ID from the card.
3. `./install-host.sh <that-id>` — builds `tools/dots-capture-host` and
   registers it with Chrome.
4. Restart Chrome.

## Use

- Click the Dots toolbar button, or press **⌥⇧D**.
- Whole page → saved as a source. With a selection → source **plus** an
  extraction idea (quote-provenance, source-linked).
- Badge: green ✓ saved · red ! failed (no vault set up, or host not
  installed).

Web Store packaging and Safari support are not included yet.
