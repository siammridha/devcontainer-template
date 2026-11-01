# syntax=docker/dockerfile:1
# The `syntax` line above turns on two BuildKit features used below: cache
# mounts (`--mount=type=cache`), which keep cargo's downloads and build
# output between image rebuilds, and multi-stage builds, which let the dev
# CLIs below compile in a separate stage that runs in parallel with the
# unrelated installs later in this file instead of blocking them.

# The plain Alpine devcontainer base (what devcontainers/rust builds on), so we
# don't inherit the rust image's metadata that force-installs VS Code
# extensions (rust-analyzer, CodeLLDB, Even Better TOML).
FROM mcr.microsoft.com/devcontainers/base:alpine AS base

# Toolchain deps the base image lacks: a C linker for rustc, plus pkg-config /
# OpenSSL headers commonly needed by Rust crates.
RUN apk add --no-cache build-base pkgconf openssl-dev


# Dev CLIs: the test runner (cargo nextest), the file watcher (bacon), and the
# browser-test driver (agent-browser). Built in their own stage (from `base`)
# so BuildKit can run this compile-heavy work in parallel with the unrelated
# installs in the main stage below, instead of making them wait behind it.
#
# `cargo install` with several crates in one command builds them one at a
# time, and even a single crate's own dependency graph often narrows to one
# compileable crate at a time (e.g. everything blocked on a proc-macro crate
# like `serde`/`syn` finishing) - both leave cores idle. Running the three
# installs as separate, concurrent processes gives cargo three independent
# dependency graphs to pull work from at once, so a stall in one doesn't
# stall the others.
#
# Each install gets its own `--target-dir` cache mount rather than sharing
# one: cargo holds an exclusive lock on a target dir while building, so
# concurrent installs sharing one would just serialize behind that lock,
# undoing the point of running them concurrently. The crates.io registry/git
# cache is shared across all three, and persists across future image
# rebuilds too, since cargo already manages safe concurrent access to it and
# a cache mount survives even when the layer using it gets rebuilt.
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

# Chromium for the agent-browser browser test. Chrome for Testing has no arm64
# build, so the test drives this system Chromium at /usr/bin/chromium.
# jq is used below to edit the Claude Code user prefs file (.claude.json).
RUN apk add --no-cache jq

# Keep ALL Claude state (including what would otherwise be ~/.claude.json) in
# one directory, so a single volume mount persists login + sessions.
ENV CLAUDE_CONFIG_DIR=/home/vscode/.claude

# The native installer is a PER-USER install: it drops the binary in
# ~/.local/bin for whoever runs it. So Claude Code (and the user-scope plugin
# below) are installed as the vscode user, and ~/.local/bin is put on PATH.
# Updates happen via `claude update` / the background auto-updater, NOT apk.
ENV PATH=/home/vscode/.local/bin:$PATH
USER vscode

# Claude Code via Anthropic's native installer. Needs bash + the musl runtime
# deps (libgcc, libstdc++, ripgrep) installed in the first apk layer above.
RUN curl -fsSL https://claude.ai/install.sh | bash

# Stop Claude Code from auto-installing its VS Code extension when `claude`
# runs in the integrated terminal. This is a /config toggle, not a
# settings.json field, so it lives in .claude.json instead. Baked into the
# image (not just set live) so it also lands in the fresh claude-config
# volume that gets created for any new clone/rebuild of this devcontainer.
RUN jq '.autoInstallIdeExtension = false' "$CLAUDE_CONFIG_DIR/.claude.json" > /tmp/claude.json.tmp \
    && mv /tmp/claude.json.tmp "$CLAUDE_CONFIG_DIR/.claude.json"

USER root
