import 'package:flutter/foundation.dart';
import 'package:parchment/parchment.dart';

/// Utility class to convert between Parchment Delta format and HTML
/// for WordPress API integration
class DeltaHtmlConverter {
  /// Normalize HTML for comparison purposes
  /// Strips CSS classes, styles, and normalizes structure to compare content only
  static String normalizeHtmlForComparison(String html) {
    if (html.isEmpty) return '';

    String normalized = html;

    // Remove CSS classes
    normalized = normalized.replaceAll(RegExp(r'\s+class="[^"]*"'), '');

    // Remove inline styles
    normalized = normalized.replaceAll(RegExp(r'\s+style="[^"]*"'), '');

    // Remove other common attributes (width, height, alt with content)
    normalized = normalized.replaceAll(RegExp(r'\s+width="[^"]*"'), '');
    normalized = normalized.replaceAll(RegExp(r'\s+height="[^"]*"'), '');
    normalized = normalized.replaceAll(RegExp(r'\s+alt="[^"]*"'), '');

    // Normalize image tags - keep only src
    normalized = normalized.replaceAllMapped(
      RegExp(r'<img[^>]*src="([^"]+)"[^>]*/?>', caseSensitive: false),
      (match) => '<img src="${match.group(1)}" />',
    );

    // Remove empty list items
    normalized = normalized.replaceAll(RegExp(r'<li>\s*</li>'), '');

    // Remove <br> tags (they're often inconsistent)
    normalized = normalized.replaceAll(RegExp(r'<br\s*/?>'), ' ');

    // Normalize whitespace
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

    // Remove whitespace between tags
    normalized = normalized.replaceAll(RegExp(r'>\s+<'), '><');

    // Trim
    normalized = normalized.trim();

    return normalized;
  }

  /// Compare two HTML strings for semantic equality
  /// Returns true if they have the same content (ignoring formatting differences)
  static bool htmlContentEquals(String html1, String html2) {
    final normalized1 = normalizeHtmlForComparison(html1);
    final normalized2 = normalizeHtmlForComparison(html2);
    return normalized1 == normalized2;
  }

  /// Convert Delta document to HTML string for WordPress API
  static String deltaToHtml(ParchmentDocument document) {
    try {
      final delta = document.toDelta();
      final buffer = StringBuffer();
      String currentBlock = '';
      bool inList = false;
      String? listType;

      for (var op in delta.toList()) {
        if (op.isInsert) {
          final data = op.data;
          final attributes = op.attributes ?? {};

          // Handle embeds (images)
          if (data is Map) {
            // Check for image embed - Parchment format has 'source' key
            String? imageSrc;
            if (data.containsKey('source')) {
              imageSrc = data['source']?.toString();
            } else if (data.containsKey('image')) {
              // Legacy format or nested format
              final imageData = data['image'];
              if (imageData is String) {
                imageSrc = imageData;
              } else if (imageData is Map && imageData.containsKey('source')) {
                imageSrc = imageData['source']?.toString();
              }
            }

            // Optional per-image display width (percentage). Preserved so the
            // vendor's chosen size survives save/load and reaches the storefront.
            int? imageWidth;
            final rawWidth = data['width'];
            if (rawWidth is int) {
              imageWidth = rawWidth;
            } else if (rawWidth is num) {
              imageWidth = rawWidth.toInt();
            } else if (rawWidth is String) {
              imageWidth = int.tryParse(rawWidth);
            }

            if (imageSrc != null && imageSrc.isNotEmpty) {
              if (imageWidth != null && imageWidth > 0 && imageWidth <= 100) {
                buffer.write(
                  '<img src="$imageSrc" alt="" style="width:$imageWidth%" />',
                );
              } else {
                buffer.write('<img src="$imageSrc" alt="" />');
              }
            }
            continue;
          }

          // Handle text
          if (data is String) {
            final lines = data.split('\n');

            for (int i = 0; i < lines.length; i++) {
              String line = lines[i];

              // Apply inline styles
              if (attributes['b'] == true) {
                line = '<strong>$line</strong>';
              }
              if (attributes['i'] == true) {
                line = '<em>$line</em>';
              }
              if (attributes['u'] == true) {
                line = '<u>$line</u>';
              }
              if (attributes['s'] == true) {
                line = '<s>$line</s>';
              }

              currentBlock += line;

              // Handle newlines (block boundaries)
              if (i < lines.length - 1 || data.endsWith('\n')) {
                // Check for block attributes
                final blockType = attributes['block'];
                final heading = attributes['heading'];

                if (blockType == 'ul') {
                  if (!inList || listType != 'ul') {
                    if (inList) buffer.write('</$listType>');
                    buffer.write('<ul>');
                    inList = true;
                    listType = 'ul';
                  }
                  buffer.write('<li>$currentBlock</li>');
                } else if (blockType == 'ol') {
                  if (!inList || listType != 'ol') {
                    if (inList) buffer.write('</$listType>');
                    buffer.write('<ol>');
                    inList = true;
                    listType = 'ol';
                  }
                  buffer.write('<li>$currentBlock</li>');
                } else if (blockType == 'quote') {
                  if (inList) {
                    buffer.write('</$listType>');
                    inList = false;
                  }
                  buffer.write('<blockquote>$currentBlock</blockquote>');
                } else if (blockType == 'code') {
                  if (inList) {
                    buffer.write('</$listType>');
                    inList = false;
                  }
                  buffer.write('<pre><code>$currentBlock</code></pre>');
                } else if (heading != null) {
                  if (inList) {
                    buffer.write('</$listType>');
                    inList = false;
                  }
                  buffer.write('<h$heading>$currentBlock</h$heading>');
                } else {
                  if (inList) {
                    buffer.write('</$listType>');
                    inList = false;
                  }
                  if (currentBlock.isNotEmpty) {
                    buffer.write('<p>$currentBlock</p>');
                  }
                }

                currentBlock = '';
              }
            }
          }
        }
      }

      // Close any open list
      if (inList && listType != null) {
        buffer.write('</$listType>');
      }

      // Handle any remaining content
      if (currentBlock.isNotEmpty) {
        buffer.write('<p>$currentBlock</p>');
      }

      final result = buffer.toString();
      return result.isEmpty ? '<p></p>' : result;
    } catch (e) {
      debugPrint('[DELTA_HTML] Error in deltaToHtml: ${e.runtimeType}');
      debugPrint('[DELTA_HTML] StackTrace redacted');
      return '<p></p>'; // Return empty paragraph on error
    }
  }

  /// Convert HTML string from WordPress to Delta document
  /// Preserves formatting: headings, bold, italic, underline, lists
  static ParchmentDocument htmlToDelta(String html) {
    if (html.isEmpty) {
      return ParchmentDocument();
    }

    try {
      final delta = Delta();

      // Parse HTML into structured blocks. Gemini can return plain text, so
      // fall back to paragraphs when no supported HTML tags are present.
      var blocks = _parseHtmlBlocks(html);
      if (blocks.isEmpty) {
        blocks = _parsePlainTextBlocks(html);
      }

      for (final block in blocks) {
        if (block['type'] == 'image') {
          // Add image embed (carry optional display width)
          final embed = <String, dynamic>{
            '_type': 'image',
            '_inline': false,
            'source': block['src'],
          };
          if (block['width'] != null) {
            embed['width'] = block['width'];
          }
          delta.push(Operation.insert(embed));
          delta.push(Operation.insert('\n'));
        } else {
          // Add text with formatting
          final text = block['text'] as String;
          final attributes = block['attributes'] as Map<String, dynamic>?;

          if (text.isNotEmpty) {
            if (attributes != null && attributes.isNotEmpty) {
              delta.push(Operation.insert(text, attributes));
            } else {
              delta.push(Operation.insert(text));
            }
            delta.push(Operation.insert('\n', block['blockAttributes']));
          }
        }
      }

      // Ensure document ends with newline
      if (delta.isEmpty) {
        delta.push(Operation.insert('\n'));
      }

      debugPrint(
        '📝 Built Delta with ${delta.length} operations (formatting preserved)',
      );
      return ParchmentDocument.fromDelta(delta);
    } catch (e) {
      debugPrint('[DELTA_HTML] Error in htmlToDelta: ${e.runtimeType}');
      debugPrint('[DELTA_HTML] StackTrace redacted');
      return ParchmentDocument();
    }
  }

  /// Parse HTML into structured blocks with formatting
  static List<Map<String, dynamic>> _parseHtmlBlocks(String html) {
    final blocks = <Map<String, dynamic>>[];

    // Extract images and replace with markers
    final imageRegex = RegExp(
      r'<img[^>]+src="([^"]+)"[^>]*>',
      caseSensitive: false,
    );
    final images = <Map<String, dynamic>>[];
    html = html.replaceAllMapped(imageRegex, (match) {
      final tag = match.group(0) ?? '';
      final src = match.group(1) ?? '';
      if (src.isNotEmpty) {
        final wMatch = RegExp(
          r'width\s*:\s*(\d+)\s*%',
          caseSensitive: false,
        ).firstMatch(tag);
        images.add({
          'src': src,
          'width': wMatch != null ? int.tryParse(wMatch.group(1)!) : null,
        });
        return '{{IMG_${images.length - 1}}}';
      }
      return '';
    });

    debugPrint('🖼️ Extracted ${images.length} images from HTML');

    // Parse all elements in document order
    final elementRegex = RegExp(
      r'<(h[1-6]|p|div)(?:\s[^>]*)?>(.+?)</\1>|<(ul|ol)[^>]*>(.*?)</\3>|{{IMG_(\d+)}}',
      caseSensitive: false,
      dotAll: true,
    );

    for (final match in elementRegex.allMatches(html)) {
      final blockTag = match.group(1)?.toLowerCase();
      final blockContent = match.group(2);
      final listTag = match.group(3)?.toLowerCase();
      final listContent = match.group(4);
      final imageIndex = match.group(5);

      if (imageIndex != null) {
        // Image block (standalone)
        final idx = int.tryParse(imageIndex);
        if (idx != null && idx < images.length) {
          blocks.add({
            'type': 'image',
            'src': images[idx]['src'],
            'width': images[idx]['width'],
          });
        }
      } else if (listTag != null && listContent != null) {
        // List block - parse list items
        final liRegex = RegExp(
          r'<li[^>]*>(.*?)</li>',
          caseSensitive: false,
          dotAll: true,
        );

        for (final liMatch in liRegex.allMatches(listContent)) {
          final content = liMatch.group(1) ?? '';
          if (content.trim().isEmpty) continue; // Skip empty list items

          // Check if list item contains image markers and split content
          final parts = _splitContentWithImages(content, images);

          for (final part in parts) {
            if (part['type'] == 'image') {
              blocks.add(part);
            } else {
              final text = _extractTextWithInlineFormatting(
                part['content'] as String,
              );
              if ((text['text'] as String).isNotEmpty) {
                blocks.add({
                  'type': 'text',
                  'text': text['text'],
                  'attributes': text['attributes'],
                  'blockAttributes': {'block': listTag}, // 'ul' or 'ol'
                });
              }
            }
          }
        }
      } else if (blockTag != null && blockContent != null) {
        // Regular block (heading, paragraph, div)
        // Check if block contains image markers and split content
        final parts = _splitContentWithImages(blockContent, images);

        for (final part in parts) {
          if (part['type'] == 'image') {
            blocks.add(part);
          } else {
            final content = part['content'] as String;
            if (content.trim().isEmpty) continue; // Skip empty blocks

            final text = _extractTextWithInlineFormatting(content);
            if ((text['text'] as String).isEmpty) continue;

            final blockAttributes = <String, dynamic>{};

            // Handle headings
            if (blockTag.startsWith('h')) {
              final level = int.tryParse(blockTag.substring(1));
              if (level != null) {
                blockAttributes['heading'] = level;
              }
            }

            blocks.add({
              'type': 'text',
              'text': text['text'],
              'attributes': text['attributes'],
              'blockAttributes': blockAttributes.isNotEmpty
                  ? blockAttributes
                  : null,
            });
          }
        }
      }
    }

    return blocks;
  }

  static List<Map<String, dynamic>> _parsePlainTextBlocks(String value) {
    final text = _stripHtmlTags(value).trim();
    if (text.isEmpty) return const [];

    final paragraphs = text
        .split(RegExp(r'\n\s*\n+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);

    return paragraphs
        .map(
          (paragraph) => <String, dynamic>{
            'type': 'text',
            'text': paragraph.replaceAll(RegExp(r'\s*\n\s*'), ' '),
            'attributes': null,
            'blockAttributes': null,
          },
        )
        .toList();
  }

  static String _stripHtmlTags(String value) {
    return value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  /// Split content that may contain image markers into separate parts
  static List<Map<String, dynamic>> _splitContentWithImages(
    String content,
    List<Map<String, dynamic>> images,
  ) {
    final parts = <Map<String, dynamic>>[];
    final imgMarkerRegex = RegExp(r'\{\{IMG_(\d+)\}\}');

    int lastEnd = 0;
    for (final match in imgMarkerRegex.allMatches(content)) {
      // Add text before the image marker
      if (match.start > lastEnd) {
        final textBefore = content.substring(lastEnd, match.start);
        if (textBefore.trim().isNotEmpty) {
          parts.add({'type': 'text', 'content': textBefore});
        }
      }

      // Add the image
      final idx = int.tryParse(match.group(1) ?? '');
      if (idx != null && idx < images.length) {
        parts.add({
          'type': 'image',
          'src': images[idx]['src'],
          'width': images[idx]['width'],
        });
      }

      lastEnd = match.end;
    }

    // Add remaining text after last image marker
    if (lastEnd < content.length) {
      final textAfter = content.substring(lastEnd);
      if (textAfter.trim().isNotEmpty) {
        parts.add({'type': 'text', 'content': textAfter});
      }
    }

    // If no image markers found, return the whole content as text
    if (parts.isEmpty && content.trim().isNotEmpty) {
      parts.add({'type': 'text', 'content': content});
    }

    return parts;
  }

  /// Extract text with inline formatting (bold, italic, underline)
  static Map<String, dynamic> _extractTextWithInlineFormatting(String html) {
    // For now, extract plain text and detect if there's formatting
    // A full implementation would preserve inline styles per character
    String text = html;
    final attributes = <String, dynamic>{};

    // Check for bold
    if (RegExp(r'<(strong|b)>', caseSensitive: false).hasMatch(html)) {
      attributes['b'] = true;
    }

    // Check for italic
    if (RegExp(r'<(em|i)>', caseSensitive: false).hasMatch(html)) {
      attributes['i'] = true;
    }

    // Check for underline
    if (RegExp(r'<u>', caseSensitive: false).hasMatch(html)) {
      attributes['u'] = true;
    }

    // Check for strikethrough (symmetric with deltaToHtml's attributes['s'])
    if (RegExp(r'<(s|strike|del)>', caseSensitive: false).hasMatch(html)) {
      attributes['s'] = true;
    }

    // Remove all HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // Decode HTML entities
    text = _decodeHtmlEntities(text);

    // Trim whitespace
    text = text.trim();

    return {
      'text': text,
      'attributes': attributes.isNotEmpty ? attributes : null,
    };
  }

  /// Decode common HTML entities
  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
  }
}
