import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';

const int _maxPages = 15;
const int _maxBytes = 10 * 1024 * 1024;

class _Page {
  final String name;
  final List<int> bytes;
  final bool isImage;
  const _Page(this.name, this.bytes, this.isImage);
}

/// Student: download the question paper, write on paper, then upload photos / PDFs of the answer sheets.
class PaperExamScreen extends StatefulWidget {
  final int examId;
  const PaperExamScreen({super.key, required this.examId});

  @override
  State<PaperExamScreen> createState() => _PaperExamScreenState();
}

class _PaperExamScreenState extends State<PaperExamScreen> {
  Map<String, dynamic>? _exam;
  Map<String, dynamic>? _attempt;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  final List<_Page> _pages = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Api.get('/my-exams/${widget.examId}');
      if (!mounted) return;
      setState(() {
        _exam = Map<String, dynamic>.from(res['exam'] as Map);
        _attempt = res['attempt'] is Map ? Map<String, dynamic>.from(res['attempt'] as Map) : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool get _locked {
    final s = str(_attempt?['status']);
    return s == 'graded' || s == 'published';
  }

  bool get _isOpen => _exam?['is_open'] == true;

  /* ---------------------------- picking ---------------------------- */

  Future<void> _add(String name, List<int> bytes, bool isImage) async {
    if (_pages.length >= _maxPages) {
      showSnack(context, 'You can upload at most $_maxPages pages', error: true);
      return;
    }
    if (bytes.length > _maxBytes) {
      showSnack(context, '$name is larger than 10 MB', error: true);
      return;
    }
    setState(() => _pages.add(_Page(name, bytes, isImage)));
  }

  Future<void> _takePhoto() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2400);
      if (x == null) return;
      await _add(x.name.isEmpty ? 'photo-${DateTime.now().millisecondsSinceEpoch}.jpg' : x.name,
          await x.readAsBytes(), true);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open the camera: $e', error: true);
    }
  }

  Future<void> _choosePhotos() async {
    try {
      final list = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 2400);
      for (final x in list) {
        await _add(x.name, await x.readAsBytes(), true);
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open the gallery: $e', error: true);
    }
  }

  Future<void> _choosePdf() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        allowMultiple: true,
        withData: true,
      );
      if (res == null) return;
      for (final f in res.files) {
        if (f.bytes == null) continue;
        await _add(f.name, f.bytes!, false);
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not pick the file: $e', error: true);
    }
  }

  void _move(int i, int d) {
    final j = i + d;
    if (j < 0 || j >= _pages.length) return;
    setState(() {
      final p = _pages.removeAt(i);
      _pages.insert(j, p);
    });
  }

  /* ---------------------------- submit ---------------------------- */

  Future<void> _submit() async {
    if (_pages.isEmpty) {
      showSnack(context, 'Add at least one page', error: true);
      return;
    }
    final ok = await confirmDialog(
      context,
      'Send answer sheets',
      'Send ${_pages.length} page(s) to your teacher?'
          '${_attempt != null ? ' This replaces your earlier upload.' : ''}',
      yes: 'Send',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final res = await Api.upload(
        '/my-exams/${widget.examId}/paper-submission',
        fileField: 'files[]',
        files: [for (final p in _pages) UploadFile(p.name, p.bytes)],
      );
      if (!mounted) return;
      showSnack(context, str(res['message'], 'Answer sheets sent'));
      setState(() {
        _pages.clear();
        _busy = false;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, e.toString(), error: true);
    }
  }

  /* ---------------------------- UI ---------------------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_exam != null ? str(_exam!['title'], 'Paper exam') : 'Paper exam')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(onRefresh: _load, child: _content()),
    );
  }

  Widget _content() {
    final e = _exam!;
    final status = str(_attempt?['status']);
    final published = status == 'published';
    final paperUrl = str(e['question_paper_url']);
    final canUpload = !_locked && (_attempt != null || _isOpen);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(str(e['title']),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimary)),
                ),
                StatusChip(_attempt == null ? 'pending' : (status == 'graded' ? 'submitted' : status)),
              ]),
              const SizedBox(height: 4),
              Text('${str(e['subject'], '—')} · by ${str(e['created_by_name'])}',
                  style: TextStyle(color: Colors.grey.shade600)),
              const Divider(height: 24),
              Text('${formatMarks(e['total_marks'])} marks'
                  '${e['pass_marks'] != null ? ' · pass ${formatMarks(e['pass_marks'])}' : ''}'),
              if (str(e['start_at']).isNotEmpty) Text('Opens: ${formatDateTime(e['start_at'])}'),
              if (str(e['end_at']).isNotEmpty) Text('Due: ${formatDateTime(e['end_at'])}'),
            ],
          ),
        ),
        if (str(e['instructions']).isNotEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [const SectionTitle('Instructions'), Text(str(e['instructions']))],
            ),
          ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('1. Question paper'),
              if (paperUrl.isEmpty)
                Text('The question paper has not been uploaded yet.', style: TextStyle(color: Colors.grey.shade600))
              else
                OutlinedButton.icon(
                  onPressed: () => openUrl(context, paperUrl),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Open question paper'),
                ),
            ],
          ),
        ),
        if (published) _resultCard() else if (status == 'graded') ...[
          const MessageBanner('Your answer sheets have been received and are being evaluated.', error: false),
        ],
        if (_attempt != null) _submittedCard(),
        if (canUpload) _uploadCard() else if (!_locked && _attempt == null)
          MessageBanner(e['not_open_yet'] == true ? 'This exam is not open yet.' : 'The deadline has passed.'),
      ],
    );
  }

  Widget _resultCard() {
    final a = _attempt!;
    final e = _exam!;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Result'),
          Text('${formatMarks(a['marks'])} / ${formatMarks(e['total_marks'])}',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: kPrimary)),
          if (e['pass_marks'] != null && a['marks'] != null)
            Text(toDouble(a['marks']) >= toDouble(e['pass_marks']) ? 'Passed' : 'Not passed',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: toDouble(a['marks']) >= toDouble(e['pass_marks'])
                        ? Colors.green.shade700
                        : Colors.red.shade700)),
          if (str(a['remarks']).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Teacher\'s remarks', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            Text(str(a['remarks'])),
          ],
        ],
      ),
    );
  }

  Widget _submittedCard() {
    final files = asList(_attempt!['files']);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Submitted answer sheets'),
          Text('Submitted ${formatDateTime(_attempt!['submitted_at'])}',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          if (files.isEmpty) const Text('No files'),
          for (final f in files)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(str(f['name']).toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image_outlined),
              title: Text(str(f['name'], 'Answer sheet'), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => openUrl(context, str(f['url'])),
            ),
        ],
      ),
    );
  }

  Widget _uploadCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(_attempt == null ? '2. Upload your answer sheets' : 'Replace your answer sheets'),
          Text('Photograph or scan every page (up to $_maxPages, 10 MB each), or pick a PDF.',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(onPressed: _busy ? null : _takePhoto, icon: const Icon(Icons.photo_camera_outlined), label: const Text('Camera')),
              OutlinedButton.icon(onPressed: _busy ? null : _choosePhotos, icon: const Icon(Icons.photo_library_outlined), label: const Text('Photos')),
              OutlinedButton.icon(onPressed: _busy ? null : _choosePdf, icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('PDF')),
            ],
          ),
          if (_pages.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < _pages.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _pages[i].isImage
                          ? Image.memory(_asBytes(_pages[i].bytes), width: 56, height: 56, fit: BoxFit.cover)
                          : Container(
                              width: 56,
                              height: 56,
                              color: Colors.red.shade50,
                              child: Icon(Icons.picture_as_pdf, color: Colors.red.shade400),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Page ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(_pages[i].name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: i > 0 ? () => _move(i, -1) : null,
                        icon: const Icon(Icons.arrow_upward, size: 20)),
                    IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: i < _pages.length - 1 ? () => _move(i, 1) : null,
                        icon: const Icon(Icons.arrow_downward, size: 20)),
                    IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _pages.removeAt(i)),
                        icon: Icon(Icons.close, size: 20, color: Colors.red.shade600)),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            PrimaryButton(label: 'Send ${_pages.length} page(s)', loading: _busy, onPressed: _submit),
          ],
        ],
      ),
    );
  }
}

Uint8List _asBytes(List<int> b) => b is Uint8List ? b : Uint8List.fromList(b);
