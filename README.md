# Quote Recall

A small iPhone app for learning exam quotes by typing them from memory, with hints that fade as you improve and spaced repetition.

## How it works

- Each card has a character, a moment (your prompt), the quote and some themes.
- New cards show the first letter of every word. As you get a card right, the hint shrinks to just the first word, then disappears.
- Wrong answers come back later in the same session and reset to full hints.
- Review gaps grow from 10 minutes to 1, 2, 4 and 7 days.
- Marking ignores capitals and punctuation and allows small typos. Missed words are shown in red.
- Filter by theme to drill, say, every Responsibility quote.

## Build

Every push to `main` builds an unsigned IPA on GitHub Actions (XcodeGen plus xcodebuild, no Mac needed) and publishes it to the `latest` release:

`https://github.com/<you>/quote-recall/releases/download/latest/QuoteRecall.ipa`

Sign and install it with Feather.
