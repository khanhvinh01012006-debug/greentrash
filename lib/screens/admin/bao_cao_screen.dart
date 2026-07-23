// ============================================================================
// bao_cao_screen.dart - BÁO CÁO THỐNG KÊ CHO ADMIN (BM07 + BM10)
// ----------------------------------------------------------------------------
// (Ứng với UC18 "Báo cáo doanh thu tháng" và NV10 "Thống kê loại rác thu gom")
//
// Chức năng:
//   - Chọn tháng/năm -> hiện:
//     + Tổng doanh thu tháng (chỉ tính lịch hoàn tất)
//     + Số lịch theo từng trạng thái
//     + Thống kê loại rác thu gom nhiều nhất (thanh bar tự vẽ - không cần
//       thư viện chart, phù hợp trình độ năm 2)
// ============================================================================

import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../widgets/common.dart';

class BaoCaoScreen extends StatefulWidget {
  const BaoCaoScreen({super.key});

  @override
  State<BaoCaoScreen> createState() => _BaoCaoScreenState();
}

class _BaoCaoScreenState extends State<BaoCaoScreen> {
  // Mặc định là tháng hiện tại
  int _nam = DateTime.now().year;
  int _thang = DateTime.now().month;

  Map<String, dynamic>? _baoCao; // kết quả báo cáo từ service
  bool _dangTai = false;

  @override
  void initState() {
    super.initState();
    _taiBaoCao();
  }

  Future<void> _taiBaoCao() async {
    setState(() => _dangTai = true);
    final kq = await DatabaseService.baoCaoThang(_nam, _thang);
    if (mounted) {
      setState(() {
        _baoCao = kq;
        _dangTai = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Bộ chọn tháng / năm ----
          Row(
            children: [
              // Dropdown chọn tháng 1-12
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _thang,
                  decoration: const InputDecoration(labelText: 'Tháng'),
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem(
                        value: i + 1, child: Text('Tháng ${i + 1}')),
                  ),
                  onChanged: (v) {
                    setState(() => _thang = v!);
                    _taiBaoCao(); // đổi tháng -> tải lại báo cáo
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Dropdown chọn năm (3 năm gần nhất)
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _nam,
                  decoration: const InputDecoration(labelText: 'Năm'),
                  items: List.generate(3, (i) {
                    final nam = DateTime.now().year - i;
                    return DropdownMenuItem(value: nam, child: Text('$nam'));
                  }),
                  onChanged: (v) {
                    setState(() => _nam = v!);
                    _taiBaoCao();
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Nút TẢI LẠI: báo cáo là kiểu tải-một-lần (không realtime),
              // vừa hoàn tất lịch xong thì bấm nút này để số liệu cập nhật
              // (không cần F5 cả trang)
              IconButton.outlined(
                tooltip: 'Tải lại số liệu',
                icon: const Icon(Icons.refresh),
                onPressed: _taiBaoCao,
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_dangTai)
            const Center(child: CircularProgressIndicator())
          else if (_baoCao != null) ...[
            // ---- Thẻ TỔNG DOANH THU (BM07) ----
            Card(
              color: const Color(0xFF2E7D32),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('TỔNG DOANH THU',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text(
                      dinhDangTien(_baoCao!['tong_doanh_thu']),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold),
                    ),
                    Text('Tháng $_thang/$_nam - ${_baoCao!['tong_so_lich']} lịch hẹn',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---- Số lịch theo trạng thái ----
            Text('Số lịch theo trạng thái',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            // .entries biến map thành danh sách (key, value) để duyệt
            for (final e
                in (_baoCao!['dem_trang_thai'] as Map<String, int>).entries)
              ListTile(
                dense: true,
                leading: Icon(Icons.circle,
                    size: 14, color: mauTrangThai(e.key)),
                title: Text(tenTrangThai(e.key)),
                trailing: Text('${e.value} lịch',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            const SizedBox(height: 16),

            // ---- Thống kê loại rác thu gom (BM10) - biểu đồ thanh tự vẽ ----
            Text('Loại rác thu gom nhiều nhất (đã hoàn tất)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _veBieuDoThanh(_baoCao!['dem_loai_rac'] as Map<String, int>),
          ],
        ],
      ),
    );
  }

  /// Vẽ biểu đồ thanh ngang ĐƠN GIẢN bằng Container (không cần thư viện):
  /// độ dài thanh = số lượt / số lượt lớn nhất
  Widget _veBieuDoThanh(Map<String, int> duLieu) {
    if (duLieu.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Chưa có lịch hoàn tất nào trong tháng này.'),
      );
    }

    // Sắp xếp giảm dần theo số lượt để loại nhiều nhất lên đầu
    final dsSapXep = duLieu.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final max = dsSapXep.first.value; // giá trị lớn nhất để tính tỷ lệ

    return Column(
      children: [
        for (final e in dsSapXep)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                // Tên loại rác - cố định 120px cho thẳng hàng
                SizedBox(width: 120, child: Text(e.key, maxLines: 2)),
                // Thanh bar: FractionallySizedBox chiếm % chiều rộng còn lại
                Expanded(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: e.value / max, // tỷ lệ 0.0 -> 1.0
                    child: Container(
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFF66BB6A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${e.value} lượt',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }
}
