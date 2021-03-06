// Copyright 2015 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef GARNET_EXAMPLES_UI_NOODLES_NOODLES_VIEW_H_
#define GARNET_EXAMPLES_UI_NOODLES_NOODLES_VIEW_H_

#include "examples/ui/lib/skia_view.h"
#include "lib/fxl/macros.h"

class SkCanvas;

namespace examples {

class Frame;
class Rasterizer;

class NoodlesView : public mozart::SkiaView {
 public:
  NoodlesView(views_v1::ViewManagerPtr view_manager,
              fidl::InterfaceRequest<views_v1_token::ViewOwner> view_owner_request);

  ~NoodlesView() override;

 private:
  // |BaseView|:
  void OnSceneInvalidated(
      images::PresentationInfo presentation_info) override;

  void Draw(SkCanvas* canvas, float t);

  uint64_t start_time_ = 0u;
  int wx_ = 0;
  int wy_ = 0;

  FXL_DISALLOW_COPY_AND_ASSIGN(NoodlesView);
};

}  // namespace examples

#endif  // GARNET_EXAMPLES_UI_NOODLES_NOODLES_VIEW_H_
