// ============================================================================
// admin_home_screen.dart - KHUNG CHÍNH phía QUẢN TRỊ VIÊN
// ----------------------------------------------------------------------------
// Vì admin có tới 7 mục chức năng, ta dùng DRAWER (menu trượt từ trái) -
// bố cục quen thuộc của mọi trang quản trị, thay cho thanh tab dưới đáy
// (thanh đáy chỉ đẹp khi <= 5 mục).
//
// 7 mục (đối chiếu báo cáo):
//   1. Lịch hẹn      - duyệt / hoàn tất / từ chối lịch (UC06, BM08)
//   2. Hóa đơn       - lịch sử hóa đơn + vật tư tiêu hao (UC16, BM04)
//   3. Người dùng    - phân quyền, khóa tài khoản (UC22)
//   4. Loại rác      - danh mục + đơn giá (UC11)
//   5. Kho vật tư    - nhập/xuất kho, cảnh báo tồn (UC12, UC13, BM02)
//   (chú ý: định mức sử dụng chỉnh trong form sửa vật tư)
//   6. Bài viết      - đăng tin tức cho trang chủ khách
//   7. Báo cáo       - doanh thu tháng + thống kê loại rác (UC18, BM07, BM10)
// ============================================================================

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'quan_ly_lich_screen.dart';
import 'hoa_don_screen.dart';
import 'quan_ly_nguoi_dung_screen.dart';
import 'quan_ly_loai_rac_screen.dart';
import 'quan_ly_vat_tu_screen.dart';
import 'quan_ly_bai_viet_screen.dart';
import 'bao_cao_screen.dart';
import 'danh_gia_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _mucDangChon = 0; // vị trí mục menu đang mở

  // Danh sách mục menu: (icon, tên hiển thị)
  static const _menu = [
    (Icons.event_note, 'Lịch hẹn'),
    (Icons.receipt_long, 'Hóa đơn'),
    (Icons.people, 'Người dùng'),
    (Icons.category, 'Loại rác'),
    (Icons.inventory_2, 'Kho vật tư'),
    (Icons.article, 'Bài viết'),
    (Icons.star_rate, 'Đánh giá'),
    (Icons.bar_chart, 'Báo cáo'),
  ];

  // 7 màn hình tương ứng 7 mục menu (cùng thứ tự với _menu)
  final _cacManHinh = const [
    QuanLyLichScreen(),
    HoaDonScreen(),
    QuanLyNguoiDungScreen(),
    QuanLyLoaiRacScreen(),
    QuanLyVatTuScreen(),
    QuanLyBaiVietScreen(),
    DanhGiaScreen(), // xem đánh giá dịch vụ của khách (BM09)
    BaoCaoScreen(),
  ];

  /// Đăng xuất (hỏi xác nhận trước)
  Future<void> _dangXuat() async {
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đăng xuất')),
        ],
      ),
    );
    if (dongY == true) await AuthService.dangXuat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Màu xanh đậm hơn phía khách để phân biệt "đây là trang quản trị"
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: Text('Quản trị - ${_menu[_mucDangChon].$2}'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: _dangXuat,
          ),
        ],
      ),

      // ---- MENU TRƯỢT BÊN TRÁI ----
      drawer: Drawer(
        child: Column(
          children: [
            // Phần đầu menu: logo + chữ
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF1B5E20)),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.recycling, size: 48, color: Colors.white),
                    SizedBox(height: 8),
                    Text('GreenTrash Admin',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

            // Các mục menu - sinh tự động từ danh sách _menu
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _menu.length,
                itemBuilder: (context, i) => ListTile(
                  leading: Icon(_menu[i].$1,
                      color: i == _mucDangChon
                          ? const Color(0xFF1B5E20)
                          : Colors.grey.shade600),
                  title: Text(_menu[i].$2,
                      style: TextStyle(
                          fontWeight: i == _mucDangChon
                              ? FontWeight.bold
                              : FontWeight.normal)),
                  selected: i == _mucDangChon, // mục đang mở được tô nền
                  selectedTileColor: const Color(0xFFE8F5E9),
                  onTap: () {
                    setState(() => _mucDangChon = i);
                    Navigator.pop(context); // đóng menu sau khi chọn
                  },
                ),
              ),
            ),
          ],
        ),
      ),

      // IndexedStack giữ trạng thái từng màn hình khi chuyển qua lại
      body: IndexedStack(index: _mucDangChon, children: _cacManHinh),
    );
  }
}
