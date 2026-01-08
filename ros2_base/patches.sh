#!/bin/bash
SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
WS="$(dirname "$SCRIPT_PATH")"
PKG_PATH="${1:-}"
patched=0

patched=1
case "$PKG_PATH" in
  src/*/*_vendor)
    sed -i 's/\(Build-Depends:.*\)$/\1, vcstool, git, ca-certificates/' \
      $WS/$PKG_PATH/debian/control
    ;;

  "src/ros2/rosidl_dynamic_typesupport")
    sed -i 's/librosidl-runtime-c-cpp-dev, /&ros-jazzy-rosidl-runtime-c, /' \
      $WS/$PKG_PATH/debian/control
    ;;

  "src/ros2/rmw/rmw")
    sed -i 's/librosidl-runtime-c-cpp-dev, /&ros-jazzy-rosidl-runtime-c, /' \
      $WS/$PKG_PATH/debian/control
    ;;

  "src/ros2/rosidl/rosidl_cli")
    # Drop stray pytest caches in python installs to avoid file clashes
    sed -i 's|dh_auto_install$|dh_auto_install \\&\\& \\\\|;s|^\\(.*dh_auto_install \\\\&\\\\& \\\\)$|\\1\\n\\tfind debian/ros-jazzy-rosidl-cli -path \"*/.pytest_cache\" -prune -exec rm -rf {} +|' \
      $WS/$PKG_PATH/debian/rules
    ;;

  "src/ros2/rpyutils")
    sed -i 's|dh_auto_install$|dh_auto_install \\&\\& \\\\|;s|^\\(.*dh_auto_install \\\\&\\\\& \\\\)$|\\1\\n\\tfind debian/ros-jazzy-rpyutils -path \"*/.pytest_cache\" -prune -exec rm -rf {} +|' \
      $WS/$PKG_PATH/debian/rules
    ;;

  "src/ros2/rosidl/rosidl_cmake")
    # Make ros-jazzy-rosidl-cmake replace the Debian system rosidl-cmake package
    # to ensure our newer version (with INCLUDE_PATHS support) is used
    sed -i '/^Depends:/a\
Conflicts: rosidl-cmake\
Replaces: rosidl-cmake\
Provides: rosidl-cmake' \
      $WS/$PKG_PATH/debian/control
    ;;

  "src/ros2/rosidl/rosidl_generator_c")
    # Make ros-jazzy-rosidl-generator-c replace the Debian system rosidl-generator-c-cpp package
    # to ensure our newer version (with updated templates) is used
    sed -i '/^Depends:/a\
Conflicts: rosidl-generator-c-cpp\
Replaces: rosidl-generator-c-cpp\
Provides: rosidl-generator-c-cpp' \
      $WS/$PKG_PATH/debian/control
    # Replace librosidl-typesupport-interface-dev dependency with ros-jazzy-rosidl-typesupport-interface
    sed -i 's/librosidl-typesupport-interface-dev/ros-jazzy-rosidl-typesupport-interface/' \
      $WS/$PKG_PATH/debian/control
    ;;

  "src/ros2/rosidl/rosidl_typesupport_interface")
    # Make ros-jazzy-rosidl-typesupport-interface replace the Debian librosidl-typesupport-interface-dev package
    # to ensure our newer version (with updated macros for service event messages) is used
    sed -i '/^Depends:/a\
Conflicts: librosidl-typesupport-interface-dev\
Replaces: librosidl-typesupport-interface-dev\
Provides: librosidl-typesupport-interface-dev' \
      $WS/$PKG_PATH/debian/control
    ;;

  "src/ros2/common_interfaces/std_msgs")
    # Make ros-jazzy-std-msgs replace the Debian ROS 1 std_msgs packages
    sed -i '/^Depends:/a\
Conflicts: libstd-msgs-dev, python3-std-msgs, ros-std-msgs\
Replaces: libstd-msgs-dev, python3-std-msgs, ros-std-msgs\
Provides: libstd-msgs-dev, python3-std-msgs, ros-std-msgs' \
      $WS/$PKG_PATH/debian/control
    ;;

  "src/ros2/common_interfaces/geometry_msgs")
    # Make ros-jazzy-geometry-msgs replace the Debian ROS 1 geometry_msgs packages
    sed -i '/^Depends:/a\
Conflicts: libgeometry-msgs-dev, python3-geometry-msgs, ros-geometry-msgs\
Replaces: libgeometry-msgs-dev, python3-geometry-msgs, ros-geometry-msgs\
Provides: libgeometry-msgs-dev, python3-geometry-msgs, ros-geometry-msgs' \
      $WS/$PKG_PATH/debian/control
    ;;

  "src/ros2/common_interfaces/sensor_msgs")
    # Make ros-jazzy-sensor-msgs replace the Debian ROS 1 sensor_msgs packages
    sed -i '/^Depends:/a\
Conflicts: libsensor-msgs-dev, python3-sensor-msgs, ros-sensor-msgs\
Replaces: libsensor-msgs-dev, python3-sensor-msgs, ros-sensor-msgs\
Provides: libsensor-msgs-dev, python3-sensor-msgs, ros-sensor-msgs' \
      $WS/$PKG_PATH/debian/control
    ;;

  "src/ament/ament_cmake/ament_cmake_vendor_package")
    # Fix vcstool package name: Debian uses 'vcstool' not 'python3-vcstool'
    sed -i 's/python3-vcstool/vcstool/' \
      $WS/$PKG_PATH/debian/control
    ;;

  "src/ros2/urdf/urdf_parser_plugin")
    # Use Debian's liburdfdom-headers-dev instead of ros-jazzy-urdfdom-headers
    sed -i 's/ros-jazzy-urdfdom-headers/liburdfdom-headers-dev/g' \
      $WS/$PKG_PATH/debian/control
    ;;

  "src/ros2/urdf/urdf")
    # Use Debian's liburdfdom-dev instead of ros-jazzy-urdfdom and ros-jazzy-urdfdom-headers
    sed -i 's/ros-jazzy-urdfdom-headers/liburdfdom-headers-dev/g' \
      $WS/$PKG_PATH/debian/control
    sed -i 's/ros-jazzy-urdfdom/liburdfdom-dev/g' \
      $WS/$PKG_PATH/debian/control
    # Add system library path to dh_shlibdeps to find liburdfdom_model.so
    sed -i 's|\(dh_shlibdeps -l[^ ]*\)|\1:/usr/lib/aarch64-linux-gnu|' \
      $WS/$PKG_PATH/debian/rules
    ;;

  "src/ros/urdfdom")
    # Use Debian's liburdfdom-headers-dev instead of ros-jazzy-urdfdom-headers
    sed -i 's/ros-jazzy-urdfdom-headers/liburdfdom-headers-dev/g' \
      $WS/$PKG_PATH/debian/control
    ;;

  "src/ros/kdl_parser/kdl_parser")
    # Use Debian's liburdfdom-headers-dev instead of ros-jazzy-urdfdom-headers
    sed -i 's/ros-jazzy-urdfdom-headers/liburdfdom-headers-dev/g' \
      $WS/$PKG_PATH/debian/control
    ;;

  "src/eclipse-cyclonedds/cyclonedds")
    # Add LD_LIBRARY_PATH to override_dh_auto_build so idlc can find libiceoryx_posh.so
    # The idlc tool is built and executed during the build process, and needs to find
    # iceoryx libraries that were installed from earlier packages in the build sequence
    # Include both standard and multiarch lib directories
    sed -i '/override_dh_auto_build:/,/dh_auto_build/ {
      /setup\.sh.*; fi &&/s|; fi &&|; fi \&\& export LD_LIBRARY_PATH="/opt/ros/jazzy/lib:/opt/ros/jazzy/lib/${DEB_HOST_MULTIARCH}:$$LD_LIBRARY_PATH" \&\&|
    }' $WS/$PKG_PATH/debian/rules
    ;;

  *)
    patched=0
    ;;
esac

# Generic fix: if a package has dh_shlibdeps with -l but doesn't include
# /opt/ros/jazzy/lib, add it to find ROS libraries from build dependencies
if [ -f "$WS/$PKG_PATH/debian/rules" ] && \
   grep -q "dh_shlibdeps -l" "$WS/$PKG_PATH/debian/rules" && \
   ! grep -q "dh_shlibdeps.*:/opt/ros/jazzy/lib" "$WS/$PKG_PATH/debian/rules"; then
  sed -i 's|\(dh_shlibdeps -l.*\)$|\1:/opt/ros/jazzy/lib|' \
    $WS/$PKG_PATH/debian/rules
  echo "== Applied generic dh_shlibdeps fix to $PKG_PATH"
  patched=1
fi

if [ $patched -eq 1 ]; then
  echo "== Applied patches to $PKG_PATH"
fi
