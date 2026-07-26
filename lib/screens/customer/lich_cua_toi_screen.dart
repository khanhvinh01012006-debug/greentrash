// ============================================================================
// lich_cua_toi_screen.dart - LỊCH CỦA TÔI (UC08 + UC10 + BM09)
// ----------------------------------------------------------------------------
// Chức năng:
//   - Xem danh sách lịch của mình theo THỜI GIAN THỰC (StreamBuilder + realtime)
//     => Admin vừa duyệt lịch, màn hình này ĐỔI NGAY không cần refresh!
//   - Hủy lịch (chỉ khi còn 'cho_xac_nhan')
//   - Xem ảnh rác đã upload
//   - Đánh giá dịch vụ khi lịch 'hoan_tat'
// ============================================================================

import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../widgets/common.dart';
import '../../widgets/khung_chat.dart';

class LichCuaToiScreen extends StatefulWidget {
  // Bấm nút "Đặt lịch ngay" ở trạng thái rỗng -> gọi callback này để màn
  // cha (CustomerHomeScreen) nhảy sang tab Đặt lịch, giống cách
  // TrangChuScreen đang nhận onDatLichNgay - tái dùng luôn, không tạo
  // callback mới.
  final VoidCallback onDatLichNgay;
  const LichCuaToiScreen({super.key, required this.onDatLichNgay});

  @override
  State<LichCuaToiScreen> createState() => _LichCuaToiScreenState();
}

class _LichCuaToiScreenState extends State<LichCuaToiScreen> {
  // Lưu Stream trong state (thay vì gọi thẳng trong build() như trước) để
  // nút "Thử lại" ở trạng thái lỗi có thể setState gán 1 Stream MỚI, buộc
  // StreamBuilder resubscribe lại từ đầu.
  late Stream<List<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = DatabaseService.streamLichCuaToi();
  }

  void _thuLai() {
    setState(() => _stream = DatabaseService.streamLichCuaToi());
  }

  @override
  Widget build(BuildContext context) {
    // StreamBuilder: mỗi khi database ĐỔI (thêm/sửa lịch), stream phát dữ liệu
    // mới -> builder chạy lại -> giao diện tự cập nhật. Đây là REALTIME.
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        // TRẠNG THÁI 1: đang tải - CHỈ hiện spinner, chưa hiện gì khác
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // TRẠNG THÁI 2: lỗi tải - thông báo lỗi + nút "Thử lại"
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Không tải được lịch: ${snapshot.error}',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _thuLai,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }

        final dsLich = snapshot.data ?? [];

        // TRẠNG THÁI 3: tải xong, danh sách rỗng - empty state có hành động
        // rõ ràng (bấm được), không bắt khách tự mò sang tab khác nữa
        if (dsLich.isEmpty) {
          return _TrangThaiRong(onDatLichNgay: widget.onDatLichNgay);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: dsLich.length,
          itemBuilder: (context, i) => _TheLich(lich: dsLich[i]),
        );
      },
    );
  }
}

// ============================================================================
// _TrangThaiRong: hiện khi khách CHƯA có lịch thu gom nào - icon tròn to +
// tiêu đề + mô tả ngắn + nút bấm thẳng sang tab Đặt lịch.
// ============================================================================
class _TrangThaiRong extends StatelessWidget {
  final VoidCallback onDatLichNgay;
  const _TrangThaiRong({required this.onDatLichNgay});

  @override
  Widget build(BuildContext context) {
    final mauChuDao = Theme.of(context).colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: mauChuDao.withOpacity(0.1),
              ),
              child: Icon(Icons.event_note, size: 56, color: mauChuDao),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chưa có lịch thu gom nào',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Đặt lịch đầu tiên để chúng tôi đến tận nhà thu gom',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onDatLichNgay,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Đặt lịch ngay'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// _TheLich - Card hiển thị 1 lịch thu gom
// ============================================================================
class _TheLich extends StatelessWidget {
  final Map<String, dynamic> lich;
  const _TheLich({required this.lich});

  @override
  Widget build(BuildContext context) {
    final trangThai = lich['trang_thai'] as String;
    final ngayHen = DateTime.parse(lich['ngay_hen']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dòng đầu: mã lịch + chip trạng thái
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Lịch #${lich['id']}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                ChipTrangThai(trangThai: trangThai),
              ],
            ),
            const SizedBox(height: 8),

            // Nhãn TRẠNG THÁI THANH TOÁN - chỉ hiện khi lịch đã được duyệt
            // (chưa duyệt thì chưa cần bàn chuyện tiền)
            if (trangThai == 'da_xac_nhan' || trangThai == 'hoan_tat') ...[
              Align(
                alignment: Alignment.centerLeft,
                child: ChipThanhToan(
                  trangThaiTT: lich['trang_thai_tt'],
                  phuongThuc: lich['phuong_thuc_tt'],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Thông tin chính
            _dongThongTin(Icons.calendar_today_outlined,
                '${dinhDangNgay(ngayHen)} - ${lich['khung_gio'] == 'sang' ? 'Sáng' : 'Chiều'}'),
            _dongThongTin(
                Icons.location_on_outlined, lich['dia_chi_thu_gom'] ?? ''),
            _dongThongTin(Icons.scale_outlined,
                '${lich['khoi_luong_uoc_tinh'] ?? '?'} kg - ${dinhDangTien(lich['chi_phi_du_kien'] ?? 0)}'),
            // Ghi chú tĩnh: khách chỉ trả tiền rác theo khối lượng - vật tư
            // là chi phí nội bộ, không cộng vào số trên. Chỉ là chữ hiển
            // thị, không đụng gì tới cách tính chi_phi_du_kien.
            const Padding(
              padding: EdgeInsets.only(left: 22, bottom: 4),
              child: Text(
                'Đã bao gồm phí thu gom tận nơi. Miễn phí túi đựng và đồ bảo hộ.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),

            // Ảnh rác nếu có upload
            if (lich['hinh_anh_url'] != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  lich['hinh_anh_url'],
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  // Nếu link ảnh hỏng thì hiện icon thay vì văng lỗi
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, size: 60),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Các nút hành động - hiện/ẩn tùy trạng thái
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Nhắn tin với admin về lịch này - luôn hiện, không phụ
                // thuộc trạng thái (khách có thể cần hỏi ở bất kỳ lúc nào)
                TextButton.icon(
                  onPressed: () => moKhungChat(context, lich['id']),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Nhắn tin'),
                ),

                // Chỉ được HỦY khi lịch còn chờ xác nhận (đúng quy định UC10)
                if (trangThai == 'cho_xac_nhan')
                  TextButton.icon(
                    onPressed: () => _xacNhanHuy(context),
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                    label: const Text('Hủy lịch',
                        style: TextStyle(color: Colors.red)),
                  ),

                // Nút THANH TOÁN: hiện khi lịch đã được duyệt (hoặc hoàn tất)
                // và tiền chưa được admin xác nhận đã nhận
                if ((trangThai == 'da_xac_nhan' || trangThai == 'hoan_tat') &&
                    lich['trang_thai_tt'] != 'da_thanh_toan')
                  TextButton.icon(
                    onPressed: () => _moThanhToan(context),
                    icon: const Icon(Icons.payments_outlined,
                        color: Color(0xFF2E7D32)),
                    label: const Text('Thanh toán',
                        style: TextStyle(color: Color(0xFF2E7D32))),
                  ),

                // Lịch HOÀN TẤT: khách xem được HÓA ĐƠN + ĐÁNH GIÁ dịch vụ
                if (trangThai == 'hoan_tat') ...[
                  TextButton.icon(
                    onPressed: () => _xemHoaDon(context),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Hóa đơn'),
                  ),
                  TextButton.icon(
                    onPressed: () => _moDialogDanhGia(context),
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Đánh giá'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Widget nhỏ: 1 dòng icon + chữ
  Widget _dongThongTin(IconData icon, String noiDung) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(child: Text(noiDung)),
        ],
      ),
    );
  }

  /// Hộp thoại xác nhận hủy lịch
  Future<void> _xacNhanHuy(BuildContext context) async {
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy lịch thu gom'),
        content: Text('Bạn có chắc muốn hủy lịch #${lich['id']}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Không')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy lịch'),
          ),
        ],
      ),
    );

    if (dongY == true) {
      await DatabaseService.huyLich(lich['id']);
      // Không cần setState: stream realtime tự cập nhật giao diện!
    }
  }



  /// BƯỚC 1 THANH TOÁN: khách chọn phương thức (UC15 dạng demo)
  Future<void> _moThanhToan(BuildContext context) async {
    final soTien = dinhDangTien(lich['chi_phi_du_kien'] ?? 0);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chọn phương thức thanh toán'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Số tiền cần thanh toán: $soTien',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // --- Lựa chọn 1: TIỀN MẶT ---
            ListTile(
              leading: const Icon(Icons.money, color: Color(0xFF2E7D32)),
              title: const Text('Tiền mặt'),
              subtitle: const Text('Trả trực tiếp khi nhân viên đến thu gom'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300)),
              onTap: () async {
                Navigator.pop(ctx);
                // Ghi lựa chọn vào database (chưa tính là đã trả tiền)
                await ThanhToanService.khachChonThanhToan(
                    maLich: lich['id'], phuongThuc: 'tien_mat');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Đã chọn tiền mặt. Bạn thanh toán khi nhân viên đến nhé!'),
                      backgroundColor: Colors.green));
                }
              },
            ),
            const SizedBox(height: 10),

            // --- Lựa chọn 2: CHUYỂN KHOẢN QR ---
            ListTile(
              leading: const Icon(Icons.qr_code_2, color: Color(0xFF2E7D32)),
              title: const Text('Chuyển khoản QR'),
              subtitle: const Text('Quét mã ngân hàng hoặc MoMo'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300)),
              onTap: () {
                Navigator.pop(ctx);
                _moManHinhQR(context); // sang bước 2: hiện mã QR
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
        ],
      ),
    );
  }

  /// BƯỚC 2 THANH TOÁN: hiện 2 mã QR (ngân hàng + MoMo) để khách quét.
  /// Khách chuyển xong bấm "Tôi đã chuyển khoản" -> admin nhận nhãn báo
  /// ngay lập tức trên màn hình quản lý lịch (nhờ realtime).
  Future<void> _moManHinhQR(BuildContext context) async {
    final soTien = dinhDangTien(lich['chi_phi_du_kien'] ?? 0);
    // 0 = tab Ngân hàng, 1 = tab MoMo
    int tabQR = 0;

    showDialog(
      context: context,
      // StatefulBuilder cho phép setState riêng bên trong dialog (đổi tab QR)
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('Chuyển khoản $soTien'),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nút gạt chọn Ngân hàng / MoMo
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                        value: 0,
                        label: Text('Ngân hàng'),
                        icon: Icon(Icons.account_balance)),
                    ButtonSegment(
                        value: 1,
                        label: Text('MoMo'),
                        icon: Icon(Icons.smartphone)),
                  ],
                  selected: {tabQR},
                  onSelectionChanged: (chon) =>
                      setStateDialog(() => tabQR = chon.first),
                ),
                const SizedBox(height: 12),

                // Ảnh QR đóng gói sẵn trong app (thư mục assets/)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    tabQR == 0
                        ? 'assets/qr_ngan_hang.png'
                        : 'assets/qr_momo.png',
                    height: 320,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nội dung CK: GreenTrash + Mã lịch',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Để sau')),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Tôi đã chuyển khoản'),
              onPressed: () async {
                Navigator.pop(ctx);
                // Ghi trạng thái "khách báo đã chuyển" để admin kiểm tra
                await ThanhToanService.khachChonThanhToan(
                  maLich: lich['id'],
                  phuongThuc: 'chuyen_khoan',
                  daChuyenKhoan: true,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Đã ghi nhận! Quản trị viên sẽ kiểm tra '
                          'và xác nhận trong ít phút.'),
                      backgroundColor: Colors.green));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Khách xem HÓA ĐƠN của lịch đã hoàn tất (hóa đơn do admin lập tự động)
  Future<void> _xemHoaDon(BuildContext context) async {
    try {
      final hd = await HoaDonService.layHoaDonTheoLich(lich['id']);
      if (!context.mounted) return;

      if (hd == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Lịch này chưa có hóa đơn (đã hoàn tất trước khi '
                'hệ thống hóa đơn được thêm vào).')));
        return;
      }

      final lichHd = hd['lich_thu_gom'] ?? {};
      final loaiRac = (lichHd['loai_rac'] ?? {})['ten_loai_rac'] ?? '—';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Hóa đơn #${hd['id']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ngày lập: '
                  '${dinhDangNgay(DateTime.parse(hd['ngay_lap']))}'),
              const SizedBox(height: 6),
              Text('Loại rác: $loaiRac'),
              Text('Khối lượng: ${lichHd['khoi_luong_uoc_tinh'] ?? '—'} kg'),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tiền thanh toán:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    dinhDangTien(hd['tien_rac'] ?? 0),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF2E7D32)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng')),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Lỗi tải hóa đơn: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  /// Hộp thoại đánh giá dịch vụ (chọn sao + nhận xét) - BM09
  Future<void> _moDialogDanhGia(BuildContext context) async {
    // Kiểm tra đã đánh giá chưa (mỗi lịch chỉ đánh giá 1 lần)
    final daDanhGia = await DatabaseService.daDanhGia(lich['id']);
    if (daDanhGia && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn đã đánh giá lịch này rồi.')),
      );
      return;
    }
    if (!context.mounted) return;

    int soSao = 5; // mặc định 5 sao
    final nhanXetCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        // StatefulBuilder cho phép setState BÊN TRONG dialog (đổi số sao)
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Đánh giá dịch vụ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dãy 5 ngôi sao bấm được
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(
                      i < soSao ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setStateDialog(() => soSao = i + 1),
                  );
                }),
              ),
              TextField(
                controller: nhanXetCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Nhận xét (không bắt buộc)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              onPressed: () async {
                await DatabaseService.guiDanhGia(
                  maLich: lich['id'],
                  soSao: soSao,
                  nhanXet: nhanXetCtrl.text.trim().isEmpty
                      ? null
                      : nhanXetCtrl.text.trim(),
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Cảm ơn bạn đã đánh giá! ⭐'),
                        backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('Gửi đánh giá'),
            ),
          ],
        ),
      ),
    );
  }
}
