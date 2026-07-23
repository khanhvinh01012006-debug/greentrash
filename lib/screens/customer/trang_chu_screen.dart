// ============================================================================
// trang_chu_screen.dart - TRANG CHỦ giới thiệu dịch vụ
// (tham khảo bố cục xulychatthairan.com: banner ảnh chạy tự động ở đầu trang)
// ----------------------------------------------------------------------------
// Bố cục từ trên xuống, mỗi khối một mục đích rõ ràng:
//   1. Banner: ảnh/khẩu hiệu chạy tự động (vuốt tay cũng được) + nút "Đặt lịch"
//   2. Giới thiệu ngắn về GreenTrash
//   3. Quy trình 3 bước: đặt lịch -> xác nhận -> thu gom
//   4. GreenTrash thu gom gì: đọc bảng loai_rac, hiện card TO kèm ĐƠN GIÁ
//      (thay thế luôn tab Bảng giá cũ - gộp 2 trong 1 cho gọn)
//   5. Hướng dẫn phân loại rác tại nguồn (ExpansionTile bấm mở từng loại)
//   6. Liên hệ (hotline/email) - giống khối cuối trang của các web dịch vụ
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../widgets/common.dart';
import 'chi_tiet_bai_viet_screen.dart';

class TrangChuScreen extends StatelessWidget {
  /// Hàm được gọi khi bấm nút "Đặt lịch ngay" -> trang cha chuyển tab
  final VoidCallback onDatLichNgay;

  /// Điều khiển cuộn từ BÊN NGOÀI (menu ngang ở customer_home_screen.dart
  /// dùng để cuộn lên đầu trang khi bấm "TRANG CHỦ")
  final ScrollController? scrollController;

  /// Các "cột mốc" để menu ngang cuộn thẳng tới đúng khối tương ứng
  /// (Scrollable.ensureVisible cần 1 GlobalKey gắn trên widget cần cuộn tới)
  final GlobalKey? keyGioiThieu;
  final GlobalKey? keyQuyTrinh;
  final GlobalKey? keyBangGia;
  final GlobalKey? keyTinTuc;
  final GlobalKey? keyHuongDan;
  final GlobalKey? keyLienHe;

  const TrangChuScreen({
    super.key,
    required this.onDatLichNgay,
    this.scrollController,
    this.keyGioiThieu,
    this.keyQuyTrinh,
    this.keyBangGia,
    this.keyTinTuc,
    this.keyHuongDan,
    this.keyLienHe,
  });

  // Màu xanh chủ đạo dùng lại nhiều lần
  static const _xanhDam = Color(0xFF1B5E20);
  static const _xanh = Color(0xFF2E7D32);
  static const _xanhNhat = Color(0xFFE8F5E9);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _boc(_khoiBanner()),
          _boc(_khoiGioiThieu(), mau: _xanhNhat),
          _boc(_khoiQuyTrinh()),
          _boc(_khoiDiemManh(), mau: _xanhDam),
          _boc(_khoiBangGia()),
          _boc(_khoiTinTuc(), mau: _xanhNhat),
          _boc(_khoiHuongDanPhanLoai()),
          _boc(_khoiLienHe(), mau: _xanhDam),
          // Đệm cuối trang (cùng màu Liên hệ, không lộ ra là "đệm giả"):
          // "Liên hệ" là khối CUỐI CÙNG, phía dưới không còn gì để cuộn thêm
          // -> nếu không có đệm này, menu ngang bấm "Liên hệ" hoặc "Hướng
          // dẫn phân loại" (khối áp chót) sẽ không đủ chỗ để kéo khối đó lên
          // sát đầu màn hình, bị kẹt lưng chừng trông như nhảy nhầm sang
          // khối khác. Kéo tay bằng chuột không gặp lỗi này vì người dùng tự
          // dừng đúng chỗ, không cố kéo hết cỡ.
          // Từ khi Liên hệ đã thành footer 3 cột (cao hơn hẳn khối trống cũ),
          // giảm đệm từ 0.6 xuống 0.15 - CẦN TEST LẠI xem còn đủ hay không.
          Container(
            width: double.infinity,
            color: _xanhDam,
            height: MediaQuery.of(context).size.height * 0.15,
          ),
        ],
      ),
    );
  }

  /// Bọc 1 khối thành "dải nền" tràn hết bề rộng màn hình (giống các web
  /// dịch vụ xen kẽ dải trắng/xanh nhạt/xanh đậm), bên trong vẫn giới hạn nội
  /// dung tối đa 1000px và canh giữa để không bị kéo dài quá trên màn rộng.
  Widget _boc(Widget con, {Color? mau}) {
    return Container(
      width: double.infinity,
      color: mau, // null = nền trắng mặc định của Scaffold
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: con,
        ),
      ),
    );
  }

  // ==========================================================================
  // KHỐI 1: BANNER - ảnh/khẩu hiệu chạy tự động (giống banner đầu trang của
  // các web dịch vụ), bên dưới là nút hành động chính "Đặt lịch thu gom ngay"
  // ==========================================================================
  Widget _khoiBanner() {
    // Nội dung từng slide: (2 màu gradient dự phòng, icon to, tiêu đề, mô tả
    // ngắn, đường dẫn ảnh thật - banner1.png .. banner4.png). Nếu file ảnh
    // CHƯA có trong assets/images/ thì banner tự động hiện màu gradient +
    // icon thay thế (xem _BannerCarousel).
    const slides = [
      (
        [_xanhDam, Color(0xFF43A047)],
        Icons.recycling,
        'Thu Gom Rác Tận Nhà',
        'Nhanh chóng - đúng hẹn - đúng chuẩn',
        'assets/images/banner1.png',
      ),
      (
        [Color(0xFF00695C), Color(0xFF26A69A)],
        Icons.eco_outlined,
        'Phân Loại Tại Nguồn',
        'Chung tay bảo vệ môi trường xanh - sạch - đẹp',
        'assets/images/banner2.png',
      ),
      (
        [Color(0xFF1565C0), Color(0xFF42A5F5)],
        Icons.edit_calendar_outlined,
        'Đặt Lịch Chỉ Trong 1 Phút',
        'Chọn loại rác, ngày giờ - admin xác nhận tức thì',
        'assets/images/banner3.png',
      ),
      (
        [Color(0xFF2E7D32), Color(0xFF9CCC65)],
        Icons.payments_outlined,
        'Giá Thu Mua Minh Bạch',
        'Bảng giá rõ ràng theo từng loại rác, cân tại nhà',
        'assets/images/banner4.png',
      ),
    ];

    return Column(
      children: [
        _BannerCarousel(slides: slides),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _xanhDam,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: onDatLichNgay,
            icon: const Icon(Icons.calendar_month),
            label: const Text('Đặt lịch thu gom ngay',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // KHỐI 2: GIỚI THIỆU - chữ bên trái + ảnh bên phải (2 cột trên màn rộng,
  // xếp chồng trên điện thoại), giống mục "Giới thiệu" của các web dịch vụ
  // ==========================================================================
  Widget _khoiGioiThieu() {
    final vanBan = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _tieuDeKhoi('Giới thiệu'),
        const Text(
          'GreenTrash là dịch vụ đặt lịch thu gom rác tận nhà, ra đời từ đồ án '
          'môn Công Nghệ Phần Mềm với mong muốn giúp việc phân loại và thu gom '
          'rác tái chế trở nên đơn giản, minh bạch và tiện lợi hơn cho mọi nhà.',
          style: TextStyle(height: 1.6, fontSize: 15),
        ),
        const SizedBox(height: 20),
        // 2 badge nhỏ tóm tắt thế mạnh - giống 2 icon dưới khối Giới thiệu
        // của trang tham khảo
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _badge(Icons.recycling, 'Thu gom rác tái chế'),
            _badge(Icons.eco, 'Phân loại tại nguồn'),
          ],
        ),
      ],
    );

    final anh = _oAnhHoacTrong('assets/images/gioi_thieu.png',
        height: 260, goiY: 'Ảnh giới thiệu GreenTrash');

    return Padding(
      key: keyGioiThieu,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: LayoutBuilder(
        builder: (context, rangBuoc) {
          // Màn rộng (web/máy tính): chữ trái - ảnh phải, 2 cột song song
          if (rangBuoc.maxWidth >= 700) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: vanBan),
                const SizedBox(width: 32),
                Expanded(child: anh),
              ],
            );
          }
          // Màn hẹp (điện thoại): xếp chồng, chữ trước ảnh sau
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [vanBan, const SizedBox(height: 20), anh],
          );
        },
      ),
    );
  }

  /// 1 badge nhỏ: icon tròn + chữ - dùng ở khối Giới thiệu
  Widget _badge(IconData icon, String chu) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: _xanh,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 8),
        Text(chu, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  /// Hiện ẢNH THẬT nếu file đã có trong assets/images/, CHƯA có thì tự hiện
  /// khung viền nét đứt kiểu "chờ ảnh" (không lỗi, không vỡ layout) - dùng
  /// chung cho mọi chỗ cần ảnh minh họa trong Trang chủ.
  Widget _oAnhHoacTrong(String duongDan,
      {double height = 220, String goiY = ''}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        duongDan,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _xanh.withOpacity(0.35), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined,
                  size: 40, color: _xanh.withOpacity(0.6)),
              const SizedBox(height: 8),
              Text(goiY, style: TextStyle(color: _xanh.withOpacity(0.7))),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // KHỐI 2: QUY TRÌNH 3 BƯỚC - khách mới nhìn vào hiểu ngay cách dùng
  // ==========================================================================
  Widget _khoiQuyTrinh() {
    // Dữ liệu 3 bước: (icon, tiêu đề, mô tả)
    const buoc = [
      (
        Icons.edit_calendar,
        'Bước 1: Đặt lịch',
        'Chọn loại rác, ngày giờ, chụp ảnh rác cần thu gom'
      ),
      (
        Icons.verified_outlined,
        'Bước 2: Chờ xác nhận',
        'Quản trị viên duyệt lịch, bạn theo dõi trạng thái trực tiếp'
      ),
      (
        Icons.local_shipping_outlined,
        'Bước 3: Thu gom tận nhà',
        'Nhân viên đến đúng hẹn, hoàn tất và bạn đánh giá dịch vụ'
      ),
    ];

    return Padding(
      key: keyQuyTrinh,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tieuDeKhoi('Quy trình đơn giản'),
          // Mỗi bước là một Card có số thứ tự to
          ...buoc.map((b) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: _xanhNhat,
                    radius: 24,
                    child: Icon(b.$1, color: _xanh, size: 26),
                  ),
                  title: Text(b.$2,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text(b.$3, style: const TextStyle(height: 1.4)),
                ),
              )),
        ],
      ),
    );
  }

  // ==========================================================================
  // KHỐI: GREENTRASH KHÁC BIỆT THẾ NÀO - dải nền xanh đậm nổi bật, 4 điểm
  // mạnh dạng icon, giống dải "UY TÍN/CHẤT LƯỢNG/TẬN TÂM/HỖ TRỢ 24/7" của
  // các web dịch vụ tham khảo (nội dung đổi lại cho khớp GreenTrash)
  // ==========================================================================
  Widget _khoiDiemManh() {
    const diem = [
      (
        Icons.schedule,
        'Đúng hẹn',
        'Có mặt đúng khung giờ bạn đã chọn khi đặt lịch'
      ),
      (
        Icons.price_check,
        'Giá minh bạch',
        'Bảng giá công khai theo từng loại rác, không phát sinh'
      ),
      (
        Icons.eco,
        'Thân thiện môi trường',
        'Rác được phân loại và đưa đúng nơi tái chế'
      ),
      (
        Icons.support_agent,
        'Hỗ trợ nhanh',
        'Phản hồi và xử lý yêu cầu trong ngày'
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: LayoutBuilder(
        builder: (context, rangBuoc) {
          final soCot =
              rangBuoc.maxWidth >= 800 ? 4 : (rangBuoc.maxWidth >= 480 ? 2 : 1);
          const khoangCach = 20.0;
          final rongCard =
              (rangBuoc.maxWidth - khoangCach * (soCot - 1)) / soCot;

          return Wrap(
            spacing: khoangCach,
            runSpacing: khoangCach,
            children: diem.map((d) {
              return SizedBox(
                width: rongCard,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      child: Icon(d.$1, color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 12),
                    Text(d.$2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(d.$3,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white70, height: 1.4)),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ==========================================================================
  // KHỐI 3: THU GOM GÌ + BẢNG GIÁ (đọc từ database - bảng loai_rac)
  // ==========================================================================
  Widget _khoiBangGia() {
    return Padding(
      key: keyBangGia,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tieuDeKhoi('GreenTrash thu gom gì?'),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseService.layDanhSachLoaiRac(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Lỗi tải bảng giá: ${snapshot.error}'),
                  ),
                );
              }
              final ds = snapshot.data ?? [];

              // Chưa có loại rác nào (admin chưa thêm, hoặc chưa chạy file
              // supabase/update_05_cong_khai_bang_gia_tin_tuc.sql) -> nói rõ
              // thay vì để trắng trơn khó hiểu
              if (ds.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Chưa có bảng giá nào được thêm.'),
                  ),
                );
              }

              // Mỗi loại rác một card to, giá nổi bật bên phải
              return Column(
                children: ds
                    .map((loai) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: const CircleAvatar(
                              radius: 24,
                              backgroundColor: _xanhNhat,
                              child: Icon(Icons.delete_outline,
                                  color: _xanh, size: 26),
                            ),
                            title: Text(loai['ten_loai_rac'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Text(loai['mo_ta'] ?? '',
                                style: const TextStyle(height: 1.4)),
                            trailing: Text(
                              '${dinhDangTien(loai['don_gia'])}/kg',
                              style: const TextStyle(
                                  color: _xanh,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // KHỐI 4: TIN TỨC & BÀI VIẾT (đọc từ bảng bai_viet - admin đăng)
  // Kiểu card báo chí giống vechaioi: ảnh bìa to -> tiêu đề -> tóm tắt
  // Bấm vào card -> mở màn hình đọc bài đầy đủ
  // ==========================================================================
  Widget _khoiTinTuc() {
    return Padding(
      key: keyTinTuc,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tieuDeKhoi('Tin tức & mẹo sống xanh'),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: BaiVietService.layDanhSachBaiViet(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              // Lỗi (thường do chưa chạy update_01_bai_viet.sql) -> nhắc nhẹ
              if (snapshot.hasError) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Chưa tải được tin tức. Bạn đã chạy file '
                        'update_01_bai_viet.sql trong SQL Editor chưa?'),
                  ),
                );
              }

              final dsBai = snapshot.data ?? [];
              if (dsBai.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Chưa có bài viết nào.'),
                  ),
                );
              }

              // LƯỚI TIN TỨC TỰ CO GIÃN (giống vechaioi):
              // LayoutBuilder cho biết bề rộng đang có -> tính số cột phù hợp
              //   >= 800px: 3 cột | >= 550px: 2 cột | nhỏ hơn (điện thoại): 1 cột
              return LayoutBuilder(
                builder: (context, rangBuoc) {
                  final rong = rangBuoc.maxWidth;
                  final soCot = rong >= 800 ? 3 : (rong >= 550 ? 2 : 1);
                  const khoangCach = 12.0;
                  // Bề rộng mỗi card = (tổng - các khe hở) / số cột
                  final rongCard = (rong - khoangCach * (soCot - 1)) / soCot;

                  // Wrap: tự xếp các card thành hàng, đầy hàng thì xuống dòng
                  return Wrap(
                    spacing: khoangCach, // khe ngang giữa các card
                    runSpacing: khoangCach, // khe dọc giữa các hàng
                    children: dsBai
                        .map((bai) => SizedBox(
                              width: rongCard,
                              child: _cardBaiViet(context, bai),
                            ))
                        .toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  /// Card 1 bài viết: ảnh bìa trên, chữ dưới - bấm vào để đọc
  Widget _cardBaiViet(BuildContext context, Map<String, dynamic> bai) {
    return Card(
      margin: EdgeInsets.zero, // khoảng cách do Wrap ở ngoài quản lý
      clipBehavior: Clip.antiAlias, // để ảnh bo tròn theo góc card
      child: InkWell(
        // InkWell: làm card bấm được, có hiệu ứng gợn sóng
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChiTietBaiVietScreen(baiViet: bai)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Ảnh bìa (nếu có) ----
            if (bai['hinh_anh_url'] != null)
              Image.network(
                bai['hinh_anh_url'],
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
                // Ảnh đang tải -> khung xám mờ giữ chỗ, không giật layout
                loadingBuilder: (ctx, child, tienTrinh) => tienTrinh == null
                    ? child
                    : Container(height: 150, color: _xanhNhat),
                errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: _xanhNhat,
                    child: const Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            color: Colors.grey))),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bai['tieu_de'],
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold, height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    bai['tom_tat'] ?? '',
                    maxLines: 2, // tóm tắt tối đa 2 dòng cho card gọn
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  // Dòng "Đọc tiếp" màu xanh gợi ý bấm vào
                  const Row(
                    children: [
                      Text('Đọc tiếp',
                          style: TextStyle(
                              color: _xanh, fontWeight: FontWeight.w600)),
                      Icon(Icons.arrow_forward, size: 16, color: _xanh),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // KHỐI 5: HƯỚNG DẪN PHÂN LOẠI TẠI NGUỒN (nội dung tĩnh, bấm mở từng mục)
  // ==========================================================================
  Widget _khoiHuongDanPhanLoai() {
    // (tiêu đề, danh sách gạch đầu dòng)
    const huongDan = [
      (
        'Giấy, sách báo',
        [
          'Buộc gọn bằng dây hoặc bỏ vào túi giấy để tránh rơi vãi.',
          'Gỡ bỏ kim bấm, băng keo còn sót trên bìa carton, sổ tay.',
          'Giữ khô ráo - giấy ướt sẽ không tái chế được.',
        ]
      ),
      (
        'Nhựa',
        [
          'Đổ hết dung dịch bên trong, tháo nắp, lột nhãn nếu được.',
          'Bóp dẹp chai lọ để tiết kiệm không gian.',
          'Xem ký hiệu dưới đáy: PET 1, HDPE 2, LDPE 4, PP 5 đều tái chế được.',
        ]
      ),
      (
        'Kim loại (nhôm, sắt, đồng)',
        [
          'Tráng qua nước hoặc lau sạch chất còn sót bên trong.',
          'Ép dẹt lon nhôm để giảm thể tích.',
          'Xếp gọn vật sắc nhọn, bọc lại để tránh gây thương tích.',
        ]
      ),
      (
        'Rác điện tử',
        [
          'Tháo pin ra khỏi thiết bị trước khi giao.',
          'Không đập vỡ màn hình, bóng đèn - chứa chất độc hại.',
          'Để nguyên trong hộp hoặc túi riêng, không trộn với rác khác.',
        ]
      ),
    ];

    return Padding(
      key: keyHuongDan,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tieuDeKhoi('Hướng dẫn phân loại tại nguồn'),
          ...huongDan.map((muc) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                // ExpansionTile: bấm vào tiêu đề sẽ xổ nội dung xuống
                child: ExpansionTile(
                  leading:
                      const Icon(Icons.tips_and_updates_outlined, color: _xanh),
                  title: Text(muc.$1,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: muc.$2
                      .map((dong) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('•  ',
                                    style: TextStyle(color: _xanh)),
                                Expanded(
                                    child: Text(dong,
                                        style: const TextStyle(height: 1.4))),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              )),
        ],
      ),
    );
  }

  // ==========================================================================
  // KHỐI 6: FOOTER - đặt cuối trang, style kiểu FOOTER (nền xanh đậm, chữ
  // trắng) giống khối cuối trang của các web dịch vụ tham khảo.
  // 3 cột: Về GreenTrash / Dịch vụ / Liên hệ - màn hẹp thì xếp dọc.
  // ==========================================================================
  Widget _khoiLienHe() {
    final cotGioiThieu = _cotFooter(
      tieuDe: 'Về GreenTrash',
      child: const Text(
        'Dịch vụ đặt lịch thu gom rác tận nhà, ra đời từ đồ án môn Công '
        'Nghệ Phần Mềm - giúp việc phân loại và thu gom rác tái chế trở '
        'nên đơn giản, minh bạch hơn cho mọi nhà.',
        style: TextStyle(color: Colors.white70, height: 1.6),
      ),
    );

    // Tóm tắt lại đúng 4 nội dung đã giới thiệu ở banner đầu trang, không
    // bịa thêm dịch vụ mới chưa có thật trong app
    final cotDichVu = _cotFooter(
      tieuDe: 'Dịch vụ',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thu gom rác tận nhà',
              style: TextStyle(color: Colors.white70, height: 2)),
          Text('Phân loại rác tại nguồn',
              style: TextStyle(color: Colors.white70, height: 2)),
          Text('Đặt lịch thu gom trực tuyến',
              style: TextStyle(color: Colors.white70, height: 2)),
          Text('Thu mua rác tái chế',
              style: TextStyle(color: Colors.white70, height: 2)),
        ],
      ),
    );

    final cotLienHe = _cotFooter(
      tieuDe: 'Liên hệ',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dongLienHe(Icons.phone_in_talk_outlined, 'Hotline',
              '1900 1234 (7h - 21h, kể cả cuối tuần)'),
          const Divider(color: Colors.white24, height: 32),
          _dongLienHe(
              Icons.email_outlined, 'Email hỗ trợ', 'hotro@greentrash.vn'),
          const Divider(color: Colors.white24, height: 32),
          _dongLienHe(Icons.location_on_outlined, 'Khu vực phục vụ',
              'Nội thành và các quận lân cận'),
        ],
      ),
    );

    return Padding(
      key: keyLienHe,
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, rangBuoc) {
              // Màn rộng: 3 cột song song. Màn hẹp (điện thoại): xếp dọc
              if (rangBuoc.maxWidth >= 700) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cotGioiThieu),
                    const SizedBox(width: 32),
                    Expanded(child: cotDichVu),
                    const SizedBox(width: 32),
                    Expanded(child: cotLienHe),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  cotGioiThieu,
                  const SizedBox(height: 28),
                  cotDichVu,
                  const SizedBox(height: 28),
                  cotLienHe,
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          const Text('© 2026 GreenTrash - Đồ án môn Công Nghệ Phần Mềm',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  /// 1 cột trong footer: tiêu đề trắng đậm (giữ đúng kiểu chữ của tiêu đề
  /// "Liên hệ" cũ) + nội dung bên dưới
  Widget _cotFooter({required String tieuDe, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tieuDe,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  /// 1 dòng thông tin liên hệ: icon trắng + tiêu đề đậm + nội dung nhạt hơn
  Widget _dongLienHe(IconData icon, String tieuDe, String noiDung) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tieuDe,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(noiDung, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }

  /// Tiêu đề chung cho mỗi khối - chữ to, có vạch xanh bên trái
  Widget _tieuDeKhoi(String chu) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Row(
        children: [
          Container(width: 5, height: 24, color: _xanh),
          const SizedBox(width: 10),
          Text(chu,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ============================================================================
// _BannerCarousel: banner ảnh/khẩu hiệu CHẠY TỰ ĐỘNG (auto-slide mỗi 4 giây)
// và vẫn VUỐT TAY được (PageView có sẵn cử chỉ vuốt).
// Cách hoạt động:
//   - PageController điều khiển PageView chứa các slide
//   - Timer.periodic mỗi 4s gọi nextPage() -> tới slide kế, hết thì quay vòng
//   - Chấm tròn bên dưới (dot indicator) hiện slide đang xem, bấm vào chấm
//     cũng nhảy thẳng tới slide đó
// ============================================================================
class _BannerCarousel extends StatefulWidget {
  // Mỗi slide: (2 màu gradient dự phòng, icon, tiêu đề, mô tả, đường dẫn ảnh)
  final List<(List<Color>, IconData, String, String, String)> slides;
  const _BannerCarousel({required this.slides});

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _trangHienTai = 0;

  @override
  void initState() {
    super.initState();
    // Cứ 4 giây tự động lật sang slide kế tiếp, tới cuối thì quay lại đầu
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients) return;
      final trangKe = (_trangHienTai + 1) % widget.slides.length;
      _controller.animateToPage(
        trangKe,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // hủy timer khi rời màn hình - tránh rò rỉ bộ nhớ
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      // LayoutBuilder để biết bề rộng thực tế đang có, từ đó TỰ TÍNH chiều
      // cao banner theo tỉ lệ (thay vì cố định 220px trước đây). Banner cũ
      // quá "dẹt" so với bề rộng (gần 1000 x 220 ~ tỉ lệ 4.5:1) nên
      // BoxFit.cover phải cắt/phóng to ảnh rất nhiều mới lấp đầy khung,
      // nhìn bị zoom xấu. Banner mới tỉ lệ ~2.3:1 (giống ảnh chụp ngang
      // thường gặp) nên ảnh hiện tự nhiên, đỡ bị cắt/phóng quá đà.
      child: LayoutBuilder(
        builder: (context, rangBuoc) {
          final chieuCao = (rangBuoc.maxWidth * 0.45).clamp(240.0, 420.0);
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              SizedBox(
                height: chieuCao,
                child: PageView.builder(
                  controller: _controller,
                  // Người dùng vuốt tay -> cập nhật chấm tròn cho đúng
                  onPageChanged: (i) => setState(() => _trangHienTai = i),
                  itemCount: widget.slides.length,
                  itemBuilder: (context, i) {
                    final (mauNen, icon, tieuDe, moTa, duongDanAnh) =
                        widget.slides[i];
                    // Nền: ảnh thật nếu file đã có trong assets/images/, chưa có
                    // thì errorBuilder tự thay bằng gradient (không bị vỡ layout)
                    final nenGradient = Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: mauNen,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    );
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          duongDanAnh,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => nenGradient,
                        ),
                        // Lớp phủ tối dần từ trái - chữ luôn đọc rõ dù ảnh sáng
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.55),
                                Colors.black.withOpacity(0.1),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, size: 44, color: Colors.white),
                              const SizedBox(height: 12),
                              Text(
                                tieuDe,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                moTa,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // Chấm tròn chỉ vị trí slide - đặt chồng lên đáy banner
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(widget.slides.length, (i) {
                    final dangChon = i == _trangHienTai;
                    return GestureDetector(
                      onTap: () => _controller.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: dangChon ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(dangChon ? 1 : 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
