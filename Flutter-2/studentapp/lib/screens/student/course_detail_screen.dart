import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../config.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';

class CourseDetailScreen extends StatefulWidget {
  final int courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  Razorpay? _razorpay;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _loadError;

  int? _batchId;
  bool _paying = false;
  String? _error;

  // razorpay_flutter only works on Android and iOS
  bool get _paymentsSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (_paymentsSupported) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    }
    _load();
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final res = await Api.get('/courses/${widget.courseId}');
      if (!mounted) return;
      setState(() {
        _data = res;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.message;
      });
    }
  }

  Future<void> _buy(Map<String, dynamic> course, bool needsBatch) async {
    if (needsBatch && _batchId == null) {
      setState(() => _error = 'Please select a batch');
      return;
    }
    final price = toDouble(course['price']);
    if (price > 0 && !_paymentsSupported) {
      setState(() => _error = 'Online payment works only in the Android or iOS app.');
      return;
    }

    setState(() {
      _paying = true;
      _error = null;
    });

    try {
      final order = await Api.post(
        '/payments/create-order',
        body: {'course_id': toInt(course['id']), 'batch_id': _batchId},
      );
      if (!mounted) return;

      // Free course: the server already enrolled the student.
      if (order['free'] == true) {
        showSnack(context, str(order['message'], 'Enrolled successfully'));
        Navigator.pop(context, true);
        return;
      }

      final user = order['user'] is Map ? Map<String, dynamic>.from(order['user'] as Map) : <String, dynamic>{};
      _razorpay!.open(<String, dynamic>{
        'key': order['key_id'],
        'amount': order['amount'],
        'currency': order['currency'],
        'name': AppConfig.appName,
        'description': order['course_name'],
        'order_id': order['order_id'],
        'prefill': {'name': user['name'], 'email': user['email']},
        'theme': {'color': '#1E3A8A'},
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _error = 'Could not open the payment screen. Please try again.';
      });
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse r) async {
    try {
      final res = await Api.post('/payments/verify', body: {
        'razorpay_order_id': r.orderId ?? '',
        'razorpay_payment_id': r.paymentId ?? '',
        'razorpay_signature': r.signature ?? '',
      });
      if (!mounted) return;
      showSnack(context, str(res['message'], 'Payment successful'));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _error = 'Payment was made but could not be confirmed: ${e.message}. '
            'Contact the academy with payment id ${r.paymentId ?? ''}.';
      });
    }
  }

  void _onPaymentError(PaymentFailureResponse r) {
    if (!mounted) return;
    setState(() {
      _paying = false;
      _error = (r.message == null || r.message!.isEmpty) ? 'Payment failed or was cancelled' : r.message;
    });
  }

  void _onExternalWallet(ExternalWalletResponse r) {
    // Nothing to do; the wallet app completes the payment itself.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Course details')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingView();
    if (_loadError != null || _data == null) {
      return ErrorView(message: _loadError ?? 'Could not load the course', onRetry: _load);
    }

    final course = Map<String, dynamic>.from(_data!['course'] as Map);
    final batches = asList(_data!['batches']);
    final purchased = _data!['purchased'] == true;
    final needsBatch = batches.isNotEmpty;
    final price = toDouble(course['price']);

    return ListView(
      children: [
        NetImage(url: course['image_url']?.toString(), height: 200),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(str(course['course_name']),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kPrimary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (str(course['duration']).isNotEmpty) ...[
                    Icon(Icons.schedule, size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(str(course['duration'])),
                    const SizedBox(width: 16),
                  ],
                  Text(formatPrice(course['price']),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 14),
              Text(str(course['description'], 'No description yet.'),
                  style: TextStyle(color: Colors.grey.shade800, height: 1.4)),
              const SizedBox(height: 20),
              const SectionTitle('Batches'),
              if (!needsBatch)
                Text('No batches scheduled yet.', style: TextStyle(color: Colors.grey.shade600)),
              for (final b in batches) _batchTile(b, purchased),
              const SizedBox(height: 12),
              MessageBanner(_error),
              if (purchased)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text('You have already purchased this course. Find it in My Courses.',
                      style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600)),
                )
              else
                PrimaryButton(
                  label: price > 0 ? 'Buy now — ${formatPrice(price)}' : 'Enrol for free',
                  loading: _paying,
                  onPressed: () => _buy(course, needsBatch),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _batchTile(Map<String, dynamic> b, bool purchased) {
    final id = toInt(b['id']);
    final seatsLeft = toInt(b['seats_left']);
    final full = seatsLeft <= 0;
    final selected = _batchId == id;

    return Opacity(
      opacity: full ? 0.5 : 1,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        onTap: (purchased || full) ? null : () => setState(() => _batchId = id),
        child: Row(
          children: [
            if (!purchased)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? kPrimary : Colors.grey,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(str(b['batch_name']), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${formatDate(b['start_date'])} → ${formatDate(b['end_date'])}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            Text(full ? 'Full' : '$seatsLeft seats left', style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
