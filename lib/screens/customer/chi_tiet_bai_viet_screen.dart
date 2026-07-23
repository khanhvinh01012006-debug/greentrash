// ============================================================================
// chi_tiet_bai_viet_screen.dart - Màn hình ĐỌC BÀI VIẾT đầy đủ
// ----------------------------------------------------------------------------
// Được mở khi khách bấm vào một bài ở khối "Tin tức" trang chủ.
// Bố cục giống trang báo: ảnh bìa to -> tiêu đề -> ngày đăng -> nội dung.
// ============================================================================

import 'package:flutter/material.dart';
import '../../widgets/common.dart';

class ChiTietBaiVietScreen extends StatelessWidget {
  final Map<String, dynamic> baiViet;

  const ChiTietBaiVietScreen({super.key, required this.baiViet});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bài viết')),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Ảnh bìa to (nếu có) ----
                if (baiViet['hinh_anh_url'] != null)
                  Image.network(
                    baiViet['hinh_anh_url'],
                    width: double.infinity,
                    height: 260,
                    fit: BoxFit.cover,
                    // Ảnh lỗi -> khung màu thay thế, app không bị vỡ
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: const Color(0xFFE8F5E9),
                      child: const Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              size: 48, color: Colors.grey)),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---- Tiêu đề ----
                      Text(
                        baiViet['tieu_de'],
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.3),
                      ),
                      const SizedBox(height: 8),

                      // ---- Ngày đăng ----
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            dinhDangNgay(
                                DateTime.parse(baiViet['ngay_dang'])),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      const Divider(height: 32),

                      // ---- Nội dung đầy đủ ----
                      // fontSize 16 + height 1.7: cỡ chữ và giãn dòng dễ đọc
                      Text(
                        baiViet['noi_dung'],
                        style: const TextStyle(fontSize: 16, height: 1.7),
                      ),
                    ],
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
