# devcontainer-template

Everything needed to start a new Rust project in a VS Code dev container
with Claude Code:

- `base/` – the shared `devbase` image (Rust, cargo-nextest, bacon,
  agent-browser, Chromium, gh, jq, Claude Code and its status line script).
  Published as `ghcr.io/siammridha/devbase`.
- `template/` – the files copied into each new project: `.devcontainer/`,
  `.claude/`, `CLAUDE.md` and `hooks/`.
- `new-project.sh` – copies `template/` into a project folder.
- `release-devbase.sh` – builds the `devbase` image on your Mac and pushes it.
- `.devcontainer/` – the dev container for working on this repo itself.

## Start a new project

```sh
git clone https://github.com/siammridha/devcontainer-template.git
./devcontainer-template/new-project.sh ~/code/my_project
```

Then open `~/code/my_project` in VS Code and choose "Reopen in Container".
The project's Dockerfile starts `FROM ghcr.io/siammridha/devbase:latest`;
add project-only tools there.

The template expects these in your Mac's shell profile:

- `GH_TOKEN` – used by `gh` inside the container.
- `CLAUDE_CODE_OAUTH_TOKEN` – a long-lived token from `claude setup-token`.

## Release a new devbase image

1. Change `base/` and push to `main`.
2. Tag and push the tag:

   ```sh
   git tag v1.1.0
   git push origin v1.1.0
   ```

GitHub Actions (`.github/workflows/build-devbase.yml`) builds the image for
`linux/arm64` only (Apple Silicon) and pushes it tagged `1.1.0` and `latest`.

### Or build it on your Mac

```sh
./release-devbase.sh          # next patch version, e.g. v1.0.1 → 1.0.2
./release-devbase.sh 1.1.0    # a version you choose
```

It tags and pushes the commit, then builds `base/` with no cache, so Rust,
Claude Code and every other tool are the newest versions. It needs Docker and
a one-time `docker login ghcr.io` with a token that has `write:packages`.
The tag push also starts the GitHub Actions build above.

To use the new image in a project, pull it and rebuild the container:

```sh
docker pull ghcr.io/siammridha/devbase:latest
```

then "Dev Containers: Rebuild Container" in VS Code.
