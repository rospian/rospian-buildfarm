#!/bin/bash
SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
WS="$(dirname "$SCRIPT_PATH")"
PKG_PATH="${1:-}"

if [ $PKG_PATH == "src/gazebo-release/gz_cmake_vendor" ]; then
  sed -i 's/pkg-config, /pkg-config, vcstool, /' \
    $WS/src/gazebo-release/gz_cmake_vendor/debian/control
fi

if [ $PKG_PATH == "src/ros2/rosidl_dynamic_typesupport" ]; then
  sed -i 's/librosidl-runtime-c-cpp-dev, /&ros-jazzy-rosidl-runtime-c, /' \
    $WS/src/ros2/rosidl_dynamic_typesupport/debian/control
fi

if [ $PKG_PATH == "src/ros2/rmw/rmw" ]; then
  sed -i 's/librosidl-runtime-c-cpp-dev, /&ros-jazzy-rosidl-runtime-c, /' \
    $WS/src/ros2/rmw/rmw/debian/control
fi

if [ $PKG_PATH == "src/ros2/mimick_vendor" ]; then
  sed -i 's/ament-lint <!nocheck>/ament-lint <!nocheck>, vcstool, git, ca-certificates/' \
    $WS/src/ros2/mimick_vendor/debian/control
fi

if [ $PKG_PATH == "src/ros2/rcl_interfaces/action_msgs" ]; then
  sed -i 's/ros-jazzy-unique-identifier-msgs/ros-jazzy-unique-identifier-msgs,/' \
    $WS/src/ros2/rcl_interfaces/action_msgs/debian/control
  sed -i '/^Build-Depends:/a\
    ros-jazzy-rosidl-cmake (>= 4.6.7),\
    ros-jazzy-rosidl-generator-c (>= 4.6.7),\
    ros-jazzy-rosidl-generator-cpp (>= 4.6.7),\
    ros-jazzy-rosidl-generator-type-description (>= 4.6.7),\
    ros-jazzy-rosidl-adapter (>= 4.6.7),\
    ros-jazzy-rosidl-parser (>= 4.6.7),\
    ros-jazzy-rosidl-pycommon (>= 4.6.7),\
    ros-jazzy-rosidl-cli (>= 4.6.7),\
    ros-jazzy-rpyutils (>= 0.4.2), \
    ros-jazzy-rosidl-typesupport-interface (>= 4.6.7),\
    ros-jazzy-rosidl-typesupport-c (>= 3.2.2),\
    ros-jazzy-rosidl-typesupport-cpp (>= 3.2.2)' \
    $WS/src/ros2/rcl_interfaces/action_msgs/debian/control
fi

if [ $PKG_PATH == "src/ros2/rosidl/rosidl_cli" ]; then
  # Drop stray pytest caches in python installs to avoid file clashes
  sed -i 's|dh_auto_install$|dh_auto_install \\&\\& \\\\|;s|^\\(.*dh_auto_install \\\\&\\\\& \\\\)$|\\1\\n\\tfind debian/ros-jazzy-rosidl-cli -path \"*/.pytest_cache\" -prune -exec rm -rf {} +|' \
    $WS/src/ros2/rosidl/rosidl_cli/debian/rules
fi

if [ $PKG_PATH == "src/ros2/rpyutils" ]; then
  sed -i 's|dh_auto_install$|dh_auto_install \\&\\& \\\\|;s|^\\(.*dh_auto_install \\\\&\\\\& \\\\)$|\\1\\n\\tfind debian/ros-jazzy-rpyutils -path \"*/.pytest_cache\" -prune -exec rm -rf {} +|' \
    $WS/src/ros2/rpyutils/debian/rules
fi

if [ $PKG_PATH == "src/ros2/rcl_interfaces/builtin_interfaces" ]; then
    sed -i 's/ros-jazzy-rosidl-core-generators/ros-jazzy-rosidl-core-generators,/' \
      $WS/src/ros2/rcl_interfaces/builtin_interfaces/debian/control
    sed -i '/^Build-Depends:/a\
      ros-jazzy-rosidl-cmake (>= 4.6.7),\
      ros-jazzy-rosidl-generator-c (>= 4.6.7),\
      ros-jazzy-rosidl-generator-cpp (>= 4.6.7),\
      ros-jazzy-rosidl-generator-type-description (>= 4.6.7),\
      ros-jazzy-rosidl-adapter (>= 4.6.7),\
      ros-jazzy-rosidl-parser (>= 4.6.7),\
      ros-jazzy-rosidl-pycommon (>= 4.6.7),\
      ros-jazzy-rosidl-cli (>= 4.6.7),\
      ros-jazzy-rpyutils (>= 0.4.2)' \
      $WS/src/ros2/rcl_interfaces/builtin_interfaces/debian/control
    sed -i '/^override_dh_auto_install:/a\
    override_dh_installdeb:\\n\\tdh_installdeb\\n\\tdh_lintian\\n' \
      $WS/src/ros2/rcl_interfaces/builtin_interfaces/debian/rules
fi

if [ $PKG_PATH == "src/ros2/rosidl/rosidl_cmake" ]; then
  # Make ros-jazzy-rosidl-cmake replace the Debian system rosidl-cmake package
  # to ensure our newer version (with INCLUDE_PATHS support) is used
  sed -i '/^Depends:/a\
Conflicts: rosidl-cmake\
Replaces: rosidl-cmake\
Provides: rosidl-cmake' \
    $WS/src/ros2/rosidl/rosidl_cmake/debian/control
fi

if [ $PKG_PATH == "src/ros2/common_interfaces/actionlib_msgs" ]; then
  # Add explicit dependencies on ros-jazzy-rosidl stack and ros-jazzy-std-msgs to avoid using outdated Debian packages
  sed -i 's/ros-std-msgs$/&,/' \
    $WS/src/ros2/common_interfaces/actionlib_msgs/debian/control
  sed -i '/ros-std-msgs,$/a\
  ros-jazzy-std-msgs,\
  ros-jazzy-rosidl-cmake (>= 4.6.7),\
  ros-jazzy-rosidl-generator-c (>= 4.6.7),\
  ros-jazzy-rosidl-generator-cpp (>= 4.6.7),\
  ros-jazzy-rosidl-generator-type-description (>= 4.6.7),\
  ros-jazzy-rosidl-adapter (>= 4.6.7),\
  ros-jazzy-rosidl-parser (>= 4.6.7),\
  ros-jazzy-rosidl-pycommon (>= 4.6.7),\
  ros-jazzy-rosidl-cli (>= 4.6.7),\
  ros-jazzy-rpyutils (>= 0.4.2)' \
    $WS/src/ros2/common_interfaces/actionlib_msgs/debian/control
fi

if [ $PKG_PATH == "src/ros2/common_interfaces/std_msgs" ]; then
  # Add explicit dependencies on ros-jazzy-rosidl stack to avoid using outdated Debian packages
  sed -i 's/ros-jazzy-rosidl-default-generators$/&,/' \
    $WS/src/ros2/common_interfaces/std_msgs/debian/control
  sed -i '/ros-jazzy-rosidl-default-generators,$/a\
  ros-jazzy-rosidl-cmake (>= 4.6.7),\
  ros-jazzy-rosidl-generator-c (>= 4.6.7),\
  ros-jazzy-rosidl-generator-cpp (>= 4.6.7),\
  ros-jazzy-rosidl-generator-type-description (>= 4.6.7),\
  ros-jazzy-rosidl-adapter (>= 4.6.7),\
  ros-jazzy-rosidl-parser (>= 4.6.7),\
  ros-jazzy-rosidl-pycommon (>= 4.6.7),\
  ros-jazzy-rosidl-cli (>= 4.6.7),\
  ros-jazzy-rpyutils (>= 0.4.2)' \
    $WS/src/ros2/common_interfaces/std_msgs/debian/control
  # Make ros-jazzy-std-msgs replace the Debian ROS 1 std_msgs packages
  sed -i '/^Depends:/a\
Conflicts: libstd-msgs-dev, python3-std-msgs, ros-std-msgs\
Replaces: libstd-msgs-dev, python3-std-msgs, ros-std-msgs\
Provides: libstd-msgs-dev, python3-std-msgs, ros-std-msgs' \
    $WS/src/ros2/common_interfaces/std_msgs/debian/control
fi

#
# Universal patch: Apply to any package with rosidl_default_generators that wasn't already patched above
#
# Skip if already patched (check if ros-jazzy-rosidl-cmake is already in control file)
if [ -f "$WS/$PKG_PATH/debian/control" ]; then
  if ! grep -q "ros-jazzy-rosidl-cmake" "$WS/$PKG_PATH/debian/control" 2>/dev/null; then
    if grep -q "ros-jazzy-rosidl-default-generators" "$WS/$PKG_PATH/debian/control" 2>/dev/null; then
      # Add explicit rosidl stack dependencies to avoid using outdated Debian packages
      # Replace ros-jazzy-rosidl-default-generators with itself plus all the versioned dependencies
      sed -i 's/ros-jazzy-rosidl-default-generators/&, ros-jazzy-rosidl-cmake (>= 4.6.7), ros-jazzy-rosidl-generator-c (>= 4.6.7), ros-jazzy-rosidl-generator-cpp (>= 4.6.7), ros-jazzy-rosidl-generator-type-description (>= 4.6.7), ros-jazzy-rosidl-adapter (>= 4.6.7), ros-jazzy-rosidl-parser (>= 4.6.7), ros-jazzy-rosidl-pycommon (>= 4.6.7), ros-jazzy-rosidl-cli (>= 4.6.7), ros-jazzy-rpyutils (>= 0.4.2)/' "$WS/$PKG_PATH/debian/control"

      # If package depends on std_msgs, replace ros-std-msgs with ros-jazzy-std-msgs
      if grep -q "ros-std-msgs" "$WS/$PKG_PATH/debian/control" 2>/dev/null; then
        # Replace first occurrence of ros-std-msgs with ros-jazzy-std-msgs in Build-Depends
        sed -i '0,/ros-std-msgs/{s/ros-std-msgs/ros-jazzy-std-msgs/}' "$WS/$PKG_PATH/debian/control"
      fi
    fi
  fi
fi
