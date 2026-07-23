// ============================================================================
// dat_lich_screen.dart - MÀN HÌNH ĐẶT LỊCH THU GOM MỚI (UC04 + BM01)
// ----------------------------------------------------------------------------
// Luồng nghiệp vụ (theo đặc tả UC04 trong báo cáo):
//   1. Chọn loại rác (dropdown lấy từ bảng loai_rac)
//   2. Nhập địa chỉ, chọn ngày hẹn + khung giờ (sáng/chiều)
//   3. Nhập khối lượng ước tính -> app TỰ TÍNH chi phí = khối lượng x đơn giá
//   4. (Tùy chọn) CHỤP/CHỌN ẢNH rác -> upload lên Supabase Storage
//   5. Bấm Đặt lịch -> lưu vào bảng lich_thu_gom, trạng thái 'cho_xac_nhan'
// ============================================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common.dart';

class DatLichScreen extends StatefulWidget {
  const DatLichScreen({super.key});

  @override
  State<DatLichScreen> createState() => _DatLichScreenState();
}

class _DatLichScreenState extends State<DatLichScreen> {
  final _formKey = GlobalKey<FormState>();
  final _diaChiCtrl = TextEditingController();
  final _khoiLuongCtrl = TextEditingController();
  final _ghiChuCtrl = TextEditingController();

  // Dữ liệu người dùng đang chọn
  List<Map<String, dynamic>> _dsLoaiRac = []; // danh sách loại rác từ server
  int? _loaiRacDangChon;                       // id loại rác được chọn
  DateTime? _ngayHen;                          // ngày hẹn
  String _khungGio = 'sang';                   // khung giờ mặc định

  // Ảnh đã chọn (chưa upload) - lưu dạng byte để hiện preview
  Uint8List? _anhBytes;
  String? _tenFileAnh;

  bool _dangTai = false;

  @override
  void initState() {
    super.initState();
    _taiDanhSachLoaiRac(); // gọi 1 lần khi màn hình vừa mở
    _dienSanDiaChi(); // tự điền địa chỉ đã lưu trong hồ sơ -> đỡ gõ lại
  }

  /// Đọc địa chỉ mặc định từ hồ sơ (tab Tài khoản) và điền sẵn vào ô địa chỉ.
  /// Khách vẫn SỬA ĐƯỢC nếu lần này muốn thu gom ở nơi khác (nhà người thân,
  /// công ty...) - đó là lý do lịch thu gom vẫn cần cột địa chỉ riêng.
  Future<void> _dienSanDiaChi() async {
    final hoSo = await DatabaseService.layHoSoCuaToi();
    // Chỉ điền khi ô đang trống, tránh ghi đè chữ khách đã gõ
    if (mounted && _diaChiCtrl.text.isEmpty) {
      _diaChiCtrl.text = hoSo?['dia_chi'] ?? '';
    }
  }

  Future<void> _taiDanhSachLoaiRac() async {
    final ds = await DatabaseService.layDanhSachLoaiRac();
    if (mounted) setState(() => _dsLoaiRac = ds);
  }

  /// TỰ TÍNH chi phí dự kiến = khối lượng x đơn giá loại rác đang chọn
  /// (đáp ứng yêu cầu số 6 trong bảng khảo sát: "xem báo giá dự kiến")
  num get _chiPhiDuKien {
    if (_loaiRacDangChon == null) return 0;
    final khoiLuong = double.tryParse(_khoiLuongCtrl.text) ?? 0;

    // firstWhere = tìm phần tử đầu tiên thỏa điều kiện trong danh sách
    final loai = _dsLoaiRac.firstWhere(
      (l) => l['id'] == _loaiRacDangChon,
      orElse: () => {'don_gia': 0},
    );
    return khoiLuong * (loai['don_gia'] as num);
  }

  /// Mở hộp thoại chọn ảnh và hiện preview (CHƯA upload vội - chỉ upload khi
  /// bấm Đặt lịch, tránh upload rác nếu người dùng đổi ý)
  Future<void> _chonAnh() async {
    final ketQua = await StorageService.chonAnh();
    if (ketQua != null) {
      setState(() {
        _anhBytes = ketQua.bytes;
        _tenFileAnh = ketQua.tenFile;
      });
    }
  }

  /// Mở lịch cho người dùng chọn ngày hẹn
  Future<void> _chonNgay() async {
    final homNay = DateTime.now();
    final ngay = await showDatePicker(
      context: context,
      // Theo quy định QD01: đặt trước ít nhất... -> đơn giản hóa: từ NGÀY MAI
      firstDate: homNay.add(const Duration(days: 1)),
      lastDate: homNay.add(const Duration(days: 60)), // tối đa 60 ngày tới
      initialDate: homNay.add(const Duration(days: 1)),
    );
    if (ngay != null) setState(() => _ngayHen = ngay);
  }

  /// Xử lý khi bấm nút ĐẶT LỊCH
  Future<void> _xuLyDatLich() async {
    if (!_formKey.currentState!.validate()) return;

    // Kiểm tra thêm các trường không thuộc Form
    if (_loaiRacDangChon == null) {
      _baoLoi('Vui lòng chọn loại rác');
      return;
    }
    if (_ngayHen == null) {
      _baoLoi('Vui lòng chọn ngày hẹn');
      return;
    }

    setState(() => _dangTai = true);
    try {
      // BƯỚC 1: nếu có chọn ảnh thì upload trước, lấy link
      String? linkAnh;
      if (_anhBytes != null) {
        linkAnh = await StorageService.uploadAnh(_anhBytes!, _tenFileAnh!);
      }

      // BƯỚC 2: lưu lịch vào database (kèm link ảnh nếu có)
      await DatabaseService.datLich(
        maLoaiRac: _loaiRacDangChon!,
        diaChi: _diaChiCtrl.text.trim(),
        ngayHen: _ngayHen!,
        khungGio: _khungGio,
        khoiLuong: double.parse(_khoiLuongCtrl.text),
        chiPhiDuKien: _chiPhiDuKien,
        ghiChu: _ghiChuCtrl.text.trim().isEmpty ? null : _ghiChuCtrl.text.trim(),
        hinhAnhUrl: linkAnh,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đặt lịch thành công! Vui lòng chờ xác nhận. 🌱'),
            backgroundColor: Colors.green,
          ),
        );
        // Dọn form để đặt lịch mới - CHỦ ĐÍCH không gọi _formKey.reset()
        // vì reset() xóa TẤT CẢ ô nhập, bay luôn địa chỉ ta muốn giữ.
        // Chỉ xóa từng ô cần xóa, ô địa chỉ GIỮ NGUYÊN cho lần đặt sau.
        _khoiLuongCtrl.clear();
        _ghiChuCtrl.clear();
        setState(() {
          _loaiRacDangChon = null;
          _ngayHen = null;
          _anhBytes = null;
          _khungGio = 'sang';
        });

        // Nếu HỒ SƠ chưa có địa chỉ mặc định (tài khoản cũ đăng ký thiếu),
        // lấy luôn địa chỉ vừa đặt lưu vào hồ sơ -> từ nay mọi lần đặt lịch
        // và cả tab Tài khoản đều có sẵn địa chỉ này
        try {
          final hoSo = await DatabaseService.layHoSoCuaToi();
          final diaChiHoSo = (hoSo?['dia_chi'] ?? '').toString().trim();
          if (diaChiHoSo.isEmpty) {
            await supabase.from('nguoi_dung').update(
                {'dia_chi': _diaChiCtrl.text.trim()}).eq(
                'id', supabase.auth.currentUser!.id);
          }
        } catch (_) {
          // lỗi lưu hồ sơ không ảnh hưởng việc đặt lịch -> bỏ qua êm
        }
      }
    } catch (e) {
      _baoLoi('Đặt lịch thất bại: $e');
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  void _baoLoi(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _diaChiCtrl.dispose();
    _khoiLuongCtrl.dispose();
    _ghiChuCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Đặt lịch thu gom rác',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),

                // ---- 1. Chọn loại rác (dropdown) ----
                DropdownButtonFormField<int>(
                  value: _loaiRacDangChon,
                  decoration: const InputDecoration(
                    labelText: 'Loại rác',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _dsLoaiRac
                      .map((l) => DropdownMenuItem<int>(
                            value: l['id'],
                            child: Text(
                                '${l['ten_loai_rac']} - ${dinhDangTien(l['don_gia'])}/kg'),
                          ))
                      .toList(),
                  // setState để chi phí dự kiến tính lại ngay khi đổi loại
                  onChanged: (v) => setState(() => _loaiRacDangChon = v),
                ),
                const SizedBox(height: 16),

                // ---- 2. Địa chỉ thu gom ----
                TextFormField(
                  controller: _diaChiCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ thu gom',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Vui lòng nhập địa chỉ' : null,
                ),
                const SizedBox(height: 16),

                // ---- 3. Ngày hẹn + khung giờ (2 ô cạnh nhau) ----
                Row(
                  children: [
                    // Ô chọn ngày - dùng InkWell để bấm vào mở lịch
                    Expanded(
                      child: InkWell(
                        onTap: _chonNgay,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Ngày hẹn',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Text(
                            _ngayHen == null
                                ? 'Chọn ngày'
                                : dinhDangNgay(_ngayHen!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Dropdown khung giờ
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _khungGio,
                        decoration: const InputDecoration(
                          labelText: 'Khung giờ',
                          prefixIcon: Icon(Icons.schedule_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'sang', child: Text('Sáng (7h-11h)')),
                          DropdownMenuItem(
                              value: 'chieu', child: Text('Chiều (13h-17h)')),
                        ],
                        onChanged: (v) => setState(() => _khungGio = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ---- 4. Khối lượng ước tính ----
                TextFormField(
                  controller: _khoiLuongCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Khối lượng ước tính (kg)',
                    prefixIcon: Icon(Icons.scale_outlined),
                  ),
                  // Mỗi lần gõ số -> build lại để cập nhật chi phí dự kiến
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final so = double.tryParse(v ?? '');
                    if (so == null || so <= 0) {
                      return 'Nhập số kg hợp lệ (> 0)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ---- 5. Chọn ảnh rác (KHÔNG bắt buộc) ----
                OutlinedButton.icon(
                  onPressed: _chonAnh,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_anhBytes == null
                      ? 'Chọn ảnh rác (không bắt buộc)'
                      : 'Đổi ảnh khác'),
                ),
                // Hiện preview ảnh đã chọn (Image.memory hiện ảnh từ byte)
                if (_anhBytes != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_anhBytes!, height: 180, fit: BoxFit.cover),
                  ),
                ],
                const SizedBox(height: 16),

                // ---- 6. Ghi chú ----
                TextFormField(
                  controller: _ghiChuCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú (không bắt buộc)',
                    prefixIcon: Icon(Icons.note_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // ---- 7. Ô hiển thị CHI PHÍ DỰ KIẾN (tự tính) ----
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Chi phí dự kiến:',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        dinhDangTien(_chiPhiDuKien),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ---- 8. Nút ĐẶT LỊCH ----
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _dangTai ? null : _xuLyDatLich,
                    icon: _dangTai
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_dangTai ? 'Đang xử lý...' : 'Đặt lịch thu gom'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
