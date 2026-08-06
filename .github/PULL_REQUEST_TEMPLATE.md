<!--
Org-wide default PR template. Delete any section that doesn't apply — an empty
heading is worse than no heading.
-->

## What this changes

<!-- One or two sentences. The diff says what; say why. -->

## Why

<!-- What problem does this solve? Link the issue if there is one: Fixes #123 -->

## How it was verified

<!--
Not "tests pass" — which tests, and what would have failed before this change?
For a parser or scraper fix, name the fixture you added.
-->

- [ ] `make test` passes locally
- [ ] `make lint` passes locally
- [ ] Added a test that fails without this change (or explained why not below)
- [ ] No unit test added that touches the network

## Anything the reviewer should look at closely

<!--
Where you're unsure, where you made a judgement call, where you'd expect
disagreement. Silence here reads as "this is all routine".
-->
