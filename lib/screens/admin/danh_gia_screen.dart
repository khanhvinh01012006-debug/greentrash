// ============================================================================
// danh_gia_screen.dart - ADMIN xem ĐÁNH GIÁ DỊCH VỤ của khách (BM09)
// ----------------------------------------------------------------------------
// Khách đánh giá 1-5 sao + nhận xét sau khi lịch hoàn tất (ở phía khách).
// Màn hình này cho admin:
//   - Xem ĐIỂM TRUNG BÌNH + tổng số lượt đánh giá (thẻ tổng quan trên cùng)
//   - Danh sách từng đánh giá: sao, nhận xét, khách nào, lịch nào, ngày nào
// RLS của bảng danh_gia đã cho admin đọc tất cả (policy trong schema.sql).
// ============================================================================

import 'package:flutter/material.dart';
import '../../main.dart';
import '../../widgets/common.dart';

class DanhGiaScreen extends StatefulWidget {
  const DanhGiaScreen({super.key});

  @override
  State<DanhGiaScreen> createState() => _DanhGiaScreenState();
}

class _DanhGiaScreenState extends State<DanhGiaScreen> {
  List<Map<String, dynamic>> _dsDanhGia = [];
  bool _dangTai = true;

  @override
  void initState() {
    super.initState();
    _taiDanhSach();
  }

  Future<void> _taiDanhSach() async {
    setState(() => _dangTai = true);
    try {
      // JOIN lồng: đánh giá -> người đánh giá (tên) + lịch liên quan (loại rác)
      final ds = await supabase
          .from('danh_gia')
          .select('*, nguoi_dung(ho_ten), '
              'lich_thu_gom(ngay_hen, loai_rac(ten_loai_rac))')
          .order('ngay_danh_gia', ascending: false);
      if (mounted) setState(() => _dsDanhGia = List<Map<String, dynamic>>.from(ds));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Lỗi tải đánh giá: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  /// Tính điểm trung bình từ danh sách (làm tròn 1 chữ số thập phân)
  double get _diemTrungBinh {
    if (_dsDanhGia.isEmpty) return 0;
    // fold = cộng dồn: chạy qua từng phần tử, gom vào biến tổng
    final tong = _dsDanhGia.fold<int>(0, (t, dg) => t + (dg['so_sao'] as int));
    return tong / _dsDanhGia.length;
  }

  /// Vẽ dãy 5 ngôi sao, tô vàng theo số sao được chấm
  Widget _daySao(int soSao, {double size = 18}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < soSao ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dangTai) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        // ---- Thẻ tổng quan: điểm trung bình + số lượt + nút tải lại ----
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(_diemTrungBinh.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _daySao(_diemTrungBinh.round(), size: 22),
                      Text('${_dsDanhGia.length} lượt đánh giá',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _taiDanhSach,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Tải lại'),
                ),
              ],
            ),
          ),
        ),

        // ---- Danh sách từng đánh giá ----
        Expanded(
          child: _dsDanhGia.isEmpty
              ? const Center(
                  child: Text(
                      'Chưa có đánh giá nào.\nKhách đánh giá được sau khi lịch hoàn tất.',
                      textAlign: TextAlign.center))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: _dsDanhGia.length,
                  itemBuilder: (context, i) {
                    final dg = _dsDanhGia[i];
                    final khach = dg['nguoi_dung'] ?? {};
                    final lich = dg['lich_thu_gom'] ?? {};
                    final loaiRac =
                        (lich['loai_rac'] ?? {})['ten_loai_rac'] ?? '—';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(khach['ho_ten'] ?? '(ẩn danh)',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                _daySao(dg['so_sao'] ?? 0),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lịch #${dg['ma_lich']} - $loaiRac - '
                              '${dinhDangNgay(DateTime.parse(dg['ngay_danh_gia']))}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                            ),
                            // Nhận xét (nếu khách có viết)
                            if ((dg['nhan_xet'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F8E9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('"${dg['nhan_xet']}"',
                                    style: const TextStyle(
                                        fontStyle: FontStyle.italic,
                                        height: 1.4)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
