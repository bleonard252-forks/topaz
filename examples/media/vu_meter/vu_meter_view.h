// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once

#include <memory>
#include <queue>

#include <fbl/vmo_mapper.h>
#include <fuchsia/cpp/media.h>
#include <lib/async-loop/cpp/loop.h>

#include "examples/ui/lib/skia_view.h"
#include "lib/app/cpp/application_context.h"
#include "lib/fxl/macros.h"
#include "topaz/examples/media/vu_meter/vu_meter_params.h"

namespace examples {

class VuMeterView : public mozart::SkiaView {
 public:
  VuMeterView(async::Loop* loop,
              views_v1::ViewManagerPtr view_manager,
              fidl::InterfaceRequest<views_v1_token::ViewOwner> view_owner_request,
              component::ApplicationContext* application_context,
              const VuMeterParams& params);

  ~VuMeterView() override;

 private:
  static constexpr float kVuFullWidth = 35000.0f;
  static constexpr float kFastDecay = 0.0001f;
  static constexpr float kSlowDecay = 0.00003f;

  class PeakFilter {
   public:
    PeakFilter(float decay) : multiplier_(1.0f - decay) {}

    float Process(float in) {
      if (current_ < in) {
        current_ = in;
      } else {
        current_ *= multiplier_;
      }
      return current_;
    }

    float current() { return current_; }

   private:
    float multiplier_;
    float current_ = 0;
  };

  // |BaseView|:
  void OnSceneInvalidated(
      images::PresentationInfo presentation_info) override;
  bool OnInputEvent(input::InputEvent event) override;

  // Draws the UI.
  void DrawContent(SkCanvas* canvas);

  // Send a capture request to our capturer.
  void SendCaptureRequest();

  // Toggles between start and stop.
  void ToggleStartStop() {
    started_ = !started_;
    SendCaptureRequest();
  }

  // Shutdown the app
  void Shutdown();

  void OnDefaultFormatFetched(media::MediaType default_type);
  void OnPacketCaptured(media::MediaPacket packet);

  async::Loop* const loop_;
  media::AudioCapturerPtr capturer_;
  fbl::VmoMapper payload_buffer_;
  bool started_ = false;
  bool request_in_flight_ = false;

  PeakFilter fast_left_;
  PeakFilter fast_right_;
  PeakFilter slow_left_;
  PeakFilter slow_right_;

  FXL_DISALLOW_COPY_AND_ASSIGN(VuMeterView);
};

}  // namespace examples
