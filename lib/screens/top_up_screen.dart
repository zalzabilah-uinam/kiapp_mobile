import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../services/api_client.dart';
import '../services/payment_service.dart';
import 'payment_screen.dart';
import 'payment_history_screen.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  late Future<List<CreditPackage>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CreditPackage>> _load() {
    return context.read<PaymentService>().listPackages();
  }

  void _refresh() {
    setState(() => _future = _load());
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
        title: const Text('Top Up Kuota'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Riwayat Pembelian',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PaymentHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: FutureBuilder<List<CreditPackage>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return _ErrorView(
                  message: snap.error.toString(),
                  onRetry: _refresh,
                );
              }
              final pkgs = snap.data ?? const [];
              if (pkgs.isEmpty) {
                return const Center(
                  child: Text(
                    'Belum ada paket tersedia.',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 88, 16, 24),
                  itemCount: pkgs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final p = pkgs[i];
                    return _PackageCard(pkg: p, rupiah: rupiah);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final CreditPackage pkg;
  final NumberFormat rupiah;
  const _PackageCard({required this.pkg, required this.rupiah});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _onTap(context),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: AppTheme.glassCard(radius: 20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${pkg.credits}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pkg.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pkg.credits} unduhan',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    rupiah.format(pkg.priceIdr),
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Icon(Icons.chevron_right, color: Colors.white70),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context) async {
    final svc = context.read<PaymentService>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final trx = await svc.createTransaction(pkg.id);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaymentScreen(initial: trx),
        ),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
