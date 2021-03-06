// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIB_UI_SCENIC_SKIA_IMAGE_INFO_H_
#define LIB_UI_SCENIC_SKIA_IMAGE_INFO_H_

#include <fuchsia/cpp/images.h>

#include "third_party/skia/include/core/SkImageInfo.h"

namespace scenic_lib {
namespace skia {

// Creates Skia image information from a |images::ImageInfo| object.
SkImageInfo MakeSkImageInfo(const images::ImageInfo& image_info);

}  // namespace skia
}  // namespace scenic_lib

#endif  // LIB_UI_SCENIC_SKIA_IMAGE_INFO_H_
