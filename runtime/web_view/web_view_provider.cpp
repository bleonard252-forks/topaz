// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/runtime/web_view/web_view_provider.h"

#include "lib/icu_data/cpp/icu_data.h"
#include "peridot/lib/rapidjson/rapidjson.h"

WebViewProvider::WebViewProvider(async::Loop* loop, const std::string url)
    : loop_(loop),
      url_(url),
      context_(component::ApplicationContext::CreateFromStartupInfo()),
      view_provider_binding_(this),
      module_binding_(this),
      lifecycle_binding_(this),
      main_link_watcher_binding_(this) {
  FXL_DCHECK(loop);
  if (!icu_data::Initialize(context_.get())) {
    FXL_LOG(WARNING) << "Could not load ICU data";
  }

  context_->outgoing().AddPublicService<views_v1::ViewProvider>(
      [this](fidl::InterfaceRequest<ViewProvider> request) {
        FXL_LOG(INFO) << "Add ViewProvider binding";
        view_provider_binding_.Bind(std::move(request));
      });
  context_->outgoing().AddPublicService<modular::Module>(
      [this](fidl::InterfaceRequest<modular::Module> request) {
        FXL_LOG(INFO) << "got request for module service";
        module_binding_.Bind(std::move(request));
      });
  context_->outgoing().AddPublicService<modular::Lifecycle>(
      [this](fidl::InterfaceRequest<modular::Lifecycle> request) {
        FXL_LOG(INFO) << "got request for lifecycle service";
        lifecycle_binding_.Bind(std::move(request));
      });
}

void WebViewProvider::CreateView(
    fidl::InterfaceRequest<views_v1_token::ViewOwner> view_owner_request,
    fidl::InterfaceRequest<component::ServiceProvider> view_services) {
  FXL_LOG(INFO) << "CreateView";
  FXL_DCHECK(!view_);
  view_ = std::make_unique<WebViewImpl>(
      context_->ConnectToEnvironmentService<views_v1::ViewManager>(),
      std::move(view_owner_request), std::move(view_services), url_);
#ifdef EXPERIMENTAL_WEB_ENTITY_EXTRACTION
  if (context_writer_) {
    view_->set_context_writer(std::move(context_writer_));
  }
  if (component_context_) {
    view_->set_component_context(std::move(component_context_));
  }
#endif

  view_->SetReleaseHandler([this] {
    FXL_LOG(INFO) << "release handler";
    view_ = nullptr;
  });
}

void WebViewProvider::Initialize(
    fidl::InterfaceHandle<modular::ModuleContext> context,
    fidl::InterfaceRequest<component::ServiceProvider> outgoing_services) {
  auto context_ptr = context.Bind();
  context_ptr->GetLink(nullptr, main_link_.NewRequest());
  main_link_->Watch(main_link_watcher_binding_.NewBinding());

#ifdef EXPERIMENTAL_WEB_ENTITY_EXTRACTION
  modular::IntelligenceServicesPtr intelligence_services;
  context_ptr->GetIntelligenceServices(intelligence_services.NewRequest());
  intelligence_services->GetContextWriter(context_writer_.NewRequest());
  context_ptr->GetComponentContext(component_context_.NewRequest());

  if (view_) {
    view_->set_context_writer(std::move(context_writer_));
    view_->set_component_context(std::move(component_context_));
  }
#endif

  FXL_LOG(INFO) << "Initialize()";
}

void WebViewProvider::Terminate() {
  loop_->Quit();
}

void WebViewProvider::Notify(fidl::StringPtr json) {
  modular::JsonDoc parsed_json;
  parsed_json.Parse(json);

  if (!parsed_json.IsObject()) {
    FXL_LOG(WARNING) << "Not an object: "
                     << modular::JsonValueToPrettyString(parsed_json);
    return;
  }

  const auto contract_it = parsed_json.FindMember("view");
  if (contract_it != parsed_json.MemberEnd()) {
    const auto& contract = contract_it->value;
    auto url_it = contract.FindMember("uri");
    if (url_it == contract.MemberEnd() || !url_it->value.IsString()) {
      FXL_LOG(WARNING) << "/view/uri must be a string in " << json;
    } else {
      url_ = url_it->value.GetString();
      if (view_) {
        view_->SetUrl(url_);
      }
    }
  }
}
