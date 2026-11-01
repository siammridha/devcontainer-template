# syntax=docker/dockerfile:1
# The shared "devbase" image every project's devcontainer builds FROM. It holds
# everything the projects have in common, so Docker stores it once instead of
# once per project; each project's own Dockerfile adds only its extras.
#
# Built by GitHub Actions (.github/workflows/build-devbase.yml) when a v* tag
# is pushed, and published as ghcr.io/siammridha/devbase:latest. To pick up a
# new release, run "Rebuild Container" in each project (with the "pull"
# option, or after `docker pull ghcr.io/siammridha/devbase:latest`).

FROM mcr.microsoft.com/devcontainers/base:alpine AS base

# Toolchain deps the base image lacks: a C linker for rustc, plus pkg-config /
# OpenSSL headers commonly needed by Rust crates.
RUN apk add --no-cache build-base pkgconf openssl-dev

ENV CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path \
        --default-toolchain stable --profile minimal \
        -c rustfmt -c clippy -c rust-src -c rust-analyzer \
    && chown -R vscode:vscode /usr/local/cargo /usr/local/rustup


# Dev CLIs: the test runner (cargo nextest), the file watcher (bacon), and the
# browser-test driver (agent-browser). Built in their own stage so BuildKit
# runs this compile-heavy work in parallel with the main stage below, as three
# concurrent installs (each with its own target dir, since cargo locks a
# target dir while building) so a stall in one doesn't idle the others.
FROM base AS tools
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/usr/local/cargo-target-nextest \
    --mount=type=cache,target=/usr/local/cargo-target-bacon \
    --mount=type=cache,target=/usr/local/cargo-target-agent-browser \
    cargo install --locked --target-dir /usr/local/cargo-target-nextest cargo-nextest & pid1=$!; \
    cargo install --locked --target-dir /usr/local/cargo-target-bacon bacon & pid2=$!; \
    cargo install --locked --target-dir /usr/local/cargo-target-agent-browser agent-browser & pid3=$!; \
    wait "$pid1" && wait "$pid2" && wait "$pid3"

FROM base

# Chromium for agent-browser (Chrome for Testing has no arm64 build, so tests
# drive this system Chromium at /usr/bin/chromium), gh, and jq (used below to
# edit Claude Code's config files).
RUN apk add --no-cache chromium github-cli jq

# Mount points for the template's volumes, plus cargo-target (CARGO_TARGET_DIR,
# not a volume, so build output goes away with the container). A fresh (empty)
# named volume takes the ownership of the directory it's mounted over, so
# creating them here as vscode keeps them writable by vscode, not root-owned.
RUN mkdir -p /usr/local/cargo/registry /usr/local/cargo/git /home/vscode/cargo-target \
    && chown vscode:vscode /usr/local/cargo/registry /usr/local/cargo/git /home/vscode/cargo-target

# Keep ALL Claude state (including what would otherwise be ~/.claude.json) in
# one directory, so a single volume mount persists sessions and settings.
ENV CLAUDE_CONFIG_DIR=/home/vscode/.claude

# The native installer is a PER-USER install into ~/.local/bin, so Claude Code
# and its plugins are installed as vscode. Updates happen via `claude update`.
ENV PATH=/home/vscode/.local/bin:$PATH
USER vscode
RUN curl -fsSL https://claude.ai/install.sh | bash
RUN claude plugin marketplace add DietrichGebert/ponytail && \
    claude plugin marketplace add anthropics/claude-plugins-official && \
    (claude plugin install ponytail@ponytail || echo "Warning: plugin install failed, continuing build") && \
    (claude plugin install rust-analyzer-lsp@claude-plugins-official || echo "Warning: plugin install failed, continuing build")

# Don't auto-install the VS Code extension (a /config toggle in .claude.json),
# and use the shared status line script. Baked in here so they land in each
# project's claude-config volume when it's first created.
RUN cd "$CLAUDE_CONFIG_DIR" \
    && for f in .claude.json settings.json; do [ -f "$f" ] || echo '{}' > "$f"; done \
    && jq '.autoInstallIdeExtension = false' .claude.json > /tmp/c.json && mv /tmp/c.json .claude.json \
    && jq '.statusLine = {"type": "command", "command": "claude-statusline"}' settings.json > /tmp/s.json \
    && mv /tmp/s.json settings.json

USER root
COPY --chmod=755 statusline-command.sh /usr/local/bin/claude-statusline
COPY --from=tools --chown=vscode:vscode \
    /usr/local/cargo/bin/cargo-nextest \
    /usr/local/cargo/bin/bacon \
    /usr/local/cargo/bin/agent-browser \
    /usr/local/cargo/bin/
