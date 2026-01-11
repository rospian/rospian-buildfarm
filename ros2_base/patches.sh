#!/bin/bash
SCRIPT_PATH="$(readlink -f -- "${BASH_SOURCE[0]}")"
WS="$(dirname "$SCRIPT_PATH")"
PKG_PATH="${1:-}"
patched=0

diff_tmp=""
control_before=""
rules_before=""
if [ -n "$PKG_PATH" ]; then
  diff_tmp="$(mktemp -d)"
  if [ -f "$WS/$PKG_PATH/debian/control" ]; then
    control_before="$diff_tmp/control"
    cp "$WS/$PKG_PATH/debian/control" "$control_before"
  fi
  if [ -f "$WS/$PKG_PATH/debian/rules" ]; then
    rules_before="$diff_tmp/rules"
    cp "$WS/$PKG_PATH/debian/rules" "$rules_before"
  fi
fi

patched=1
case "$PKG_PATH" in
  "src/ros2/rviz/rviz_ogre_vendor")
    # Add OGRE plugin dir to dh_shlibdeps search path so PCZSceneManager is found
    # Plugin_OctreeZone.so links against Plugin_PCZSceneManager.so which lives in lib/OGRE/
    # Note: \$(CURDIR) must be escaped to prevent shell expansion
    sed -i 's|\(rviz_ogre_vendor/lib/\)|\1:\$(CURDIR)/debian/ros-jazzy-rviz-ogre-vendor//opt/ros/jazzy/opt/rviz_ogre_vendor/lib/OGRE/|' \
      $WS/$PKG_PATH/debian/rules
    ;;

  "src/ros2/rviz/rviz_rendering")
    # Add rviz_ogre_vendor lib dir to dh_shlibdeps so Ogre libs resolve
    # Note: \$(CURDIR) must be escaped to prevent shell expansion
    sed -i 's|\(rviz_rendering/lib/\)|\1:\$(CURDIR)/debian/ros-jazzy-rviz-rendering//opt/ros/jazzy/opt/rviz_ogre_vendor/lib/:/opt/ros/jazzy/opt/rviz_ogre_vendor/lib/|' \
      $WS/$PKG_PATH/debian/rules
    ;;

  "src/ros2/rviz/rviz_default_plugins" | \
  "src/ros2/rviz/rviz_common")
    # Add rviz_ogre_vendor lib dir to dh_shlibdeps so Ogre libs resolve
    # (gz vendor paths for AMENT_PREFIX_PATH and dh_shlibdeps will be added automatically
    # by the generic gz vendor patches below)
    if ! grep -q "/opt/ros/jazzy/opt/rviz_ogre_vendor/lib" "$WS/$PKG_PATH/debian/rules"; then
      sed -i '/dh_shlibdeps -l/ s|$|:/opt/ros/jazzy/opt/rviz_ogre_vendor/lib|' \
        $WS/$PKG_PATH/debian/rules
    fi
    ;;

  "src/ros2/rosidl_dynamic_typesupport" | \
  "src/ros2/rmw/rmw")
    # Add ros-jazzy-rosidl-runtime-c dependency alongside librosidl-runtime-c-cpp-dev
    sed -i 's/librosidl-runtime-c-cpp-dev, /&ros-jazzy-rosidl-runtime-c, /' \
      $WS/$PKG_PATH/debian/control
    ;;

  "src/ros2/rosidl/rosidl_cli" | \
  "src/ros2/rpyutils")
    # Drop stray pytest caches in python installs to avoid file clashes
    # Extract package name from path (e.g., "rosidl_cli" from "src/ros2/rosidl/rosidl_cli")
    pkg_name=$(basename "$PKG_PATH")
    ros_pkg_name="ros-jazzy-${pkg_name//_/-}"
    # Use awk to add the pytest cache cleanup after dh_auto_install
    awk -v pkg="$ros_pkg_name" '/^\tdh_auto_install$/ {
      print "\tdh_auto_install && \\"
      print "\tfind debian/" pkg " -path \"*/.pytest_cache\" -prune -exec rm -rf {} +"
      next
    }
    { print }' "$WS/$PKG_PATH/debian/rules" > "$WS/$PKG_PATH/debian/rules.tmp"
    mv "$WS/$PKG_PATH/debian/rules.tmp" "$WS/$PKG_PATH/debian/rules"
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

  "src/ros2/urdf/urdf_parser_plugin" | \
  "src/ros/urdfdom" | \
  "src/ros/kdl_parser/kdl_parser")
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

  "src/ros/sdformat_urdf/sdformat_urdf")
    # Add sdformat_vendor + gz_math_vendor lib dirs to dh_shlibdeps so libsdformat14/libgz-math7 resolve
    if ! grep -q "/opt/ros/jazzy/opt/sdformat_vendor/lib" "$WS/$PKG_PATH/debian/rules"; then
      sed -i '/dh_shlibdeps -l/ s|$|:/opt/ros/jazzy/opt/sdformat_vendor/lib:/opt/ros/jazzy/opt/gz_math_vendor/lib|' \
        $WS/$PKG_PATH/debian/rules
    fi
    ;;

  "src/ros-visualization/qt_gui_core/qt_gui" | \
  "src/ros-visualization/python_qt_binding")
    # Use python3-pyqt5.sip; python3-sip(-dev) is not available in Trixie
    sed -i -e 's/python3-sip-dev/python3-pyqt5.sip/g' \
      -e 's/python3-sip\>/python3-pyqt5.sip/g' \
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

  "src/ros2/rmw_implementation/rmw_implementation")
    # Remove rmw_connextdds build dependency - we're skipping RTI Connext DDS packages
    # since they require proprietary middleware not available on Debian
    sed -i 's/ros-jazzy-rmw-connextdds, //g' \
      $WS/$PKG_PATH/debian/control
    # Add ros-jazzy-rmw-fastrtps-cpp as a runtime dependency so that any package
    # that depends on rmw_implementation will have at least one concrete RMW available.
    # This fixes CMake configure failures where rmw_implementation_cmake cannot find
    # any RMW implementation when building packages that transitively depend on rmw.
    sed -i 's/^\(Depends:.*ros-jazzy-rmw-implementation-cmake\)/\1, ros-jazzy-rmw-fastrtps-cpp/' \
      $WS/$PKG_PATH/debian/control
    ;;

  "src/ros/ros_environment")
    # Install prefix-level setup scripts so /opt/ros/jazzy/setup.bash exists.
    # Without these, ros2cli can't find Python package metadata.
    awk '
      { print }
      /^\tdh_auto_install$/ {
        print "\tprintf '\''%s\\n'\'' \\"
        print "\t  \"import os\" \\"
        print "\t  \"from ament_package import templates\" \\"
        print "\t  \"\" \\"
        print "\t  \"prefix = os.path.join('\''debian'\'', '\''ros-jazzy-ros-environment'\'', '\''opt'\'', '\''ros'\'', '\''jazzy'\'')\" \\"
        print "\t  \"os.makedirs(prefix, exist_ok=True)\" \\"
        print "\t  \"\" \\"
        print "\t  \"env = {\" \\"
        print "\t  \"    '\''CMAKE_INSTALL_PREFIX'\'': '\''/opt/ros/jazzy'\'',\" \\"
        print "\t  \"    '\''ament_package_PYTHON_EXECUTABLE'\'': '\''/usr/bin/python3'\'',\" \\"
        print "\t  \"    '\''SKIP_PARENT_PREFIX_PATH'\'': '\'''\'',\" \\"
        print "\t  \"}\" \\"
        print "\t  \"\" \\"
        print "\t  \"def write_template(name):\" \\"
        print "\t  \"    path = templates.get_prefix_level_template_path(name)\" \\"
        print "\t  \"    if name.endswith('\''.in'\''):\" \\"
        print "\t  \"        content = templates.configure_file(str(path), env)\" \\"
        print "\t  \"        out_name = name[:-3]\" \\"
        print "\t  \"    else:\" \\"
        print "\t  \"        with open(path, '\''r'\'', encoding='\''utf-8'\'') as f:\" \\"
        print "\t  \"            content = f.read()\" \\"
        print "\t  \"        out_name = name\" \\"
        print "\t  \"    dest = os.path.join(prefix, out_name)\" \\"
        print "\t  \"    with open(dest, '\''w'\'', encoding='\''utf-8'\'') as f:\" \\"
        print "\t  \"        f.write(content)\" \\"
        print "\t  \"    os.chmod(dest, 0o644)\" \\"
        print "\t  \"\" \\"
        print "\t  \"for name in [\" \\"
        print "\t  \"    '\''setup.bash'\'',\" \\"
        print "\t  \"    '\''setup.zsh'\'',\" \\"
        print "\t  \"    '\''local_setup.bash'\'',\" \\"
        print "\t  \"    '\''local_setup.zsh'\'',\" \\"
        print "\t  \"    '\''_local_setup_util.py'\'',\" \\"
        print "\t  \"    '\''setup.sh.in'\'',\" \\"
        print "\t  \"    '\''local_setup.sh.in'\'',\" \\"
        print "\t  \"]:\" \\"
        print "\t  \"    write_template(name)\" \\"
        print "\t  > debian/ros-jazzy-ros-environment/_generate_prefix_setup.py"
        print "\tPYTHONPATH=\"/opt/ros/jazzy/lib/python3.13/site-packages:$$PYTHONPATH\" \\"
        print "\tpython3 debian/ros-jazzy-ros-environment/_generate_prefix_setup.py"
        print "\trm -f debian/ros-jazzy-ros-environment/_generate_prefix_setup.py"
      }
    ' "$WS/$PKG_PATH/debian/rules" > "$WS/$PKG_PATH/debian/rules.new"
    mv "$WS/$PKG_PATH/debian/rules.new" "$WS/$PKG_PATH/debian/rules"
    ;;

  *)
    patched=0
    ;;
esac

if [ $patched -eq 1 ]; then
  echo "== Applied custom patch to $PKG_PATH"
fi

# Generic vendor package handling
if [[ "$PKG_PATH" == src/*/*_vendor ]]; then
  sed -i 's/\(Build-Depends:.*\)$/\1, vcstool, git, ca-certificates/' \
    $WS/$PKG_PATH/debian/control
  echo "== Applied generic vendor Build-Depends fix to $PKG_PATH"
fi

# Generic fix: if a package has dh_shlibdeps with -l but doesn't include
# /opt/ros/jazzy/lib, add it to find ROS libraries from build dependencies
if [ -f "$WS/$PKG_PATH/debian/rules" ] && \
   grep -q "dh_shlibdeps -l" "$WS/$PKG_PATH/debian/rules" && \
   ! grep -q "dh_shlibdeps.*:/opt/ros/jazzy/lib" "$WS/$PKG_PATH/debian/rules"; then
  sed -i 's|\(dh_shlibdeps -l.*\)$|\1:/opt/ros/jazzy/lib:/opt/ros/jazzy/lib/${DEB_HOST_MULTIARCH}|' \
    $WS/$PKG_PATH/debian/rules
  echo "== Applied generic dh_shlibdeps fix to $PKG_PATH"
fi

# Additional fix: if dh_shlibdeps has /opt/ros/jazzy/lib but not the multiarch directory, add it
if [ -f "$WS/$PKG_PATH/debian/rules" ] && \
   grep -q "dh_shlibdeps.*:/opt/ros/jazzy/lib" "$WS/$PKG_PATH/debian/rules" && \
   ! grep -q "dh_shlibdeps.*:/opt/ros/jazzy/lib/\${DEB_HOST_MULTIARCH}" "$WS/$PKG_PATH/debian/rules"; then
  sed -i 's|\(dh_shlibdeps.*:/opt/ros/jazzy/lib\)|\1:/opt/ros/jazzy/lib/${DEB_HOST_MULTIARCH}|' \
    $WS/$PKG_PATH/debian/rules
  echo "== Applied multiarch dh_shlibdeps fix to $PKG_PATH"
fi

# Generic fix: Replace setup.sh sourcing with PYTHONPATH export in debian/rules
# This ensures Python packages can be found without sourcing the ROS setup script
if [ -f "$WS/$PKG_PATH/debian/rules" ] && \
   grep -q 'if \[ -f "/opt/ros/jazzy/setup.sh" \]; then \. "/opt/ros/jazzy/setup.sh"; fi' "$WS/$PKG_PATH/debian/rules"; then
  sed -i 's|if \[ -f "/opt/ros/jazzy/setup.sh" \]; then \. "/opt/ros/jazzy/setup.sh"; fi && \\|export PYTHONPATH="/opt/ros/jazzy/lib/python3.13/site-packages:$$PYTHONPATH" \&\& \\|' \
    "$WS/$PKG_PATH/debian/rules"
  echo "== Applied Python path fix to $PKG_PATH"
fi

# Generic fix: Enable parallel builds in debian/rules
# Bloom generates debhelper compat level 9, which requires explicit --parallel flag
# (compat 10+ enables parallel automatically from DEB_BUILD_OPTIONS)
if [ -f "$WS/$PKG_PATH/debian/rules" ] && \
   grep -q 'dh $@' "$WS/$PKG_PATH/debian/rules" && \
   ! grep -q 'dh $@ --parallel\|dh $@ .* --parallel' "$WS/$PKG_PATH/debian/rules"; then
  sed -i 's/dh $@ /dh $@ --parallel /' "$WS/$PKG_PATH/debian/rules"
  echo "== Enabled parallel builds for $PKG_PATH"
fi

# Generic fix: Set ROS_DISTRO environment variable for packages that require it
# Some packages check ENV{ROS_DISTRO} in CMakeLists.txt for distro-specific workarounds
if grep -R -q -E 'ENV\{ROS_DISTRO\}|\$ENV\{ROS_DISTRO\}' "$WS/$PKG_PATH" 2>/dev/null && \
   [ -f "$WS/$PKG_PATH/debian/rules" ] && \
   ! grep -q 'export ROS_DISTRO=' "$WS/$PKG_PATH/debian/rules"; then
  sed -i '/^export DH_VERBOSE/a export ROS_DISTRO=jazzy' "$WS/$PKG_PATH/debian/rules"
  echo "== Added ROS_DISTRO=jazzy export to $PKG_PATH"
fi

# Generic fix: Add gz vendor paths to AMENT_PREFIX_PATH for packages that depend on them
# When a package depends on gz vendor packages, ament needs to know where to find them
# so it can set up CMAKE_PREFIX_PATH correctly. The vendor packages' -extras.cmake files
# will then add both the extra_cmake and parent directories to CMAKE_PREFIX_PATH.
if [ -f "$WS/$PKG_PATH/debian/control" ] && [ -f "$WS/$PKG_PATH/debian/rules" ]; then
  gz_vendor_paths=""

  # Build list of gz vendor paths based on dependencies
  if grep -q "ros-jazzy-gz-math-vendor" "$WS/$PKG_PATH/debian/control"; then
    gz_vendor_paths="${gz_vendor_paths}:/opt/ros/jazzy/opt/gz_math_vendor"
  fi

  if grep -q "ros-jazzy-gz-cmake-vendor" "$WS/$PKG_PATH/debian/control"; then
    gz_vendor_paths="${gz_vendor_paths}:/opt/ros/jazzy/opt/gz_cmake_vendor"
  fi

  if grep -q "ros-jazzy-gz-utils-vendor" "$WS/$PKG_PATH/debian/control"; then
    gz_vendor_paths="${gz_vendor_paths}:/opt/ros/jazzy/opt/gz_utils_vendor"
  fi

  if grep -q "ros-jazzy-gz-tools-vendor" "$WS/$PKG_PATH/debian/control"; then
    gz_vendor_paths="${gz_vendor_paths}:/opt/ros/jazzy/opt/gz_tools_vendor"
  fi

  # If we found gz vendor dependencies and they're not already in AMENT_PREFIX_PATH, add them
  # Check specifically in the AMENT_PREFIX_PATH line, not elsewhere in the file
  if [ -n "$gz_vendor_paths" ] && \
     grep -q 'AMENT_PREFIX_PATH="/opt/ros/jazzy"' "$WS/$PKG_PATH/debian/rules" && \
     ! grep 'AMENT_PREFIX_PATH=' "$WS/$PKG_PATH/debian/rules" | grep -q "/opt/ros/jazzy/opt/gz_.*_vendor"; then
    sed -i "s|-DAMENT_PREFIX_PATH=\"/opt/ros/jazzy\"|-DAMENT_PREFIX_PATH=\"/opt/ros/jazzy${gz_vendor_paths}\"|" \
      "$WS/$PKG_PATH/debian/rules"
    echo "== Added gz vendor paths to AMENT_PREFIX_PATH for $PKG_PATH"
  fi
fi

# Generic fix: Add gz vendor package library paths for packages that depend on them
# If a package depends on any of the gz vendor packages (gz-math, gz-utils, gz-tools),
# add their library directories to dh_shlibdeps so dpkg-shlibdeps can find the vendored libraries
if [ -f "$WS/$PKG_PATH/debian/control" ] && [ -f "$WS/$PKG_PATH/debian/rules" ]; then
  gz_vendor_libs=""

  # Check for gz_math_vendor dependency and add its lib path
  if grep -q "ros-jazzy-gz-math-vendor" "$WS/$PKG_PATH/debian/control" && \
     ! grep -q "/opt/ros/jazzy/opt/gz_math_vendor/lib" "$WS/$PKG_PATH/debian/rules"; then
    gz_vendor_libs="${gz_vendor_libs}:/opt/ros/jazzy/opt/gz_math_vendor/lib"
  fi

  # Check for gz_utils_vendor dependency and add its lib path
  if grep -q "ros-jazzy-gz-utils-vendor" "$WS/$PKG_PATH/debian/control" && \
     ! grep -q "/opt/ros/jazzy/opt/gz_utils_vendor/lib" "$WS/$PKG_PATH/debian/rules"; then
    gz_vendor_libs="${gz_vendor_libs}:/opt/ros/jazzy/opt/gz_utils_vendor/lib"
  fi

  # Check for gz_tools_vendor dependency and add its lib path
  if grep -q "ros-jazzy-gz-tools-vendor" "$WS/$PKG_PATH/debian/control" && \
     ! grep -q "/opt/ros/jazzy/opt/gz_tools_vendor/lib" "$WS/$PKG_PATH/debian/rules"; then
    gz_vendor_libs="${gz_vendor_libs}:/opt/ros/jazzy/opt/gz_tools_vendor/lib"
  fi

  # If we found any gz vendor dependencies, add their lib paths to dh_shlibdeps
  if [ -n "$gz_vendor_libs" ] && grep -q "dh_shlibdeps" "$WS/$PKG_PATH/debian/rules"; then
    sed -i "/dh_shlibdeps -l/ s|\$|${gz_vendor_libs}|" "$WS/$PKG_PATH/debian/rules"
    echo "== Added gz vendor lib paths to dh_shlibdeps for $PKG_PATH"
  fi
fi

# Log differences if any
if [ -n "$diff_tmp" ]; then
  diff_dir="$WS/diff/deb/$PKG_PATH/debian"
  mkdir -p "$diff_dir"
  if [ -n "$control_before" ] && [ -f "$WS/$PKG_PATH/debian/control" ]; then
    if ! diff -u --label "a/debian/control" --label "b/debian/control" \
      "$control_before" "$WS/$PKG_PATH/debian/control" > "$diff_dir/control.diff"; then
      echo "== debian/control diff for $PKG_PATH"
      cat "$diff_dir/control.diff"
    else
      rm -f "$diff_dir/control.diff"
    fi
  fi
  if [ -n "$rules_before" ] && [ -f "$WS/$PKG_PATH/debian/rules" ]; then
    if ! diff -u --label "a/debian/rules" --label "b/debian/rules" \
      "$rules_before" "$WS/$PKG_PATH/debian/rules" > "$diff_dir/rules.diff"; then
      echo "== debian/rules diff for $PKG_PATH"
      cat "$diff_dir/rules.diff"
    else
      rm -f "$diff_dir/rules.diff"
    fi
  fi
  rm -rf "$diff_tmp"
fi
