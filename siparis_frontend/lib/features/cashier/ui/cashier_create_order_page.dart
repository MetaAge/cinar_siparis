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
  final int _detailsMaxLength = 320;

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

  void _setDeliveryPreset(DateTime dt) {
    setState(() => _delivery = dt);
  }

  void _setDeliveryToday() {
    final now = DateTime.now();
    _setDeliveryPreset(DateTime(now.year, now.month, now.day, 18, 0));
  }

  void _setDeliveryTomorrow() {
    final now = DateTime.now().add(const Duration(days: 1));
    _setDeliveryPreset(DateTime(now.year, now.month, now.day, 12, 0));
  }

  void _setDeliveryWeekend() {
    final now = DateTime.now();
    final daysToSaturday = (6 - now.weekday) % 7;
    final saturday = now.add(Duration(days: daysToSaturday));
    _setDeliveryPreset(DateTime(saturday.year, saturday.month, saturday.day, 12));
  }

  void _setDeliveryNext3Hours() {
    final dt = DateTime.now().add(const Duration(hours: 3));
    _setDeliveryPreset(dt);
  }

  void _setDepositPercent(int percent) {
    final total = int.tryParse(_total.text.trim()) ?? 0;
    final deposit = ((total * percent) / 100).round();
    setState(() => _deposit.text = deposit.toString());
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
        color: Colors.grey.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 12), child],
          ),
        ),
      );
    }

    Widget summaryCard() {
      final chips = <Widget>[];
      if (_customerName.text.trim().isNotEmpty) {
        chips.add(_InfoChip(label: 'Müşteri', value: _customerName.text.trim()));
      }
      if (_customerPhone.text.trim().isNotEmpty) {
        chips.add(_InfoChip(label: 'Telefon', value: _customerPhone.text.trim()));
      }
      if (_delivery != null) {
        chips.add(
          _InfoChip(
            label: 'Teslim',
            value: DateFormat('dd.MM HH:mm').format(_delivery!),
            icon: Icons.calendar_month,
          ),
        );
      }
      final totalVal = int.tryParse(_total.text.trim()) ?? 0;
      final depositVal = int.tryParse(_deposit.text.trim()) ?? 0;
      if (totalVal > 0) {
        chips.add(_InfoChip(label: 'Toplam', value: '$totalVal ₺', icon: Icons.savings));
      }
      if (depositVal > 0) {
        chips.add(_InfoChip(label: 'Kapora', value: '$depositVal ₺', icon: Icons.payments));
      }

      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Özet',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 10),
              chips.isEmpty
                  ? const Text(
                      'Bilgileri girdikçe özet burada görünecek',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: chips,
                    ),
            ],
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
          constraints: const BoxConstraints(maxWidth: 840),
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
                  summaryCard(),

                  // 1️⃣ MÜŞTERİ BİLGİLERİ
                  sectionCard(
                    title: sectionTitle(Icons.person, 'Müşteri Bilgileri'),
                    child: twoCol(
                      TextField(
                        controller: _customerName,
                        decoration: const InputDecoration(
                          labelText: 'Müşteri Adı *',
                          helperText: 'Zorunlu alan',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      TextField(
                        controller: _customerPhone,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          TrPhoneFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Telefon *',
                          hintText: '05XX XXX XX XX',
                          helperText: 'Zorunlu alan',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),

                  // 2️⃣ SİPARİŞ DETAYI
                  sectionCard(
                    title: sectionTitle(Icons.list_alt, 'Sipariş Detayı'),
                    child: TextField(
                      controller: _details,
                      maxLines: 5,
                      maxLength: _detailsMaxLength,
                      decoration: const InputDecoration(
                        labelText: 'Sipariş Detayı *',
                        helperText: 'Zorunlu alan · Ne üretilecek, ölçü/beden vs.',
                      ),
                      onChanged: (_) => setState(() {}),
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
                          labelText: 'Toplam (₺) *',
                          helperText: 'Zorunlu alan',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      TextField(
                        controller: _deposit,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Kapora (₺)',
                          helperText: 'İstersen alttan hızlı % seç',
                          suffix: Wrap(
                            spacing: 6,
                            children: [
                              _MiniChip(text: '%0', onTap: () => _setDepositPercent(0)),
                              _MiniChip(
                                text: '%25',
                                onTap: () => _setDepositPercent(25),
                              ),
                              _MiniChip(
                                text: '%50',
                                onTap: () => _setDepositPercent(50),
                              ),
                              _MiniChip(
                                text: '%100',
                                onTap: () => _setDepositPercent(100),
                              ),
                            ],
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),

                  // 4️⃣ TESLİM TARİHİ
                  sectionCard(
                    title: sectionTitle(
                      Icons.calendar_month,
                      'Teslim Tarihi / Saati',
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(deliveryText),
                          trailing: ElevatedButton.icon(
                            onPressed: _pickDelivery,
                            icon: const Icon(Icons.calendar_month),
                            label: const Text('Seç'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              label: const Text('Bugün 18:00'),
                              onPressed: _setDeliveryToday,
                            ),
                            ActionChip(
                              label: const Text('Yarın 12:00'),
                              onPressed: _setDeliveryTomorrow,
                            ),
                            ActionChip(
                              label: const Text('Hafta sonu'),
                              onPressed: _setDeliveryWeekend,
                            ),
                            ActionChip(
                              label: const Text('+3 saat'),
                              onPressed: _setDeliveryNext3Hours,
                            ),
                          ],
                        ),
                      ],
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
                            helperText: 'Yüklersen önizleme gözükecek',
                          ),
                          onChanged: (_) => setState(() {}),
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
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  _imageUrl.text,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => Container(
                                        width: 80,
                                        height: 80,
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              const Spacer(),
              FilledButton.icon(
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
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  const _InfoChip({required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: icon != null ? Icon(icon, size: 16) : null,
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _MiniChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
