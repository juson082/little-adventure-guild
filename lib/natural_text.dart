import 'package:flutter/material.dart';

/// Keeps Korean syllables together when the word can fit on a line.
String koreanWordBreaks(String text, bool Function(String) fits) {
  return text.replaceAllMapped(RegExp(r'[\uAC00-\uD7A3]{2,}'), (match) {
    final word = match.group(0)!;
    if (!fits(word)) return word;
    return word.characters.join('\u2060');
  });
}

class NaturalText extends StatelessWidget {
  const NaturalText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.visibleCharacters,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? visibleCharacters;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    return LayoutBuilder(
      builder: (context, constraints) {
        var display = text;
        if (locale.languageCode == 'ko' && constraints.maxWidth.isFinite) {
          display = koreanWordBreaks(text, (word) {
            final painter = TextPainter(
              text: TextSpan(text: word, style: effectiveStyle),
              textDirection: direction,
              textScaler: scaler,
              locale: locale,
              maxLines: 1,
            )..layout();
            final fits = painter.width <= constraints.maxWidth;
            painter.dispose();
            return fits;
          });
        }
        final visible = visibleCharacters;
        if (visible == null) {
          return Semantics(
            label: text,
            child: ExcludeSemantics(
              child: Text(
                display,
                style: style,
                textAlign: textAlign,
                locale: locale,
              ),
            ),
          );
        }
        final first = StringBuffer(), rest = StringBuffer();
        var count = 0;
        for (final char in display.characters) {
          if (char == '\u2060') {
            (count <= visible ? first : rest).write(char);
          } else {
            (count < visible ? first : rest).write(char);
            count++;
          }
        }
        return Semantics(
          label: text,
          child: ExcludeSemantics(
            child: Text.rich(
              TextSpan(
                style: style,
                children: [
                  TextSpan(text: first.toString()),
                  TextSpan(
                    text: rest.toString(),
                    style: const TextStyle(color: Colors.transparent),
                  ),
                ],
              ),
              textAlign: textAlign,
              locale: locale,
            ),
          ),
        );
      },
    );
  }
}
