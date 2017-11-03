// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';
import 'service/build_info.dart';
import 'service/build_service.dart';

/// Indicates the last known status of a particular build.
enum BuildStatus {
  /// The build status hasn't been determined yet.
  unknown,

  /// A network error occurred getting the build status.
  networkError,

  /// A parse error occurred while determining the build status.
  parseError,

  /// The build was successful.
  success,

  /// The build failed.
  failure,
}

final DateTime _kHalloween = new DateTime.utc(
  2017,
  10,
  31,
  12,
);

/// Manages a build status and associated metadata.
class BuildStatusModel extends ModuleModel {
  /// The build type.
  final String type;

  /// The build name.
  final String name;

  /// The url of the page used to determine the build status.
  final String url;

  /// The service used to fetch [BuildInfo].
  final BuildService _buildService;

  DateTime _lastRefreshed;
  DateTime _lastRefreshStarted;
  DateTime _lastRefreshEnded;
  DateTime _lastFailTime;
  DateTime _lastPassTime;
  BuildStatus _buildStatus = BuildStatus.unknown;
  String _errorMessage;

  /// Constructor.
  BuildStatusModel({this.type, this.name, this.url, BuildService buildService})
      : _buildService = buildService;

  /// Returns the time when the status was refreshed.
  DateTime get lastRefreshed => _lastRefreshed;

  /// Returns the time when the status is starting to refresh.
  DateTime get lastRefreshStarted => _lastRefreshStarted;

  /// Returns the time when the status is finished refreshing.
  DateTime get lastRefreshEnded => _lastRefreshEnded;

  /// Returns the current build status.
  BuildStatus get buildStatus => _buildStatus;

  /// The time the build started failing.
  DateTime get lastFailTime => _lastFailTime;

  /// The time the build started passing.
  DateTime get lastPassTime => _lastPassTime;

  /// If the build status isn't [BuildStatus.success] this will indicate any
  /// additional information about why not.
  String get errorMessage => _errorMessage;

  bool _outstandingGet = false;

  /// The color to use as the background of a successful build.
  Color get successColor {
    Duration difference = new DateTime.now().difference(_kHalloween).abs();
    if (difference < const Duration(days: 1)) {
      return Colors.orange[700];
    }
    return Colors.green[300];
  }

  /// The color to use as the background of a failed build.
  Color get failColor {
    Duration difference = new DateTime.now().difference(_kHalloween).abs();
    if (difference < const Duration(days: 1)) {
      return Colors.black;
    }
    return Colors.red[400];
  }

  /// Starts the model refreshing periodically.
  void start() {
    new Timer.periodic(
      const Duration(seconds: 60),
      (_) => refresh(),
    );
    refresh();
  }

  /// Initiates a refresh of the build status.
  void refresh() {
    DateTime now = new DateTime.now().toLocal();
    if (_lastRefreshed == null ||
        now.difference(_lastRefreshed) > const Duration(seconds: 60)) {
      _lastRefreshed = now;
      _fetchConfigStatus();
      notifyListeners();
    }
  }

  Future<Null> _fetchConfigStatus() async {
    if (_outstandingGet) {
      return;
    }
    _outstandingGet = true;

    String errorMessage;
    _lastRefreshStarted = new DateTime.now();
    _lastRefreshEnded = null;

    BuildInfo info;

    try {
      info = await _buildService.getBuildByName(url).first;
    } on BuildServiceException catch (error) {
      _buildStatus = BuildStatus.networkError;
      errorMessage = 'Error receiving response:\n$error';
    } finally {
      _outstandingGet = false;
      _lastRefreshEnded = new DateTime.now();
      _buildStatus =
          info?.result == 'SUCCESS' ? BuildStatus.success : BuildStatus.failure;
      _errorMessage = errorMessage;

      if (_buildStatus == BuildStatus.success) {
        if (_lastPassTime == null) {
          _lastPassTime = new DateTime.now();
          _lastFailTime = null;
        }
      } else {
        if (_lastFailTime == null) {
          _lastFailTime = new DateTime.now();
          _lastPassTime = null;
        }
      }
      notifyListeners();
    }
  }
}
