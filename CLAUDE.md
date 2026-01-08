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

## Patching System

There are two different patching mechanisms:

### 1. patches.sh - For Debian Packaging Files
The `patches.sh` script modifies bloom-generated **Debian packaging files** (debian/control, debian/rules) during the build process.

**When to use patches.sh:**
- Replacing dependencies (e.g., ROS packages with Debian system packages)
- Adding Conflicts/Replaces/Provides fields to debian/control
- Fixing package names or library paths in debian/rules
- Any modification to debian/ directory files

**How to add a patch:**
1. Add a new case statement to `patches.sh`
2. Use the package path relative to workspace (e.g., `src/ros2/urdf/urdf_parser_plugin`)
3. Use `sed -i` to modify files in `$WS/$PKG_PATH/debian/`
4. Script runs automatically during build

**Example:**
```bash
"src/ros2/urdf/urdf_parser_plugin")
  # Use Debian's liburdfdom-headers-dev instead of ros-jazzy-urdfdom-headers
  sed -i 's/ros-jazzy-urdfdom-headers/liburdfdom-headers-dev/g' \
    $WS/$PKG_PATH/debian/control
  ;;
```

### 2. patches/ Directory - For ROS 2 Source Files
The `patches/` directory contains replacement files for **ROS 2 source code** that need modifications.

**When to use patches/ directory:**
- Fixing C++ or Python source code bugs
- Modifying CMakeLists.txt or package.xml
- Replacing template files or generated code
- Any changes to the actual ROS 2 package source

**Structure:**
- Mirror the workspace structure: `patches/src/ros2/package_name/file.cpp`
- Files in patches/ completely replace the original source files
- Applied automatically by build.sh before building

**Important Distinctions:**
- `patches.sh` = modifies Debian packaging (debian/ directory)
- `patches/` = replaces ROS 2 source files (everything else)
- Use the appropriate mechanism for your changes

## Build Script Usage

### Building Specific Packages
```bash
./build.sh <package_path>
```

Where `<package_path>` is the relative path from the workspace root to the package directory containing `package.xml`.

**Examples:**
```bash
# Build a single package by path
./build.sh src/ros2/rosidl/rosidl_cmake

# Build all packages (no arguments)
./build.sh
```

**Notes:**
- The script automatically changes to the workspace directory (defaults to ros2_base/)
- Package path must be relative to the workspace, not absolute
- When building a specific package, the script sets `force_build=1`
