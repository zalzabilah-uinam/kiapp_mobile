import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/download_provider.dart';
import '../services/api_client.dart';
import '../services/payment_service.dart';

class PaymentScreen extends StatefulWidget {
  final PaymentTransaction initial;
  const PaymentScreen({super.key, required this.initial});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late PaymentTransaction _trx;
  Timer? _poll;
  Timer? _tick;
  bool _checking = false;
  bool _expiredHandled = false;
  Duration _remaining = Duration.zero;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _trx = widget.initial;
    _recomputeRemaining();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        _recomputeRemaining();
      });
    });
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _checkStatus());
    // langsung cek sekali
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStatus());
  }

  void _recomputeRemaining() {
    if (_trx.expiredAt == null) {
      _remaining = const Duration(minutes: 15);
      return;
    }
    _remaining = _trx.expiredAt!.difference(_now);
    if (_remaining.isNegative) _remaining = Duration.zero;
  }

  Future<void> _checkStatus() async {
    if (_checking || _expiredHandled) return;
    _checking = true;
    try {
      final svc = context.read<PaymentService>();
      final fresh = await svc.getStatus(_trx.orderId);
      if (!mounted) return;
      if (fresh.status == 'completed') {
        _poll?.cancel();
        _tick?.cancel();
        // Refresh quota di provider lain supaya UI langsung sync
        // (home badge, settings, dsb).
        // ignore: use_build_context_synchronously
        final auth = context.read<AuthProvider>();
        final dl = context.read<DownloadProvider>();
        await auth.refreshProfile();
        await dl.refreshQuota();
        if (!mounted) return;
        await _celebrate();
      } else if (fresh.status == 'expired' && !_expiredHandled) {
        _expiredHandled = true;
        _poll?.cancel();
      } else {
        setState(() {
          _trx = fresh;
          _recomputeRemaining();
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      // ignore; polling akan coba lagi
    } finally {
      _checking = false;
    }
  }

  Future<void> _celebrate() async {
    if (!mounted) return;
    final credits = _trx.pkg?.credits ?? 0;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        icon: const Icon(Icons.check_circle, color: AppTheme.success, size: 56),
        title: const Text(
          'Pembayaran Berhasil',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        content: Text(
          credits > 0
              ? '+$credits unduhan telah ditambahkan ke akun Anda.'
              : 'Saldo telah ditambahkan ke akun Anda.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // keluar payment screen
            },
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rupiah = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Pembayaran'),
        actions: [
          IconButton(
            tooltip: 'Cek status sekarang',
            icon: const Icon(Icons.refresh),
            onPressed: _checkStatus,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 88, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _Header(trx: _trx, rupiah: rupiah),
                const SizedBox(height: 24),
                _QrCard(trx: _trx, remaining: _remaining),
                const SizedBox(height: 20),
                const _HowToPay(),
                const SizedBox(height: 16),
                _OrderIdRow(orderId: _trx.orderId),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatRemaining(Duration d) {
  if (d <= Duration.zero) return '00:00';
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final h = d.inHours;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:$m:$s';
  }
  return '$m:$s';
}

class _Header extends StatelessWidget {
  final PaymentTransaction trx;
  final NumberFormat rupiah;
  const _Header({required this.trx, required this.rupiah});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          trx.pkg?.name ?? 'Top Up',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${trx.pkg?.credits ?? 0} unduhan',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 18),
        Text(
          rupiah.format(trx.totalPayment),
          style: const TextStyle(
            color: AppTheme.accent,
            fontWeight: FontWeight.w800,
            fontSize: 30,
          ),
        ),
        if (trx.fee > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Termasuk biaya layanan ${rupiah.format(trx.fee)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _QrCard extends StatelessWidget {
  final PaymentTransaction trx;
  final Duration remaining;
  const _QrCard({required this.trx, required this.remaining});
  @override
  Widget build(BuildContext context) {
    final expired = remaining <= Duration.zero;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassCard(radius: 22),
      child: Column(
        children: [
          if (trx.isSandbox)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: AppTheme.error, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'MODE SANDBOX. QR dummy, e-wallet production akan tolak. Hubungi admin.',
                      style: TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: trx.qrString == null || trx.qrString!.isEmpty
                ? const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(
                      child: Icon(Icons.qr_code_2,
                          size: 96, color: Colors.black26),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      QrImageView(
                        data: trx.qrString!,
                        size: 220,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Panjang: ${trx.qrString!.length} char',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          if (expired)
            Text(
              'QR sudah kedaluwarsa',
              style: TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Text(
              'Kedaluwarsa dalam ${_formatRemaining(remaining)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 13,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            trx.paymentMethod.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _HowToPay extends StatelessWidget {
  const _HowToPay();
  @override
  Widget build(BuildContext context) {
    final steps = const [
      'Buka aplikasi e-wallet / mobile banking yang mendukung QRIS',
      'Pilih menu Scan / Bayar',
      'Arahkan ke kode QR di atas',
      'Konfirmasi nominal otomatis terisi (sesuai QRIS)',
      'Pembayaran otomatis terdeteksi',
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassCard(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cara Bayar',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    steps[i],
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            if (i < steps.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _OrderIdRow extends StatelessWidget {
  final String orderId;
  const _OrderIdRow({required this.orderId});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: orderId));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order ID disalin')),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ID: $orderId',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.copy,
                size: 14, color: Colors.white.withValues(alpha: 0.55)),
          ],
        ),
      ),
    );
  }
}
