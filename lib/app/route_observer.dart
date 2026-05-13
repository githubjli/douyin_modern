import 'package:flutter/material.dart';

/// App-wide route observer. Register widgets with [RouteAware] to receive
/// push/pop notifications (e.g., to pause video when another route appears).
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
