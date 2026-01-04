import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:siparis_frontend/features/cashier/providers/cashier_provider.dart';
import 'package:flutter/services.dart';
import 'package:siparis_frontend/core/formatters/phone_tr_formatter.dart';
import '../providers/cashier_create_order_providers.dart';

class CashierCreateOrderPage extends ConsumerStatefulWidget {
  const CashierCreateOrderPage({super.key});

  @override
  ConsumerState<CashierCreateOrderPage> createState() =>
      _CashierCreateOrderPageState();
}

class _CashierCreateOrderPageState
    extends ConsumerState<CashierCreateOrderPage> {
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _details = TextEditingController();
  final _total = TextEditingController(text: '0');
  final _deposit = TextEditingController(text: '0');
  final _imageUrl = TextEditingController();

  DateTime? _delivery;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _customerName.dispose();
    _customerPhone.dispose();
    _details.dispose();
    _total.dispose();
    _deposit.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  String _formatApiDate(DateTime dt) =>
      DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);

  Future<void> _pickDelivery() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now,
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;

    setState(() {
      _delivery = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _uploadImage() async {
    setState(() => _error = null);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true, // web için bytes
    );
    if (result == null || result.files.isEmpty) return;

    final f = result.files.first;
    if (f.bytes == null) {
      setState(() => _error = 'Dosya okunamadı');
      return;
    }

    final multipart = MultipartFile.fromBytes(f.bytes!, filename: f.name);

    try {
      final url = await ref.read(uploadOrderImageProvider(multipart).future);
      setState(() => _imageUrl.text = url);
    } catch (e) {
      setState(() => _error = 'Görsel yüklenemedi');
    }
  }

  Future<void> _save() async {
    void _validateOrThrow() {
      if (_customerName.text.trim().isEmpty) {
        throw Exception('Müşteri adı boş olamaz');
      }
      if (_customerPhone.text.trim().isEmpty) {
        throw Exception('Telefon boş olamaz');
      }
      if (_details.text.trim().isEmpty) {
        throw Exception('Sipariş detayı boş olamaz');
      }

      final total = int.tryParse(_total.text) ?? 0;
      final deposit = int.tryParse(_deposit.text) ?? 0;

      if (total <= 0) {
        throw Exception('Toplam tutar 0 olamaz');
      }
      if (deposit > total) {
        throw Exception('Kapora, toplamdan büyük olamaz');
      }
      if (_delivery == null) {
        throw Exception('Teslim tarihi seçilmedi');
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      _validateOrThrow();
      if (_delivery == null) {
        throw Exception('Teslim tarihi seçilmedi');
      }

      final total = int.tryParse(_total.text.trim()) ?? 0;
      final deposit = int.tryParse(_deposit.text.trim()) ?? 0;

      final payload = CreateOrderPayload(
        customerName: _customerName.text.trim(),
        customerPhone: _customerPhone.text.replaceAll(' ', ''),
        orderDetails: _details.text.trim(),
        totalAmount: total,
        depositAmount: deposit,
        deliveryDatetime: _formatApiDate(_delivery!),
        imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
      );

      await ref.read(createCashierOrderProvider(payload).future);

      // listeyi yenile
      ref.invalidate(cashierOrdersProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sipariş oluşturuldu')));
      }
    } catch (e) {
      setState(() {
        _error =
            e is Exception
                ? e.toString().replaceFirst('Exception: ', '')
                : 'Beklenmeyen bir hata oluştu';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveryText =
        _delivery == null
            ? 'Seçilmedi'
            : DateFormat('dd.MM.yyyy HH:mm').format(_delivery!);

    Widget sectionTitle(IconData icon, String text) {
      return Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    Widget sectionCard({required Widget child, required Widget title}) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 12), child],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Sipariş'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon:
                _saving
                    ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.save),
            label: const Text('Kaydet'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              Widget twoCol(Widget left, Widget right) {
                if (!isWide) {
                  return Column(
                    children: [left, const SizedBox(height: 12), right],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 16),
                    Expanded(child: right),
                  ],
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                  ],

                  // 1️⃣ MÜŞTERİ BİLGİLERİ
                  sectionCard(
                    title: sectionTitle(Icons.person, 'Müşteri Bilgileri'),
                    child: twoCol(
                      TextField(
                        controller: _customerName,
                        decoration: const InputDecoration(
                          labelText: 'Müşteri Adı',
                        ),
                      ),
                      TextField(
                        controller: _customerPhone,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          TrPhoneFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Telefon',
                          hintText: '05XX XXX XX XX',
                        ),
                      ),
                    ),
                  ),

                  // 2️⃣ SİPARİŞ DETAYI
                  sectionCard(
                    title: sectionTitle(Icons.list_alt, 'Sipariş Detayı'),
                    child: TextField(
                      controller: _details,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Sipariş Detayı',
                      ),
                    ),
                  ),

                  // 3️⃣ ÖDEME BİLGİLERİ
                  sectionCard(
                    title: sectionTitle(Icons.payments, 'Ödeme Bilgileri'),
                    child: twoCol(
                      TextField(
                        controller: _total,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Toplam (₺)',
                        ),
                      ),
                      TextField(
                        controller: _deposit,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Kapora (₺)',
                        ),
                      ),
                    ),
                  ),

                  // 4️⃣ TESLİM TARİHİ
                  sectionCard(
                    title: sectionTitle(
                      Icons.calendar_month,
                      'Teslim Tarihi / Saati',
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(deliveryText),
                      trailing: ElevatedButton.icon(
                        onPressed: _pickDelivery,
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Seç'),
                      ),
                    ),
                  ),

                  // 5️⃣ GÖRSEL
                  sectionCard(
                    title: sectionTitle(Icons.image, 'Sipariş Görseli'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _imageUrl,
                          decoration: const InputDecoration(
                            labelText: 'Görsel URL (opsiyonel)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _uploadImage,
                              icon: const Icon(Icons.upload),
                              label: const Text('Görsel Yükle'),
                            ),
                            const SizedBox(width: 16),
                            if (_imageUrl.text.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _imageUrl.text,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => Container(
                                        width: 72,
                                        height: 72,
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.broken_image,
                                          size: 20,
                                        ),
                                      ),
                                ),
                              )
                            else
                              const Text(
                                'Yüklü görsel yok',
                                style: TextStyle(color: Colors.black54),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
