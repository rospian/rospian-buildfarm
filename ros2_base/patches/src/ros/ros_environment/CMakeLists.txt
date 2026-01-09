cmake_minimum_required(VERSION 3.5)
project(ros_environment NONE)
find_package(ament_cmake_core REQUIRED)

set(ROS_AUTOMATIC_DISCOVERY_RANGE "SUBNET")
set(ROS_VERSION "2")
set(ROS_PYTHON_VERSION "3")

# Capture Debian multiarch triplet for LD_LIBRARY_PATH hooks.
execute_process(
  COMMAND dpkg-architecture -qDEB_HOST_MULTIARCH
  OUTPUT_VARIABLE DEB_HOST_MULTIARCH
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

# allow overriding the distro name
if(DEFINED ENV{ROS_DISTRO_OVERRIDE})
  set(ROS_DISTRO $ENV{ROS_DISTRO_OVERRIDE})
else()
  set(ROS_DISTRO "jazzy")
endif()

set(
  hooks
  "1.ros_distro"
  "1.ros_discovery"
  "1.ros_python_version"
  "1.ros_version"
  "1.ld_library_path"
)
set(shells "dsv")
if(CMAKE_HOST_UNIX)
  list(APPEND shells "sh")
else()
  list(APPEND shells "bat")
endif()
foreach(hook ${hooks})
  foreach(shell ${shells})
    ament_environment_hooks(
      "${CMAKE_CURRENT_SOURCE_DIR}/env-hooks/${hook}.${shell}.in")
  endforeach()
endforeach()
if(CMAKE_HOST_UNIX)
  ament_environment_hooks(
    "${CMAKE_CURRENT_SOURCE_DIR}/env-hooks/0.ros_distro_check.sh.in")
endif()

ament_package()
