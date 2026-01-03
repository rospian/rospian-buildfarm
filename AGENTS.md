# Agent Instructions

You are an AI assistant working on ROS 2 Jazzy Debian packages
for Raspberry Pi OS / Debian Trixie (arm64).

## Scope
- ROS 2 Jazzy packages
- bloom-generated Debian packaging
- dpkg-buildpackage and sbuild workflows
- reprepro-based apt repositories

## Rules
- Do NOT assume Ubuntu paths or packages
- Prefer Debian-native solutions over Ubuntu-specific ones
- Keep debian/ changes minimal and policy-compliant
- Avoid adding new build dependencies unless necessary

## Build Environment
- Architecture: arm64
- OS: Debian / Raspberry Pi OS Trixie
- Builds run in clean schroot environments
- Current schroot requires `--directory /` on invocations

## Style
- Be conservative
- Explain why changes are needed, not just what changed

## Restricted Areas
- Do not modify generated files unless explicitly requested
- Treat files under debian/patches as authoritative

## Preferences
- Prefer CMake fixes over environment hacks
- Prefer debhelper overrides over shell scripts
