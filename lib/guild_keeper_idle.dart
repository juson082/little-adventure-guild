import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const keeperIdleSequences = <String, List<int>>{
  'scratch': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
  'yawn': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
  'eat': [
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    6,
    7,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
  ],
  'flick': [
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    6,
    7,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
  ],
  'beard': [
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    8,
    7,
    6,
    5,
    4,
    5,
    6,
    7,
    8,
    9,
    8,
    7,
    6,
    5,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
  ],
  'stretch': [
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    10,
    10,
    10,
    10,
    10,
    10,
    10,
    10,
    10,
    10,
    10,
    10,
    10,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
  ],
  'sleep': [
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
  ],
};

class GuildKeeperIdle extends StatefulWidget {
  const GuildKeeperIdle({super.key});
  @override
  State<GuildKeeperIdle> createState() => _GuildKeeperIdleState();
}

class _GuildKeeperIdleState extends State<GuildKeeperIdle>
    with WidgetsBindingObserver {
  Timer? _wait, _preload, _play;
  int _generation = 0, _phase = 0;
  String? _action, _preparedAction;
  ui.Image? _room;
  List<_KeeperFrame>? _frames;
  bool _reduceMotion = false, _due = false;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (_wait == null || disabled != _reduceMotion) {
      _reduceMotion = disabled;
      _restart();
    }
  }

  bool get _foreground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  void _restart({Duration delay = const Duration(minutes: 3)}) {
    _generation++;
    _wait?.cancel();
    _wait = null;
    _preload?.cancel();
    _preload = null;
    _play?.cancel();
    _play = null;
    _disposeImages();
    _action = null;
    _preparedAction = null;
    _due = false;
    if (!_reduceMotion && _foreground) {
      const lead = Duration(seconds: 20);
      _preload = Timer(delay > lead ? delay - lead : Duration.zero, _prepare);
      _wait = Timer(delay, () {
        _wait = null;
        _due = true;
        _activate();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() => _restart());
  }

  Future<void> _prepare() async {
    _preload = null;
    final generation = _generation;
    final names = keeperIdleSequences.keys.toList();
    final action = names[_random.nextInt(names.length)];
    ui.Image? room;
    List<_KeeperFrame>? frames;
    try {
      room = await _loadImage('assets/keeper_idle/empty-room.png');
      frames = await _loadFrames(action);
      if (!mounted ||
          generation != _generation ||
          !_foreground ||
          _reduceMotion) {
        room.dispose();
        for (final frame in frames) {
          frame.image.dispose();
        }
        return;
      }
      _room = room;
      _frames = frames;
      _preparedAction = action;
      if (_due) _activate();
    } catch (error) {
      debugPrint('Keeper animation could not load: $error');
      room?.dispose();
      if (frames != null) {
        for (final frame in frames) {
          frame.image.dispose();
        }
      }
      if (mounted && generation == _generation) setState(() => _restart());
    }
  }

  void _activate() {
    final action = _preparedAction;
    if (!_due || action == null || _frames == null || _room == null) return;
    setState(() {
      _action = action;
      _phase = 0;
    });
    _play = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (!mounted) return;
      if (_phase + 1 >= keeperIdleSequences[action]!.length) {
        final elapsed = Duration(
          milliseconds: keeperIdleSequences[action]!.length * 150,
        );
        setState(() => _restart(delay: const Duration(minutes: 3) - elapsed));
      } else {
        setState(() => _phase++);
      }
    });
  }

  void _disposeImages() {
    _room?.dispose();
    _room = null;
    final oldFrames = _frames;
    _frames = null;
    if (oldFrames != null) {
      for (final frame in oldFrames) {
        frame.image.dispose();
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _wait?.cancel();
    _preload?.cancel();
    _play?.cancel();
    _disposeImages();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_action == null || _frames == null || _room == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: CustomPaint(
        painter: _KeeperPainter(_room!, _frames!, _action!, _phase),
      ),
    );
  }
}

class _KeeperFrame {
  const _KeeperFrame(this.image, this.bottom, this.torso, this.nose);
  final ui.Image image;
  final int bottom;
  final double? torso, nose;
}

Future<ui.Image> _loadImage(String path) async {
  final data = await rootBundle.load(path);
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

Future<List<_KeeperFrame>> _loadFrames(String action) async {
  final atlas = await _loadImage('assets/keeper_idle/$action.png');
  final result = <_KeeperFrame>[];
  try {
    for (var frame = 0; frame < 18; frame++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final cellW = atlas.width / 6, cellH = atlas.height / 3;
      canvas.drawImageRect(
        atlas,
        Rect.fromLTWH((frame % 6) * cellW, (frame ~/ 6) * cellH, cellW, cellH),
        const Rect.fromLTWH(0, 0, 296, 296),
        Paint()..filterQuality = FilterQuality.none,
      );
      final picture = recorder.endRecording();
      final cell = await picture.toImage(296, 296);
      picture.dispose();
      final bytes = await cell.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      cell.dispose();
      if (bytes == null) throw StateError('Cannot decode keeper frame');
      final rgba = bytes.buffer.asUint8List();
      final metadata = _maskFrame(rgba, action);
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        rgba,
        296,
        296,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      result.add(
        _KeeperFrame(
          await completer.future,
          metadata.$1,
          metadata.$2,
          metadata.$3,
        ),
      );
    }
    return result;
  } catch (_) {
    for (final frame in result) {
      frame.image.dispose();
    }
    rethrow;
  } finally {
    atlas.dispose();
  }
}

(int, double?, double?) _maskFrame(Uint8List d, String action) {
  const w = 296, count = w * w;
  final seen = Uint8List(count), queue = Int32List(count);
  var head = 0, tail = 0;
  void add(int i) {
    if (seen[i] != 0) return;
    final p = i * 4, r = d[p], g = d[p + 1], b = d[p + 2], a = d[p + 3];
    if (a < 180 ||
        (math.min(r, math.min(g, b)) > 145 &&
            math.max(r, math.max(g, b)) - math.min(r, math.min(g, b)) < 38)) {
      seen[i] = 1;
      queue[tail++] = i;
    }
  }

  for (var x = 0; x < w; x++) {
    add(x);
    add((w - 1) * w + x);
  }
  for (var y = 0; y < w; y++) {
    add(y * w);
    add(y * w + w - 1);
  }
  while (head < tail) {
    final i = queue[head++], x = i % w, y = i ~/ w;
    if (x > 0) add(i - 1);
    if (x < w - 1) add(i + 1);
    if (y > 0) add(i - w);
    if (y < w - 1) add(i + w);
  }
  for (var i = 0; i < count; i++) {
    final p = i * 4,
        r = d[p],
        g = d[p + 1],
        b = d[p + 2],
        x = i % w,
        y = i ~/ w;
    final low = math.min(r, math.min(g, b)),
        neutral = math.max(r, math.max(g, b)) - low;
    final hole =
        (action == 'beard' || action == 'flick') &&
        y > 145 &&
        y < 265 &&
        (x < 130 || x > 185) &&
        low > 145 &&
        neutral < 45;
    if (seen[i] != 0 ||
        (low > 190 && neutral < 20) ||
        (y > 100 &&
            y < 265 &&
            (x < 108 || x > 188) &&
            low > 160 &&
            neutral < 35) ||
        hole) {
      d[p + 3] = 0;
    }
  }
  var bottom = 0, torsoX = 0, torsoN = 0, noseX = 0, noseN = 0;
  for (var y = 150; y < 294; y++) {
    var solid = 0;
    for (var x = 40; x < 256; x++) {
      final i = (y * w + x) * 4, r = d[i], g = d[i + 1], b = d[i + 2];
      if (d[i + 3] > 200 &&
          math.max(r, math.max(g, b)) - math.min(r, math.min(g, b)) > 24 &&
          r > g * 1.08) {
        solid++;
      }
    }
    if (solid >= 12) bottom = y;
  }
  for (var y = 190; y < 265; y++) {
    for (var x = 65; x < 230; x++) {
      final i = (y * w + x) * 4, r = d[i], g = d[i + 1], b = d[i + 2];
      if (d[i + 3] > 220 &&
          r > 50 &&
          r < 155 &&
          r > g * 1.3 &&
          g > b * 1.1 &&
          g < 100) {
        torsoX += x;
        torsoN++;
      }
    }
  }
  if (action == 'scratch') {
    for (var y = 75; y < 125; y++) {
      for (var x = 100; x < 195; x++) {
        final i = (y * w + x) * 4, r = d[i], g = d[i + 1], b = d[i + 2];
        if (d[i + 3] > 220 &&
            r > 175 &&
            g > 65 &&
            g < 165 &&
            b < 125 &&
            r > g * 1.35 &&
            r - b > 80) {
          noseX += x;
          noseN++;
        }
      }
    }
  }
  return (
    bottom == 0 ? 278 : bottom,
    torsoN > 80 ? torsoX / torsoN : null,
    noseN > 40 ? noseX / noseN : null,
  );
}

class _KeeperPainter extends CustomPainter {
  _KeeperPainter(this.room, this.frames, this.action, this.phase);
  final ui.Image room;
  final List<_KeeperFrame> frames;
  final String action;
  final int phase;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = w * 1312 / 1199, sprite = w * .33;
    final roomRect = Rect.fromLTWH(0, 0, w, h);
    final patch = Rect.fromLTWH(w * .30, h * .19, w * .40, h * .32);
    final paint = Paint()..filterQuality = FilterQuality.none;
    canvas.save();
    canvas.clipRect(patch);
    canvas.drawImageRect(
      room,
      Rect.fromLTWH(0, 0, room.width.toDouble(), room.height.toDouble()),
      roomRect,
      paint,
    );
    final f = frames[keeperIdleSequences[action]![phase]], first = frames.first;
    final anchor = action == 'scratch' ? first.nose : first.torso;
    final current = action == 'scratch' ? f.nose : f.torso;
    final dx = anchor != null && current != null
        ? (anchor - current).round()
        : 0;
    final overlap = action == 'beard'
        ? 15
        : action == 'flick'
        ? 3
        : 0;
    final tremble = action == 'stretch' && phase >= 11 && phase <= 24
        ? [0, 1, 0, -1][(phase - 11) % 4]
        : 0;
    final left = w * .335 + (dx + tremble) * sprite / 296;
    final top = h * .194 + (281 - f.bottom + overlap) * sprite / 296;
    canvas.drawImageRect(
      f.image,
      const Rect.fromLTWH(0, 0, 296, 296),
      Rect.fromLTWH(left, top, sprite, sprite),
      paint,
    );
    final counterTop = h * (action == 'beard' ? .478 : .492);
    canvas.clipRect(Rect.fromLTRB(0, counterTop, w, h));
    canvas.drawImageRect(
      room,
      Rect.fromLTWH(0, 0, room.width.toDouble(), room.height.toDouble()),
      roomRect,
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _KeeperPainter old) =>
      old.phase != phase || old.action != action || old.frames != frames;
}
