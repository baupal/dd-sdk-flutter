// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

/// A Dio client Interceptor which enables automatic resource tracking and
/// distributed tracing
class DatadogDioInterceptor extends Interceptor {
  final Uuid uuid = const Uuid();
  final DatadogSdk _datadog;

  @internal
  final internalLogger = InternalLogger();

  static const _resourceIdKey = 'datadog_resource_id';

  DatadogDioInterceptor(this._datadog);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final rum = _datadog.rum;
    if (rum == null) {
      return super.onRequest(options, handler);
    }

    final tracingHeaderTypes = _datadog.headerTypesForHost(options.uri);
    bool shouldSample = false;
    TracingContext? tracingContext;
    if (tracingHeaderTypes.isNotEmpty) {
      shouldSample = rum.shouldSampleTrace();
      tracingContext = generateTracingContext(shouldSample);
      _injectTracingHeaders(rum, options, tracingHeaderTypes, tracingContext);
    }

    final internalAttributes = <String, Object?>{};

    final resourceId = _startRumResource(
      options,
      rum,
      tracingContext,
      internalAttributes,
    );

    options.extra[_resourceIdKey] = resourceId;

    return super.onRequest(options, handler);
  }

  @override
  void onResponse(response, ResponseInterceptorHandler handler) {
    final resourceId = response.requestOptions.extra[_resourceIdKey];
    if (resourceId is String) {
      final rum = _datadog.rum;
      if (rum != null) {
        int? size;
        final contentLength = response.headers.value('content-length');
        if (contentLength != null) {
          size = int.tryParse(contentLength);
        }
        rum.stopResource(
          resourceId,
          response.statusCode,
          RumResourceType.fetch,
          size,
        );
      }
    }
    return super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final resourceId = err.requestOptions.extra[_resourceIdKey];
    if (resourceId is String) {
      final rum = _datadog.rum;
      if (rum != null) {
        rum.stopResourceWithErrorInfo(
          resourceId,
          err.toString(),
          err.runtimeType.toString(),
        );
      }
    }
    return super.onError(err, handler);
  }

  void _injectTracingHeaders(
    DatadogRum rum,
    RequestOptions options,
    Set<TracingHeaderType> tracingHeaderTypes,
    TracingContext tracingContext,
  ) {
    final newHeaders = <String, String>{};
    try {
      for (final headerType in tracingHeaderTypes) {
        final tracingHeaders = getTracingHeaders(
          tracingContext,
          headerType,
          contextInjection: rum.contextInjectionSetting,
        );
        for (final entry in tracingHeaders.entries) {
          // Don't replace exiting headers
          if (!options.headers.containsKey(entry.key)) {
            newHeaders[entry.key] = entry.value;
          }
        }
      }
    } catch (e, st) {
      internalLogger.sendToDatadog(
        'DatadogInterceptor encountered an error while attempting to inject headers call: $e',
        st,
        e.runtimeType.toString(),
      );
    }
    options.headers.addAll(newHeaders);
  }

  String _startRumResource(
    RequestOptions options,
    DatadogRum rum,
    TracingContext? tracingContext,
    Map<String, Object?> internalAttributes,
  ) {
    final resourceId = uuid.v1();
    final datadogAttributes = generateDatadogAttributes(
      tracingContext,
      rum.traceSampleRate,
    );
    final attributes = {
      ...datadogAttributes,
      ...internalAttributes,
    };

    rum.startResource(
      resourceId,
      rumMethodFromMethodString(options.method.toLowerCase()),
      options.uri.toString(),
      attributes,
    );

    return resourceId;
  }
}
