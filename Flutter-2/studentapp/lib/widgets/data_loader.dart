import 'package:flutter/material.dart';

import 'common.dart';

/// Loads data once, shows a spinner / error+retry / the content.
/// The builder gets a `reload` function you can give to a RefreshIndicator.
class DataLoader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  const DataLoader({super.key, required this.load, required this.builder});

  @override
  State<DataLoader<T>> createState() => _DataLoaderState<T>();
}

class _DataLoaderState<T> extends State<DataLoader<T>> {
  T? _data;
  bool _hasData = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch({bool silent = false}) async {
    if (!silent && _error != null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = d;
        _hasData = true;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      if (_hasData) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !_hasData) return const LoadingView();
    if (!_hasData) {
      return ErrorView(message: _error ?? 'Something went wrong', onRetry: _fetch);
    }
    return widget.builder(context, _data as T, () => _fetch(silent: true));
  }
}
