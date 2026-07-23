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

  /// Icon gợi ý theo TÊN loại rác (so khớp gần đúng bằng contains, không
  /// cần khớp tuyệt đối). Luôn có nhánh mặc định (Icons.delete_outline) để
  /// loại rác admin thêm mới sau này (chưa nằm trong danh sách so khớp bên
  /// dưới) vẫn hiện được icon, không bao giờ thiếu icon.
  IconData _iconTheoLoai(String ten) {
    final t = ten.toLowerCase();
    // "tái chế" phải kiểm tra TRƯỚC "rác thường" (không có nhánh riêng cho
    // "rác thường" nên nó rơi vào mặc định) để không bị nhánh khác nuốt mất.
    if (t.contains('tái chế')) return Icons.recycling;
    if (t.contains('nguy hại')) return Icons.warning_amber;
    if (t.contains('cồng kềnh')) return Icons.chair;
    if (t.contains('hữu cơ')) return Icons.compost;
    if (t.contains('điện tử')) return Icons.devices;
    return Icons.delete_outline;
  }

  /// Panel tóm tắt đơn bên phải form - liệt kê lại đúng những gì khách ĐÃ
  /// điền bên trái, cập nhật realtime nhờ CÙNG các setState() form đang có
  /// sẵn (chọn loại rác, chọn ngày, đổi khung giờ, gõ khối lượng) - không
  /// thêm biến trạng thái mới nào, chỉ đọc lại state hiện có để hiển thị.
  Widget _panelTomTat() {
    // Tìm loại rác đang chọn (nếu có) để lấy tên + đơn giá hiện ra panel
    Map<String, dynamic>? loaiDangChon;
    if (_loaiRacDangChon != null) {
      final tim = _dsLoaiRac.firstWhere(
        (l) => l['id'] == _loaiRacDangChon,
        orElse: () => {},
      );
      loaiDangChon = tim.isEmpty ? null : tim;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tóm tắt đơn',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _dongTomTat(
              'Loại rác',
              loaiDangChon == null
                  ? '—'
                  : '${loaiDangChon['ten_loai_rac']} '
                      '(${dinhDangTien(loaiDangChon['don_gia'])}/kg)',
            ),
            _dongTomTat(
                'Ngày hẹn', _ngayHen == null ? '—' : dinhDangNgay(_ngayHen!)),
            _dongTomTat('Khung giờ',
                _khungGio == 'sang' ? 'Sáng (7h-11h)' : 'Chiều (13h-17h)'),
            _dongTomTat(
              'Khối lượng ước tính',
              _khoiLuongCtrl.text.trim().isEmpty
                  ? '—'
                  : '${_khoiLuongCtrl.text.trim()} kg',
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Chi phí dự kiến',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  dinhDangTien(_chiPhiDuKien),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 1 dòng nhãn (nhỏ, xám) + giá trị (đậm) trong panel tóm tắt - tách hàm vì
  /// 4 dòng (loại rác/ngày/khung giờ/khối lượng) dùng chung đúng bố cục này.
  Widget _dongTomTat(String nhan, String giaTri) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nhan,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text(giaTri, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  /// 1 thẻ loại rác trong lưới chọn. Bấm vào -> chọn (hoặc đổi sang loại
  /// khác); thẻ đang chọn đổi viền + nền bằng AnimatedContainer cho mượt.
  Widget _theLoaiRac(Map<String, dynamic> loai) {
    final dangChon = loai['id'] == _loaiRacDangChon;
    final mauChuDao = Theme.of(context).colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _loaiRacDangChon = loai['id']),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(
              color: dangChon ? mauChuDao : Colors.grey.shade300,
              width: dangChon ? 2 : 1,
            ),
            color: dangChon ? mauChuDao.withOpacity(0.08) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_iconTheoLoai(loai['ten_loai_rac']), color: mauChuDao),
              const SizedBox(height: 6),
              Text(
                loai['ten_loai_rac'],
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                '${dinhDangTien(loai['don_gia'])}/kg',
                style: TextStyle(color: mauChuDao, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                (loai['mo_ta'] ?? '').toString(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(16),
          // 1 LayoutBuilder DUY NHẤT đo bề rộng thật đang có (đã bị giới hạn
          // tối đa 1200 bởi ConstrainedBox ở trên) để quyết định bố cục -
          // mốc 1000px: đủ rộng thì panel tóm tắt 300px mới có chỗ đứng
          // cạnh form 3 cột, không thì tràn (overflow) như đã gặp.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final manHinhRong = constraints.maxWidth >= 1000;
              if (!manHinhRong) {
                // Màn hẹp: ẩn HẲN panel (không render, không phải chỉ
                // Visibility) + form chiếm trọn bề ngang + lưới về 2 cột +
                // TOÀN BỘ form (kể cả dòng Chi phí dự kiến) tự cuộn như cũ
                return SingleChildScrollView(
                  child: _formDatLich(soCotLuoi: 2, hienChiPhiCuoiForm: true),
                );
              }
              // Màn rộng: panel phải ĐỨNG YÊN trong khi chỉ cột form cuộn ->
              // SingleChildScrollView chuyển vào TRONG, chỉ bọc riêng từng
              // cột (form + panel), Row không còn bị bọc scroll chung nữa.
              // Row cần chiều cao xác định để 2 cột con biết giới hạn cuộn
              // của mình - bọc SizedBox.expand() lấy đúng chiều cao khung
              // hình cha đang cấp (cách đơn giản nhất, không cần Sliver).
              return SizedBox.expand(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: _formDatLich(
                            soCotLuoi: 3, hienChiPhiCuoiForm: false),
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 300,
                      // Phòng màn thấp: panel cao hơn vùng hiển thị thì tự
                      // cuộn riêng, không tràn ra ngoài.
                      child: SingleChildScrollView(child: _panelTomTat()),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Form đặt lịch (bên trái, hoặc chiếm trọn màn hẹp) - tách riêng khỏi
  /// build() để build() gọi chung 1 hàm này cho cả 2 chế độ (không nhân đôi
  /// widget con); [soCotLuoi] = số cột lưới thẻ loại rác, [hienChiPhiCuoiForm]
  /// = có hiện lại dòng "Chi phí dự kiến" ở cuối form không (màn rộng đã có
  /// sẵn số này trong panel tóm tắt bên cạnh nên ẩn đi, tránh lặp 2 lần).
  Widget _formDatLich({required int soCotLuoi, required bool hienChiPhiCuoiForm}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Đặt lịch thu gom rác',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),

                // ---- 1. Chọn loại rác (lưới thẻ) ----
                const Text('Loại rác',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.black54)),
                const SizedBox(height: 8),
                // Số cột do build() truyền vào theo mốc 1000px (3 cột khi
                // có panel bên cạnh, 2 cột khi form chiếm trọn màn hẹp).
                //
                // GridView.builder + mainAxisExtent (chiều cao CỐ ĐỊNH theo
                // px) thay vì GridView.count + childAspectRatio (chiều cao
                // TỈ LỆ theo bề rộng cột) - childAspectRatio làm thẻ quá
                // thấp khi màn hẹp (cột hẹp -> thẻ thấp) trong khi nội dung
                // thẻ (icon + tên + giá + mô tả) cần cùng 1 chiều cao tối
                // thiểu bất kể màn rộng hay hẹp -> tràn 1.9px ở đáy.
                GridView.builder(
                  // Nằm trong form đang cuộn (SingleChildScrollView) nên
                  // GridView không tự cuộn riêng - để cha cuộn hết
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: soCotLuoi,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 200,
                  ),
                  itemCount: _dsLoaiRac.length,
                  itemBuilder: (context, i) => _theLoaiRac(_dsLoaiRac[i]),
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

                // ---- 3. Ngày hẹn + khung giờ ----
                // LayoutBuilder mốc 600px: màn hẹp không đủ chỗ cho 2 ô
                // cùng hàng (tràn 22px) -> xếp dọc. Xây 2 ô này 1 LẦN thành
                // biến rồi đặt vào Column hoặc Row tùy bề rộng - không viết
                // 2 bản riêng cho InkWell/DropdownButtonFormField.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final oNgayHen = InkWell(
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
                    );
                    final oKhungGio = DropdownButtonFormField<String>(
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
                    );

                    if (constraints.maxWidth < 600) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          oNgayHen,
                          const SizedBox(height: 12),
                          oKhungGio,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: oNgayHen),
                        const SizedBox(width: 12),
                        Expanded(child: oKhungGio),
                      ],
                    );
                  },
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
                // Màn rộng đã có số này trong panel tóm tắt bên cạnh rồi -
                // ẩn ở đây để khỏi hiện lặp lại 2 lần trên cùng màn hình.
                if (hienChiPhiCuoiForm) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Expanded để nhãn tự XUỐNG DÒNG khi màn hẹp thay vì
                        // tràn ngang (trước đây 2 Text chia nhau 1 Row không
                        // ai nhường ai, hẹp lại là tràn 70px)
                        const Expanded(
                          child: Text('Chi phí dự kiến:',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Text(
                          // Chưa chọn loại rác thì chưa có gì để tính - hiện
                          // chữ nhắc thay vì "0 đ" (nhìn như lỗi tính toán)
                          _loaiRacDangChon == null
                              ? 'Chọn loại rác để xem giá'
                              : dinhDangTien(_chiPhiDuKien),
                          style: _loaiRacDangChon == null
                              ? const TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black54)
                              : const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

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
          );
  }
}
