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
