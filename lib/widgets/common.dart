// ============================================================================
// common.dart - Các WIDGET & HÀM DÙNG CHUNG cho nhiều màn hình
// ----------------------------------------------------------------------------
// Nguyên tắc DRY (Don't Repeat Yourself): code dùng ở 2+ nơi thì tách ra đây
// để sửa 1 chỗ là mọi nơi thay đổi theo.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Định dạng số tiền kiểu Việt Nam: 15000 -> "15.000 đ"
String dinhDangTien(num soTien) {
  final f = NumberFormat.decimalPattern('vi_VN');
  return '${f.format(soTien)} đ';
}

/// Định dạng ngày: DateTime -> "21/07/2026"
String dinhDangNgay(DateTime ngay) {
  return DateFormat('dd/MM/yyyy').format(ngay);
}

/// Đổi mã trạng thái trong database -> chữ tiếng Việt hiển thị
String tenTrangThai(String trangThai) {
  switch (trangThai) {
    case 'cho_xac_nhan':
      return 'Chờ xác nhận';
    case 'da_xac_nhan':
      return 'Đã xác nhận';
    case 'hoan_tat':
      return 'Hoàn tất';
    case 'da_huy':
      return 'Đã hủy';
    default:
      return trangThai;
  }
}

/// Màu tương ứng với từng trạng thái (dùng thống nhất toàn app)
Color mauTrangThai(String trangThai) {
  switch (trangThai) {
    case 'cho_xac_nhan':
      return Colors.orange;
    case 'da_xac_nhan':
      return Colors.blue;
    case 'hoan_tat':
      return Colors.green;
    case 'da_huy':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

/// Chip nhỏ hiển thị trạng thái lịch với màu tương ứng
class ChipTrangThai extends StatelessWidget {
  final String trangThai;
  const ChipTrangThai({super.key, required this.trangThai});

  @override
  Widget build(BuildContext context) {
    final mau = mauTrangThai(trangThai);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: mau.withOpacity(0.15),          // nền nhạt
        borderRadius: BorderRadius.circular(20), // bo tròn
        border: Border.all(color: mau),
      ),
      child: Text(
        tenTrangThai(trangThai),
        style: TextStyle(color: mau, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ============================================================================
// PHẦN BỔ SUNG: nhãn TRẠNG THÁI THANH TOÁN (dùng chung khách + admin)
// ============================================================================

/// Đổi mã trạng thái thanh toán -> chữ tiếng Việt dễ đọc
String tenTrangThaiTT(String? trangThaiTT, String? phuongThuc) {
  switch (trangThaiTT) {
    case 'khach_bao_da_chuyen':
      return 'Khách báo đã chuyển khoản';
    case 'da_thanh_toan':
      return 'Đã thanh toán';
    default:
      // Chưa thanh toán: nói rõ thêm phương thức nếu khách đã chọn
      if (phuongThuc == 'tien_mat') return 'Trả tiền mặt khi thu gom';
      return 'Chưa thanh toán';
  }
}

/// Nhãn nhỏ hiển thị trạng thái thanh toán (xanh = xong, cam = chờ, xám = chưa)
class ChipThanhToan extends StatelessWidget {
  final String? trangThaiTT;
  final String? phuongThuc;
  const ChipThanhToan({super.key, this.trangThaiTT, this.phuongThuc});

  @override
  Widget build(BuildContext context) {
    final mau = switch (trangThaiTT) {
      'da_thanh_toan' => Colors.green,
      'khach_bao_da_chuyen' => Colors.orange,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: mau.withOpacity(0.12),          // nền nhạt
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: mau),        // viền cùng màu
      ),
      child: Text(
        '💰 ${tenTrangThaiTT(trangThaiTT, phuongThuc)}',
        style: TextStyle(fontSize: 12, color: mau, fontWeight: FontWeight.w600),
      ),
    );
  }
}
