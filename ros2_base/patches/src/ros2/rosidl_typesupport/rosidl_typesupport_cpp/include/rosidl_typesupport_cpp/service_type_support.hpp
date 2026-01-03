// Copyright 2016 Open Source Robotics Foundation, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifndef ROSIDL_TYPESUPPORT_CPP__SERVICE_TYPE_SUPPORT_HPP_
#define ROSIDL_TYPESUPPORT_CPP__SERVICE_TYPE_SUPPORT_HPP_

#include "rcutils/allocator.h"
#include "rosidl_runtime_c/service_type_support_struct.h"
#include "rosidl_typesupport_cpp/visibility_control.h"

namespace rosidl_typesupport_cpp
{

// Minimal shims for service event message support. These functions intentionally
// return nullptr / false if no underlying implementation is available.
template<typename ServiceT>
inline void * service_create_event_message(
  const rosidl_service_type_support_t *,
  rcutils_allocator_t * allocator,
  const void *,
  const void *)
{
  (void)allocator;
  return nullptr;
}

template<typename ServiceT>
inline bool service_destroy_event_message(
  void * event_msg,
  rcutils_allocator_t * allocator)
{
  if (event_msg == nullptr || allocator == nullptr) {
    return false;
  }
  allocator->deallocate(event_msg, allocator->state);
  return true;
}

}  // namespace rosidl_typesupport_cpp

#endif  // ROSIDL_TYPESUPPORT_CPP__SERVICE_TYPE_SUPPORT_HPP_
