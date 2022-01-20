// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import 'datadog_sdk.dart';
import 'datadog_sdk_platform_interface.dart';

class DatadogSdkMethodChannel extends DatadogSdkPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('datadog_sdk_flutter');

  @override
  Future<void> setSdkVerbosity(Verbosity verbosity) {
    return methodChannel
        .invokeMethod('setSdkVerbosity', {'value': verbosity.toString()});
  }

  @override
  Future<void> setTrackingConsent(TrackingConsent trackingConsent) {
    return methodChannel.invokeMethod(
        'setTrackingConsent', {'value': trackingConsent.toString()});
  }

  @override
  Future<void> initialize(DdSdkConfiguration configuration,
      {LogCallback? logCallback}) async {
    if (logCallback != null) {
      methodChannel.setMethodCallHandler((call) {
        switch (call.method) {
          case 'logCallback':
            logCallback(call.arguments as String);
            break;
        }
        return Future.value();
      });
    }

    await methodChannel
        .invokeMethod('initialize', {'configuration': configuration.encode()});
  }
}
