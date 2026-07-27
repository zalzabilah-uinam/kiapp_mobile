import '../config/api_config.dart';
import 'api_client.dart';

class CreditPackage {
  final String id;
  final String name;
  final int credits;
  final int priceIdr;
  final String? description;
  final int? sortOrder;

  CreditPackage({
    required this.id,
    required this.name,
    required this.credits,
    required this.priceIdr,
    this.description,
    this.sortOrder,
  });

  factory CreditPackage.fromJson(Map<String, dynamic> j) => CreditPackage(
        id: j['id'] as String,
        name: j['name'] as String,
        credits: (j['credits'] as num).toInt(),
        priceIdr: (j['priceIdr'] as num).toInt(),
        description: j['description'] as String?,
        sortOrder: (j['sortOrder'] as num?)?.toInt(),
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
    return PaymentTransaction(
      orderId: j['orderId'] as String,
      amount: (j['amount'] as num).toInt(),
      fee: (j['fee'] as num?)?.toInt() ?? 0,
      totalPayment: (j['totalPayment'] as num?)?.toInt() ?? (j['amount'] as num).toInt(),
      paymentMethod: j['paymentMethod'] as String? ?? 'qris',
      qrString: j['qrString'] as String?,
      expiredAt: _parseDate(j['expiredAt']),
      pkg: pkg,
      paymentId: j['paymentId'] as String?,
    );
  }

  factory PaymentTransaction.fromStatus(Map<String, dynamic> j) {
    return PaymentTransaction(
      orderId: j['orderId'] as String,
      amount: (j['amountIdr'] as num).toInt(),
      fee: 0,
      totalPayment: (j['amountIdr'] as num).toInt(),
      paymentMethod: j['paymentMethod'] as String? ?? 'qris',
      expiredAt: _parseDate(j['expiredAt']),
      status: j['status'] as String?,
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
        id: j['id'] as String,
        orderId: j['orderId'] as String,
        amountIdr: (j['amountIdr'] as num).toInt(),
        credits: (j['credits'] as num).toInt(),
        status: j['status'] as String,
        paymentMethod: j['paymentMethod'] as String?,
        packageName: j['packageName'] as String?,
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
