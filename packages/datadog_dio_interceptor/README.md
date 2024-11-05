
# Datadog Dio Interceptor / Plugin

> A plugin for use with the `DatadogSdk`, used to track calls made using the Dio package.

## Getting started

To utilize this plugin, create an instance of `DatadogDioInterceptor`, then add it to your list of interceptors when creating a Dio client.:

```dart
import 'package:datadog_dio_interceptor/datadog_dio_interceptor.dart';
import 'package:dio/dio.dart';

// Initialize Datadog, be sure to set the [DatadogConfiguration.firstPartyHosts] member
// to enable Datadog Distributed Tracing
final config = DatadogConfiguration(
  // ...
  firstParthHosts = ['localhost']
)

// Create the Dio interceptor
final datadogInterceptor = DatadogDioInterceptor(DatadogSdk.instance)

// Create the Dio client
final dio = Dio()

// Add the interceptor to the Dio client
dio.interceptors.add(datadogInterceptor)
```

# Contributing

Pull requests are welcome. First, open an issue to discuss what you would like
to change. For more information, read the [Contributing
guide](../../CONTRIBUTING.md) in the root repository.

# License

[Apache License, v2.0](LICENSE)
