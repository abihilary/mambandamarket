/// Retired. Chat now goes through the API.
///
/// Threads and messages live in `ChatRepository` (lib/api/repositories.dart)
/// backed by `/conversations`; the models are `Conversation` and `Message` in
/// lib/api/models.dart. This file previously held an in-memory stub used while
/// the backend did not exist.
///
/// Kept only as a signpost — delete once nothing references the path.
library;

export '../api/models.dart' show Conversation, Message;
export '../api/repositories.dart' show ChatRepository;
