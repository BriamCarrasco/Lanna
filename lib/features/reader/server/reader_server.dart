// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

class ReaderServer {
  ReaderServer._(this._server, this.baseUri, this._bookRoot);

  final HttpServer _server;
  final Uri baseUri;
  final String _bookRoot;

  static const _assetByPath = {
    '/': 'assets/reader/reader.html',
    '/reader.html': 'assets/reader/reader.html',
    '/epub.min.js': 'assets/reader/epub.min.js',
    '/jszip.min.js': 'assets/reader/jszip.min.js',
  };

  static Future<ReaderServer> start(Directory bookDir) async {
    final root = p.normalize(bookDir.absolute.path);
    final handler = const Pipeline()
        .addMiddleware(logRequests(logger: (_, _) {}))
        .addHandler((request) => _handle(request, root));

    final server = await shelf_io.serve(
      handler,
      InternetAddress.loopbackIPv4,
      0,
    );
    server.autoCompress = true;

    final base = Uri(scheme: 'http', host: '127.0.0.1', port: server.port);
    return ReaderServer._(server, base, root);
  }

  static Future<Response> _handle(Request request, String bookRoot) async {
    final path = '/${request.url.path}';

    if (path.startsWith('/book/')) {
      final rel = Uri.decodeComponent(path.substring('/book/'.length));
      final target = p.normalize(p.join(bookRoot, rel));
      if (!p.isWithin(bookRoot, target) && target != bookRoot) {
        return Response.forbidden('fuera de alcance');
      }
      final file = File(target);
      if (!file.existsSync()) return Response.notFound('no encontrado');
      return Response.ok(
        file.openRead(),
        headers: {
          'content-type': lookupMimeType(target) ?? 'application/octet-stream',
          'cache-control': 'no-store',

          'content-security-policy':
              "default-src 'self'; script-src 'none'; connect-src 'none'; "
              "img-src 'self' data:; style-src 'self' 'unsafe-inline'; "
              "font-src 'self' data:",
        },
      );
    }

    final asset = _assetByPath[path];
    if (asset != null) {
      final data = await rootBundle.load(asset);
      final ext = asset.split('.').last;
      final type = ext == 'js'
          ? 'application/javascript; charset=utf-8'
          : 'text/html; charset=utf-8';
      return Response.ok(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        headers: {'content-type': type},
      );
    }

    return Response.notFound('no encontrado');
  }

  Uri readerUrl({String? opfPath, String? cfi, bool hasLocations = false}) {
    return baseUri.replace(
      path: '/reader.html',
      queryParameters: {
        if (opfPath != null && opfPath.isNotEmpty) 'opf': opfPath,
        if (cfi != null && cfi.isNotEmpty) 'cfi': cfi,
        if (hasLocations) 'loc': '1',
      },
    );
  }

  String get bookRoot => _bookRoot;

  Future<void> dispose() => _server.close(force: true);
}
