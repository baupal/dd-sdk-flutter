// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class DatadogSdkMock extends Mock implements DatadogSdk {}

class RumMock extends Mock implements DatadogRum {}

void main() {
  const int port = 50192;

  late DatadogSdkMock mockDatadog;
  late RumMock mockRum;

  setUpAll(() {
    registerFallbackValue(Uri(host: 'localhost'));
  });

  void verifyHeaders(
    TracingHeaderType type,
    Map<String, String> metadata,
    bool sampled,
    TraceContextInjection traceContextInjection,
  ) {
    BigInt? traceInt;
    BigInt? spanInt;

    bool shouldInjectHeaders =
        sampled || traceContextInjection == TraceContextInjection.all;

    switch (type) {
      case TracingHeaderType.datadog:
        if (shouldInjectHeaders) {
          expect(metadata['x-datadog-sampling-priority'], sampled ? '1' : '0');
          traceInt = BigInt.tryParse(metadata['x-datadog-trace-id'] ?? '');
          spanInt = BigInt.tryParse(metadata['x-datadog-parent-id'] ?? '');
          final tagsHeader = metadata['x-datadog-tags'];
          final parts = tagsHeader?.split('=');
          expect(parts, isNotNull);
          expect(parts?[0], '_dd.p.tid');
          BigInt? highTraceInt = BigInt.tryParse(parts?[1] ?? '', radix: 16);
          expect(highTraceInt, isNotNull);
          expect(highTraceInt?.bitLength, lessThanOrEqualTo(64));
        } else {
          expect(metadata['x-datadog-origin'], isNull);
          expect(metadata['x-datadog-sampling-priority'], isNull);
          expect(metadata['x-datadog-trace-id'], isNull);
          expect(metadata['x-datadog-parent-id'], isNull);
          expect(metadata['x-datadog-tags'], isNull);
        }
        break;
      case TracingHeaderType.b3:
        var singleHeader = metadata['b3'];
        if (sampled) {
          var headerParts = singleHeader!.split('-');
          traceInt = BigInt.tryParse(headerParts[0], radix: 16);
          spanInt = BigInt.tryParse(headerParts[1], radix: 16);
          expect(headerParts[2], '1');
        } else if (shouldInjectHeaders) {
          expect(singleHeader, '0');
        } else {
          expect(singleHeader, isNull);
        }
        break;
      case TracingHeaderType.b3multi:
        if (shouldInjectHeaders) {
          expect(metadata['x-b3-sampled'], sampled ? '1' : '0');
          if (sampled) {
            traceInt =
                BigInt.tryParse(metadata['x-b3-traceid'] ?? '', radix: 16);
            spanInt = BigInt.tryParse(metadata['x-b3-spanid'] ?? '', radix: 16);
          }
        } else {
          expect(metadata['X-B3-Sampled'], isNull);
          expect(metadata['X-B3-TraceId'], isNull);
          expect(metadata['X-B3-SpanId'], isNull);
        }
        break;
      case TracingHeaderType.tracecontext:
        if (shouldInjectHeaders) {
          var parentHeader = metadata['traceparent']!;
          var headerParts = parentHeader.split('-');
          expect(headerParts[0], '00');
          traceInt = BigInt.tryParse(headerParts[1], radix: 16);
          spanInt = BigInt.tryParse(headerParts[2], radix: 16);
          expect(headerParts[3], sampled ? '01' : '00');

          final stateHeader = metadata['tracestate']!;
          final stateParts = getDdTraceState(stateHeader);
          expect(stateParts['s'], sampled ? '1' : '0');
          expect(stateParts['o'], 'rum');
          expect(stateParts['p'], headerParts[2]);
        } else {
          expect(metadata['traceparent'], isNull);
        }
        break;
    }

    if (sampled) {
      expect(traceInt, isNotNull);
    }
    if (traceInt != null) {
      if (type == TracingHeaderType.datadog) {
        expect(traceInt.bitLength, lessThanOrEqualTo(64));
      } else {
        expect(traceInt.bitLength, lessThanOrEqualTo(128));
      }
    }

    if (sampled) {
      expect(spanInt, isNotNull);
    }
    if (spanInt != null) {
      expect(spanInt.bitLength, lessThanOrEqualTo(63));
    }
  }
}
