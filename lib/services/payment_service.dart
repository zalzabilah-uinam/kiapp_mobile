import '../config/api_config.dart';
import 'api_client.dart';

class CreditPackage {
  final String id;
  final String name;
  final int credits;
  final int priceIdr;
  final int? sortOrder;

  CreditPackage({
    required this.id,
    required this.name,
    required this.credits,
    required this.priceIdr,
    this.sortOrder,
  });

  factory CreditPackage.fromJson(Map<String, dynamic> j) => CreditPackage(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        credits: _asInt(j['credits']),
        priceIdr: _asInt(j['priceIdr']),
        sortOrder: _asIntOrNull(j['sortOrder']),
      );
}

class PaymentTransaction {
  final String orderId;
  final int amount;
  final int fee;
  final int totalPayment;
  final String paymentMethod;
  final String? qrString;
  final DateTime? expiredAt;
  final CreditPackage? pkg;
  final String? paymentId;
  final String? status;

  PaymentTransaction({
    required this.orderId,
    required this.amount,
    required this.fee,
    required this.totalPayment,
    required this.paymentMethod,
    this.qrString,
    this.expiredAt,
    this.pkg,
    this.paymentId,
    this.status,
  });

  factory PaymentTransaction.fromCreate(Map<String, dynamic> j) {
    final pkg = j['package'] != null
        ? CreditPackage.fromJson(j['package'] as Map<String, dynamic>)
        : null;
    final amount = _asInt(j['amount']);
    return PaymentTransaction(
      orderId: j['orderId']?.toString() ?? '',
      amount: amount,
      fee: _asInt(j['fee']),
      totalPayment: _asIntOrNull(j['totalPayment']) ?? amount,
      paymentMethod: j['paymentMethod']?.toString() ?? 'qris',
      qrString: j['qrString']?.toString(),
      expiredAt: _parseDate(j['expiredAt']),
      pkg: pkg,
      paymentId: j['paymentId']?.toString(),
    );
  }

  factory PaymentTransaction.fromStatus(Map<String, dynamic> j) {
    final amount = _asInt(j['amountIdr']);
    return PaymentTransaction(
      orderId: j['orderId']?.toString() ?? '',
      amount: amount,
      fee: 0,
      totalPayment: amount,
      paymentMethod: j['paymentMethod']?.toString() ?? 'qris',
      expiredAt: _parseDate(j['expiredAt']),
      status: j['status']?.toString(),
    );
  }
}

class PaymentHistoryItem {
  final String id;
  final String orderId;
  final int amountIdr;
  final int credits;
  final String status;
  final String? paymentMethod;
  final String? packageName;
  final DateTime? paidAt;
  final DateTime? createdAt;

  PaymentHistoryItem({
    required this.id,
    required this.orderId,
    required this.amountIdr,
    required this.credits,
    required this.status,
    this.paymentMethod,
    this.packageName,
    this.paidAt,
    this.createdAt,
  });

  factory PaymentHistoryItem.fromJson(Map<String, dynamic> j) => PaymentHistoryItem(
        id: j['id']?.toString() ?? '',
        orderId: j['orderId']?.toString() ?? '',
        amountIdr: _asInt(j['amountIdr']),
        credits: _asInt(j['credits']),
        status: j['status']?.toString() ?? 'unknown',
        paymentMethod: j['paymentMethod']?.toString(),
        packageName: j['packageName']?.toString(),
        paidAt: _parseDate(j['paidAt']),
        createdAt: _parseDate(j['createdAt']),
      );
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is String && v.isNotEmpty) {
    return DateTime.tryParse(v);
  }
  return null;
}

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

int? _asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

class PaymentService {
  final ApiClient _client;

  PaymentService(this._client);

  Future<List<CreditPackage>> listPackages() async {
    final res = await _client.get(ApiConfig.paymentPackages);
    final data = (res['data'] as List?) ?? const [];
    return data
        .map((e) => CreditPackage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PaymentTransaction> createTransaction(String packageId) async {
    final res = await _client.post(
      ApiConfig.paymentCreate,
      body: {'package_id': packageId},
    );
    return PaymentTransaction.fromCreate(res['data'] as Map<String, dynamic>);
  }

  Future<PaymentTransaction> getStatus(String orderId) async {
    final res = await _client.get(ApiConfig.paymentStatus(orderId));
    return PaymentTransaction.fromStatus(res['data'] as Map<String, dynamic>);
  }

  Future<List<PaymentHistoryItem>> getHistory() async {
    final res = await _client.get(ApiConfig.paymentHistory);
    final data = (res['data'] as List?) ?? const [];
    return data
        .map((e) => PaymentHistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
