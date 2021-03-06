// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.app.dart/app.dart';
import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:lib.agent.dart/agent.dart';
import 'package:meta/meta.dart';

import 'home_work_proposer.dart';

// ignore: unused_element
HomeWorkAgent _agent;

/// An implementation of the [Agent] interface.
class HomeWorkAgent extends AgentImpl {
  final IntelligenceServicesProxy _intelligenceServices =
      new IntelligenceServicesProxy();
  final ContextReaderProxy _contextReader = new ContextReaderProxy();
  final HomeWorkProposer _homeWorkProposer = new HomeWorkProposer();

  /// Constructor.
  HomeWorkAgent({@required ApplicationContext applicationContext})
      : super(applicationContext: applicationContext);

  @override
  Future<Null> onReady(
    ApplicationContext applicationContext,
    AgentContext agentContext,
    ComponentContext componentContext,
    TokenProvider tokenProvider,
    ServiceProviderImpl outgoingServices,
  ) async {
    agentContext.getIntelligenceServices(_intelligenceServices.ctrl.request());
    _intelligenceServices..getContextReader(_contextReader.ctrl.request());

    _homeWorkProposer.start(
      _contextReader,
      _intelligenceServices,
    );
  }

  @override
  Future<Null> onStop() async {
    _homeWorkProposer.stop();
    _contextReader.ctrl.close();
    _intelligenceServices.ctrl.close();
  }
}

Future<Null> main(List<dynamic> args) async {
  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();
  _agent = new HomeWorkAgent(
    applicationContext: applicationContext,
  )..advertise();
}
