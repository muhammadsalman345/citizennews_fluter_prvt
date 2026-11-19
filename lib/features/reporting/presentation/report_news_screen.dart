import 'dart:async';
import 'dart:convert';
import 'dart:math' show max;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/ads/ads_scope.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_scope.dart';
import '../data/report_draft_store.dart';
import '../data/reporting_repository.dart';
import '../domain/report_models.dart';

class ReportNewsScreen extends StatefulWidget {
  const ReportNewsScreen({this.postId, super.key});

  final String? postId;

  @override
  State<ReportNewsScreen> createState() => _ReportNewsScreenState();
}

class _ReportNewsScreenState extends State<ReportNewsScreen> {
  final _headline = TextEditingController();
  final _summary = TextEditingController();
  final _body = TextEditingController();
  final _source = TextEditingController();
  final _tags = TextEditingController();
  final _correction = TextEditingController();
  final _drafts = const ReportDraftStore();

  ReportingRepository? _repository;
  List<ReportingCategory> _categories = const [];
  List<ReportImage> _images = const [];
  ReportLocation? _location;
  Map<String, dynamic>? _originalBody;
  Map<String, dynamic>? _existingDeviceMetadata;
  DateTime? _eventTime;
  DateTime? _jobDeadline;
  String _jobTimezone = 'UTC';
  String _mainCategoryId = '';
  String _jobCategoryId = '';
  String _newPostId = '';
  String _revisionId = '';
  String? _databasePostId;
  String? _existingStatus;
  String? _owner;
  String? _error;
  String _progress = '';
  Timer? _autosave;
  Timer? _historyTimer;
  final List<TextEditingValue> _bodyHistory = [];
  int _bodyHistoryIndex = -1;
  bool _applyingHistory = false;
  bool _initialized = false;
  bool _restoring = false;
  bool _loading = true;
  bool _busy = false;
  bool _preview = false;
  bool _bodyDirty = false;
  bool _draftRestored = false;
  bool _finished = false;

  String get _routeKey => widget.postId ?? 'new';
  bool get _isRevision =>
      _existingStatus == 'published' || _existingStatus == 'corrected';

  List<ReportingCategory> get _mainCategories => _categories
      .where(
        (item) =>
            item.active && item.slug != 'breaking' && !item.isJobChild,
      )
      .toList(growable: false);

  List<ReportingCategory> get _jobCategories => _categories
      .where((item) => item.active && item.isJobChild)
      .toList(growable: false);

  ReportingCategory? get _mainCategory =>
      _firstWhere(_mainCategories, _mainCategoryId);

  ReportingCategory? get _selectedCategory {
    final main = _mainCategory;
    if (main == null) return null;
    return main.isJobs ? _firstWhere(_jobCategories, _jobCategoryId) : main;
  }

  bool get _canManageEvidence => widget.postId == null && _databasePostId == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    for (final controller in [
      _headline,
      _summary,
      _source,
      _tags,
      _correction,
    ]) {
      controller.addListener(_changed);
    }
    _body.addListener(_bodyChanged);
    final session = AuthScope.read(context);
    final client = session.service.client;
    final owner = session.user?.id;
    if (client == null || owner == null) {
      setState(() {
        _loading = false;
        _error = 'Sign in with a verified reporter account to submit news.';
      });
      return;
    }
    _owner = owner;
    _repository = ReportingRepository(client);
    _newPostId = _repository!.newId();
    _revisionId = _repository!.newId();
    _databasePostId = widget.postId;
    unawaited(_load());
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _historyTimer?.cancel();
    if (!_finished && _owner != null && _repository != null) {
      unawaited(_persistDraft());
    }
    for (final controller in [
      _headline,
      _summary,
      _body,
      _source,
      _tags,
      _correction,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  ReportingCategory? _firstWhere(
    List<ReportingCategory> values,
    String id,
  ) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }

  Future<void> _load() async {
    try {
      final draft = await _drafts.read(_owner!, _routeKey);
      if (draft != null) {
        await _restoreDraft(draft);
        _draftRestored = true;
      }

      try {
        final liveCategories = await _repository!.categories();
        if (liveCategories.isNotEmpty) _categories = liveCategories;
      } catch (_) {
        if (_categories.isEmpty) rethrow;
      }

      if (draft == null && widget.postId != null) {
        final post = await _repository!.ownPost(widget.postId!);
        if (post == null) throw Exception('This story was not found.');
        _loadExisting(post);
      }
      _restoreJobSelection();
      if (widget.postId == null && _location == null) {
        unawaited(_detectLocation(silent: true));
      }
    } catch (error) {
      _error = AppError.message(error);
    } finally {
      _resetBodyHistory();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restoreDraft(Map<String, dynamic> draft) async {
    _restoring = true;
    try {
      _headline.text = draft['headline']?.toString() ?? '';
      _summary.text = draft['summary']?.toString() ?? '';
      _body.text = draft['body_text']?.toString() ?? '';
      _source.text = draft['source']?.toString() ?? '';
      _tags.text = draft['tags']?.toString() ?? '';
      _correction.text = draft['correction']?.toString() ?? '';
      _mainCategoryId = draft['main_category_id']?.toString() ?? '';
      _jobCategoryId = draft['job_category_id']?.toString() ?? '';
      _newPostId = draft['new_post_id']?.toString() ?? _newPostId;
      _revisionId = draft['revision_id']?.toString() ?? _revisionId;
      _databasePostId = draft['database_post_id']?.toString().isNotEmpty == true
          ? draft['database_post_id'].toString()
          : widget.postId;
      _existingStatus = draft['existing_status']?.toString();
      _jobTimezone = draft['job_timezone']?.toString() ?? 'UTC';
      _eventTime = _dateTime(draft['event_time']);
      _jobDeadline = _dateOnly(draft['job_deadline']);
      _bodyDirty = draft['body_dirty'] as bool? ?? false;
      if (draft['original_body'] is Map) {
        _originalBody = Map<String, dynamic>.from(draft['original_body'] as Map);
      }
      if (draft['existing_device_metadata'] is Map) {
        _existingDeviceMetadata = Map<String, dynamic>.from(
          draft['existing_device_metadata'] as Map,
        );
      }
      if (draft['location'] is Map) {
        _location = ReportLocation.fromJson(
          Map<String, dynamic>.from(draft['location'] as Map),
        );
      }
      final storedCategories = (draft['categories'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (row) => ReportingCategory.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false);
      if (storedCategories.isNotEmpty) _categories = storedCategories;

      final restoredImages = <ReportImage>[];
      for (final raw in (draft['images'] as List? ?? const []).whereType<Map>()) {
        final value = Map<String, dynamic>.from(raw);
        final path = value['file_path']?.toString() ?? '';
        if (path.isEmpty || value['location'] is! Map) continue;
        final file = XFile(path);
        try {
          await file.length();
          restoredImages.add(
            ReportImage(
              file: file,
              location: ReportLocation.fromJson(
                Map<String, dynamic>.from(value['location'] as Map),
              ),
              evidencePath: value['evidence_path']?.toString(),
            ),
          );
        } catch (_) {
          // The operating system may remove a temporary picker file.
        }
      }
      _images = restoredImages;
    } finally {
      _restoring = false;
    }
  }

  void _loadExisting(Map<String, dynamic> post) {
    final status = post['status']?.toString() ?? '';
    if (!const {
      'draft',
      'changes_requested',
      'published',
      'corrected',
    }.contains(status)) {
      throw Exception('This story can no longer be edited.');
    }
    _restoring = true;
    try {
      _databasePostId = post['id']?.toString();
      _existingStatus = status;
      _headline.text = post['headline']?.toString() ?? '';
      _summary.text = post['summary']?.toString() ?? '';
      _source.text = post['source']?.toString() ?? '';
      _tags.text = (post['tags'] as List? ?? const []).join(', ');
      _eventTime = _dateTime(post['event_time']);
      _jobDeadline = _dateOnly(post['job_deadline']);
      _jobTimezone = post['job_timezone']?.toString() ?? 'UTC';
      _mainCategoryId = post['category_id']?.toString() ?? '';
      if (post['body'] is Map) {
        _originalBody = Map<String, dynamic>.from(post['body'] as Map);
        _body.text = _plainText(_originalBody!);
      }
      if (post['device_metadata'] is Map) {
        _existingDeviceMetadata = Map<String, dynamic>.from(
          post['device_metadata'] as Map,
        );
      }
      _bodyDirty = false;
    } finally {
      _restoring = false;
    }
  }

  void _restoreJobSelection() {
    final selected = _firstWhere(_categories, _mainCategoryId);
    if (selected?.isJobChild == true) {
      _jobCategoryId = selected!.id;
      for (final category in _categories) {
        if (category.isJobs) {
          _mainCategoryId = category.id;
          break;
        }
      }
    }
  }

  void _changed() {
    if (_restoring || _loading || _finished) return;
    _bodyDirty = _originalBody == null
        ? _body.text.isNotEmpty
        : _body.text != _plainText(_originalBody!);
    _preview = false;
    if (mounted) setState(() {});
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 500), () {
      unawaited(_persistDraft());
    });
  }

  void _bodyChanged() {
    _changed();
    if (_restoring || _loading || _applyingHistory) return;
    _historyTimer?.cancel();
    _historyTimer = Timer(
      const Duration(milliseconds: 350),
      _recordBodyHistory,
    );
  }

  void _resetBodyHistory() {
    _bodyHistory
      ..clear()
      ..add(_body.value);
    _bodyHistoryIndex = 0;
  }

  void _recordBodyHistory() {
    final current = _body.value;
    if (_bodyHistoryIndex >= 0 &&
        _bodyHistory[_bodyHistoryIndex].text == current.text &&
        _bodyHistory[_bodyHistoryIndex].selection == current.selection) {
      return;
    }
    if (_bodyHistoryIndex < _bodyHistory.length - 1) {
      _bodyHistory.removeRange(_bodyHistoryIndex + 1, _bodyHistory.length);
    }
    _bodyHistory.add(current);
    if (_bodyHistory.length > 80) _bodyHistory.removeAt(0);
    _bodyHistoryIndex = _bodyHistory.length - 1;
  }

  void _undoBody() {
    _historyTimer?.cancel();
    _recordBodyHistory();
    if (_bodyHistoryIndex <= 0) return;
    _applyBodyHistory(_bodyHistoryIndex - 1);
  }

  void _redoBody() {
    _historyTimer?.cancel();
    if (_bodyHistoryIndex >= _bodyHistory.length - 1) return;
    _applyBodyHistory(_bodyHistoryIndex + 1);
  }

  void _applyBodyHistory(int index) {
    _applyingHistory = true;
    _bodyHistoryIndex = index;
    _body.value = _bodyHistory[index];
    _applyingHistory = false;
    _changed();
  }

  void _wrapBody(String before, String after, {String fallback = 'text'}) {
    final value = _body.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final selected = start == end ? fallback : value.text.substring(start, end);
    final replacement = '$before$selected$after';
    _body.value = value.copyWith(
      text: value.text.replaceRange(start, end, replacement),
      selection: TextSelection(
        baseOffset: start + before.length,
        extentOffset: start + before.length + selected.length,
      ),
      composing: TextRange.empty,
    );
    _recordBodyHistory();
  }

  void _prefixBodyLines(String prefix) {
    final value = _body.value;
    final selection = value.selection;
    final selectionStart = selection.isValid ? selection.start : value.text.length;
    final selectionEnd = selection.isValid ? selection.end : value.text.length;
    final start = value.text.lastIndexOf('\n', max(0, selectionStart - 1)) + 1;
    final newline = value.text.indexOf('\n', selectionEnd);
    final end = newline < 0 ? value.text.length : newline;
    final original = value.text.substring(start, end);
    final replacement = original
        .split('\n')
        .map((line) => line.isEmpty ? prefix.trimRight() : '$prefix$line')
        .join('\n');
    _body.value = value.copyWith(
      text: value.text.replaceRange(start, end, replacement),
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + replacement.length,
      ),
      composing: TextRange.empty,
    );
    _recordBodyHistory();
  }

  Future<void> _persistDraft() async {
    if (_owner == null || _finished) return;
    await _drafts.write(_owner!, _routeKey, {
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'headline': _headline.text,
      'summary': _summary.text,
      'body_text': _body.text,
      'source': _source.text,
      'tags': _tags.text,
      'correction': _correction.text,
      'main_category_id': _mainCategoryId,
      'job_category_id': _jobCategoryId,
      'event_time': _eventTime?.toUtc().toIso8601String(),
      'job_deadline': _jobDeadline == null ? null : _ymd(_jobDeadline!),
      'job_timezone': _jobTimezone,
      'new_post_id': _newPostId,
      'revision_id': _revisionId,
      'database_post_id': _databasePostId,
      'existing_status': _existingStatus,
      'existing_device_metadata': _existingDeviceMetadata,
      'original_body': _originalBody,
      'body_dirty': _bodyDirty,
      'location': _location?.toJson(),
      'categories': [
        for (final category in _categories)
          {
            'id': category.id,
            'name': category.name,
            'slug': category.slug,
            'active': category.active,
          },
      ],
      'images': [
        for (final image in _images)
          {
            'file_path': image.file.path,
            'evidence_path': image.evidencePath,
            'location': image.location.toJson(),
          },
      ],
    });
  }

  Future<void> _detectLocation({bool silent = false}) async {
    if (_busy && !silent) return;
    if (!silent) setState(() => _busy = true);
    try {
      final location = await _repository!.locate();
      if (!mounted) return;
      setState(() {
        _location = location;
        if (_jobTimezone == 'UTC' && location.timezone?.isNotEmpty == true) {
          _jobTimezone = location.timezone!;
        }
        _error = null;
      });
      await _persistDraft();
    } catch (error) {
      if (!silent && mounted) {
        setState(() => _error = AppError.message(error));
      }
    } finally {
      if (!silent && mounted) setState(() => _busy = false);
    }
  }

  Future<void> _takePhoto() async {
    if (_selectedCategory == null) {
      _message('Choose a category before adding evidence.', danger: true);
      return;
    }
    if (_images.length >= 5) {
      _message('A story can contain at most five photos.', danger: true);
      return;
    }
    await _run('Opening camera…', () async {
      final image = await _repository!.camera();
      if (image == null) return;
      final stored = image.withPath(_repository!.evidencePath());
      setState(() {
        _images = [..._images, stored];
        _location = _images.first.location;
        if (_location!.timezone?.isNotEmpty == true) {
          _jobTimezone = _location!.timezone!;
        }
      });
      await _persistDraft();
    });
  }

  Future<void> _pickGallery() async {
    if (_selectedCategory == null) {
      _message('Choose a category before adding evidence.', danger: true);
      return;
    }
    if (_selectedCategory!.cameraOnly) {
      _message('Accident reports require fresh camera photos.', danger: true);
      return;
    }
    final remaining = 5 - _images.length;
    if (remaining <= 0) {
      _message('A story can contain at most five photos.', danger: true);
      return;
    }
    await _run('Reading selected photos…', () async {
      final picked = await _repository!.gallery(remaining);
      if (picked.isEmpty) return;
      final stored = [
        for (final image in picked)
          image.withPath(_repository!.evidencePath()),
      ];
      setState(() {
        _images = [..._images, ...stored];
        _location = _images.first.location;
        if (_location!.timezone?.isNotEmpty == true) {
          _jobTimezone = _location!.timezone!;
        }
      });
      await _persistDraft();
    });
  }

  void _removeImage(int index) {
    if (!_canManageEvidence || _busy) return;
    final next = [..._images]..removeAt(index);
    setState(() {
      _images = next;
      _location = next.isEmpty ? null : next.first.location;
    });
    _changed();
  }

  void _makePrimary(int index) {
    if (!_canManageEvidence || _busy || index == 0) return;
    final next = [..._images];
    final primary = next.removeAt(index);
    next.insert(0, primary);
    setState(() {
      _images = next;
      _location = primary.location;
    });
    _changed();
  }

  void _categoryChanged(String? value) {
    if (value == null) return;
    setState(() {
      _mainCategoryId = value;
      if (_mainCategory?.isJobs != true) _jobCategoryId = '';
      if (_selectedCategory?.cameraOnly == true && _canManageEvidence) {
        _images = _images
            .where((image) => image.location.mediaSource == 'camera')
            .toList(growable: false);
        _location = _images.isEmpty ? null : _images.first.location;
      }
      _preview = false;
      _error = null;
    });
    _changed();
  }

  Future<void> _chooseJobDeadline() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDate: _jobDeadline ?? now,
    );
    if (value != null) {
      setState(() => _jobDeadline = value);
      _changed();
    }
  }

  Future<void> _chooseEventTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDate: _eventTime ?? now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_eventTime ?? now),
    );
    if (time == null) return;
    setState(() {
      _eventTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
    _changed();
  }

  Map<String, dynamic> _document() {
    if (!_bodyDirty && _originalBody != null) return _originalBody!;
    final paragraphs = _body.text
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'\n\s*\n'));
    return {
      'type': 'doc',
      'content': [
        for (final paragraph in paragraphs) _blockNode(paragraph.trim()),
      ],
    };
  }

  Map<String, dynamic> _blockNode(String block) {
    if (block.startsWith('### ')) {
      return {
        'type': 'heading',
        'attrs': {'level': 3},
        'content': _inlineContent(block.substring(4)),
      };
    }
    if (block.startsWith('## ')) {
      return {
        'type': 'heading',
        'attrs': {'level': 2},
        'content': _inlineContent(block.substring(3)),
      };
    }
    if (block.startsWith('> ')) {
      return {
        'type': 'blockquote',
        'content': [
          {
            'type': 'paragraph',
            'content': _inlineContent(block.substring(2)),
          },
        ],
      };
    }
    final lines = block.split('\n');
    if (lines.isNotEmpty && lines.every((line) => line.startsWith('- '))) {
      return {
        'type': 'bulletList',
        'content': [
          for (final line in lines)
            {
              'type': 'listItem',
              'content': [
                {
                  'type': 'paragraph',
                  'content': _inlineContent(line.substring(2)),
                },
              ],
            },
        ],
      };
    }
    final ordered = RegExp(r'^\d+\.\s+');
    if (lines.isNotEmpty && lines.every(ordered.hasMatch)) {
      return {
        'type': 'orderedList',
        'content': [
          for (final line in lines)
            {
              'type': 'listItem',
              'content': [
                {
                  'type': 'paragraph',
                  'content': _inlineContent(line.replaceFirst(ordered, '')),
                },
              ],
            },
        ],
      };
    }
    return {'type': 'paragraph', 'content': _paragraphContent(block)};
  }

  List<Map<String, dynamic>> _paragraphContent(String paragraph) {
    if (paragraph.isEmpty) return const [];
    final lines = paragraph.split('\n');
    return [
      for (var index = 0; index < lines.length; index++) ...[
        ..._inlineContent(lines[index]),
        if (index < lines.length - 1) {'type': 'hardBreak'},
      ],
    ];
  }

  List<Map<String, dynamic>> _inlineContent(String value) {
    if (value.isEmpty) return const [];
    final pattern = RegExp(
      r'\*\*(.+?)\*\*|\*([^*\n]+)\*|\[([^\]]+)\]\((https?://[^\s)]+)\)',
    );
    final nodes = <Map<String, dynamic>>[];
    var offset = 0;
    for (final match in pattern.allMatches(value)) {
      if (match.start > offset) {
        nodes.add({'type': 'text', 'text': value.substring(offset, match.start)});
      }
      if (match.group(1) != null) {
        nodes.add({
          'type': 'text',
          'text': match.group(1),
          'marks': [
            {'type': 'bold'},
          ],
        });
      } else if (match.group(2) != null) {
        nodes.add({
          'type': 'text',
          'text': match.group(2),
          'marks': [
            {'type': 'italic'},
          ],
        });
      } else {
        nodes.add({
          'type': 'text',
          'text': match.group(3),
          'marks': [
            {
              'type': 'link',
              'attrs': {
                'href': match.group(4),
                'target': '_blank',
                'rel': 'noopener noreferrer nofollow',
              },
            },
          ],
        });
      }
      offset = match.end;
    }
    if (offset < value.length) {
      nodes.add({'type': 'text', 'text': value.substring(offset)});
    }
    return nodes;
  }

  String _plainText(Map<String, dynamic> node) {
    final type = node['type']?.toString() ?? '';
    if (type == 'text') {
      var text = node['text']?.toString() ?? '';
      for (final raw in (node['marks'] as List? ?? const []).whereType<Map>()) {
        final mark = Map<String, dynamic>.from(raw);
        final type = mark['type']?.toString();
        if (type == 'bold') {
          text = '**$text**';
        } else if (type == 'italic') {
          text = '*$text*';
        } else if (type == 'link') {
          final attributes = mark['attrs'] is Map
              ? Map<String, dynamic>.from(mark['attrs'] as Map)
              : const <String, dynamic>{};
          final href = attributes['href']?.toString() ?? '';
          if (href.startsWith('http://') || href.startsWith('https://')) {
            text = '[$text]($href)';
          }
        }
      }
      return text;
    }
    if (type == 'hardBreak') return '\n';
    final own = node['text']?.toString() ?? '';
    final values = (node['content'] as List? ?? const [])
        .whereType<Map>()
        .map((child) => _plainText(Map<String, dynamic>.from(child)))
        .toList(growable: false);
    final joined = switch (type) {
      'doc' => values.join('\n\n'),
      'heading' => '${((node['attrs'] as Map?)?['level'] == 3) ? '###' : '##'} ${values.join()}',
      'blockquote' => '> ${values.join()}',
      'bulletList' => values.map((value) => '- $value').join('\n'),
      'orderedList' => [
          for (var index = 0; index < values.length; index++)
            '${index + 1}. ${values[index]}',
        ].join('\n'),
      'listItem' => values.join(),
      _ => values.join(),
    };
    return '$own$joined'.trim();
  }

  String _summaryValue() {
    final entered = _summary.text.trim();
    if (entered.isNotEmpty) return entered;
    final text = _body.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= 240) return text;
    final short = text.substring(0, 237).replaceFirst(RegExp(r'\s+\S*$'), '');
    return '${short.isEmpty ? text.substring(0, 237) : short}…';
  }

  String? _validate() {
    final headline = _headline.text.trim();
    final summary = _summaryValue();
    final document = _document();
    if (headline.length < 10 || headline.length > 180) {
      return 'Headline must contain 10 to 180 characters.';
    }
    if (_selectedCategory == null) return 'Choose a reporting category.';
    if (_body.text.trim().isEmpty) return 'Write the story before previewing it.';
    if (summary.isEmpty || summary.length > 500) {
      return 'Summary must contain 1 to 500 characters.';
    }
    if (utf8.encode(jsonEncode(document)).length > 100000) {
      return 'The structured article document must stay under 100 KB.';
    }
    if (_mainCategory?.isJobs == true) {
      if (_jobCategoryId.isEmpty) return 'Choose a specific job category.';
      if (_jobDeadline == null) return 'Choose the job application deadline.';
      final today = DateTime.now();
      final minimum = DateTime(today.year, today.month, today.day);
      if (_jobDeadline!.isBefore(minimum)) return 'The job deadline has passed.';
    }
    final source = _existingDeviceMetadata?['media_source']?.toString() ??
        (_images.isNotEmpty
            ? _images.first.location.mediaSource
            : _location?.mediaSource ?? 'none');
    if (_selectedCategory!.cameraOnly &&
        (source != 'camera' ||
            (_databasePostId == null && _images.isEmpty))) {
      return 'Accident reports require a fresh camera photo.';
    }
    if (_isRevision && _correction.text.trim().isEmpty) {
      return 'Explain what is being corrected in this published story.';
    }
    return null;
  }

  void _showPreview() {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final summary = _summaryValue();
    if (_summary.text.trim().isEmpty) {
      _restoring = true;
      _summary.text = summary;
      _restoring = false;
    }
    setState(() {
      _preview = true;
      _error = null;
    });
    unawaited(_persistDraft());
  }

  Future<void> _submit() async {
    final validation = _validate();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    await _run('Sending for review…', () async {
      final summary = _summaryValue();
      final document = _document();
      final category = _selectedCategory!;
      final deadline = _mainCategory?.isJobs == true && _jobDeadline != null
          ? _ymd(_jobDeadline!)
          : null;
      await _persistDraft();

      if (_isRevision) {
        await _repository!.createRevision(
          revisionId: _revisionId,
          postId: _databasePostId!,
          headline: _headline.text,
          summary: summary,
          body: document,
          source: _source.text,
          correctionNote: _correction.text,
          jobDeadline: deadline,
          jobTimezone: deadline == null ? null : _jobTimezone,
        );
        await _complete();
        return;
      }

      if (_databasePostId != null) {
        final current = await _repository!.ownPost(_databasePostId!);
        final status = current?['status']?.toString();
        if (status == 'pending' || status == 'under_review') {
          await _complete();
          return;
        }
        if (status != 'draft' && status != 'changes_requested') {
          throw Exception('This story can no longer be edited.');
        }
      }

      ReportLocation? evidence = _images.isNotEmpty
          ? _images.first.location
          : _location;
      if (_databasePostId == null) {
        final stale = evidence == null ||
            DateTime.now().toUtc().difference(evidence.capturedAt.toUtc()) >
                const Duration(minutes: 14);
        if (stale && _images.isEmpty && !category.cameraOnly) {
          evidence = await _repository!.locate();
          _location = evidence;
        } else if (stale) {
          throw Exception(
            category.cameraOnly
                ? 'Take a fresh camera photo before submitting.'
                : 'Selected photo evidence is stale. Select it again before submitting.',
          );
        }
        if (evidence == null) {
          throw Exception('A fresh reporting location is required.');
        }
        if (_mainCategory?.isJobs == true &&
            evidence.timezone?.isNotEmpty == true) {
          _jobTimezone = evidence.timezone!;
        }
      }

      final postId = await _repository!.savePost(
        postId: _newPostId,
        existingId: _databasePostId,
        headline: _headline.text,
        summary: summary,
        body: document,
        categoryId: category.id,
        source: _source.text,
        tags: _tags.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList(growable: false),
        location: evidence ?? _location,
        eventTime: _eventTime,
        jobDeadline: deadline,
        jobTimezone: deadline == null ? null : _jobTimezone,
      );
      _databasePostId = postId;
      _existingStatus ??= 'draft';
      await _persistDraft();

      final media = await _repository!.media(postId);
      final existingPaths = media
          .map((row) => row['path']?.toString() ?? '')
          .where((path) => path.isNotEmpty)
          .toSet();
      var hasPrimary = media.any((row) => row['primary_evidence'] == true);
      for (var index = 0; index < _images.length; index++) {
        final image = _images[index];
        if (existingPaths.contains(image.evidencePath)) {
          if (index == 0) hasPrimary = true;
          continue;
        }
        setState(() => _progress = 'Uploading photo ${index + 1} of ${_images.length}…');
        final uploaded = await _repository!.uploadEvidence(
          postId: postId,
          image: image,
          primary: !hasPrimary && index == 0,
        );
        final next = [..._images];
        next[index] = uploaded;
        _images = next;
        if (!hasPrimary && index == 0) hasPrimary = true;
        await _persistDraft();
      }
      await _repository!.submit(postId);
      await _complete();
    });
  }

  Future<void> _complete() async {
    _finished = true;
    _autosave?.cancel();
    await _drafts.remove(_owner!, _routeKey);
    if (!mounted) return;
    _message(
      _isRevision
          ? 'Correction submitted for editorial review.'
          : 'Story submitted for editorial review.',
    );
    final ads = AdsScope.read(context);
    if (ads.available &&
        !ads.adFree &&
        !ads.trafficProtected &&
        !ads.fullScreen) {
      final watch = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Story submitted'),
          content: const Text(
            'Optional: watch a rewarded ad to pause ads for 30 minutes. This does not earn points, cash or wallet credit.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Skip'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Watch ad'),
            ),
          ],
        ),
      );
      if (watch == true) await ads.showRewardedAd();
      if (!mounted) return;
    }
    context.go('/my-stories');
  }

  Future<void> _run(
    String progress,
    Future<void> Function() operation,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _progress = progress;
      _error = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
      try {
        await _persistDraft();
      } catch (_) {
        // The original submission error is more useful to the reporter.
      }
    } finally {
      if (mounted && !_finished) {
        setState(() {
          _busy = false;
          _progress = '';
        });
      }
    }
  }

  void _message(String value, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: danger ? AppColors.redDark : AppColors.success,
      ),
    );
  }

  DateTime? _dateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  DateTime? _dateOnly(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    final parts = value.toString().split('-');
    if (parts.length != 3) return null;
    return DateTime.tryParse('${parts[0]}-${parts[1]}-${parts[2]}');
  }

  String _ymd(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    return '${_ymd(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  bool get _detailsReady =>
      _mainCategoryId.isNotEmpty &&
      _headline.text.trim().isNotEmpty &&
      _body.text.trim().isNotEmpty;

  bool get _evidenceReady {
    if (_isRevision) return true;
    if (_location == null) return false;
    if (_selectedCategory?.cameraOnly == true) return _images.isNotEmpty;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.contentMax,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ReportWorkspaceHeader(
                  revision: _isRevision,
                  editing: widget.postId != null,
                  detailsReady: _detailsReady,
                  evidenceReady: _evidenceReady,
                  previewReady: _preview,
                ),
                if (_draftRestored) ...[
                  const SizedBox(height: 12),
                  const _Notice(
                    icon: Icons.restore_rounded,
                    text: 'Your locally saved draft was restored on this device.',
                  ),
                ],
                if (_existingStatus == 'changes_requested') ...[
                  const SizedBox(height: 12),
                  const _Notice(
                    icon: Icons.edit_note_rounded,
                    text: 'Editorial changes were requested. Update the story and send it again.',
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _Notice(
                    icon: Icons.error_outline_rounded,
                    text: _error!,
                    danger: true,
                  ),
                ],
                if (_progress.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _Notice(icon: Icons.sync_rounded, text: _progress),
                ],
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final sidebar = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_isRevision) _evidenceCard(),
                        if (_preview) ...[
                          if (!_isRevision) const SizedBox(height: 14),
                          _previewCard(),
                        ],
                        const SizedBox(height: 14),
                        _submissionCard(),
                      ],
                    );
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: _storyCard()),
                              const SizedBox(width: 16),
                              Expanded(flex: 3, child: sidebar),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _storyCard(),
                              const SizedBox(height: 14),
                              sidebar,
                            ],
                          );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _storyCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionHeading(
                icon: Icons.article_outlined,
                title: 'Story details',
                subtitle: 'Write a clear, factual account for editorial review.',
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _mainCategoryId.isEmpty ? null : _mainCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  for (final category in _mainCategories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: _busy || _isRevision ? null : _categoryChanged,
              ),
              if (_mainCategory?.isJobs == true) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _jobCategoryId.isEmpty ? null : _jobCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Job category *',
                    prefixIcon: Icon(Icons.work_outline_rounded),
                  ),
                  items: [
                    for (final category in _jobCategories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          setState(() => _jobCategoryId = value ?? '');
                          _changed();
                        },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _chooseJobDeadline,
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text(
                    _jobDeadline == null
                        ? 'Choose application deadline *'
                        : 'Deadline: ${_ymd(_jobDeadline!)} ($_jobTimezone)',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _headline,
                enabled: !_busy,
                maxLength: 180,
                decoration: const InputDecoration(
                  labelText: 'Headline *',
                  hintText: 'Describe what happened clearly',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _summary,
                enabled: !_busy,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Summary',
                  hintText: 'Optional — generated from the story if left blank',
                ),
              ),
              const SizedBox(height: 8),
              _editorToolbar(),
              const SizedBox(height: 6),
              TextField(
                controller: _body,
                enabled: !_busy,
                minLines: 9,
                maxLines: 18,
                decoration: const InputDecoration(
                  labelText: 'Full story *',
                  alignLabelWithHint: true,
                  hintText: 'Write verified facts. Separate paragraphs with a blank line.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _source,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Source',
                  hintText: 'Witness, public record, official statement…',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tags,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: 'traffic, rain, community',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _chooseEventTime,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(
                        _eventTime == null
                            ? 'Add event time'
                            : _dateLabel(_eventTime!),
                      ),
                    ),
                  ),
                  if (_eventTime != null) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Clear event time',
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() => _eventTime = null);
                              _changed();
                            },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ],
              ),
              if (_isRevision) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _correction,
                  enabled: !_busy,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Correction note *',
                    hintText: 'Explain exactly what changed and why',
                  ),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _submissionCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.fact_check_outlined,
                    color: AppColors.red,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Final review',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              const Text(
                'Check names, dates, evidence and location before sending. Editorial review begins after submission.',
                style: TextStyle(color: AppColors.muted, height: 1.45),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _busy ? null : _showPreview,
                icon: const Icon(Icons.preview_outlined),
                label: const Text('Preview story'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _busy
                      ? 'Working...'
                      : _isRevision
                          ? 'Send correction'
                          : 'Send for review',
                ),
              ),
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_outlined, size: 15, color: AppColors.muted),
                  SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Changes are saved locally while you work.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _editorToolbar() => Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border),
        ),
        child: Wrap(
          spacing: 2,
          runSpacing: 2,
          children: [
            _EditorButton(
              tooltip: 'Undo',
              icon: Icons.undo_rounded,
              onPressed: _busy ? null : _undoBody,
            ),
            _EditorButton(
              tooltip: 'Redo',
              icon: Icons.redo_rounded,
              onPressed: _busy ? null : _redoBody,
            ),
            _EditorButton(
              tooltip: 'Heading',
              label: 'H2',
              onPressed: _busy ? null : () => _prefixBodyLines('## '),
            ),
            _EditorButton(
              tooltip: 'Bold',
              icon: Icons.format_bold_rounded,
              onPressed: _busy ? null : () => _wrapBody('**', '**'),
            ),
            _EditorButton(
              tooltip: 'Italic',
              icon: Icons.format_italic_rounded,
              onPressed: _busy ? null : () => _wrapBody('*', '*'),
            ),
            _EditorButton(
              tooltip: 'Bullet list',
              icon: Icons.format_list_bulleted_rounded,
              onPressed: _busy ? null : () => _prefixBodyLines('- '),
            ),
            _EditorButton(
              tooltip: 'Numbered list',
              icon: Icons.format_list_numbered_rounded,
              onPressed: _busy ? null : () => _prefixBodyLines('1. '),
            ),
            _EditorButton(
              tooltip: 'Quote',
              icon: Icons.format_quote_rounded,
              onPressed: _busy ? null : () => _prefixBodyLines('> '),
            ),
            _EditorButton(
              tooltip: 'Link',
              icon: Icons.link_rounded,
              onPressed: _busy
                  ? null
                  : () => _wrapBody('[', '](https://)', fallback: 'link text'),
            ),
          ],
        ),
      );

  Widget _evidenceCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeading(
                icon: Icons.add_a_photo_outlined,
                title: 'Evidence & location',
                subtitle: _selectedCategory?.cameraOnly == true
                    ? 'A fresh rear-camera photo is required for accident reports.'
                    : 'Add up to five photos and confirm the reporting location.',
              ),
              const SizedBox(height: 12),
              if (_canManageEvidence)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _takePhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Camera'),
                    ),
                    if (_selectedCategory?.cameraOnly != true)
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _pickGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Gallery'),
                      ),
                  ],
                ),
              if (_images.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 126,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => _imageTile(index),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _Notice(
                icon: Icons.location_on_outlined,
                text: _location == null
                    ? 'No fresh reporting location yet.'
                    : '${_location!.cityName} • accuracy ${_location!.accuracy.toStringAsFixed(0)} m • ${_location!.mediaSource}',
              ),
              if (_canManageEvidence) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _detectLocation,
                  icon: const Icon(Icons.my_location_rounded),
                  label: const Text('Refresh posting location'),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'The server assigns city, area, locality and timezone from the private location ticket. These fields are not manually editable.',
                style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      );

  Widget _imageTile(int index) {
    final image = _images[index];
    return SizedBox(
      width: 118,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: FutureBuilder<Uint8List>(
              future: image.file.readAsBytes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const ColoredBox(
                    color: AppColors.surface,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return Image.memory(snapshot.data!, fit: BoxFit.cover);
              },
            ),
          ),
          Positioned(
            left: 5,
            bottom: 5,
            child: GestureDetector(
              onTap: index == 0 ? null : () => _makePrimary(index),
              child: Chip(
                visualDensity: VisualDensity.compact,
                label: Text(index == 0 ? 'Primary' : 'Make primary'),
              ),
            ),
          ),
          if (_canManageEvidence)
            Positioned(
              right: 2,
              top: 2,
              child: IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                tooltip: 'Remove photo',
                onPressed: _busy ? null : () => _removeImage(index),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  Widget _previewCard() => Card(
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'REVIEW BEFORE SENDING',
                style: TextStyle(
                  color: AppColors.red,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(_headline.text.trim(), style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(_summaryValue(), style: const TextStyle(color: AppColors.muted)),
              const Divider(height: 28),
              Text(_body.text.trim(), style: const TextStyle(height: 1.55)),
              const SizedBox(height: 12),
              Text(
                '${_selectedCategory?.name ?? ''} • ${_location?.cityName ?? 'Existing verified location'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
}

class _ReportWorkspaceHeader extends StatelessWidget {
  const _ReportWorkspaceHeader({
    required this.revision,
    required this.editing,
    required this.detailsReady,
    required this.evidenceReady,
    required this.previewReady,
  });

  final bool revision;
  final bool editing;
  final bool detailsReady;
  final bool evidenceReady;
  final bool previewReady;

  @override
  Widget build(BuildContext context) {
    final title = revision
        ? 'Correct your published story'
        : editing
            ? 'Update your story'
            : 'Share verified local news';
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF101826), Color(0xFF202D41)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.edit_document,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'REPORTER NEWSROOM',
                      style: TextStyle(
                        color: Color(0xFFFF8A8A),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      revision
                          ? 'Explain the correction clearly. Your published story stays visible until editorial approval.'
                          : 'Build the story, attach supporting evidence and review everything before submission.',
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/my-stories'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF526175)),
                ),
                icon: const Icon(Icons.library_books_outlined),
                label: const Text('My stories'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ReportStep(
                number: '1',
                label: 'Story',
                complete: detailsReady,
                active: !detailsReady,
              ),
              _ReportStep(
                number: '2',
                label: 'Evidence',
                complete: evidenceReady,
                active: detailsReady && !evidenceReady,
              ),
              _ReportStep(
                number: '3',
                label: 'Review',
                complete: previewReady,
                active: detailsReady && evidenceReady,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportStep extends StatelessWidget {
  const _ReportStep({
    required this.number,
    required this.label,
    required this.complete,
    required this.active,
  });

  final String number;
  final String label;
  final bool complete;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final highlighted = complete || active;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? Colors.white.withValues(alpha: .12)
            : Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: highlighted
              ? Colors.white.withValues(alpha: .26)
              : Colors.white.withValues(alpha: .1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 23,
            height: 23,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: complete
                  ? AppColors.success
                  : active
                      ? AppColors.red
                      : const Color(0xFF415065),
              shape: BoxShape.circle,
            ),
            child: complete
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: highlighted ? Colors.white : const Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColors.red, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    this.danger = false,
  });

  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (danger ? AppColors.red : AppColors.focus).withValues(alpha: .07),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: (danger ? AppColors.red : AppColors.focus).withValues(alpha: .22),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: danger ? AppColors.red : AppColors.focus),
            const SizedBox(width: 9),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _EditorButton extends StatelessWidget {
  const _EditorButton({
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.label,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? label;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onPressed,
          icon: icon == null
              ? Text(
                  label ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                )
              : Icon(icon, size: 20),
        ),
      );
}
