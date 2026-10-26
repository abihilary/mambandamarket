import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Photos sent in chats, kept on disk.
///
/// Chat attachments live in a private bucket, so every fetch of a thread
/// hands out a freshly signed URL for the same photo, and a URL-keyed cache
/// would download it again each time. Call sites key it by
/// `'chat:${attachmentPath}'` instead, so a photo is downloaded once.
///
/// Its own cache, apart from listing photos: sixty pictures and two weeks,
/// emptied on sign-out and whenever a different account signs in. On web,
/// CachedNetworkImage ignores it and the browser loads the URL directly.
final CacheManager chatAttachmentCache = CacheManager(
  Config(
    'chat_attachments_v1',
    stalePeriod: const Duration(days: 14),
    maxNrOfCacheObjects: 60,
  ),
);
