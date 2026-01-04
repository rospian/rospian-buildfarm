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

if [ $PKG_PATH == "src/ros2/rosidl/rosidl_generator_c" ]; then
  # Make ros-jazzy-rosidl-generator-c replace the Debian system rosidl-generator-c-cpp package
  # to ensure our newer version (with updated templates) is used
  sed -i '/^Depends:/a\
Conflicts: rosidl-generator-c-cpp\
Replaces: rosidl-generator-c-cpp\
Provides: rosidl-generator-c-cpp' \
    $WS/src/ros2/rosidl/rosidl_generator_c/debian/control
  # Replace librosidl-typesupport-interface-dev dependency with ros-jazzy-rosidl-typesupport-interface
  sed -i 's/librosidl-typesupport-interface-dev/ros-jazzy-rosidl-typesupport-interface/' \
    $WS/src/ros2/rosidl/rosidl_generator_c/debian/control
fi

if [ $PKG_PATH == "src/ros2/rosidl/rosidl_typesupport_interface" ]; then
  # Make ros-jazzy-rosidl-typesupport-interface replace the Debian librosidl-typesupport-interface-dev package
  # to ensure our newer version (with updated macros for service event messages) is used
  sed -i '/^Depends:/a\
Conflicts: librosidl-typesupport-interface-dev\
Replaces: librosidl-typesupport-interface-dev\
Provides: librosidl-typesupport-interface-dev' \
    $WS/src/ros2/rosidl/rosidl_typesupport_interface/debian/control
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

if [ $PKG_PATH == "src/ros2/common_interfaces/geometry_msgs" ]; then
  # Make ros-jazzy-geometry-msgs replace the Debian ROS 1 geometry_msgs packages
  sed -i '/^Depends:/a\
Conflicts: libgeometry-msgs-dev, python3-geometry-msgs, ros-geometry-msgs\
Replaces: libgeometry-msgs-dev, python3-geometry-msgs, ros-geometry-msgs\
Provides: libgeometry-msgs-dev, python3-geometry-msgs, ros-geometry-msgs' \
    $WS/src/ros2/common_interfaces/geometry_msgs/debian/control
  # Remove Debian ROS 1 std_msgs package names and replace ros-std-msgs with ros-jazzy-std-msgs
  sed -i 's/, libstd-msgs-dev, python3-std-msgs//g' \
    $WS/src/ros2/common_interfaces/geometry_msgs/debian/control
  sed -i 's/ros-std-msgs/ros-jazzy-std-msgs/g' \
    $WS/src/ros2/common_interfaces/geometry_msgs/debian/control
fi

if [ $PKG_PATH == "src/ros2/common_interfaces/sensor_msgs" ]; then
  # Make ros-jazzy-sensor-msgs replace the Debian ROS 1 sensor_msgs packages
  sed -i '/^Depends:/a\
Conflicts: libsensor-msgs-dev, python3-sensor-msgs, ros-sensor-msgs\
Replaces: libsensor-msgs-dev, python3-sensor-msgs, ros-sensor-msgs\
Provides: libsensor-msgs-dev, python3-sensor-msgs, ros-sensor-msgs' \
    $WS/src/ros2/common_interfaces/sensor_msgs/debian/control
  # Replace Debian ROS 1 message packages with ros-jazzy-* in both Build-Depends and Depends
  sed -i 's/libgeometry-msgs-dev, libstd-msgs-dev, python3-geometry-msgs, python3-std-msgs, ros-geometry-msgs/ros-jazzy-geometry-msgs/g' \
    $WS/src/ros2/common_interfaces/sensor_msgs/debian/control
  sed -i 's/ros-std-msgs/ros-jazzy-std-msgs/g' \
    $WS/src/ros2/common_interfaces/sensor_msgs/debian/control
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

      # Remove Debian ROS 1 message package names (lib*-msgs-dev, python3-*-msgs) from Build-Depends and Depends
      # This prevents apt from installing Debian's old ROS 1 message packages
      sed -i 's/, libgeometry-msgs-dev, python3-geometry-msgs//g' "$WS/$PKG_PATH/debian/control"
      sed -i 's/, libsensor-msgs-dev, python3-sensor-msgs//g' "$WS/$PKG_PATH/debian/control"
      sed -i 's/, libstd-msgs-dev, python3-std-msgs//g' "$WS/$PKG_PATH/debian/control"
      sed -i 's/, libnav-msgs-dev, python3-nav-msgs//g' "$WS/$PKG_PATH/debian/control"
      sed -i 's/, libshape-msgs-dev, python3-shape-msgs//g' "$WS/$PKG_PATH/debian/control"
      sed -i 's/, libstereo-msgs-dev, python3-stereo-msgs//g' "$WS/$PKG_PATH/debian/control"
      sed -i 's/, libtrajectory-msgs-dev, python3-trajectory-msgs//g' "$WS/$PKG_PATH/debian/control"

      # Replace ALL ros-*-msgs (ROS 1) with ros-jazzy-*-msgs (ROS 2) in both Build-Depends and Depends
      sed -i 's/ros-geometry-msgs/ros-jazzy-geometry-msgs/g' "$WS/$PKG_PATH/debian/control"
      sed -i 's/ros-sensor-msgs/ros-jazzy-sensor-msgs/g' "$WS/$PKG_PATH/debian/control"
      sed -i 's/ros-std-msgs/ros-jazzy-std-msgs/g' "$WS/$PKG_PATH/debian/control"
      sed -i 's/ros-nav-msgs/ros-jazzy-nav-msgs/g' "$WS/$PKG_PATH/debian/control"
      sed -i 's/ros-shape-msgs/ros-jazzy-shape-msgs/g' "$WS/$PKG_PATH/debian/control"
      sed -i 's/ros-stereo-msgs/ros-jazzy-stereo-msgs/g' "$WS/$PKG_PATH/debian/control"
      sed -i 's/ros-trajectory-msgs/ros-jazzy-trajectory-msgs/g' "$WS/$PKG_PATH/debian/control"
    fi
  fi
fi
