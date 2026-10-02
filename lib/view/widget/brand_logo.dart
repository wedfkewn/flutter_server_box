import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:server_box/core/utils/program_logo.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/res/store.dart';

/// Fixed geometry and original artwork colors, including during load/failure.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.source, this.size = 24,
    this.label, this.fallback = Icons.terminal});

  final String? source;
  final double size;
  final String? label;
  final IconData fallback;

  static void refreshSource(String url) => _LogoCache._items.remove(url);

  Widget _fallback(BuildContext context) => Icon(fallback, size: size - 4,
    color: source == null ? Theme.of(context).colorScheme.onSurfaceVariant : const Color(0xff475569));

  @override
  Widget build(BuildContext context) {
    final path = source;
    return Semantics(label: label, image: true, child: SizedBox.square(
      dimension: size,
      child: path == null ? _fallback(context) : DecoratedBox(
        // A neutral plate keeps native black/dark artwork visible in dark mode.
        decoration: BoxDecoration(color: const Color(0xfff5f6f8), borderRadius: BorderRadius.circular(5)),
        child: Padding(padding: const EdgeInsets.all(2), child:
          path.startsWith('assets/') ? SvgPicture.asset(path, fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _fallback(context)) :
          FutureBuilder<Uint8List>(future: _LogoCache.load(path), builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null) return _fallback(context);
            final isSvg = Uri.tryParse(path)?.path.toLowerCase().endsWith('.svg') == true ||
                String.fromCharCodes(data.take(200)).contains('<svg');
            return isSvg ? SvgPicture.memory(data, fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _fallback(context)) :
              Image.memory(data, fit: BoxFit.contain,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
                errorBuilder: (_, _, _) => _fallback(context));
          }),
        ),
      ),
    ));
  }
}

class ProgramLogo extends StatelessWidget {
  const ProgramLogo(this.name, {super.key, this.type, this.service = false, this.size = 24});
  final String name;
  final bool service;
  final ServiceUnitType? type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final settings = Stores.setting;
    return ListenableBuilder(listenable: Listenable.merge([
      settings.showProgramLogos.listenable(),
      settings.processLogoMap.listenable(), settings.serviceLogoMap.listenable(),
    ]), builder: (context, _) => BrandLogo(
      size: size,
      label: name,
      fallback: service ? (type == ServiceUnitType.service ? Icons.miscellaneous_services_outlined : Icons.description_outlined) : Icons.terminal,
      source: settings.showProgramLogos.fetch() ? resolveProgramLogo(name,
        service: service, type: type,
        overrides: service ? settings.serviceLogoMap.fetch() : settings.processLogoMap.fetch()) : null,
    ));
  }
}

abstract final class _LogoCache {
  static final _items = <String, Future<Uint8List>>{};
  static final _client = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8)));

  static Future<Uint8List> load(String url) {
    final existing = _items[url];
    if (existing != null) return existing;
    if (_items.length >= 64) _items.remove(_items.keys.first);
    return _items[url] = _fetch(url);
  }

  static Future<Uint8List> _fetch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) throw FormatException('Invalid image URL');
    final cancel = CancelToken();
    final response = await _client.get<List<int>>(url,
      cancelToken: cancel, options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: (received, _) {
        if (received > 512 * 1024) cancel.cancel('Image is too large');
      });
    final data = response.data;
    if (data == null || data.isEmpty || data.length > 512 * 1024) throw FormatException('Image is empty or too large');
    return Uint8List.fromList(data);
  }
}
