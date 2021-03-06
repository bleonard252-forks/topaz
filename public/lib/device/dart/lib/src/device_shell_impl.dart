// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:fuchsia.fidl.modular_auth/modular_auth.dart';
import 'package:fidl/fidl.dart';
import 'package:fuchsia.fidl.presentation/presentation.dart';
import 'package:meta/meta.dart';

/// Called when [DeviceShell.initialize] occurs.
typedef void OnDeviceShellReady(
  UserProvider userProvider,
  DeviceShellContext deviceShellContext,
  Presentation presentation,
);

/// Called when [Lifecycle.terminate] occurs.
typedef void OnDeviceShellStop();

/// Implements a DeviceShell for receiving the services a [DeviceShell] needs to
/// operate.
class DeviceShellImpl implements DeviceShell, Lifecycle {
  final DeviceShellContextProxy _deviceShellContextProxy =
      new DeviceShellContextProxy();
  final UserProviderProxy _userProviderProxy = new UserProviderProxy();
  final PresentationProxy _presentationProxy = new PresentationProxy();
  final Set<AuthenticationContextBinding> _bindingSet =
      new Set<AuthenticationContextBinding>();

  /// Called when [initialize] occurs.
  final OnDeviceShellReady onReady;

  /// Called when the [DeviceShell] terminates.
  final OnDeviceShellStop onStop;

  /// The [AuthenticationContext] to provide when requested.
  final AuthenticationContext authenticationContext;

  /// Constructor.
  DeviceShellImpl({
    @required this.authenticationContext,
    this.onReady,
    this.onStop,
  });

  @override
  void initialize(
    InterfaceHandle<DeviceShellContext> deviceShellContextHandle,
    DeviceShellParams deviceShellParams,
  ) {
    if (onReady != null) {
      _deviceShellContextProxy.ctrl.bind(deviceShellContextHandle);
      _deviceShellContextProxy
          .getUserProvider(_userProviderProxy.ctrl.request());
      if (deviceShellParams.presentation.channel != null) {
        _presentationProxy.ctrl.bind(deviceShellParams.presentation);
      }
      onReady(_userProviderProxy, _deviceShellContextProxy, _presentationProxy);
    }
  }

  @override
  void terminate() {
    onStop?.call();
    _userProviderProxy.ctrl.close();
    _deviceShellContextProxy.ctrl.close();
    for (AuthenticationContextBinding binding in _bindingSet) {
      binding.close();
    }
  }

  @override
  void getAuthenticationContext(
    String username,
    InterfaceRequest<AuthenticationContext> request,
  ) {
    AuthenticationContextBinding binding = new AuthenticationContextBinding()
      ..bind(authenticationContext, request);
    _bindingSet.add(binding);
  }

  /// Closes all bindings to authentication contexts, effectively cancelling any ongoing
  /// authorization flows.
  void closeAuthenticationContextBindings() {
    for (AuthenticationContextBinding binding in _bindingSet) {
      binding.close();
    }
    _bindingSet.clear();
  }
}
