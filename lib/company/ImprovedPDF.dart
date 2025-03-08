import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ImprovedPDFScreen extends StatefulWidget {
  final String pdfUrl;
  // Can accept either a file path or URL
  final bool isLocalFile;

  const ImprovedPDFScreen({
    Key? key,
    required this.pdfUrl,
    this.isLocalFile = false,
  }) : super(key: key);

  @override
  State<ImprovedPDFScreen> createState() => _ImprovedPDFScreenState();
}

class _ImprovedPDFScreenState extends State<ImprovedPDFScreen> {
  late PdfViewerController _pdfViewerController;
  bool _isLoading = true;
  String? _localPath;
  String? _errorMessage;
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _initPDF();
  }

  Future<void> _initPDF() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.isLocalFile) {
        _localPath = widget.pdfUrl;
      } else {
        await _downloadPDF(widget.pdfUrl);
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading PDF: $e';
      });
      debugPrint('PDF loading error: $e');
    }
  }

  Future<void> _downloadPDF(String url) async {
    try {
      debugPrint('Downloading PDF from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 Flutter App',
          'Accept': 'application/pdf',
        },
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to download PDF: HTTP status ${response.statusCode}');
      }
      
      if (response.bodyBytes.isEmpty) {
        throw Exception('Downloaded file is empty');
      }
      
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/pdf_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      
      await file.writeAsBytes(response.bodyBytes);
      debugPrint('PDF saved to: $filePath (${response.bodyBytes.length} bytes)');
      
      _localPath = filePath;
    } catch (e) {
      debugPrint('Download error: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initPDF,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading PDF...'),
          ],
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load PDF',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initPDF,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_localPath == null) {
      return const Center(
        child: Text('No PDF file available'),
      );
    }
    
    return SfPdfViewer.file(
      File(_localPath!),
      controller: _pdfViewerController,
      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
        setState(() {
          _totalPages = details.document.pages.count;
        });
      },
      onPageChanged: (PdfPageChangedDetails details) {
        setState(() {
          _currentPage = details.newPageNumber;
        });
      },
    );
  }

  Widget? _buildBottomNavigationBar() {
    if (_errorMessage != null || _isLoading || _totalPages == 0) {
      return null;
    }
    
    return Container(
      height: 50,
      color: Colors.grey[300],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _currentPage > 0 
                ? () => _pdfViewerController.previousPage()
                : null,
          ),
          Text(
            'Page ${_currentPage + 1} of $_totalPages',
            style: const TextStyle(fontSize: 16),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _currentPage < _totalPages - 1 
                ? () => _pdfViewerController.nextPage()
                : null,
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }
}