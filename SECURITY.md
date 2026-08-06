# Security policy

Org-wide default. A repository with its own `SECURITY.md` overrides this; it
applies to the rest.

## Reporting a vulnerability

Report privately through GitHub's **Report a vulnerability** button under the
repository's Security tab. That opens a private advisory only the maintainers
can see.

Please do not open a public issue for anything exploitable.

Include what you have: affected version or commit, how to reproduce, and what
an attacker gets out of it. A rough report is more useful than none.

Expect an acknowledgement within a week. These are hobby projects maintained by
one person, so a fix may take longer — you will be told where it stands rather
than left waiting.

## Scope

These tools run locally or self-hosted, against services you control, with
credentials you supply. The interesting classes are therefore:

- **Parsing attacker-influenced input.** Scrapers and downloaders consume HTML
  and JSON from remote sites and turn it into SQL, file paths, and XML. Path
  traversal via a crafted filename, or injection through scraped metadata,
  is in scope.
- **Credential handling.** API keys and tokens in config files, and anything
  that leaks them into logs, error messages, or CI output.
- **Supply chain.** Release artifacts and container images are built by the
  shared workflows in this org and carry SLSA build attestations. Anything
  that would let a release be forged is in scope.

Out of scope: vulnerabilities in Stash itself (report those to
[stashapp/stash](https://github.com/stashapp/stash)), and in the remote sites
these tools read from.

## Verifying releases

Every release artifact is hashed in `SHA256SUMS` and carries a SLSA v1 build
attestation binding it to the workflow run and commit that produced it:

```sh
gh attestation verify <artifact> --owner Anastylosis
```

A checksum proves a download arrived intact; the attestation is what proves
where it came from.
