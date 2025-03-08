import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PDFScreen extends StatefulWidget {
  final String pdfPath;

  const PDFScreen({Key? key, required this.pdfPath}) : super(key: key);

  @override
  State<PDFScreen> createState() => _PDFScreenState();
}

class _PDFScreenState extends State<PDFScreen> {
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  PDFViewController? _pdfViewController;

  @override
  void initState() {
    super.initState();
    // Add a longer delay to ensure file is completely written
    Future.delayed(const Duration(milliseconds: 500), _checkFileExists);
  }

  void _checkFileExists() async {
    try {
      final file = File(widget.pdfPath);
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      
      debugPrint('PDF file exists: $exists, size: $size bytes');
      
      if (!exists || size == 0) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _errorMessage = 'PDF file not found or empty';
        });
      } else {
        // If file exists and has content, ensure UI updates
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking PDF file: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _errorMessage = 'Error loading PDF: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resume'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
              _checkFileExists();
            },
          ),
        ],
      ),
      body: _hasError
          ? Center(
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
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                if (!_isLoading)
                  PDFView(
                    filePath: widget.pdfPath,
                    enableSwipe: true,
                    swipeHorizontal: true, 
                    autoSpacing: true,
                    pageFling: true,
                    pageSnap: true,
                    defaultPage: _currentPage,
                    fitPolicy: FitPolicy.BOTH, // Try BOTH instead of WIDTH
                    preventLinkNavigation: false,
                    onRender: (_pages) {
                      if (mounted) {
                        setState(() {
                          _totalPages = _pages!;
                          _isLoading = false;
                        });
                      }
                      debugPrint('PDF rendered with $_totalPages pages');
                    },
                    onError: (error) {
                      debugPrint('PDF view error: $error');
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                          _hasError = true;
                          _errorMessage = error.toString();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $error')),
                        );
                      }
                    },
                    onPageError: (page, error) {
                      debugPrint('Error on page $page: $error');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error on page $page: $error')),
                        );
                      }
                    },
                    onViewCreated: (PDFViewController pdfViewController) {
                      _pdfViewController = pdfViewController;
                      debugPrint('PDF view controller created');
                    },
                    onPageChanged: (int? page, int? total) {
                      if (mounted && page != null) {
                        setState(() {
                          _currentPage = page;
                        });
                      }
                    },
                  ),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
      floatingActionButton: !_hasError && _totalPages > 1 && _pdfViewController != null
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                _currentPage > 0
                    ? FloatingActionButton.small(
                        heroTag: "btn1",
                        child: const Icon(Icons.arrow_back),
                        onPressed: () {
                          _currentPage--;
                          _pdfViewController!.setPage(_currentPage);
                        },
                      )
                    : Container(),
                const SizedBox(width: 10),
                _currentPage < _totalPages - 1
                    ? FloatingActionButton.small(
                        heroTag: "btn2",
                        child: const Icon(Icons.arrow_forward),
                        onPressed: () {
                          _currentPage++;
                          _pdfViewController!.setPage(_currentPage);
                        },
                      )
                    : Container(),
              ],
            )
          : null,
      bottomNavigationBar: !_hasError && _totalPages > 0
          ? Container(
              height: 50,
              color: Colors.grey[300],
              child: Center(
                child: Text(
                  'Page ${_currentPage + 1} of $_totalPages',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            )
          : null,
    );
  }
  
  @override
  void dispose() {
    // Clear any references
    _pdfViewController = null;
    super.dispose();
  }
}